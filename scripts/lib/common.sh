#!/usr/bin/env bash
set -Eeuo pipefail

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

require_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || die 'run this script as root inside the guest'
}

load_env() {
  local file=${1:-}
  [[ -z $file || -r $file ]] || die "configuration is not readable: $file"
  if [[ -n $file ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$file"
    set +a
  fi
}

require_var() {
  local name=$1
  [[ -n ${!name:-} ]] || die "$name is required"
}

require_integer_range() {
  local name=$1 value=$2 minimum=$3 maximum=$4
  [[ $value =~ ^[0-9]+$ ]] || die "$name must be an integer"
  ((10#$value >= minimum && 10#$value <= maximum)) || die "$name is outside its valid range"
}

hermes_home_for_user() {
  local user=$1 home
  home=$(getent passwd "$user" | cut -d: -f6)
  [[ -n $home && -d $home ]] || die "home directory is unavailable for $user"
  printf '%s\n' "$home"
}

write_atomic() {
  local destination=$1 mode=$2
  local temporary
  temporary=$(mktemp "${destination}.tmp.XXXXXX")
  trap 'rm -f -- "${temporary:-}"' RETURN
  cat >"$temporary"
  install -o root -g root -m "$mode" "$temporary" "$destination"
  rm -f -- "$temporary"
  trap - RETURN
}

scan_user_state_for_obvious_credentials() {
  local home=$1
  local pattern='-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----|\b(sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{16,}|AIza[A-Za-z0-9_-]{24,})\b'
  [[ -d $home ]] || return 2
  (
    cd "$home" || exit 2
    rg -l --hidden \
      --glob '!.hermes/hermes-agent/**' \
      --glob '!.hermes/node/**' \
      --glob '!.hermes/skills/**' \
      --glob '!.local/share/hermes-autonomy/**' \
      --glob '!.local/share/uv/**' \
      --glob '!.local/share/hermes-unsafe-vm/chromium-profile/WasmTtsEngine/**' \
      --glob '!*.pyc' --glob '!*.log' \
      --regexp "$pattern" \
      .hermes .config .local/share .ssh >/dev/null 2>&1
  )
}
