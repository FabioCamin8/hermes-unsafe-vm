#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

require_root
HERMES_USER=${HERMES_USER:-hermes}
SSH_ALLOWED_CIDR=${SSH_ALLOWED_CIDR:-}
SSH_ALLOWED_IPV6_CIDR=${SSH_ALLOWED_IPV6_CIDR:-}
[[ $HERMES_USER =~ ^[a-z_][a-z0-9_-]*$ && $HERMES_USER != root ]] || die 'invalid HERMES_USER'
[[ -z $SSH_ALLOWED_CIDR || $SSH_ALLOWED_CIDR =~ ^[0-9./]+$ ]] || die 'invalid SSH_ALLOWED_CIDR'
[[ -z $SSH_ALLOWED_IPV6_CIDR || $SSH_ALLOWED_IPV6_CIDR =~ ^[0-9A-Fa-f:./]+$ ]] || die 'invalid SSH_ALLOWED_IPV6_CIDR'

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates curl dbus-user-session git iproute2 lightdm lightdm-gtk-greeter \
  linux-image-amd64 \
  nftables openssh-server python3 python3-venv qemu-guest-agent sqlite3 sudo \
  xorg xfce4 dbus-x11 at-spi2-core xfce4-power-manager x11-utils \
  x11-xserver-utils xinput wmctrl chromium nodejs npm

generic_kernel=$(find /boot -maxdepth 1 -type f -name 'vmlinuz-*' \
  ! -name '*-cloud-amd64' -printf '%f\n' | sed 's/^vmlinuz-//' | sort -V | tail -n 1)
[[ -n $generic_kernel ]] || die 'Debian generic kernel was not installed'

active_kernel=$(uname -r)
if [[ $active_kernel == *-cloud-amd64 ]]; then
  command -v grub-reboot >/dev/null 2>&1 || die 'grub-reboot is required to select the generic kernel'
  grub-reboot "Advanced options for Debian GNU/Linux>Debian GNU/Linux, with Linux $generic_kernel"
  printf '%s\n' 'OS_PROVISION=PARTIAL' "GENERIC_KERNEL=$generic_kernel" \
    'KERNEL_REBOOT_REQUIRED=YES'
  die 'generic kernel installed; reboot into it and rerun bootstrap.sh'
fi
[[ $active_kernel == *+deb13-amd64 ]] || die "active kernel is not Debian generic amd64: $active_kernel"

mapfile -t cloud_kernel_packages < <(
  dpkg-query -W -f='${db:Status-Status}\t${binary:Package}\n' \
    'linux-image-cloud-amd64' 'linux-image-*-cloud-amd64' 2>/dev/null |
    awk '$1 == "installed" { print $2 }' | sort -u
)
if ((${#cloud_kernel_packages[@]})); then
  apt-get purge -y "${cloud_kernel_packages[@]}"
fi
update-grub >/dev/null

if ! getent passwd "$HERMES_USER" >/dev/null; then
  useradd --create-home --user-group --shell /bin/bash "$HERMES_USER"
fi
home=$(hermes_home_for_user "$HERMES_USER")
passwd --lock "$HERMES_USER" >/dev/null 2>&1 || true
install -d -o "$HERMES_USER" -g "$HERMES_USER" -m 0700 "$home"

install -d -m 0755 /etc/ssh/sshd_config.d /etc/hermes-unsafe-vm
write_atomic /etc/ssh/sshd_config.d/90-hermes-unsafe-vm.conf 0644 <<EOF
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
AllowUsers $HERMES_USER
EOF
sshd -t
systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || true

firewall_tmp=$(mktemp)
trap 'rm -f -- "${firewall_tmp:-}"' EXIT
{
  printf '%s\n' 'table inet hermes_unsafe_vm {'
  printf '%s\n' '  chain input {' '    type filter hook input priority 0; policy drop;'
  printf '%s\n' '    iifname "lo" accept' '    ct state established,related accept'
  printf '%s\n' '    ip protocol icmp accept' '    ip6 nexthdr ipv6-icmp accept'
  if [[ -n $SSH_ALLOWED_CIDR ]]; then
    printf '    ip saddr %s tcp dport 22 accept\n' "$SSH_ALLOWED_CIDR"
  else
    printf '%s\n' '    tcp dport 22 accept'
  fi
  if [[ -n $SSH_ALLOWED_IPV6_CIDR ]]; then
    printf '    ip6 saddr %s tcp dport 22 accept\n' "$SSH_ALLOWED_IPV6_CIDR"
  fi
  printf '%s\n' '  }' '  chain forward {' '    type filter hook forward priority 0; policy drop;' '  }'
  printf '%s\n' '  chain output {' '    type filter hook output priority 0; policy accept;' '  }' '}'
} >"$firewall_tmp"
nft -c -f "$firewall_tmp"
install -o root -g root -m 0644 "$firewall_tmp" /etc/nftables.conf
systemctl enable --now nftables

systemctl enable --now qemu-guest-agent
install -d -m 0755 /etc/hermes-unsafe-vm
printf '%s\n' 'managed_by=hermes-unsafe-vm' 'unsafe_boundary=guest_only' > /etc/hermes-unsafe-vm/managed
chmod 0644 /etc/hermes-unsafe-vm/managed
printf '%s\n' 'OS_PROVISION=PASS' "HERMES_USER=$HERMES_USER" 'SSH_PASSWORD_AUTH=DISABLED' 'REMOTE_ROOT=DISABLED' 'FIREWALL=PASS'
