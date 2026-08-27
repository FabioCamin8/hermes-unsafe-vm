#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

require_root
[[ ${1:-} == --yes ]] || die 'use --yes to sanitize this project-created disposable VM'
[[ $# -eq 1 || ( $# -eq 2 && ${2:-} == --shutdown ) ]] || \
  die 'usage: prepare-template.sh --yes [--shutdown]'
"$script_dir/sanitize-template.sh" --yes
"$script_dir/validate-template.sh"
if [[ ${2:-} == --shutdown ]]; then
  printf '%s\n' 'TEMPLATE_PREPARE=PASS' 'SHUTDOWN=REQUESTED'
  systemctl poweroff
  exit 0
fi
printf '%s\n' 'TEMPLATE_PREPARE=PASS'
