#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"
for script in scripts/*.sh scripts/lib/*.sh proxmox/*.sh proxmox/lib/*.sh; do
  bash -n "$script"
done
bash tests/test_manifest.sh
if bash scripts/bootstrap.sh --unknown >/dev/null 2>&1; then
  printf '%s\n' 'bootstrap accepted an unknown argument' >&2
  exit 1
fi
if bash proxmox/create-vm.sh --dry-run >/dev/null 2>&1; then
  printf '%s\n' 'create-vm accepted missing environment file' >&2
  exit 1
fi
for lifecycle in proxmox/convert-template.sh proxmox/clone-template.sh proxmox/validate-clone.sh proxmox/validate-input.sh; do
  if bash "$lifecycle" >/dev/null 2>&1; then
    printf '%s\n' "$lifecycle accepted missing arguments" >&2
    exit 1
  fi
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
grep -q 'linux-image-amd64' scripts/provision-os.sh
grep -q 'grub-reboot' scripts/provision-os.sh
grep -q 'validate-input.sh' scripts/validate.sh scripts/validate-template.sh
grep -q 'KERNEL_POINTER=PASS' scripts/validate-input.sh
grep -q 'X11_POINTER=PASS' scripts/validate-input.sh
grep -q 'CUA_INPUT=PASS' scripts/validate-input.sh
grep -q 'assert_pve_tablet_device' proxmox/lib/common.sh proxmox/create-vm.sh proxmox/clone-template.sh proxmox/convert-template.sh proxmox/validate-clone.sh proxmox/validate-input.sh
grep -q 'usb-tablet' proxmox/lib/common.sh
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
grep -q 'truncate -s 0 /etc/machine-id' scripts/sanitize-template.sh
grep -q 'cloud-init clean --logs --seed --machine-id' scripts/sanitize-template.sh
grep -q 'browser_root="\$home/.local/share/hermes-unsafe-vm"' scripts/sanitize-template.sh scripts/validate-template.sh scripts/validate-clone.sh
grep -q 'chown "\$HERMES_USER:\$HERMES_USER" "\$home" "\$browser_root"' scripts/sanitize-template.sh
grep -q 'sqlite3.connect' scripts/validate-clone.sh
grep -q 'template-ready' scripts/sanitize-template.sh scripts/validate-template.sh
grep -q 'managed_by=hermes-unsafe-vm' scripts/sanitize-template.sh scripts/validate-template.sh scripts/validate-clone.sh
grep -q 'scan_user_state_for_obvious_credentials' scripts/lib/common.sh scripts/validate-template.sh scripts/validate-clone.sh
grep -q 'ssh_host_key_fingerprint' proxmox/convert-template.sh proxmox/validate-clone.sh
grep -q 'qm template' proxmox/convert-template.sh
grep -q 'qm clone' proxmox/clone-template.sh
grep -q 'qm set.*--delete sshkeys' proxmox/convert-template.sh
grep -q 'SOURCE_EVIDENCE_FILE' proxmox/template.defaults.env.example proxmox/clone.defaults.env.example
grep -q 'cloud-init status --wait --long' scripts/validate-clone.sh
grep -q "status: done" scripts/validate-clone.sh
grep -q 'runuser -u "\$HERMES_USER"' scripts/validate-clone.sh
grep -q 'hermes-vault search.*validation' scripts/validate-clone.sh
grep -q 'MACHINE_ID_UNIQUE=PASS' proxmox/validate-clone.sh
grep -q 'CLONE_VALIDATION=PASS' scripts/validate-clone.sh proxmox/validate-clone.sh
grep -q 'rm -f -- "\$home/.hermes/.env"' scripts/sanitize-template.sh
grep -q 'TEMPLATE_VALIDATION=PASS' scripts/validate-template.sh
grep -q 'if \[\[ -d "\$target/.git" \]\]' scripts/install-autonomy.sh
grep -q 'os.replace' scripts/write-manifest.py
grep -q 'NOPASSWD: ALL' SECURITY.md
! rg -n '(@latest|curl[^\n]*\|[^\n]*bash)' scripts config proxmox
tests/test_public_history.sh
printf '%s\n' 'CONTRACT_TESTS=PASS'
