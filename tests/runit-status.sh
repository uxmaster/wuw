#!/bin/sh
set -eu

base=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WUW_TEST_SOURCE_ONLY=1 . "$base/wuw"
WUW_COLOR=always setup_colors
pid_since_tail() { :; }

check_status() {
    set_runit_status "$1"
    actual="$ACTIVE_STATE|$WANTED_STATE$WANTED_TAIL|$PID|$SECS|$EXIT_CODE"
    if [ "$actual" != "$2" ]; then
        printf 'status: %s\nexpected: %s\nactual: %s\n' "$1" "$2" "$actual" >&2
        exit 1
    fi
    [ "$DOT_COLOR" = "$3" ]
    [ "$DOT_BLINK" = "$4" ]
    # Only the header dot receives blink; Active and Wanted text stays steady.
    case "$ACTIVE_COLOR$ACTIVE_TAIL$WANTED_TAIL" in *"$BLINK"*) exit 1 ;; esac
}

check_status 'run: ssh: (pid 101) 200s; run: log: (pid 999) 900s' \
    'active (running)|up|101|200|0' "$GREEN" ''
[ "$ACTIVE_TAIL" = '; running for 200s' ]

check_status 'down: ssh: 8s, normally up, want up; run: log: (pid 999) 900s' \
    'inactive (starting)|up||8|3' "$RED" "$BLINK"
[ "$ACTIVE_TAIL" = '; down for 8s' ]

check_status 'run: ssh: (pid 101) 200s, want down, got TERM' \
    'active (stopping)|down|101|200|0' "$GREEN" "$BLINK"
[ "$ACTIVE_TAIL" = '; running for 200s' ]

check_status 'run: ssh: (pid 101) 200s, got TERM; down: log: 7s, want up' \
    'active (restarting)|up|101|200|0' "$GREEN" "$BLINK"

check_status 'run: rc.local: (pid 101) 2s, want down' \
    'active (running)|down (no restart)|101|2|0' "$GREEN" ''

# This is the rc.local status seen on the target host. normally up is the
# boot default, whereas absence of want up means it now wants to stay down.
check_status 'down: /etc/service/rc.local: 500s, normally up; run: log: (pid 1761) 513s' \
    'inactive (stopped)|down||500|3' "$GREY" ''
[ "$ACTIVE_TAIL" = '; down for 500s' ]

check_status 'down: ssh: 12s; down: log: 300s, normally up, want up' \
    'inactive (stopped)|down||12|3' "$GREY" ''

check_status 'run: ssh: (pid 101) 200s, normally down' \
    'active (running)|up|101|200|0' "$GREEN" ''

check_status 'run: ssh: (pid 101) 200s, paused' \
    'active (running)|up|101|200|0' "$GREEN" ''
[ "$ACTIVE_TAIL" = '; running for 200s; paused' ]

check_status 'finish: ssh: (pid 202) 3s, want down; run: log: (pid 999) 900s' \
    'inactive (stopping; finish script)|down|202|3|3' "$GREEN" "$BLINK"
[ "$ACTIVE_TAIL" = '; finishing for 3s' ]

check_status 'finish: ssh: (pid 202) 4s; run: log: (pid 999) 900s, want down, got TERM' \
    'inactive (starting; finish script)|up|202|4|3' "$RED" "$BLINK"

check_status 'down: web:blue: 15s, normally up, want up' \
    'inactive (starting)|up||15|3' "$RED" "$BLINK"

check_status 'warning: ssh: unable to open supervise/ok: access denied' \
    'unknown||||3' "$RED" ''
check_status 'run: malformed' 'unknown||||3' "$RED" ''

WUW_COLOR=never setup_colors
pid_since_tail() { printf ' since mocked'; }
set_runit_status 'down: ssh: 8s, normally up, want up'
[ "$ACTIVE_STATE" = 'inactive (starting)' ]
[ -z "$DOT_COLOR$DOT_BLINK$ACTIVE_COLOR" ]
WUW_COLOR=auto NO_COLOR=1 setup_colors
set_runit_status 'run: ssh: (pid 101) 200s, want down, got TERM'
[ "$ACTIVE_STATE" = 'active (stopping)' ]
[ -z "$DOT_COLOR$DOT_BLINK$ACTIVE_COLOR" ]
[ "$ACTIVE_TAIL" = '; running for 200s' ]

echo 'wuw runit status test passed.'
