#!/usr/bin/env bash
set -Eeuo pipefail

runtime_env=/etc/hermes-unsafe-vm/runtime.env
if [[ -r $runtime_env ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$runtime_env"
  set +a
fi
cdp_port=${HERMES_CDP_PORT:-9222}
profile_dir=${HERMES_CHROMIUM_PROFILE_DIR:-$HOME/.local/share/hermes-unsafe-vm/chromium-profile}
env_file=${HERMES_GRAPHICAL_ENV_FILE:-$HOME/.config/hermes-unsafe-vm/graphical-session.env}
[[ $cdp_port =~ ^[0-9]+$ ]] && ((10#$cdp_port >= 1 && 10#$cdp_port <= 65535)) || exit 1
[[ -n ${DISPLAY:-} && -n ${DBUS_SESSION_BUS_ADDRESS:-} ]] || exit 1
umask 077
install -d -m 0700 "$profile_dir" "$(dirname -- "$env_file")"
{
  printf 'DISPLAY=%s\n' "$DISPLAY"
  [[ -n ${XAUTHORITY:-} ]] && printf 'XAUTHORITY=%s\n' "$XAUTHORITY"
  printf 'XDG_RUNTIME_DIR=%s\n' "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  printf 'DBUS_SESSION_BUS_ADDRESS=%s\n' "$DBUS_SESSION_BUS_ADDRESS"
  printf 'XDG_SESSION_TYPE=%s\n' "${XDG_SESSION_TYPE:-x11}"
} >"$env_file"
if pgrep -u "$(id -u)" -f -- "$profile_dir" >/dev/null 2>&1; then exit 0; fi
exec /usr/bin/chromium \
  --remote-debugging-address=127.0.0.1 \
  --remote-debugging-port="$cdp_port" \
  --user-data-dir="$profile_dir" \
  --no-first-run --no-default-browser-check
