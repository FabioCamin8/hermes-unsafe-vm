#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

[[ $# -eq 2 ]] || {
  printf '%s\n' 'Usage: convert-template.sh --apply ENV_FILE' >&2
  exit 2
}
mode=$1
env_file=$2
[[ $mode == --apply ]] || {
  printf '%s\n' 'Usage: convert-template.sh --apply ENV_FILE' >&2
  exit 2
}
require_host_root
require_pve_tools
load_env "$env_file"

for name in TEMPLATE_VMID TEMPLATE_NAME SSH_USER SSH_HOST SSH_KEY_FILE GUEST_REPO SOURCE_EVIDENCE_FILE; do
  require_var "$name"
done
require_vm_id TEMPLATE_VMID "$TEMPLATE_VMID"
require_vm_name TEMPLATE_NAME "$TEMPLATE_NAME"
require_ssh_inputs
[[ $SOURCE_EVIDENCE_FILE == /* && $SOURCE_EVIDENCE_FILE != *[\	\ ]* ]] || die 'SOURCE_EVIDENCE_FILE must be an absolute path without whitespace'
install -d -m 0700 "$(dirname -- "$SOURCE_EVIDENCE_FILE")"

capture_source_identity() {
  local machine_id fingerprint hostname_value
  if [[ -e $SOURCE_EVIDENCE_FILE ]]; then
    [[ -f $SOURCE_EVIDENCE_FILE && -r $SOURCE_EVIDENCE_FILE ]] || die 'existing source evidence is not a readable regular file'
    [[ $(wc -l <"$SOURCE_EVIDENCE_FILE") -eq 3 ]] || die 'existing source evidence must contain exactly three records'
    if ! awk -F= '
      NF != 2 || $2 == "" || !($1 == "machine_id" || $1 == "ssh_host_key_fingerprint" || $1 == "hostname") || seen[$1]++ { invalid = 1 }
      END {
        exit !(invalid == 0 && seen["machine_id"] == 1 && seen["ssh_host_key_fingerprint"] == 1 && seen["hostname"] == 1)
      }
    ' "$SOURCE_EVIDENCE_FILE"; then
      die 'existing source evidence is incomplete or has unexpected records'
    fi
    machine_id=$(awk -F= '$1 == "machine_id" { print $2; exit }' "$SOURCE_EVIDENCE_FILE")
    fingerprint=$(awk -F= '$1 == "ssh_host_key_fingerprint" { print $2; exit }' "$SOURCE_EVIDENCE_FILE")
    hostname_value=$(awk -F= '$1 == "hostname" { print $2; exit }' "$SOURCE_EVIDENCE_FILE")
    [[ $machine_id =~ ^[[:xdigit:]]{32}$ ]] || die 'existing source machine-id has an invalid format'
    [[ $fingerprint =~ ^SHA256:[A-Za-z0-9+/=]+$ ]] || die 'existing source SSH fingerprint has an invalid format'
    [[ $hostname_value =~ ^[A-Za-z0-9][A-Za-z0-9.-]{0,62}$ ]] || die 'existing source hostname has an invalid format'
    chmod 0600 "$SOURCE_EVIDENCE_FILE"
    printf '%s\n' 'SOURCE_IDENTITY_EVIDENCE=REUSED'
    return 0
  fi

  umask 077
  ssh -q -i "$SSH_KEY_FILE" -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
    "$SSH_USER@$SSH_HOST" 'sudo -n bash -s' >"$SOURCE_EVIDENCE_FILE" <<'REMOTE'
set -Eeuo pipefail
machine_id=$(cat /etc/machine-id)
[[ -n $machine_id ]] || { printf '%s\n' 'source machine-id is empty' >&2; exit 1; }
host_key=$(find /etc/ssh -maxdepth 1 -type f -name 'ssh_host_*_key.pub' -print -quit)
[[ -n $host_key ]] || { printf '%s\n' 'source SSH host key is missing' >&2; exit 1; }
fingerprint=$(ssh-keygen -lf "$host_key" | awk '{print $2}')
hostname_value=$(hostname)
[[ -n $fingerprint && -n $hostname_value ]] || exit 1
printf 'machine_id=%s\nssh_host_key_fingerprint=%s\nhostname=%s\n' \
  "$machine_id" "$fingerprint" "$hostname_value"
REMOTE
  chmod 0600 "$SOURCE_EVIDENCE_FILE"
}

assert_project_running "$TEMPLATE_VMID" "$TEMPLATE_NAME"

capture_source_identity

prepare_output=
set +e
prepare_output=$(ssh -q -i "$SSH_KEY_FILE" -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
  "$SSH_USER@$SSH_HOST" "sudo -n $GUEST_REPO/scripts/prepare-template.sh --yes --shutdown" 2>&1)
prepare_rc=$?
set -e
if grep -Fqx 'TEMPLATE_PREPARE=PASS' <<<"$prepare_output"; then
  [[ $prepare_rc -eq 0 || $prepare_rc -eq 255 ]] || {
    printf '%s\n' "$prepare_output" >&2
    die "guest template preparation failed (ssh exit=$prepare_rc)"
  }
else
  qga_output=
  set +e
  qga_output=$(qm guest exec "$TEMPLATE_VMID" -- bash "$GUEST_REPO/scripts/prepare-template.sh" --yes 2>&1)
  qga_rc=$?
  set -e
  if [[ $qga_rc -ne 0 ]] || ! grep -Fq 'TEMPLATE_PREPARE=PASS' <<<"$qga_output"; then
    printf '%s\n' "$prepare_output" "$qga_output" >&2
    die 'guest template preparation failed over SSH and QEMU Guest Agent'
  fi
  assert_project_running "$TEMPLATE_VMID" "$TEMPLATE_NAME"
  qm shutdown "$TEMPLATE_VMID"
  printf '%s\n' 'GUEST_PREPARE_TRANSPORT=QGA'
fi
wait_for_stopped "$TEMPLATE_VMID"

assert_project_vm "$TEMPLATE_VMID" "$TEMPLATE_NAME"
qm set "$TEMPLATE_VMID" --delete sshkeys >/dev/null 2>&1 || true
if grep -Fxq 'cipassword:' <<<"$(vm_config "$TEMPLATE_VMID")"; then
  qm set "$TEMPLATE_VMID" --delete cipassword >/dev/null
fi
config=$(vm_config "$TEMPLATE_VMID")
! grep -Fxq 'sshkeys:' <<<"$config" || die 'source Cloud-Init SSH key remains in template configuration'
! grep -Fxq 'cipassword:' <<<"$config" || die 'Cloud-Init password remains in template configuration'
assert_project_vm "$TEMPLATE_VMID" "$TEMPLATE_NAME"
qm template "$TEMPLATE_VMID"

config=$(vm_config "$TEMPLATE_VMID")
grep -Fxq 'template: 1' <<<"$config" || die 'Proxmox did not mark the candidate as a template'
printf '%s\n' 'TEMPLATE_CONVERSION=PASS' 'SOURCE_IDENTITY_CAPTURED=PASS' 'CLOUD_INIT_SOURCE_KEY=REMOVED'
