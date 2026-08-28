#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

require_root
HERMES_USER=${HERMES_USER:-hermes}
home=$(hermes_home_for_user "$HERMES_USER")
mode=full
if [[ $# -eq 1 && $1 == --kernel-only ]]; then
  mode=kernel-only
elif [[ $# -ne 0 ]]; then
  die 'usage: validate-input.sh [--kernel-only]'
fi

input_devices=/proc/bus/input/devices
[[ -r $input_devices ]] || die 'Linux input device inventory is unavailable'

pointer_record=$(awk '
function flush_record() {
  if (!done && name != "" && has_mouse_handler && has_event_handler) {
    print name "\t" event_handler
    found = 1
    done = 1
  }
}
/^I: / {
  flush_record()
  name = ""
  event_handler = ""
  has_mouse_handler = 0
  has_event_handler = 0
}
/^N: Name=/ {
  name = $0
  sub(/^N: Name="/, "", name)
  sub(/"$/, "", name)
}
/^H: Handlers=/ {
  handlers = $0
  sub(/^H: Handlers=/, "", handlers)
  handler_count = split(handlers, handler_names, /[[:space:]]+/)
  for (i = 1; i <= handler_count; i++) {
    if (handler_names[i] ~ /^mouse[0-9]*$/) {
      has_mouse_handler = 1
    }
    if (handler_names[i] ~ /^event[0-9]+$/) {
      event_handler = handler_names[i]
      has_event_handler = 1
    }
  }
}
END {
  flush_record()
  exit !found
}' "$input_devices") || die 'no event-backed Linux pointer device is enumerated'

pointer_name=${pointer_record%%$'\t'*}
pointer_event=${pointer_record#*$'\t'}
[[ -n $pointer_name && $pointer_event =~ ^event[0-9]+$ ]] || die 'Linux pointer record is malformed'
[[ -c /dev/input/$pointer_event ]] || die "Linux pointer event node is missing: /dev/input/$pointer_event"
printf '%s\n' "KERNEL_POINTER=PASS DEVICE=$pointer_name EVENT=$pointer_event" \
  "INPUT_EVENT=PASS PATH=/dev/input/$pointer_event"

[[ $mode == full ]] || exit 0

command -v pgrep >/dev/null 2>&1 || die 'pgrep is required for graphical input validation'
command -v xinput >/dev/null 2>&1 || die 'xinput is required for graphical input validation'
uid=$(id -u "$HERMES_USER")
session_pid=$(pgrep -u "$uid" -n xfce4-session || true)
[[ -n $session_pid ]] || die 'XFCE session is unavailable for graphical input validation'
session_environ=$(tr '\0' '\n' < "/proc/$session_pid/environ")
session_value() {
  local key=$1
  awk -F= -v expected="$key" '$1 == expected { sub(/^[^=]*=/, ""); print; exit }' <<<"$session_environ"
}
display=$(session_value DISPLAY)
xauthority=$(session_value XAUTHORITY)
runtime_dir=$(session_value XDG_RUNTIME_DIR)
dbus_address=$(session_value DBUS_SESSION_BUS_ADDRESS)
[[ -n $display && -n $xauthority && -n $runtime_dir && -n $dbus_address ]] || \
  die 'graphical session environment is incomplete'

user_env=(
  HOME="$home"
  PATH="$home/.local/bin:$home/.hermes/node/bin:/usr/local/bin:/usr/bin:/bin"
  DISPLAY="$display"
  XAUTHORITY="$xauthority"
  XDG_RUNTIME_DIR="$runtime_dir"
  DBUS_SESSION_BUS_ADDRESS="$dbus_address"
)
xinput_output=$(runuser -u "$HERMES_USER" -- env "${user_env[@]}" xinput list 2>&1) || \
  die 'X11 input inventory is unavailable'
x11_pointer=$(awk '
/Virtual core pointer/ { in_pointer = 1; next }
/Virtual core keyboard/ { in_pointer = 0 }
in_pointer && /slave[[:space:]]+pointer/ && $0 !~ /XTEST/ { print; exit }
' <<<"$xinput_output")
[[ -n $x11_pointer ]] || die 'X11 has no non-XTEST slave pointer'
printf '%s\n' "X11_POINTER=PASS DEVICE=$x11_pointer"

hermes_bin="$home/.local/bin/hermes"
[[ -x $hermes_bin ]] || die 'Hermes binary is unavailable for CUA input validation'
cua_output=$(runuser -u "$HERMES_USER" -- env "${user_env[@]}" \
  "$hermes_bin" computer-use doctor 2>&1) || die 'CUA doctor failed'
grep -Fq 'X11 reachable' <<<"$cua_output" || die 'CUA does not report X11 reachability'
grep -Fq 'input will work' <<<"$cua_output" || die 'CUA does not report X11 input injection capability'
grep -Fq 'screen capture path is functional' <<<"$cua_output" || die 'CUA screen capture capability is unavailable'
printf '%s\n' 'CUA_INPUT=PASS X11_INPUT_INJECTION=AVAILABLE SCREEN_CAPTURE=PASS'
