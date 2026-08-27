# Fresh install runbook

1. Create a disposable Debian 13 x86_64 VM with the Proxmox path or use a
   documented fresh guest.
2. Copy the repository and a private runtime configuration into the guest.
3. Review the exact Hermes commit, installer SHA-256, and the pinned autonomy
   release commit in the private config; set any allowed SSH CIDR.
4. Run `sudo ./scripts/bootstrap.sh --config PRIVATE_FILE`.
5. Capture only secret-free status, versions, and PASS/FAIL results.
6. Run the second bootstrap pass and compare memory/profile/service state.
7. Record boot identity, issue a clean guest reboot, and rerun validation.

The initial run installs operating-system packages, creates `hermes`, applies
SSH/firewall policy, creates a graphical session and fresh browser profile,
installs Hermes/CUA, verifies the autonomy tag commit, and writes
`/etc/hermes-unsafe-vm/manifest.json`.
