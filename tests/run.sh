#!/usr/bin/env bash
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
failures=0

run_test() {
  local file=$1
  printf '\n== %s ==\n' "${file#$ROOT/}"
  if ! bash "$file"; then
    printf 'FAILED: %s\n' "$file" >&2
    failures=$((failures + 1))
  fi
}

run_test "$ROOT/tests/regression.sh"
for file in "$ROOT"/tests/test_*.sh; do
  [ -f "$file" ] && run_test "$file"
done

if [ "$failures" -ne 0 ]; then
  printf '\n%d test file(s) failed\n' "$failures" >&2
  exit 1
fi
printf '\nALL TESTS PASSED\n'
