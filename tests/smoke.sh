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

WUW_TEST_SOURCE_ONLY=1 . "$base/wuw"
mkdir -p "$root/proc/101" "$root/proc/102"
cat >"$root/proc/101/status" <<'EOF'
VmRSS:        2000 kB
VmPTE:          40 kB
EOF
cat >"$root/proc/101/smaps_rollup" <<'EOF'
Rss:          2000 kB
Pss:          1000 kB
EOF
cat >"$root/proc/102/status" <<'EOF'
VmRSS:        1000 kB
VmPTE:          20 kB
EOF
cat >"$root/proc/102/smaps_rollup" <<'EOF'
Rss:          1000 kB
Pss:           500 kB
EOF
PIDS='101 102'
WUW_PROC_ROOT=$root/proc
export WUW_PROC_ROOT
[ "$(measure_memory_kb)" = '1560 estimated' ]
rm "$root/proc/102/smaps_rollup"
[ "$(measure_memory_kb)" = '3000 RSS' ]
unset WUW_PROC_ROOT WUW_TEST_SOURCE_ONLY

mkdir -p "$root/var/log/proxy" "$root/var/log/runit/proxy"
: >"$root/var/log/proxy/current"
printf 'active runit log\n' >"$root/var/log/runit/proxy/current"
WUW_ROOT=$root
export WUW_ROOT
[ "$(find_log_file proxy '')" = "$root/var/log/runit/proxy/current" ]
unset WUW_ROOT

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
