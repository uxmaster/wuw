#!/bin/sh
set -eu

base=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sh -n "$base/wuw"
bash -n "$base/completions/bash/wuw"

root=$(mktemp -d "${TMPDIR:-/tmp}/wuw-smoke.XXXXXX")
cleanup() { rm -rf "$root"; }
trap cleanup EXIT HUP INT TERM
mkdir -p "$root/etc/service" "$root/etc/sv" "$root/etc/init.d"
mkdir "$root/etc/service/sshguard" "$root/etc/sv/garbd"
touch "$root/etc/init.d/mysql" "$root/etc/init.d/README"
chmod +x "$root/etc/init.d/mysql"
services=$(WUW_ROOT=$root "$base/wuw" --list-services)
[ "$services" = "garbd
mysql
sshguard" ]

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
bash "$base/tests/bash-completion.sh"

echo 'wuw smoke test passed.'
