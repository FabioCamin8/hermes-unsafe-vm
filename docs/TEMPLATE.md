# Template mode

Template conversion is implemented, but it is only for one fully provisioned,
validated, project-created disposable VM. The Proxmox wrapper is the lifecycle
entry point:

```bash
./proxmox/convert-template.sh --apply /path/to/private-template.env
```

The private env file identifies the exact VM by VMID, hostname, and the
`hermes-unsafe-vm` tag. It also supplies a guest SSH identity and a private
source-evidence path. The wrapper captures the source machine-id, SSH host-key
fingerprint, and hostname, then asks the guest to run:

```bash
sudo ./scripts/prepare-template.sh --yes --shutdown
```

The guest sanitation removes browser profiles and caches, Hermes vault/session
state, runtime databases and journals, provider/Codex/Git credentials, shell
history, DHCP/cloud-init state, SSH host keys, machine-id contents, logs, and
temporary state. It preserves installed packages, desktop/Hermes/CUA/MCP code,
firewall policy, generic configuration, health tools, release metadata, and
`sudo NOPASSWD: ALL`, because this is explicitly an Hermes Unsafe VM template.

The fail-closed guest validator requires the managed marker, reset identity,
empty runtime state, no browser/auth state or obvious credential patterns, and
working unsafe sudo. After the guest stops, the wrapper rechecks the exact
VMID/name/tag/status, removes any inherited Proxmox Cloud-Init SSH key and
password, and only then runs `qm template`.

The source identity file is private operational state. Do not commit it or
record its values in public evidence. A clean local sanitation run is not proof
of template conversion; use the recorded template/clone evidence instead. If a
guest loses SSH after sanitation and a retry is needed, the wrapper validates a
complete private checkpoint and uses QEMU Guest Agent recovery before the
stopped/template checks.
