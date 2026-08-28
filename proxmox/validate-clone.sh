#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

[[ $# -eq 2 ]] || {
  printf '%s\n' 'Usage: validate-clone.sh --verify ENV_FILE' >&2
  exit 2
}
mode=$1
env_file=$2
[[ $mode == --verify ]] || {
  printf '%s\n' 'Usage: validate-clone.sh --verify ENV_FILE' >&2
  exit 2
}
require_host_root
require_pve_tools
load_env "$env_file"

for name in CLONE_VMID CLONE_NAME SSH_USER SSH_HOST SSH_KEY_FILE GUEST_REPO SOURCE_EVIDENCE_FILE; do
  require_var "$name"
done
require_vm_id CLONE_VMID "$CLONE_VMID"
require_vm_name CLONE_NAME "$CLONE_NAME"
require_ssh_inputs
[[ -f $SOURCE_EVIDENCE_FILE && -r $SOURCE_EVIDENCE_FILE ]] || die 'SOURCE_EVIDENCE_FILE is required for identity comparison'

config=$(vm_config "$CLONE_VMID") || die "clone VMID $CLONE_VMID does not exist"
grep -Fxq "name: $CLONE_NAME" <<<"$config" || die 'clone name mismatch'
has_project_tag "$(project_tags "$config")" || die 'clone is missing the hermes-unsafe-vm tag'
! grep -Fxq 'template: 1' <<<"$config" || die 'clone must not be a template'
assert_pve_tablet_device "$CLONE_VMID"
[[ $(vm_status "$CLONE_VMID") == running ]] || die 'clone must be running for validation'

known_hosts=$(mktemp)
trap 'rm -f -- "${known_hosts:-}"' EXIT
chmod 0600 "$known_hosts"
ssh_clone() {
  ssh -q -i "$SSH_KEY_FILE" -o BatchMode=yes -o ConnectTimeout=3 \
    -o UserKnownHostsFile="$known_hosts" -o StrictHostKeyChecking=accept-new \
    "$SSH_USER@$SSH_HOST" "$@"
}
connected=false
for attempt in {1..60}; do
  if ssh_clone true >/dev/null 2>&1; then
    connected=true
    break
  fi
  sleep 2
done
[[ $connected == true ]] || die 'clone SSH did not recover within the bounded wait'

ssh_clone "sudo -n $GUEST_REPO/scripts/validate-clone.sh"
clone_machine_id=$(ssh_clone 'sudo -n cat /etc/machine-id')
clone_hostname=$(ssh_clone 'hostname')
[[ -n $clone_machine_id && -n $clone_hostname ]] || die 'clone identity is incomplete'

source_machine_id=$(awk -F= '$1 == "machine_id" { print $2; exit }' "$SOURCE_EVIDENCE_FILE")
source_fingerprint=$(awk -F= '$1 == "ssh_host_key_fingerprint" { print $2; exit }' "$SOURCE_EVIDENCE_FILE")
source_hostname=$(awk -F= '$1 == "hostname" { print $2; exit }' "$SOURCE_EVIDENCE_FILE")
[[ -n $source_machine_id && -n $source_fingerprint && -n $source_hostname ]] || \
  die 'source identity evidence is incomplete'
[[ $clone_machine_id != "$source_machine_id" ]] || die 'clone reused the source machine-id'
[[ $clone_hostname != "$source_hostname" ]] || die 'clone reused the source hostname'

clone_fingerprints=$(ssh-keyscan -T 5 -t ed25519,ecdsa,rsa "$SSH_HOST" 2>/dev/null | \
  ssh-keygen -lf - 2>/dev/null | awk '{print $2}' || true)
[[ -n $clone_fingerprints ]] || die 'unable to read clone SSH host identity'
if grep -Fqx "$source_fingerprint" <<<"$clone_fingerprints" >/dev/null; then
  die 'clone reused the source SSH host key'
fi

printf '%s\n' \
  'MACHINE_ID_UNIQUE=PASS' 'SSH_HOST_IDENTITY_UNIQUE=PASS' \
  'HOSTNAME_UNIQUE=PASS' 'CLONE_VALIDATION=PASS'
