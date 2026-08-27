#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

require_root
HERMES_USER=${HERMES_USER:-hermes}
home=$(hermes_home_for_user "$HERMES_USER")
[[ -f /etc/hermes-unsafe-vm/managed ]] || die 'template is not marked as project-managed'
[[ -f /etc/machine-id && ! -s /etc/machine-id ]] || die 'machine-id is not empty/reset'
! compgen -G '/etc/ssh/ssh_host_*' >/dev/null || die 'SSH host keys remain'
for forbidden in \
  "$home/.hermes/.env" "$home/.hermes/auth.json" "$home/.codex/auth.json" \
  "$home/.config/codex/auth.json" "$home/.local/share/hermes-unsafe-vm/chromium-profile"; do
  [[ ! -e $forbidden ]] || die "template-forbidden state remains: $forbidden"
done
for runtime_dir in "$home/.hermes/vault" "$home/.hermes/sessions" "$home/.hermes/memories"; do
  if [[ -d $runtime_dir ]] && find "$runtime_dir" -type f -print -quit | grep -q .; then
    die "populated runtime state remains: $runtime_dir"
  fi
done
if find "$home" -type f \( -name 'id_*' -o -name '*.pem' -o -name '*.key' \) -print -quit | grep -q .; then
  die 'private key material remains under the Hermes home'
fi
if find "$home" -maxdepth 2 -type f \( -name '.bash_history' -o -name '.zsh_history' \) -print -quit | grep -q .; then
  die 'shell history remains under the Hermes home'
fi
if rg -n --hidden --glob '!.hermes/hermes-agent/**' --glob '!*.pyc' --glob '!*.log' \
  --regexp '-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----|\b(sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,})\b' \
  "$home/.hermes" "$home/.config" "$home/.local/share" 2>/dev/null; then
  die 'obvious credential pattern remains in template user state'
fi
runuser -u "$HERMES_USER" -- sudo -n id -u | grep -qx 0 || die 'unsafe sudo rule was not preserved'
printf '%s\n' 'TEMPLATE_VALIDATION=PASS' 'MACHINE_ID=RESET' 'SSH_HOST_KEYS=RESET' 'RUNTIME_STATE=CLEAN' 'UNSAFE_SUDO=PRESERVED'
