# Cloning and first boot

Clone only a template produced by `proxmox/convert-template.sh`:

```bash
./proxmox/clone-template.sh --apply /path/to/private-clone.env
```

The private clone env file names the source template, a previously unused
clone VMID, target storage, clone name, and a fresh public SSH key. The wrapper
refuses an occupied clone VMID, performs a full clone, sets `ciuser=hermes`,
installs the supplied Cloud-Init key, configures DHCP, refreshes Cloud-Init,
and starts the clone when `START_VM=1`.

After boot, query the clone's address through QEMU Guest Agent on the selected
Proxmox node, place that address in the private env file as `SSH_HOST`, and run:

```bash
./proxmox/validate-clone.sh --verify /path/to/private-clone.env
```

The host gate waits for SSH within a bounded window, compares the clone with
the private source identity evidence, and proves a new machine-id, hostname,
and SSH host-key set. The guest gate then proves Cloud-Init completion,
installed Hermes/runtime health, loopback CDP, absent provider/Codex/Git
credentials, clean browser state, empty validation vault/session state, and
healthy Vault/SQLite integrity.

A clean Chromium profile may contain its normal empty `Cookies`, `Login Data`,
`Web Data`, and `History` databases. The validator checks their data rows and
requires zero cookies, logins, autofill, and visited URLs; it does not reject
these empty database files by name.

Authentication and browser onboarding are deliberately not part of cloning.
Do not copy a provider `.env`, OAuth state, cookie, saved password, private key,
session database, or browser profile into the template or clone. If either
conversion or validation is not executed, record the gate as not validated;
never infer clone safety from a local sanitation run.
