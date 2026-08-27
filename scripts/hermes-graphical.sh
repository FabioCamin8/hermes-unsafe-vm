#!/usr/bin/env bash
set -Eeuo pipefail
env_file=${HERMES_GRAPHICAL_ENV_FILE:-$HOME/.config/hermes-unsafe-vm/graphical-session.env}
[[ -r $env_file ]] || { printf 'graphical session environment is unavailable\n' >&2; exit 1; }
set -a
# shellcheck disable=SC1090
source "$env_file"
set +a
export PATH="$HOME/.local/bin:$PATH"
exec "$@"
