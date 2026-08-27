# Security and containment

## Deliberate unsafe boundary

The guest installs:

```text
hermes ALL=(ALL:ALL) NOPASSWD: ALL
```

This is intentionally unrestricted internal agent privilege. SSH hardening,
nftables, loopback CDP, and the Proxmox VM boundary contain exposure; they do
not make Hermes safe. A compromised browser, MCP server, dependency, prompt,
or model interaction can use root inside the guest.

## Boundaries preserved

- The guest receives no Proxmox API token, host password, host private key,
  host filesystem mount, or unrestricted host-device access.
- SSH accepts public keys only; password authentication and remote root login
  are disabled.
- CDP is bound to `127.0.0.1` and is never forwarded by these scripts.
- The reusable browser profile is absent or freshly created and unauthenticated.
- Public configuration contains placeholders only; active `.env` files are
  ignored and never copied by Cloud-Init examples.
- Template conversion captures source identity privately, removes guest
  credentials/runtime/browser state, clears inherited Cloud-Init keys, and
  requires the exact tagged VM to be stopped before conversion.
- Cloning supplies a fresh Cloud-Init public key and validates identity and
  runtime separation before onboarding. Source identity evidence and operator
  addresses remain outside Git and public evidence.

The `hermes` account remains intentionally root-capable inside the VM. Do not
describe this as least privilege or as a security control.

## Operational rules

1. Use a dedicated VM with only in-scope data and network access.
2. Keep Proxmox credentials and unrelated host credentials outside the guest.
3. Validate candidate SSH/firewall configuration before reload and retain a
   working operator session during changes.
4. Back up private runtime state before upgrades; never repair SQLite by
   deleting its database.
5. Disconnect the VM and rotate potentially exposed credentials after an
   unexpected browser, MCP, or network exposure.
