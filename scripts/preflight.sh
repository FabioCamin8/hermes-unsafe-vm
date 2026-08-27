#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

require_root
. /etc/os-release
[[ ${ID:-} == debian ]] || die 'supported guest OS is Debian'
[[ ${VERSION_ID:-} == 13 ]] || die "supported guest OS is Debian 13; found ${VERSION_ID:-unknown}"
[[ $(uname -m) == x86_64 ]] || die "supported guest architecture is x86_64; found $(uname -m)"
for command_name in apt-get curl getent install ip systemctl; do
  command -v "$command_name" >/dev/null 2>&1 || die "required command is unavailable: $command_name"
done
ip route show default | grep -q . || die 'no default route is available'
printf '%s\n' \
  'PREFLIGHT=PASS' \
  "OS=$PRETTY_NAME" \
  "ARCH=$(uname -m)" \
  "KERNEL=$(uname -r)"
