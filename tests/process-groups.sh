#!/bin/sh
set -eu

base=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WUW_TEST_SOURCE_ONLY=1 . "$base/wuw"
root=$(mktemp -d "${TMPDIR:-/tmp}/wuw-process-groups.XXXXXX")
cleanup() { rm -rf "$root"; }
trap cleanup EXIT HUP INT TERM
WUW_PROC_ROOT=$root
export WUW_PROC_ROOT
PID=1766
SVC=sshguard
# Missing fixture processes must not pick up names from the test host.
ps() { return 1; }

process() {
    mkdir -p "$root/$1"
    printf 'Pid:\t%s\nPPid:\t%s\n' "$1" "$2" >"$root/$1/status"
    printf '%s (odd ) name) S %s %s 1 0\n' "$1" "$2" "$3" >"$root/$1/stat"
    printf '%s\000' "$4" >"$root/$1/cmdline"
    printf '%s\n' "${5:-$4}" >"$root/$1/comm"
}

# runsv and svlogd share a group; chpst -P isolates the service from them.
process 100 1 100 runsv
process 101 100 100 svlogd
process 1766 100 1766 '/bin/sh /usr/sbin/sshguard' sshguard
process 1965 1766 1766 '/usr/libexec/sshg-blocker' sshg-blocker
process 1966 1766 1766 '/usr/libexec/sshg-parser' sshg-parser
# Sharing the service's PGID does not make an unrelated process its child.
process 9999 1 1766 unrelated
PIDS=$(descendant_pids 1766)
[ "$PIDS" = "1766
1965
1966" ]
[ "$(process_pgid 1766)" = 1766 ]
[ "$(print_process_tree)" = '             └─1766 /bin/sh /usr/sbin/sshguard
               ├─1965 /usr/libexec/sshg-blocker
               └─1966 /usr/libexec/sshg-parser' ]

# The leader is represented once, even when it is the only or last member.
[ "$(PIDS=1766 print_process_tree)" = '             └─1766 /bin/sh /usr/sbin/sshguard' ]
[ "$(PIDS='1965 1966 1766' print_process_tree)" = '             └─1766 /bin/sh /usr/sbin/sshguard
               ├─1965 /usr/libexec/sshg-blocker
               └─1966 /usr/libexec/sshg-parser' ]

# A descendant can create another group; later members still join their PGID.
process 1965 1766 1965 '/usr/libexec/sshg-blocker' sshg-blocker
[ "$(print_process_tree)" = '             ├─1766 /bin/sh /usr/sbin/sshguard
             │ └─1966 /usr/libexec/sshg-parser
             └─1965 /usr/libexec/sshg-blocker' ]

# A disappearing or unreadable stat must not inherit the preceding PGID.
rm "$root/1965/stat"
printf '1966 (truncated) S 1766\n' >"$root/1966/stat"
if process_pgid 1965 || process_pgid 1966; then
    echo 'missing or truncated stat must not produce a PGID' >&2
    exit 1
fi
[ "$(print_process_tree)" = '             ├─1766 /bin/sh /usr/sbin/sshguard
             ├─1965 /usr/libexec/sshg-blocker
             └─1966 /usr/libexec/sshg-parser' ]

# Ordinary services keep a flat display. The supervisor's
# PGID need not be its PID, and two services can share it without sharing PIDs.
process 100 1 40 runsv
process 1734 100 40 'nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx.conf -g daemon off;' nginx
process 2204 1734 40 'nginx: worker process' nginx
PID=1734
SVC=nginx
PIDS=$(descendant_pids "$PID")
[ "$PIDS" = "1734
2204" ]
flat='             ├─1734 nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx.conf -g daemon off;
             └─2204 nginx: worker process'
[ "$(print_process_tree)" = "$flat" ]

# A service can mix inherited-group processes and a separate named group.
process 2204 1734 2204 'nginx: worker process' nginx
[ "$(print_process_tree)" = '             ├─1734 nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx.conf -g daemon off;
             └─2204 nginx: worker process' ]

# The label follows the leader; after it exits, use a surviving member's command.
process 3300 1 3300 helper
process 2204 1734 3300 'nginx: worker process' nginx
[ "$(print_process_tree)" = '             ├─1734 nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx.conf -g daemon off;
             └─3300 helper
               └─2204 nginx: worker process' ]
rm -r "$root/3300"
[ "$(print_process_tree)" = '             ├─1734 nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx.conf -g daemon off;
             └─3300 nginx: worker process
               └─2204 nginx: worker process' ]

rm "$root/2204/cmdline"
[ "$(print_process_tree)" = '             ├─1734 nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx.conf -g daemon off;
             └─3300 nginx
               └─2204 [2204]' ]
rm "$root/2204/comm"
SVC=nginx-service
[ "$(print_process_tree)" = '             ├─1734 nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx.conf -g daemon off;
             └─3300 nginx-service
               └─2204 [2204]' ]

# Missing parent metadata falls back to the main group without adding noise.
process 2204 1734 40 'nginx: worker process' nginx
rm "$root/100/stat"
[ "$(print_process_tree)" = "$flat" ]
rm "$root/100/status"
[ "$(print_process_tree)" = "$flat" ]
[ -z "$(PIDS= print_process_tree)" ]

echo 'wuw process groups test passed.'
