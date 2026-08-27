# Hermes Unsafe VM

## UNSAFE BY DESIGN

This project builds a contained Debian VM in which an LLM-controlled Hermes
Agent can receive unrestricted passwordless root access and control of an
authenticated browser. Prompt injection, agent error, malicious MCP servers,
or compromised dependencies can fully compromise the VM and any credentials
reachable from it. Use only inside a dedicated or disposable VM. Do not use a
workstation, shared server, or host containing unrelated secrets.

The VM boundary is the containment strategy. The guest is deliberately unsafe
by design; it is not a secure autonomous-agent appliance.

## What it builds

`hermes-unsafe-vm` provisions a fresh Debian 13 x86_64 guest with:

- SSH key-only access, remote root login disabled, and a minimal nftables policy;
- QEMU Guest Agent, XFCE/X11, LightDM, and a fresh Chromium profile;
- Chromium CDP bound only to `127.0.0.1`;
- Hermes Agent, Computer Use, Chrome DevTools MCP, and Codex MCP;
- the released `hermes-unsafe-autonomy` runtime, installed by immutable tag and
  expected commit rather than copied into this repository;
- a secret-free version manifest and health/validation commands.

The companion runtime repository is [hermes-unsafe-autonomy](https://github.com/FabioCamin8/hermes-unsafe-autonomy). Use that project when Hermes is already installed; use this project when a dedicated Debian/Proxmox VM must be built.

## Quick start: fresh Debian guest

Copy this repository and a private configuration file into a fresh Debian 13
VM, then run as root inside the guest:

```bash
cp config/defaults.env.example /root/hermes-unsafe-vm.local.env
sudo ./scripts/bootstrap.sh --config /root/hermes-unsafe-vm.local.env
```

The bootstrap is rerunnable. It installs only the listed guest state, never
authenticates an account, and never receives Proxmox credentials. Run
`scripts/validate.sh` after a real reboot as well as after the first pass.

## Proxmox path

Run [proxmox/create-vm.sh](proxmox/create-vm.sh) on the selected Proxmox node
with a private copy of `proxmox/defaults.env.example`. The script verifies the
official Debian image checksum, refuses an occupied VMID, parameterizes storage,
bridge, CPU, memory, disk, VLAN, and SSH key, and can only create with the
explicit `--apply` mode. See [docs/PROXMOX.md](docs/PROXMOX.md).

## Other modes

`--mode existing` performs a read-only inventory first and refuses to converge
an unmarked system. It is experimental and does not overwrite unrelated state.
`scripts/prepare-template.sh --yes --shutdown` sanitizes a project-created
disposable VM for template conversion; it preserves installed software and
the intentionally unsafe sudo rule while removing identity, credentials,
runtime memory, sessions, and browser state.

## Post-deployment authentication

Provider setup, Codex login, browser login, and optional web-service accounts
are operator actions after deployment or cloning. No API key, OAuth state,
cookie, saved password, private key, or Proxmox credential belongs in Git,
Cloud-Init, or a template.

## Validation and limitations

The acceptance contract is in [docs/VALIDATION.md](docs/VALIDATION.md). A
successful protocol initialization does not mean Codex is authenticated;
specialist execution may remain `BLOCKED_AUTH`. Debian Chromium is empirically
validated against the pinned Chrome DevTools MCP release, not claimed as its
official browser target. Run both `scripts/validate-public-tree.sh` and
`scripts/validate-public-history.sh` before publication. See
[docs/LIMITATIONS.md](docs/LIMITATIONS.md).

License: pending. No license has been selected for this experimental project.
