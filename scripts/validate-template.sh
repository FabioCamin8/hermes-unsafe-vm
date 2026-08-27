#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

require_root
HERMES_USER=${HERMES_USER:-hermes}
home=$(hermes_home_for_user "$HERMES_USER")
browser_root="$home/.local/share/hermes-unsafe-vm"
managed_file=/etc/hermes-unsafe-vm/managed
ready_file=/etc/hermes-unsafe-vm/template-ready
[[ -f $managed_file ]] || die 'template is not marked as project-managed'
grep -Fxq 'managed_by=hermes-unsafe-vm' "$managed_file" || die 'managed marker is invalid'
grep -Fxq 'unsafe_boundary=guest_only' "$managed_file" || die 'unsafe boundary marker is missing'
[[ -f $ready_file ]] || die 'template-ready marker is missing'
for marker in machine_id=reset ssh_host_keys=reset runtime_state=clean provider_auth=absent browser_state=absent; do
  grep -Fxq "$marker" "$ready_file" || die "template-ready marker is incomplete: $marker"
done

[[ ! -s /etc/machine-id ]] || die 'machine-id is not empty/reset'
[[ -d $browser_root && $(stat -c %U "$browser_root") == "$HERMES_USER" && $(stat -c %a "$browser_root") == 755 ]] || \
  die 'browser runtime parent ownership/mode is invalid'
if [[ -e /var/lib/dbus/machine-id ]]; then
  [[ -L /var/lib/dbus/machine-id ]] || die 'a separate dbus machine-id remains'
  [[ $(readlink -f /var/lib/dbus/machine-id) == /etc/machine-id ]] || die 'dbus machine-id link is unexpected'
fi
! compgen -G '/etc/ssh/ssh_host_*' >/dev/null || die 'SSH host keys remain'

for forbidden in \
  "$home/.hermes/.env" "$home/.hermes/auth.json" \
  "$home/.codex/auth.json" "$home/.codex/.credentials.json" \
  "$home/.config/codex/auth.json" "$home/.config/codex/.credentials.json" \
  "$home/.git-credentials" "$home/.netrc" "$home/.config/git/credentials" \
  "$home/.config/gh" "$home/.config/pve" "$home/.local/share/pve" \
  "$home/.local/share/hermes-unsafe-vm/chromium-profile" \
  "$home/.config/chromium" "$home/.config/google-chrome" \
  "$home/.cache/chromium" "$home/.cache/google-chrome" \
  "$home/.ssh/authorized_keys"; do
  [[ ! -e $forbidden ]] || die "template-forbidden state remains: $forbidden"
done

runtime_file=$(find "$home/.hermes" -type f \( \
  -name '*.db' -o -name '*.db-wal' -o -name '*.db-shm' -o -name '*.sqlite*' \
  -o -name '*.jsonl' -o -name 'gateway-starts.log' -o -name '*.lock' \) \
  -print -quit)
if [[ -n $runtime_file ]]; then
  die 'Hermes runtime database, journal, or lock remains'
fi
for runtime_dir in \
  "$home/.hermes/vault" "$home/.hermes/sessions" "$home/.hermes/memories" \
  "$home/.hermes/backups" "$home/.hermes/checkpoints" "$home/.hermes/logs" \
  "$home/.hermes/workspaces" "$home/.hermes/projects" "$home/.hermes/sandboxes"; do
  if [[ -d $runtime_dir ]] && [[ -n $(find "$runtime_dir" -type f -print -quit) ]]; then
    die "populated runtime state remains: $runtime_dir"
  fi
done
browser_hit=$(find "$home" -type f \( \
  -name Cookies -o -name 'Login Data' -o -name 'Web Data' -o -name History \
  -o -name 'Local Storage' -o -name 'Session Storage' \) -print -quit)
[[ -z $browser_hit ]] || die 'browser private state remains'
private_key=$(find "$home" -type f \( -name 'id_*' -o -name '*.pem' -o -name '*.key' \) -print -quit)
[[ -z $private_key ]] || die 'private key material remains under the Hermes home'
history_file=$(find "$home" -type f \( -name '.bash_history' -o -name '.zsh_history' -o -name '.fish_history' \) -print -quit)
[[ -z $history_file ]] || die 'shell history remains under the Hermes home'
env_file=$(find "$home" -type f -name '.env' -print -quit)
[[ -z $env_file ]] || die 'a provider environment file remains under the Hermes home'

if scan_user_state_for_obvious_credentials "$home"; then
  die 'obvious credential pattern remains in template user state'
else
  scan_rc=$?
  [[ $scan_rc -eq 1 ]] || die 'template credential-state scan failed'
fi
runuser -u "$HERMES_USER" -- sudo -n id -u | grep -qx 0 || die 'unsafe sudo rule was not preserved'
printf '%s\n' \
  'TEMPLATE_VALIDATION=PASS' 'MACHINE_ID=RESET' 'SSH_HOST_KEYS=RESET' \
  'RUNTIME_STATE=CLEAN' 'BROWSER_STATE=ABSENT' 'AUTH_STATE=ABSENT' \
  'UNSAFE_SUDO=PRESERVED'
