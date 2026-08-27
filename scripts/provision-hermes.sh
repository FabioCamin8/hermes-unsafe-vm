#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

require_root
HERMES_USER=${HERMES_USER:-hermes}
HERMES_INSTALLER_URL=${HERMES_INSTALLER_URL:-https://hermes-agent.nousresearch.com/install.sh}
HERMES_INSTALLER_SHA256=${HERMES_INSTALLER_SHA256:-}
HERMES_COMMIT=${HERMES_COMMIT:-}
[[ $HERMES_INSTALLER_URL == https://hermes-agent.nousresearch.com/install.sh ]] || die 'installer URL must be the documented official Hermes installer'
[[ $HERMES_INSTALLER_SHA256 =~ ^[[:xdigit:]]{64}$ ]] || die 'HERMES_INSTALLER_SHA256 must be a 64-character SHA-256 digest'
[[ -z $HERMES_COMMIT || $HERMES_COMMIT =~ ^[0-9a-fA-F]{40}$ ]] || die 'HERMES_COMMIT must be a full commit SHA'
home=$(hermes_home_for_user "$HERMES_USER")
hermes_bin="$home/.local/bin/hermes"
source_dir="$home/.hermes/hermes-agent"
install -d -o "$HERMES_USER" -g "$HERMES_USER" -m 0700 "$home/.hermes"

if [[ ! -x $hermes_bin || ! -d $source_dir/.git ]]; then
  installer=$(mktemp /tmp/hermes-agent-installer.XXXXXX.sh)
  trap 'rm -f -- "${installer:-}"' EXIT
  curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 "$HERMES_INSTALLER_URL" --output "$installer"
  printf '%s  %s\n' "$HERMES_INSTALLER_SHA256" "$installer" | sha256sum --check --status - || die 'Hermes installer checksum failed'
  grep -q -- '--skip-setup' "$installer" || die 'Hermes installer contract lacks --skip-setup'
  grep -q -- '--skip-computer-use' "$installer" || die 'Hermes installer contract lacks Computer Use control'
  chmod 0700 "$installer"
  chown "$HERMES_USER:$HERMES_USER" "$installer"
  args=(--skip-setup)
  [[ -z $HERMES_COMMIT ]] || args+=(--commit "$HERMES_COMMIT")
  runuser -u "$HERMES_USER" -- env HOME="$home" PATH="$home/.local/bin:/usr/local/bin:/usr/bin:/bin" bash "$installer" "${args[@]}"
  rm -f -- "$installer"
  trap - EXIT
fi
[[ -x $hermes_bin && -d $source_dir/.git ]] || die 'Hermes installation did not produce the expected checkout'
source_commit=$(git -C "$source_dir" rev-parse HEAD)
if [[ -n $HERMES_COMMIT && $source_commit != "$HERMES_COMMIT" ]]; then
  die "Hermes checkout resolved to $source_commit, expected $HERMES_COMMIT"
fi
hermes_version=$(runuser -u "$HERMES_USER" -- env HOME="$home" PATH="$home/.local/bin:/usr/local/bin:/usr/bin:/bin" "$hermes_bin" --version | head -n 1)
uid=$(id -u "$HERMES_USER")
runtime_dir="/run/user/$uid"
loginctl enable-linger "$HERMES_USER" >/dev/null 2>&1 || true
systemctl start "user@$uid.service" >/dev/null 2>&1 || true
if [[ ! -S "$runtime_dir/bus" ]]; then
  systemctl restart "user@$uid.service" >/dev/null 2>&1 || true
fi
for _ in {1..30}; do
  [[ -S "$runtime_dir/bus" ]] && break
  sleep 1
done
[[ -S "$runtime_dir/bus" ]] || die 'Hermes user systemd bus is unavailable; refusing to skip gateway installation'
runuser -u "$HERMES_USER" -- env HOME="$home" PATH="$home/.local/bin:/usr/local/bin:/usr/bin:/bin" XDG_RUNTIME_DIR="$runtime_dir" DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus" "$hermes_bin" gateway install --start-now --start-on-login
install -d -m 0755 /etc/hermes-unsafe-vm
printf 'version=%s\nsource_commit=%s\n' "$hermes_version" "$source_commit" > /etc/hermes-unsafe-vm/hermes-install.env
chmod 0644 /etc/hermes-unsafe-vm/hermes-install.env
printf '%s\n' 'HERMES_PROVISION=PASS' "HERMES_VERSION=$hermes_version" "HERMES_COMMIT=$source_commit"
