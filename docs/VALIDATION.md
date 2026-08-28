# Validation contract

Run `scripts/validate.sh` as root inside the provisioned guest. It proves
Debian 13/x86_64, Hermes ownership/mode, key-only SSH and disabled remote root,
QEMU Guest Agent, LightDM/X11, nftables, unsafe sudo, loopback CDP, user
gateway, autonomy health, and the secret-free manifest.

Acceptance gates for fresh mode are:

- OS/network, hermes user, key-only SSH, remote root disabled, password SSH
  disabled, and firewall: PASS;
- Hermes/gateway as user `hermes`, unsafe passwordless root: PASS;
- XFCE/X11, Chromium, CDP loopback-only, Chrome MCP, and CUA: PASS;
- functional pointer input: PVE renders a QEMU USB tablet, the guest
  enumerates an event-backed pointer, X11 exposes a non-XTEST slave pointer,
  and the CUA doctor reports X11 input injection plus screen capture;
- Codex MCP protocol: PASS or explicit `BLOCKED_AUTH` for missing credentials;
- autonomy vault, SQLite/FTS, recall, session search, and `hermes-health`: PASS;
- second bootstrap run preserves state and creates no duplicate policy;
- a real reboot changes boot identity and all post-reboot runtime gates pass.

The test suite is repository-level proof only. It never substitutes for the
fresh disposable VM, reboot, or graphical CUA gates.

The pointer gate is split at the trust boundary. Run
`proxmox/validate-input.sh --verify VMID` on the Proxmox node to validate the
rendered QEMU device, then run `scripts/validate-input.sh` as root in the
guest (or use `scripts/validate.sh`, which includes it). `tablet: 1` alone is
not accepted as proof of functional input.

## Template and clone gates

The template/clone path has its own acceptance matrix:

| Gate | Required proof |
| --- | --- |
| Guest sanitation | managed marker, empty machine-id, removed SSH host keys, clean runtime/browser/auth state, preserved unsafe sudo |
| Template conversion | exact VM identity rechecked, stopped state, source Cloud-Init key/password absent, `template: 1` |
| Clone creation | unused VMID, full clone, fresh Cloud-Init public key, DHCP, non-template state |
| Clone identity | new machine-id, hostname, and SSH host-key fingerprint set compared with private source evidence |
| Clone runtime | Cloud-Init complete, Hermes health, gateway/CDP/MCP/CUA checks, clean browser, absent credentials |
| Clone data | validation vault/session search empty and Vault/SQLite integrity healthy |

Run the host wrappers from the Proxmox node and the guest validators through
the wrappers. A `PASS` in a source-tree contract test does not prove a live
template or clone.
