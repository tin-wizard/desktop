#!/usr/bin/env bash
# Classifies a change set for CI (adapted from the github-efficiency skill template).
# Reads changed paths (one per line) on stdin and prints:
#   code=true|false   run lint, type check, unit tests and the OS builds
# Fail-safe: an empty list or the sentinel "*" (unknown base) prints code=true.
set -euo pipefail

code=false
seen=0

# Changes that cannot affect lint, types, tests or the app build.
no_code_impact() {
  case "$1" in
    # The CI workflow and the test action are what CI runs, so they count as code.
    .github/workflows/ci.yaml | .github/actions/*) return 1 ;;
    *.md | docs/* | LICENSE* | NOTICE* | .github/workflows/* | .github/ISSUE_TEMPLATE/* | .github/*.md | .githooks/*) return 0 ;;
  esac
  return 1
}

while IFS= read -r path || [[ -n "$path" ]]; do
  [[ -z "$path" ]] && continue
  seen=1
  if [[ "$path" == "*" ]] || ! no_code_impact "$path"; then
    code=true
  fi
done

[[ "$seen" -eq 0 ]] && code=true
printf 'code=%s\n' "$code"
