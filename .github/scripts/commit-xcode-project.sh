#!/usr/bin/env bash
# Commits the Xcode project that XcodeGen generated from project.yml to the given branch, so a
# pull is all it takes to open the app. If the branch moves while CI runs, this regenerates the
# project from the new tip and retries, rather than replaying one generated from an older tree.
#
# Usage: commit-xcode-project.sh <branch> [<commit before the push>]
# With the second argument, a push that edited the generated files directly fails after the
# regenerated project replaces them, so those edits aren't lost silently.
set -euo pipefail

branch=$1
before=${2:-}
generated=(NoblesTools.xcodeproj '*.entitlements' '*Info.plist')
git config user.name "github-actions[bot]"
git config user.email "41898099+github-actions[bot]@users.noreply.github.com"

# Whether the pushed commits themselves changed generated files.
push_edited_generated_files() {
  [[ -n $before && ! $before =~ ^0+$ ]] || return 1
  git fetch -q --depth=1 origin "$before" 2>/dev/null || return 1
  ! git diff --quiet "$before" HEAD -- "${generated[@]}"
}

# Commits whatever generation changed; returns non-zero when nothing did.
commit_generated() {
  git add -A
  git diff --cached --quiet && return 1
  git status --short
  git commit -qm "Regenerate Xcode project from project.yml"
}

hand_edited=false
push_edited_generated_files && hand_edited=true

if ! commit_generated; then
  echo "The committed Xcode project is up to date."
  exit 0
fi

pushed=false
for attempt in 1 2 3; do
  # The lease refuses to push over a branch that moved, or to recreate one deleted mid-run.
  if git push --force-with-lease="refs/heads/$branch:$(git rev-parse HEAD~1)" origin "HEAD:refs/heads/$branch"; then
    pushed=true
    break
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

if ! $pushed; then
  echo "::error::Couldn't push the regenerated Xcode project to $branch."
  exit 1
fi

if $hand_edited; then
  echo "This push edited generated project files directly. The regenerated project replaced these lines:"
  git diff HEAD~1 HEAD -- "${generated[@]}" | grep -E '^-[^-]' || true
  echo "::error::NoblesTools.xcodeproj was edited directly, and regenerating it from project.yml replaced those edits (listed in this step's log). Put build settings in project.yml or Config/Signing.xcconfig instead. If you only added or removed files, nothing was lost: the regenerated project includes them."
  exit 1
fi
