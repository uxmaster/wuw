#!/bin/sh
set -eu

base=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sh -n "$base/wuw"

set +e
help=$($base/wuw --help 2>&1)
help_status=$?
missing=$(WUW_COLOR=never "$base/wuw" enabla-wuw-missing-service 2>&1)
missing_status=$?
set -e

[ "$help_status" -eq 2 ]
printf '%s\n' "$help" | grep -q '^usage: wuw '
[ "$missing_status" -eq 4 ]
printf '%s\n' "$missing" | grep -q 'enabla-wuw-missing-service - not found'

echo 'wuw smoke test passed.'
