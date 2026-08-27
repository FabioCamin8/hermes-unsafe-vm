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
install -d -o "$HERMES_USER" -g "$HERMES_USER" -m 0755 \
  "$home/.local" "$home/.local/bin" "$home/.local/share"
install -d -o "$HERMES_USER" -g "$HERMES_USER" -m 0755 "$home/.config"
profile_dir="$home/.local/share/hermes-unsafe-vm/chromium-profile"
install -d -o "$HERMES_USER" -g "$HERMES_USER" -m 0700 "$profile_dir" "$home/.config/hermes-unsafe-vm"
install -o "$HERMES_USER" -g "$HERMES_USER" -m 0700 "$script_dir/hermes-session-start.sh" "$home/.local/bin/hermes-unsafe-vm-session-start"
install -o "$HERMES_USER" -g "$HERMES_USER" -m 0700 "$script_dir/hermes-graphical.sh" "$home/.local/bin/hermes-graphical"
printf 'HERMES_CDP_PORT=%s\nHERMES_CHROMIUM_PROFILE_DIR=%s\n' "$HERMES_CDP_PORT" "$profile_dir" > /etc/hermes-unsafe-vm/runtime.env
chmod 0644 /etc/hermes-unsafe-vm/runtime.env
desktop_tmp=$(mktemp)
trap 'rm -f -- "${desktop_tmp:-}"' EXIT
{
  printf '%s\n' '[Desktop Entry]' 'Type=Application' 'Name=Hermes unsafe VM Chromium'
  printf 'Exec=%s\n' "$home/.local/bin/hermes-unsafe-vm-session-start"
  printf '%s\n' 'OnlyShowIn=XFCE;' 'X-GNOME-Autostart-enabled=true' 'NoDisplay=false'
} >"$desktop_tmp"
install -o "$HERMES_USER" -g "$HERMES_USER" -m 0644 "$desktop_tmp" "$home/.config/autostart/hermes-unsafe-vm-chromium.desktop"
rm -f -- "$desktop_tmp"
trap - EXIT
chown -R "$HERMES_USER:$HERMES_USER" "$home/.config/hermes-unsafe-vm" "$profile_dir"
systemctl enable --now lightdm >/dev/null
systemctl restart lightdm
printf '%s\n' 'BROWSER_PROVISION=PASS' "CDP=127.0.0.1:$HERMES_CDP_PORT" 'PROFILE=FRESH_PER_VM'
