#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

require_root
HERMES_USER=${HERMES_USER:-hermes}
home=$(getent passwd "$HERMES_USER" | cut -d: -f6 || true)
printf '%s\n' 'EXISTING_INSPECTION=READ_ONLY'
. /etc/os-release
printf 'OS=%s\n' "${PRETTY_NAME:-unknown}"
printf 'HERMES_USER=%s\n' "$( [[ -n $home ]] && printf PRESENT || printf ABSENT )"
printf 'HERMES=%s\n' "$( [[ -x ${home:-/nonexistent}/.local/bin/hermes ]] && printf PRESENT || printf ABSENT )"
printf 'CHROMIUM=%s\n' "$( command -v chromium >/dev/null 2>&1 && printf PRESENT || printf ABSENT )"
printf 'NODE=%s\n' "$( command -v node >/dev/null 2>&1 && node --version || printf ABSENT )"
printf 'CUA=%s\n' "$( [[ -x ${home:-/nonexistent}/.local/bin/hermes ]] && "$home/.local/bin/hermes" computer-use doctor >/dev/null 2>&1 && printf PASS || printf UNKNOWN )"
printf 'AUTONOMY=%s\n' "$( [[ -d ${home:-/nonexistent}/.hermes/plugins/hermes_vault ]] && printf PRESENT || printf ABSENT )"
printf 'MCP_CONFIG=%s\n' "$( [[ -f ${home:-/nonexistent}/.hermes/config.yaml ]] && printf PRESENT || printf ABSENT )"
printf 'VAULT=%s\n' "$( [[ -d ${home:-/nonexistent}/.hermes/vault ]] && printf PRESENT || printf ABSENT )"
