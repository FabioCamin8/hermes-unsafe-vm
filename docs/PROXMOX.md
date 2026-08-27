# Proxmox deployment

Run `proxmox/create-vm.sh` on the selected node. Fill only a private copy of
`proxmox/defaults.env.example`; the repository contains no host, VMID, storage,
bridge, VLAN, or operator key.

The reference profile is q35/OVMF, host CPU, four vCPUs, 8 GiB RAM, a 40 GiB
VirtIO/SCSI disk with discard/SSD/I/O-thread flags where supported, VirtIO NIC,
Cloud-Init drive, serial console, QEMU Guest Agent enabled, and DHCP. These are
parameterized defaults, not universal Proxmox requirements.

```bash
cp proxmox/defaults.env.example /root/hermes-pve.local.env
# Fill VMID, STORAGE, and SSH_PUBLIC_KEY_FILE.
sudo ./proxmox/create-vm.sh --dry-run /root/hermes-pve.local.env
sudo ./proxmox/create-vm.sh --apply /root/hermes-pve.local.env
```

The creation path does not receive or place Proxmox credentials in the guest.
Cloud-Init carries only the supplied public key and generic user settings.
