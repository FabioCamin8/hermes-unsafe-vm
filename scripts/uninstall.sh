#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

require_root
[[ ${1:-} == --yes && $# -eq 1 ]] || die 'uninstall requires exactly --yes'
[[ -f /etc/hermes-unsafe-vm/managed ]] || die 'VM is not marked as managed by this project'
HERMES_USER=${HERMES_USER:-hermes}
home=$(hermes_home_for_user "$HERMES_USER")
rm -f -- /etc/ssh/sshd_config.d/90-hermes-unsafe-vm.conf /etc/lightdm/lightdm.conf.d/50-hermes-unsafe-vm.conf
rm -f -- /etc/hermes-unsafe-vm/runtime.env /etc/hermes-unsafe-vm/hermes-install.env /etc/hermes-unsafe-vm/autonomy.env /etc/hermes-unsafe-vm/manifest.json /etc/hermes-unsafe-vm/managed
rm -f -- "$home/.local/bin/hermes-unsafe-vm-session-start" "$home/.local/bin/hermes-graphical" "$home/.config/autostart/hermes-unsafe-vm-chromium.desktop"
sshd -t
printf '%s\n' 'UNINSTALL=PASS' 'RUNTIME_DATA=PRESERVED' 'AUTONOMY_LAYER=NOT_REMOVED'
