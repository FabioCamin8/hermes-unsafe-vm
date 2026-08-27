# Template clone validation evidence

Status: PASS
Date: 2026-08-27

One authorized project-created disposable candidate was sanitized, converted
to a Proxmox template, cloned, booted, and checked through the host and guest
validators. Public evidence contains results and sanitized facts only; source
identity values, VMIDs, addresses, keys, credentials, and raw logs remain
private.

## Acceptance results

- Template sanitation: `PASS`. The managed guest marker, reset machine-id,
  removed SSH host keys, clean runtime/browser/auth state, preserved unsafe
  sudo rule, and Hermes-owned writable browser-runtime parent all passed.
- Template conversion: `PASS`. Exact name/tag/status checks passed; the source
  Cloud-Init SSH key and password were absent; Proxmox reported `template: 1`.
- Clone creation: `PASS`. A previously unused VMID was full-cloned with a
  fresh Cloud-Init public key, DHCP, and `START_VM=1`.
- Clone identity: `PASS`. Machine-id, hostname, and SSH host-key identity were
  all new compared with the private source checkpoint.
- Cloud-Init and runtime: `PASS`. Cloud-Init reached `status: done` with no
  fatal errors; recoverable Debian deprecation notices were not treated as
  provisioning failures.
- Browser/auth state: `PASS`. Chromium/CDP recovered automatically after the
  graphical-session restart, CDP remained loopback-only, and cookies, logins,
  autofill, and visited-URL rows were empty. Provider/Codex/Git credentials
  were absent.
- Data state: `PASS`. Validation vault search and validation-source session
  search were empty; Vault/SQLite integrity passed.
- Component health: `PASS`. Hermes gateway, memory provider, vault database,
  SQLite integrity, Chrome CDP, Chrome MCP, Codex MCP, CUA, unsafe root,
  firewall, and aggregate validation all passed.

## Recovery notes

The first conversion attempt correctly failed closed on bundled dependency
example strings. The scanner was narrowed to mutable state and known generated
dependency assets, the private source checkpoint was reused, and QEMU Guest
Agent completed recovery after sanitation had intentionally removed SSH host
keys. A browser-runtime parent ownership defect was corrected in the sanitizer;
the source candidate was re-sanitized/re-converted with the final validator, and
the clone passed its final host/guest gate.

No provider credential was added or persisted during this acceptance. No OAuth
flow, website login, or authenticated browser state was performed.
