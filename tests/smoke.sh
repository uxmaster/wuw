#!/bin/sh
set -eu

base=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sh -n "$base/wuw"
bash -n "$base/completions/bash/wuw"

root=$(mktemp -d "${TMPDIR:-/tmp}/wuw-smoke.XXXXXX")
root=$(CDPATH= cd -- "$root" && pwd -P)
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

printf '1607\n' >"$root/plain.pid"
printf '  1608 extra fields\n' >"$root/decorated.pid"
[ "$(read_pidfile "$root/plain.pid")" = 1607 ]
[ "$(read_pidfile "$root/decorated.pid")" = 1608 ]

mkdir -p "$root/run/php" "$root/proc/1618"
printf '1618\n' >"$root/run/php/php8.4-fpm.pid"
WUW_ROOT=$root WUW_PROC_ROOT=$root/proc
export WUW_ROOT WUW_PROC_ROOT
[ "$(pid_from_pidfile php8.4-fpm)" = 1618 ]
unset WUW_ROOT WUW_PROC_ROOT

# The directory referenced by the supervised service link is authoritative,
# even if a different definition with the same name exists under /etc/sv.
mkdir -p "$root/usr/share/runit/sv.now/exim4" "$root/etc/sv/exim4"
ln -s ../../usr/share/runit/sv.now/exim4 "$root/etc/service/exim4"
[ "$(resolve_runit_unit_path exim4 "$root/etc/service/exim4")" = \
    "$root/usr/share/runit/sv.now/exim4" ]

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

# Only completed rotations belong in the pager, ordered newest first.
logdir=$root/var/log/runit/proxy
older=$logdir/@400000000000000000000001.s
newer=$logdir/@400000000000000000000002.s
printf 'older log\n' >"$older"
printf 'newer log\n' >"$newer"
: >"$logdir/lock"
: >"$logdir/config"
: >"$logdir/@400000000000000000000003.t"
mkdir "$logdir/@400000000000000000000004.s"

# Exercise the CLI without invoking real sudo or a service status command.
output=$(
    set +e
    id() { printf '0\n'; }
    set -- proxy.service l
    . "$base/wuw"
)
[ "$output" = "active runit log
newer log
older log" ]

mkdir "$root/bin"
cat >"$root/bin/less" <<'EOF'
#!/bin/sh
printf 'secure=%s allow=%s config=%s\n' "$LESSSECURE" "$LESSSECURE_ALLOW" "$LESSNOCONFIG"
printf '%s\n' "$@"
exit "${WUW_LESS_STATUS:-0}"
EOF
cat >"$root/bin/sudo" <<'EOF'
#!/bin/sh
printf '%s\n' "$@"
EOF
chmod +x "$root/bin/less" "$root/bin/sudo"
PATH=$root/bin:$PATH
SVC=proxy
UNIT_PATH=
output=$(LESSSECURE_ALLOW=shell LESSNOCONFIG=- page_logs)
[ "$output" = "secure=1 allow= config=
-n
--follow-name
++G
--
$logdir/current
$newer
$older" ]
rm "$older" "$newer"
output=$(page_logs)
[ "$output" = "secure=1 allow= config=
-n
--follow-name
++G
--
$logdir/current" ]

mkdir -p "$root/var/log/web"
printf 'web error\n' >"$root/var/log/web/error.log"
output=$(SVC=web page_logs)
[ "$output" = "secure=1 allow= config=
-n
--follow-name
++G
--
$root/var/log/web/error.log" ]

if (SVC=missing page_logs) >"$root/output" 2>"$root/error"; then
    echo 'missing logs must fail' >&2
    exit 1
else
    [ "$?" -eq 1 ]
fi
grep -q 'no readable per-service log for missing' "$root/error"
if (WUW_LESS_STATUS=7 page_logs) >"$root/output"; then
    echo 'pager failures must be returned' >&2
    exit 1
else
    [ "$?" -eq 7 ]
fi

output=$(
    id() { printf '1000\n'; }
    LOG_MODE=l LINES=30 run_as_root
)
[ "$output" = "--
$base/tests/smoke.sh
-n
30
proxy
l" ]
unset WUW_ROOT

for args in 'proxy x' 'proxy l extra' '-n nope proxy l'; do
    if "$base/wuw" $args >"$root/output" 2>&1; then
        echo "invalid arguments must fail: $args" >&2
        exit 1
    else
        [ "$?" -eq 2 ]
    fi
done

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
