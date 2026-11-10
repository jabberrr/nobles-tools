#!/usr/bin/env bash
# Fails the build if the app calls Foundation's Date.<= or Date.>=. Both are @backDeployed, and
# iOS 27.2 beta claims a new enough Foundation without shipping them, so a call jumps to address 0
# and the app crashes (see "Never compare Dates with <= or >=" in CONTEXT.md).
#
# Usage: check-date-operators.sh <path to the built .app>
set -euo pipefail

app=$1
# The mangled names of Date.<= ("2leoi") and Date.>= ("2geoi"), and their back-deployment thunks.
pattern='4DateV2[lg]eoi'

# A one-line canary shows whether this SDK routes Date.<= through a back-deployment thunk at all,
# so the check can't pass just because the pattern stopped matching.
canary=$(mktemp -d)
printf 'import Foundation\npublic func canary(_ a: Date, _ b: Date) -> Bool { a <= b }\n' > "$canary/canary.swift"
xcrun --sdk iphonesimulator swiftc -target arm64-apple-ios17.0-simulator -c "$canary/canary.swift" -o "$canary/canary.o"
if ! nm -m "$canary/canary.o" | grep -qE "$pattern"; then
  echo "::warning::This SDK doesn't call a back-deployed Date.<=, so this check can't see the problem."
  exit 0
fi

found=$(find "$app" -type f | while read -r file; do
  if file -b "$file" | grep -q Mach-O; then
    nm -m "$file" 2>/dev/null | grep -E "$pattern" | sed "s|^|${file#"$app"/}: |" || true
  fi
done)
if [ -n "$found" ]; then
  echo "::error::The app calls Date.<= or Date.>=, which crash on iOS 27.2 beta. Use Date.isAtOrBefore(_:) or Date.later(_:) instead."
  echo "$found"
  exit 1
fi
echo "The app makes no calls to Date.<= or Date.>=."
