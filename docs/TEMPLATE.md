# Template mode

Only sanitize a fully provisioned, validated, cleanly stopped disposable VM
created for this project. Run:

```bash
sudo ./scripts/prepare-template.sh --yes --shutdown
```

Sanitation removes the Chromium profile, Hermes vault/session/memory contents,
auth files, shell history, DHCP leases, journal contents, SSH host keys,
temporary Hermes output, and machine-id contents. It preserves packages,
desktop, Hermes/CUA/MCP code, firewall policy, generic configuration, health
tools, release metadata, and `sudo NOPASSWD: ALL` because this is explicitly an
Hermes Unsafe VM template.

`validate-template.sh` is a fail-closed gate. It requires the project marker,
empty `/etc/machine-id`, absent SSH host keys and browser/auth state, empty
runtime directories, no obvious key/token patterns, and working unsafe sudo.
