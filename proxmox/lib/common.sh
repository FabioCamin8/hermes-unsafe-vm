#!/usr/bin/env bash
set -Eeuo pipefail

proxmox_lib_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../scripts/lib/common.sh
source "$proxmox_lib_dir/../../scripts/lib/common.sh"

require_host_root() {
  [[ $EUID -eq 0 ]] || die 'run Proxmox lifecycle commands as root'
}

require_vm_id() {
  local name=$1 value=$2
  require_integer_range "$name" "$value" 100 999999999
}

require_vm_name() {
  local name=$1 value=$2
  [[ $value =~ ^[A-Za-z0-9][A-Za-z0-9.-]{0,62}$ ]] || die "$name must be a hostname-safe VM name"
}

require_ssh_inputs() {
  [[ $SSH_USER =~ ^[a-z_][a-z0-9_-]*$ && $SSH_USER != root ]] || die 'SSH_USER must be a non-root Unix account'
  [[ $SSH_HOST =~ ^[A-Za-z0-9_.:-]+$ ]] || die 'SSH_HOST contains unsupported characters'
  [[ -f $SSH_KEY_FILE && -r $SSH_KEY_FILE ]] || die 'SSH_KEY_FILE must be readable'
  [[ $GUEST_REPO == /* && $GUEST_REPO != *[\	\ ]* ]] || die 'GUEST_REPO must be an absolute path without whitespace'
}

require_pve_tools() {
  local command_name
  for command_name in qm awk grep mktemp ssh ssh-keygen; do
    command -v "$command_name" >/dev/null 2>&1 || die "required Proxmox command is unavailable: $command_name"
  done
}

vm_config() {
  qm config "$1"
}

vm_status() {
  qm status "$1" | awk '{print $2}'
}

project_tags() {
  awk -F': ' '$1 == "tags" { print $2; exit }' <<<"$1"
}

has_project_tag() {
  local tags=$1
  case ",$tags," in
    *,hermes-unsafe-vm,*) return 0 ;;
    *) return 1 ;;
  esac
}

assert_project_vm() {
  local vmid=$1 expected_name=$2 config status tags
  config=$(vm_config "$vmid") || die "VMID $vmid does not exist"
  grep -Fxq "name: $expected_name" <<<"$config" || die "VM name does not match expected candidate: $expected_name"
  tags=$(project_tags "$config")
  has_project_tag "$tags" || die 'VM does not carry the hermes-unsafe-vm project tag'
  status=$(vm_status "$vmid")
  [[ $status == stopped ]] || die "VM must be stopped for this lifecycle operation (status=$status)"
}

assert_project_running() {
  local vmid=$1 expected_name=$2 config status tags
  config=$(vm_config "$vmid") || die "VMID $vmid does not exist"
  grep -Fxq "name: $expected_name" <<<"$config" || die "VM name does not match expected candidate: $expected_name"
  tags=$(project_tags "$config")
  has_project_tag "$tags" || die 'VM does not carry the hermes-unsafe-vm project tag'
  ! grep -Fxq 'template: 1' <<<"$config" || die 'refusing to operate on an already-converted template'
  status=$(vm_status "$vmid")
  [[ $status == running ]] || die "VM must be running for guest preparation (status=$status)"
}

assert_project_template() {
  local vmid=$1 expected_name=$2 config tags
  config=$(vm_config "$vmid") || die "template VMID $vmid does not exist"
  grep -Fxq "name: $expected_name" <<<"$config" || die "template name does not match expected value: $expected_name"
  tags=$(project_tags "$config")
  has_project_tag "$tags" || die 'template does not carry the hermes-unsafe-vm project tag'
  grep -Fxq 'template: 1' <<<"$config" || die 'source VM is not a Proxmox template'
}

wait_for_stopped() {
  local vmid=$1 attempts=60 status=
  [[ $# -lt 2 ]] || attempts=$2
  for ((attempt = 1; attempt <= attempts; attempt++)); do
    status=$(vm_status "$vmid")
    [[ $status == stopped ]] && return 0
    sleep 2
  done
  die "VMID $vmid did not stop within the bounded wait"
}

verify_public_key_file() {
  local file=$1
  [[ -f $file && -r $file ]] || die 'SSH_PUBLIC_KEY_FILE must be readable'
  ! grep -q 'PRIVATE KEY' "$file" || die 'SSH_PUBLIC_KEY_FILE appears to contain private key material'
  ssh-keygen -lf "$file" >/dev/null 2>&1 || die 'SSH_PUBLIC_KEY_FILE is not a valid public key'
}
