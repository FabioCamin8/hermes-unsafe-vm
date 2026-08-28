#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

[[ $# -eq 2 && $1 == --verify ]] || {
  printf '%s\n' 'Usage: validate-input.sh --verify VMID' >&2
  exit 2
}
require_host_root
require_pve_tools
require_vm_id VMID "$2"
assert_pve_tablet_device "$2"
printf '%s\n' 'PVE_TABLET_CONFIG=PASS' 'PVE_USB_TABLET=PASS' 'PVE_INPUT_VALIDATION=PASS'
