#!/usr/bin/env bash
set -u
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export ROOT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

assert_eq() {
  [ "$1" = "$2" ] || fail "expected [$2], got [$1]${3:+ ($3)}"
}

assert_contains() {
  case "$1" in
    *"$2"*) ;;
    *) fail "missing [$2] in [$1]" ;;
  esac
}

assert_file() {
  [ -f "$1" ] || fail "missing file: $1"
}

assert_no_file() {
  [ ! -e "$1" ] || fail "unexpected file: $1"
}

make_tmp() {
  mktemp -d "${TMPDIR:-/tmp}/vps-guard-test.XXXXXX"
}

skip() {
  printf 'SKIP: %s\n' "$*"
  exit 0
}
