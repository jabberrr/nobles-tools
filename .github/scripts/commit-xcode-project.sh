#!/usr/bin/env bash
# Commits the Xcode project that XcodeGen generated from project.yml to the given branch, so a
# pull is all it takes to open the app. If the branch moves while CI runs, this regenerates the
# project from the new tip and retries, rather than replaying one generated from an older tree.
set -euo pipefail

branch=$1
git config user.name "github-actions[bot]"
git config user.email "41898099+github-actions[bot]@users.noreply.github.com"

# Commits whatever generation changed; returns non-zero when nothing did.
commit_generated() {
  git add -A
  git diff --cached --quiet && return 1
  git status --short
  git commit -qm "Regenerate Xcode project from project.yml"
}

if ! commit_generated; then
  echo "The committed Xcode project is up to date."
  exit 0
fi

for attempt in 1 2 3; do
  # The lease refuses to push over a branch that moved, or to recreate one deleted mid-run.
  if git push --force-with-lease="refs/heads/$branch:$(git rev-parse HEAD~1)" origin "HEAD:refs/heads/$branch"; then
    exit 0
  fi
  if ! git fetch origin "$branch"; then
    echo "$branch no longer exists; nothing to update."
    exit 0
  fi
  echo "$branch moved during the run; regenerating from its new tip (attempt $attempt)."
  git reset -q --hard FETCH_HEAD
  xcodegen generate
  if ! commit_generated; then
    echo "The new tip's Xcode project is already up to date."
    exit 0
  fi
done

echo "::error::Couldn't push the regenerated Xcode project to $branch."
exit 1
