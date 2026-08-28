#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

require_root
HERMES_USER=${HERMES_USER:-hermes}
HERMES_CDP_PORT=${HERMES_CDP_PORT:-9222}
require_integer_range HERMES_CDP_PORT "$HERMES_CDP_PORT" 1 65535
home=$(hermes_home_for_user "$HERMES_USER")
uid=$(id -u "$HERMES_USER")
runtime_dir=/run/user/$uid
. /etc/os-release
[[ ${ID:-} == debian && ${VERSION_ID:-} == 13 ]] || die 'OS gate failed: Debian 13 required'
[[ $(uname -m) == x86_64 ]] || die 'architecture gate failed'
[[ $(stat -c %U "$home") == "$HERMES_USER" && $(stat -c %a "$home") == 700 ]] || die 'Hermes home ownership/mode gate failed'
runuser -u "$HERMES_USER" -- sudo -n id -u | grep -qx 0 || die 'unsafe sudo gate failed'
ssh_effective=$(sshd -T)
grep -Eiq '^passwordauthentication no$' <<<"$ssh_effective" || die 'password SSH is enabled'
grep -Eiq '^permitrootlogin no$' <<<"$ssh_effective" || die 'remote root SSH is enabled'
systemctl is-active --quiet qemu-guest-agent || die 'QEMU guest agent is not active'
systemctl is-active --quiet lightdm || die 'LightDM is not active'
systemctl is-active --quiet nftables || die 'nftables is not active'
"$script_dir/validate-input.sh"
curl -fsS "http://127.0.0.1:$HERMES_CDP_PORT/json/version" >/dev/null || die 'CDP endpoint is unavailable'
listeners=$(ss -ltnH | awk -v expected="127.0.0.1:$HERMES_CDP_PORT" '$4 == expected { found = 1 } END { exit !found }' && printf PASS || printf FAIL)
[[ $listeners == PASS ]] || die 'CDP is not loopback-only'
[[ -x "$home/.local/bin/hermes-health" ]] || die 'hermes-health is not installed'
[[ -S "$runtime_dir/bus" ]] || die 'Hermes user systemd bus is unavailable'
user_env=(HOME="$home" PATH="$home/.local/bin:$home/.hermes/node/bin:/usr/local/bin:/usr/bin:/bin" XDG_RUNTIME_DIR="$runtime_dir" DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus" HERMES_CDP_PORT="$HERMES_CDP_PORT")
runuser -u "$HERMES_USER" -- env "${user_env[@]}" systemctl --user is-active --quiet hermes-gateway.service || die 'Hermes gateway is not active'
health_output=$(mktemp)
trap 'rm -f -- "${health_output:-}"' EXIT
runuser -u "$HERMES_USER" -- env "${user_env[@]}" "$home/.local/bin/hermes-health" | tee "$health_output"
grep -q '^Overall: *PASS$' "$health_output" || die 'aggregate health is not PASS'
[[ -s /etc/hermes-unsafe-vm/manifest.json ]] || die 'manifest is missing'
python3 - <<'PY'
import json
with open('/etc/hermes-unsafe-vm/manifest.json', encoding='utf-8') as handle:
    manifest = json.load(handle)
assert manifest['unsafe_root_enabled'] is True
assert manifest['cdp'].startswith('127.0.0.1:')
PY
printf '%s\n' \
  'OS_NETWORK=PASS' 'HERMES_USER=PASS' 'SSH_KEY_ONLY=PASS' \
  'REMOTE_ROOT=DISABLED' 'UNSAFE_SUDO=PASS' 'FIREWALL=PASS' \
  'DESKTOP=PASS' 'CHROMIUM=PASS' "CDP_LOOPBACK=PASS:$HERMES_CDP_PORT" \
  'HERMES_GATEWAY=PASS' 'HERMES_HEALTH=PASS' 'VALIDATION=PASS'
