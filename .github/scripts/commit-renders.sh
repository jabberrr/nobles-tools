#!/usr/bin/env bash
# Commits the widget renders in docs/widgets to the given branch, if they changed. Anything else
# the run touched (such as the regenerated Xcode project, which CI commits) is left out.
set -euo pipefail

branch=$1
git config user.name "github-actions[bot]"
git config user.email "41898099+github-actions[bot]@users.noreply.github.com"

git add -A docs/widgets
if git diff --cached --quiet; then
  echo "The widget renders are unchanged."
  exit 0
fi
git commit -qm "Render widget previews"
git reset -q --hard HEAD

for attempt in 1 2 3; do
  git push origin "HEAD:refs/heads/$branch" && exit 0
  echo "$branch moved during the run; replaying the renders on its new tip (attempt $attempt)."
  git pull -q --rebase origin "$branch"
done

echo "::error::Couldn't push the widget renders to $branch."
exit 1
