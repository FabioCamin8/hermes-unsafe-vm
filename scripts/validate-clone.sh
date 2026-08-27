#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

require_root
HERMES_USER=hermes
home=$(hermes_home_for_user "$HERMES_USER")
hermes_bin_dir="$home/.local/bin"
hermes_cli="$hermes_bin_dir/hermes"
hermes_vault="$hermes_bin_dir/hermes-vault"
[[ -x $hermes_cli && -x $hermes_vault ]] || die 'Hermes user binaries are unavailable'
user_env=(HOME="$home" PATH="$hermes_bin_dir:$home/.hermes/node/bin:/usr/local/bin:/usr/bin:/bin")
browser_root="$home/.local/share/hermes-unsafe-vm"
[[ -d $browser_root && $(stat -c %U "$browser_root") == "$HERMES_USER" && $(stat -c %a "$browser_root") == 755 ]] || \
  die 'browser runtime parent ownership/mode is invalid'
runuser -u "$HERMES_USER" -- test -w "$browser_root" || die 'browser runtime parent is not writable by Hermes'
profile_dir="$browser_root/chromium-profile"
[[ -d $profile_dir && $(stat -c %U "$profile_dir") == "$HERMES_USER" ]] || die 'fresh Chromium profile is unavailable'

managed_file=/etc/hermes-unsafe-vm/managed
[[ -f $managed_file ]] || die 'clone is not marked as project-managed'
grep -Fxq 'managed_by=hermes-unsafe-vm' "$managed_file" || die 'managed marker is invalid'
grep -Fxq 'unsafe_boundary=guest_only' "$managed_file" || die 'unsafe boundary marker is missing'

[[ -s /etc/machine-id ]] || die 'first boot did not generate a machine-id'
if [[ -e /var/lib/dbus/machine-id ]]; then
  [[ -L /var/lib/dbus/machine-id ]] || die 'dbus machine-id is not the system link'
  [[ $(readlink -f /var/lib/dbus/machine-id) == /etc/machine-id ]] || die 'dbus machine-id link is unexpected'
fi
host_key=$(find /etc/ssh -maxdepth 1 -type f -name 'ssh_host_*_key' -print -quit)
host_key_pub=$(find /etc/ssh -maxdepth 1 -type f -name 'ssh_host_*_key.pub' -print -quit)
[[ -n $host_key && -n $host_key_pub ]] || die 'first boot did not generate SSH host keys'
ssh-keygen -lf "$host_key_pub" >/dev/null 2>&1 || die 'generated SSH host key is invalid'

hostname_value=$(hostname)
[[ -n $hostname_value && $hostname_value != localhost && $hostname_value != localhost.localdomain ]] || \
  die 'clone hostname was not supplied on first boot'
if command -v cloud-init >/dev/null 2>&1; then
  cloud_init_output=
  set +e
  cloud_init_output=$(cloud-init status --wait --long 2>&1)
  cloud_init_rc=$?
  set -e
  grep -Fxq 'status: done' <<<"$cloud_init_output" || die 'Cloud-Init did not reach done state'
  grep -Fxq 'errors: []' <<<"$cloud_init_output" || die 'Cloud-Init reported fatal errors'
fi

for forbidden in \
  "$home/.hermes/.env" "$home/.hermes/auth.json" \
  "$home/.codex/auth.json" "$home/.codex/.credentials.json" \
  "$home/.config/codex/auth.json" "$home/.config/codex/.credentials.json" \
  "$home/.git-credentials" "$home/.netrc" "$home/.config/git/credentials" \
  "$home/.config/gh" "$home/.config/pve" "$home/.local/share/pve"; do
  [[ ! -e $forbidden ]] || die "clone-forbidden state remains: $forbidden"
done
private_key=$(find "$home" -type f \( -name 'id_*' -o -name '*.pem' -o -name '*.key' \) -print -quit)
[[ -z $private_key ]] || die 'private key material remains under the Hermes home'
env_file=$(find "$home" -type f -name '.env' -print -quit)
[[ -z $env_file ]] || die 'a provider environment file remains under the Hermes home'

if ! python3 - "$profile_dir" <<'PY'
import sqlite3
import sys
from pathlib import Path

profile = Path(sys.argv[1])
for database_name, table in (
    ('Cookies', 'cookies'),
    ('Login Data', 'logins'),
    ('Web Data', 'autofill'),
    ('History', 'urls'),
):
    for database in profile.rglob(database_name):
        connection = sqlite3.connect(f'file:{database}?mode=ro&immutable=1', uri=True)
        count = connection.execute(f'SELECT COUNT(*) FROM {table}').fetchone()[0]
        connection.close()
        if count:
            raise SystemExit(1)
PY
then
  die 'browser profile contains authenticated or visited state'
fi
if scan_user_state_for_obvious_credentials "$home"; then
  die 'obvious credential pattern remains in clone user state'
else
  scan_rc=$?
  [[ $scan_rc -eq 1 ]] || die 'clone credential-state scan failed'
fi

search_output=$(runuser -u "$HERMES_USER" -- env "${user_env[@]}" "$hermes_vault" search 'validation.' --limit 100 2>/dev/null) || \
  die 'clone vault search failed'
[[ $search_output != *validation.* ]] || die 'validation memory remains in clone'
session_output=$(runuser -u "$HERMES_USER" -- env "${user_env[@]}" "$hermes_cli" sessions list --source validation --limit 5 2>/dev/null) || \
  die 'clone session search failed'
[[ $session_output != *validation.* ]] || die 'validation session state remains in clone'
integrity_output=$(mktemp)
trap 'rm -f -- "$integrity_output"' EXIT
runuser -u "$HERMES_USER" -- env "${user_env[@]}" "$hermes_vault" integrity --json >"$integrity_output" 2>/dev/null || die 'clone vault integrity failed'
grep -Fq '"ok": true' "$integrity_output" || die 'clone vault integrity is not healthy'

"$script_dir/validate.sh" >/dev/null
printf '%s\n' \
  'CLONE_VALIDATION=PASS' 'MACHINE_ID=NEW' 'SSH_HOST_KEYS=NEW' \
  'HOSTNAME=NEW' 'VAULT=EMPTY' 'SESSION_STATE=CLEAN' \
  'BROWSER_STATE=CLEAN' 'AUTH_STATE=ABSENT' 'RUNTIME=PASS'
