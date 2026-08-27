#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

require_root
[[ ${1:-} == --yes && $# -eq 1 ]] || die 'sanitization requires exactly --yes on a project-created disposable VM'
[[ -f /etc/hermes-unsafe-vm/managed ]] || die 'refusing to sanitize an unmarked VM'
grep -Fxq 'managed_by=hermes-unsafe-vm' /etc/hermes-unsafe-vm/managed || die 'managed marker is not owned by hermes-unsafe-vm'
grep -Fxq 'unsafe_boundary=guest_only' /etc/hermes-unsafe-vm/managed || die 'unsafe boundary marker is missing'
HERMES_USER=${HERMES_USER:-hermes}
home=$(hermes_home_for_user "$HERMES_USER")
uid=$(id -u "$HERMES_USER")
runtime_dir=/run/user/$uid
browser_root="$home/.local/share/hermes-unsafe-vm"
profile_dir="$browser_root/chromium-profile"
if [[ -S "$runtime_dir/bus" ]]; then
  runuser -u "$HERMES_USER" -- env HOME="$home" XDG_RUNTIME_DIR="$runtime_dir" DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus" systemctl --user stop hermes-gateway.service hermes-vault-maintenance.timer >/dev/null 2>&1 || true
fi
systemctl stop lightdm >/dev/null 2>&1 || true
pkill -u "$HERMES_USER" -f -- "$profile_dir" >/dev/null 2>&1 || true
for browser_path in \
  "$profile_dir" "$home/.config/chromium" "$home/.config/google-chrome" \
  "$home/.cache/chromium" "$home/.cache/google-chrome"; do
  rm -rf -- "$browser_path"
done
for runtime_dir in \
  "$home/.hermes/vault" "$home/.hermes/sessions" "$home/.hermes/memories" \
  "$home/.hermes/backups" "$home/.hermes/checkpoints" "$home/.hermes/logs" \
  "$home/.hermes/workspaces" "$home/.hermes/projects" "$home/.hermes/sandboxes"; do
  rm -rf -- "$runtime_dir"
done
find "$home/.hermes" -type f \( \
  -name '*.db' -o -name '*.db-wal' -o -name '*.db-shm' -o -name '*.sqlite*' \
  -o -name '*.jsonl' -o -name 'gateway-starts.log' -o -name '*.lock' \) -delete
rm -f -- "$home/.hermes/.env" "$home/.hermes/auth.json" "$home/.codex/auth.json" "$home/.config/codex/auth.json" "$home/.bash_history" "$home/.zsh_history"
rm -f -- "$home/.codex/.credentials.json" "$home/.config/codex/.credentials.json" \
  "$home/.git-credentials" "$home/.netrc" "$home/.config/git/credentials"
rm -rf -- "$home/.config/gh" "$home/.config/pve" "$home/.local/share/pve" "$home/.codex/auth" "$home/.codex/sessions"
rm -rf -- "$home/.ssh"
install -d -o "$HERMES_USER" -g "$HERMES_USER" -m 0700 "$home/.ssh"
find "$home" -type f \( -name '*.pem' -o -name '*.key' -o -name 'id_*' \) -delete
find "$home" -type f \( -name '.bash_history' -o -name '.zsh_history' -o -name '.fish_history' \) -delete
if command -v cloud-init >/dev/null 2>&1; then
  cloud-init clean --logs --seed --machine-id || die 'cloud-init cleanup failed'
elif [[ -d /var/lib/cloud ]]; then
  rm -rf -- /var/lib/cloud/instances /var/lib/cloud/instance /var/lib/cloud/sem /var/lib/cloud/data /var/lib/cloud/log
fi
find /var/lib/dhcp /var/lib/dhcpcd5 /var/lib/NetworkManager -mindepth 1 -maxdepth 1 -delete 2>/dev/null || true
find /var/log/journal -mindepth 1 -delete 2>/dev/null || true
rm -f -- /var/lib/systemd/random-seed /tmp/hermes-unsafe-vm-health.out
find /tmp -xdev -user "$HERMES_USER" -mindepth 1 -maxdepth 1 -delete 2>/dev/null || true
find /var/tmp -xdev -user "$HERMES_USER" -mindepth 1 -maxdepth 1 -delete 2>/dev/null || true
if [[ -L /var/lib/dbus/machine-id ]]; then
  [[ $(readlink -f /var/lib/dbus/machine-id) == /etc/machine-id ]] || die '/var/lib/dbus/machine-id points somewhere unexpected'
elif [[ -e /var/lib/dbus/machine-id ]]; then
  rm -f -- /var/lib/dbus/machine-id
fi
if [[ -e /etc/machine-id ]]; then
  truncate -s 0 /etc/machine-id
else
  install -o root -g root -m 0644 /dev/null /etc/machine-id
fi
find /etc/ssh -maxdepth 1 -type f \( -name 'ssh_host_*' -o -name 'ssh_known_hosts' \) -delete
write_atomic /etc/hostname 0644 <<'EOF'
localhost
EOF
write_atomic /etc/hosts 0644 <<'EOF'
127.0.0.1 localhost
::1 localhost ip6-localhost ip6-loopback
EOF
install -d -o "$HERMES_USER" -g "$HERMES_USER" -m 0755 "$browser_root"
chown "$HERMES_USER:$HERMES_USER" "$home" "$browser_root"
install -d -m 0755 /etc/hermes-unsafe-vm
write_atomic /etc/hermes-unsafe-vm/template-ready 0644 <<'EOF'
schema=1
machine_id=reset
ssh_host_keys=reset
runtime_state=clean
provider_auth=absent
browser_state=absent
EOF
printf '%s\n' 'TEMPLATE_SANITIZE=PASS' 'BROWSER_PROFILE=REMOVED' 'RUNTIME_STATE=REMOVED' 'AUTH_STATE=REMOVED' 'IDENTITY=RESET'
