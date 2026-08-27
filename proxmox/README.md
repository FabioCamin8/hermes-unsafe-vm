# Proxmox helper

`create-vm.sh` is run on the selected Proxmox node, not inside the guest. It
uses official Debian genericcloud x86_64 images, verifies SHA-512 before import,
refuses occupied VMIDs, and prints the actual imported/attached volumes. Use a
private env file; never commit a real SSH key or infrastructure identifier.

```bash
./proxmox/create-vm.sh --dry-run /path/to/private.env
./proxmox/create-vm.sh --apply /path/to/private.env
```

The script does not delete, overwrite, or reboot existing guests. Cleanup must
be performed only after rechecking the exact VMID, name, and project marker.
