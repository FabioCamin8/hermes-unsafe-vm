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
- Codex MCP protocol: PASS or explicit `BLOCKED_AUTH` for missing credentials;
- autonomy vault, SQLite/FTS, recall, session search, and `hermes-health`: PASS;
- second bootstrap run preserves state and creates no duplicate policy;
- a real reboot changes boot identity and all post-reboot runtime gates pass.

The test suite is repository-level proof only. It never substitutes for the
fresh disposable VM, reboot, or graphical CUA gates.
