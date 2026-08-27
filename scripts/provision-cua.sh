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
for _ in {1..30}; do
  [[ -r $env_file ]] && break
  sleep 1
done
[[ -x $wrapper && -r $env_file ]] || die 'graphical session environment is not ready for CUA'
compat_dir="$home/.config/hermes"
compat_env_file="$compat_dir/graphical-session.env"
install -d -o "$HERMES_USER" -g "$HERMES_USER" -m 0700 "$compat_dir"
if [[ -e "$compat_env_file" || -L "$compat_env_file" ]]; then
  [[ -L "$compat_env_file" ]] || die "refusing to replace existing CUA environment file: $compat_env_file"
  [[ $(readlink -- "$compat_env_file") == "$env_file" ]] || \
    die "refusing to replace conflicting CUA environment link: $compat_env_file"
else
  ln -s -- "$env_file" "$compat_env_file"
  chown -h "$HERMES_USER:$HERMES_USER" "$compat_env_file"
fi
runuser -u "$HERMES_USER" -- env HOME="$home" PATH="$home/.local/bin:/usr/local/bin:/usr/bin:/bin" HERMES_GRAPHICAL_ENV_FILE="$env_file" "$wrapper" "$hermes_bin" computer-use doctor
printf '%s\n' 'CUA_PROVISION=PASS'
