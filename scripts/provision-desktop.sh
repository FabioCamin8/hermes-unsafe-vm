#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

require_root
HERMES_USER=${HERMES_USER:-hermes}
ENABLE_AUTOLOGIN=${ENABLE_AUTOLOGIN:-true}
[[ $ENABLE_AUTOLOGIN == true || $ENABLE_AUTOLOGIN == false ]] || die 'ENABLE_AUTOLOGIN must be true or false'
home=$(hermes_home_for_user "$HERMES_USER")
install -d -m 0755 /etc/lightdm/lightdm.conf.d
lightdm_tmp=$(mktemp)
trap 'rm -f -- "${lightdm_tmp:-}"' EXIT
{
  printf '%s\n' '[LightDM]' 'start-default-seat=true' 'logind-check-graphical=false'
  printf '%s\n' '' '[Seat:*]' 'allow-guest=false' 'greeter-session=lightdm-gtk-greeter' 'user-session=xfce'
  if [[ $ENABLE_AUTOLOGIN == true ]]; then
    printf 'autologin-user=%s\n' "$HERMES_USER"
    printf '%s\n' 'autologin-user-timeout=0' 'autologin-session=xfce'
  fi
} >"$lightdm_tmp"
install -o root -g root -m 0644 "$lightdm_tmp" /etc/lightdm/lightdm.conf.d/50-hermes-unsafe-vm.conf
rm -f -- "$lightdm_tmp"
trap - EXIT
install -d -o "$HERMES_USER" -g "$HERMES_USER" -m 0755 "$home/.local/bin" "$home/.config/autostart" "$home/.config/hermes"
systemctl set-default graphical.target >/dev/null
systemctl enable lightdm >/dev/null
printf '%s\n' 'DESKTOP_PROVISION=PASS' "AUTOLOGIN=$ENABLE_AUTOLOGIN" 'DISPLAY_STACK=XFCE_X11'
