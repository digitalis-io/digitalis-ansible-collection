#!/usr/bin/env bash
# Runs scripts/check-specs.py on each fixture root. A pass-* root must pass;
# a fail-* root must exit 1 and name the expected gap.
set -euo pipefail
cd "$(dirname "$0")"
checker=../../scripts/check-specs.py
status=0

expected() {
  case "$1" in
    fail-missing-type) echo "has no type" ;;
    fail-missing-description) echo "has no description" ;;
    fail-default-mismatch) echo "differs from defaults/" ;;
    fail-undocumented-variable) echo "not in the spec" ;;
    fail-missing-default) echo "neither a default nor required" ;;
  esac
}

for dir in pass-* fail-*; do
  [ -d "$dir" ] || continue
  if out=$("$checker" "$dir"); then rc=0; else rc=$?; fi
  case "$dir" in
    pass-*)
      if [ "$rc" -ne 0 ]; then echo "FAIL $dir: expected pass"; echo "$out"; status=1; else echo "ok   $dir"; fi ;;
    fail-*)
      if [ "$rc" -ne 1 ] || ! grep -q -- "$(expected "$dir")" <<<"$out"; then
        echo "FAIL $dir: expected a failure containing '$(expected "$dir")'"; echo "$out"; status=1
      else echo "ok   $dir"; fi ;;
  esac
done
exit "$status"
