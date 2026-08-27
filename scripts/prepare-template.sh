#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

require_root
[[ ${1:-} == --yes ]] || die 'use --yes to sanitize this project-created disposable VM'
"$script_dir/sanitize-template.sh" --yes
"$script_dir/validate-template.sh"
if [[ ${2:-} == --shutdown ]]; then
  systemctl poweroff
fi
printf '%s\n' 'TEMPLATE_PREPARE=PASS'
