#!/usr/bin/env bash
# Syntax-check (and shellcheck, if installed) every bash script in this repo.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0

scripts=(
  "$ROOT/bootstrap.sh"
  "$ROOT/lib/common.sh"
  "$ROOT/scripts/check.sh"
)

for f in "$ROOT/modules/"*.sh; do
  [ -f "$f" ] && scripts+=("$f")
done

echo "==> bash -n"
for f in "${scripts[@]}"; do
  if ! bash -n "$f"; then
    echo "syntax error: $f" >&2
    fail=1
  else
    echo "    ok  ${f#"$ROOT/"}"
  fi
done

if ! bash -n "$ROOT/config/config.example.sh"; then
  echo "syntax error: config/config.example.sh" >&2
  fail=1
else
  echo "    ok  config/config.example.sh"
fi

if command -v shellcheck >/dev/null 2>&1; then
  echo "==> shellcheck"
  if ! shellcheck --shell=bash --external-sources \
    "$ROOT/bootstrap.sh" \
    "$ROOT/lib/common.sh" \
    "$ROOT/scripts/check.sh" \
    "$ROOT/modules/"*.sh \
    "$ROOT/config/config.example.sh"; then
    fail=1
  fi
else
  echo "==> shellcheck not installed (skip)"
fi

if [ "$fail" -ne 0 ]; then
  echo "check failed" >&2
  exit 1
fi

echo "all checks passed"
