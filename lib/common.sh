#!/usr/bin/env bash
set -u
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

have() { command -v "$1" >/dev/null 2>&1; }
root_required() { [ "$(id -u)" -eq 0 ] || { echo 'Root privileges required.' >&2; return 1; }; }
run_quiet() { "$@" 2>/dev/null; }
