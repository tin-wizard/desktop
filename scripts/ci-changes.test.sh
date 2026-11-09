#!/usr/bin/env bash
# One row per rule of scripts/ci-changes.sh. Run: bash scripts/ci-changes.test.sh
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0

check() { # expected, then changed paths
  local want="$1"; shift
  local got
  got="$(printf '%s\n' "$@" | bash scripts/ci-changes.sh)"
  if [[ "$got" != "code=$want" ]]; then
    echo "FAIL: [$*] gave '$got', want code=$want"; fail=1
  fi
}

check true   ''                                    # empty diff runs everything
check true   '*'                                   # unknown base runs everything
check true   'src/main/app.ts'
check true   'package.json'
check true   '.github/workflows/ci.yaml'           # CI itself
check true   '.github/actions/test/action.yaml'    # used by CI
check true   'README.md' 'src/common/config/buildConfig.ts'  # mixed
check false  'README.md'
check false  'docs/setup.md' 'CHANGELOG.md'
check false  '.github/workflows/release.yaml'
check false  '.github/workflows/upstream-sync.yml'
check false  'LICENSE.txt'
check false  '.githooks/pre-push'

# The gates in ci.yaml must fail closed: an empty output has to run the jobs.
wf=.github/workflows/ci.yaml
if grep -q "outputs.code == 'true'" "$wf"; then
  echo "FAIL: $wf gates on == 'true' (fails open); use != 'false'"; fail=1
fi
gates="$(grep -c "needs.changes.outputs.code != 'false'" "$wf" || true)"
if [[ "$gates" -lt 5 ]]; then
  echo "FAIL: $wf has $gates fail-closed gates, want 5 (linux, windows deps, windows, mac, report)"; fail=1
fi

[[ "$fail" -eq 0 ]] && echo "ci-changes: all rows pass"
exit "$fail"
