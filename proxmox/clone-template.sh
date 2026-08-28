#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

[[ $# -eq 2 ]] || {
  printf '%s\n' 'Usage: clone-template.sh --apply ENV_FILE' >&2
  exit 2
}
mode=$1
env_file=$2
[[ $mode == --apply ]] || {
  printf '%s\n' 'Usage: clone-template.sh --apply ENV_FILE' >&2
  exit 2
}
require_host_root
require_pve_tools
load_env "$env_file"

for name in TEMPLATE_VMID TEMPLATE_NAME CLONE_VMID CLONE_NAME CLONE_STORAGE \
  SSH_PUBLIC_KEY_FILE START_VM; do
  require_var "$name"
done
require_vm_id TEMPLATE_VMID "$TEMPLATE_VMID"
require_vm_id CLONE_VMID "$CLONE_VMID"
[[ $TEMPLATE_VMID != "$CLONE_VMID" ]] || die 'template and clone VMIDs must differ'
require_vm_name TEMPLATE_NAME "$TEMPLATE_NAME"
require_vm_name CLONE_NAME "$CLONE_NAME"
verify_public_key_file "$SSH_PUBLIC_KEY_FILE"
[[ $START_VM == 0 || $START_VM == 1 ]] || die 'START_VM must be 0 or 1'

assert_project_template "$TEMPLATE_VMID" "$TEMPLATE_NAME"
if qm config "$CLONE_VMID" >/dev/null 2>&1; then
  die "clone VMID already exists: $CLONE_VMID"
fi

qm clone "$TEMPLATE_VMID" "$CLONE_VMID" --full 1 --storage "$CLONE_STORAGE" --name "$CLONE_NAME"
qm set "$CLONE_VMID" \
  --ciuser hermes \
  --sshkeys "$SSH_PUBLIC_KEY_FILE" \
  --ipconfig0 ip=dhcp \
  --ciupgrade 0 \
  --onboot 0 \
  --boot order=scsi0
qm set "$CLONE_VMID" --delete cipassword >/dev/null 2>&1 || true
qm cloudinit update "$CLONE_VMID"

config=$(vm_config "$CLONE_VMID")
grep -Fxq "name: $CLONE_NAME" <<<"$config" || die 'clone name does not match requested value'
has_project_tag "$(project_tags "$config")" || die 'clone is missing the hermes-unsafe-vm project tag'
grep -Fxq 'agent: 1' <<<"$config" || die 'clone does not retain QEMU Guest Agent'
assert_pve_tablet_device "$CLONE_VMID"
if [[ $START_VM == 1 ]]; then
  qm start "$CLONE_VMID"
  start_state=started
else
  start_state=stopped
fi
printf '%s\n' 'CLONE_CREATE=PASS' "CLONE_START_STATE=$start_state" 'CLOUD_INIT_KEY=SET'
