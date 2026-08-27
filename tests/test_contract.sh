#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"
for script in scripts/*.sh scripts/lib/*.sh proxmox/*.sh; do
  bash -n "$script"
done
grep -q 'UNSAFE BY DESIGN' README.md
grep -q -- '--enable-unsafe-root' scripts/install-autonomy.sh
grep -q 'HERMES_AUTONOMY_COMMIT' scripts/install-autonomy.sh config/defaults.env.example
grep -q 'rev-parse HEAD' scripts/install-autonomy.sh
grep -q 'normalize_checkout_permissions "\$target"' scripts/install-autonomy.sh
grep -q 'find "\$checkout" -type d -exec chmod 0755' scripts/install-autonomy.sh
grep -q 'find "\$checkout" -type f ! -perm /111 -exec chmod 0644' scripts/install-autonomy.sh
grep -q 'find "\$checkout" -type f -perm /111 -exec chmod 0755' scripts/install-autonomy.sh
grep -q 'HERMES_CDP_PORT' scripts/hermes-session-start.sh scripts/validate.sh
grep -q 'ssh_effective=\$(sshd -T)' scripts/validate.sh
grep -q '<<<"\$ssh_effective"' scripts/validate.sh
grep -q 'install -d -o "$HERMES_USER" -g "$HERMES_USER" -m 0755' scripts/provision-browser.sh
grep -q '"$home/.local" "$home/.local/bin" "$home/.local/share"' scripts/provision-browser.sh
grep -q 'install -d -o "$HERMES_USER" -g "$HERMES_USER" -m 0755 "$home/.config"' scripts/provision-browser.sh
grep -q 'systemctl restart "user@$uid.service"' scripts/provision-hermes.sh
grep -q 'for _ in {1..30}; do' scripts/provision-cua.sh
grep -q 'compat_dir="\$home/.config/hermes"' scripts/provision-cua.sh
grep -q 'compat_env_file="\$compat_dir/graphical-session.env"' scripts/provision-cua.sh
grep -q 'ln -s -- "\$env_file" "\$compat_env_file"' scripts/provision-cua.sh
grep -q '\[\[ -L "\$compat_env_file"' scripts/provision-cua.sh
grep -q 'NOPASSWD: ALL' SECURITY.md
! rg -n '(@latest|curl[^\n]*\|[^\n]*bash)' scripts config proxmox
printf '%s\n' 'CONTRACT_TESTS=PASS'
