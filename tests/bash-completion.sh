#!/bin/bash
set -eu

base=$(cd -- "$(dirname -- "$0")/.." && pwd)
. "$base/completions/bash/wuw"

_wuw_service_names() { printf '%s\n' sshguard sysinfo; }

COMP_WORDS=(wuw s)
COMP_CWORD=1
_wuw
[[ ${COMPREPLY[*]} == 'sshguard sysinfo' ]]

COMP_WORDS=(wuw -n '')
COMP_CWORD=2
_wuw
(( ${#COMPREPLY[@]} == 0 ))

COMP_WORDS=(wuw -n 20 s)
COMP_CWORD=3
_wuw
[[ ${COMPREPLY[*]} == 'sshguard sysinfo' ]]

COMP_WORDS=(wuw sshguard '')
COMP_CWORD=2
_wuw
(( ${#COMPREPLY[@]} == 0 ))

COMP_WORDS=(wuw --list-services '')
COMP_CWORD=2
_wuw
(( ${#COMPREPLY[@]} == 0 ))
