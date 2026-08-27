#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

require_root
HERMES_USER=${HERMES_USER:-hermes}
home=$(hermes_home_for_user "$HERMES_USER")
hermes_bin="$home/.local/bin/hermes"
wrapper="$home/.local/bin/hermes-graphical"
env_file="$home/.config/hermes-unsafe-vm/graphical-session.env"
[[ -x $hermes_bin ]] || die 'Hermes is not installed'
[[ -x $wrapper && -r $env_file ]] || die 'graphical session environment is not ready for CUA'
runuser -u "$HERMES_USER" -- env HOME="$home" PATH="$home/.local/bin:/usr/local/bin:/usr/bin:/bin" HERMES_GRAPHICAL_ENV_FILE="$env_file" "$wrapper" "$hermes_bin" computer-use doctor
printf '%s\n' 'CUA_PROVISION=PASS'
