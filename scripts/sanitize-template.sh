#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

require_root
[[ ${1:-} == --yes && $# -eq 1 ]] || die 'sanitization requires exactly --yes on a project-created disposable VM'
[[ -f /etc/hermes-unsafe-vm/managed ]] || die 'refusing to sanitize an unmarked VM'
HERMES_USER=${HERMES_USER:-hermes}
home=$(hermes_home_for_user "$HERMES_USER")
uid=$(id -u "$HERMES_USER")
runtime_dir=/run/user/$uid
if [[ -S "$runtime_dir/bus" ]]; then
  runuser -u "$HERMES_USER" -- env HOME="$home" XDG_RUNTIME_DIR="$runtime_dir" DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus" systemctl --user stop hermes-gateway.service hermes-vault-maintenance.timer >/dev/null 2>&1 || true
fi
profile_dir="$home/.local/share/hermes-unsafe-vm/chromium-profile"
pkill -u "$HERMES_USER" -f -- "$profile_dir" >/dev/null 2>&1 || true
rm -rf -- "$profile_dir"
for runtime_dir in "$home/.hermes/vault" "$home/.hermes/sessions" "$home/.hermes/memories"; do
  if [[ -d $runtime_dir ]]; then
    find "$runtime_dir" -mindepth 1 -delete
  fi
done
rm -f -- "$home/.hermes/.env" "$home/.hermes/auth.json" "$home/.codex/auth.json" "$home/.config/codex/auth.json" "$home/.bash_history" "$home/.zsh_history"
find "$home" -type f \( -name '*.pem' -o -name '*.key' -o -name 'id_*' \) -delete
find /var/lib/dhcp -maxdepth 1 -type f -delete 2>/dev/null || true
find /var/log/journal -mindepth 1 -delete 2>/dev/null || true
rm -f -- /tmp/hermes-unsafe-vm-health.out
find /tmp -xdev -user "$HERMES_USER" -mindepth 1 -maxdepth 1 -delete 2>/dev/null || true
find /var/tmp -xdev -user "$HERMES_USER" -mindepth 1 -maxdepth 1 -delete 2>/dev/null || true
find /etc/ssh -maxdepth 1 -type f -name 'ssh_host_*' -delete
truncate -s 0 /etc/machine-id
chown "$HERMES_USER:$HERMES_USER" "$home"
printf '%s\n' 'TEMPLATE_SANITIZE=PASS' 'BROWSER_PROFILE=REMOVED' 'RUNTIME_STATE=REMOVED' 'AUTH_STATE=REMOVED' 'IDENTITY=RESET'
