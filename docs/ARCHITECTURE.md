# Architecture

```text
Proxmox VE
└── Debian 13 x86_64 VM
    ├── SSH key-only / nftables / QEMU Guest Agent
    ├── XFCE + X11 + LightDM
    ├── Chromium --remote-debugging-address=127.0.0.1
    ├── Hermes Agent + user gateway
    │   ├── Chrome DevTools MCP (primary browser path)
    │   ├── CUA (graphical fallback)
    │   └── Codex MCP (specialist escalation)
    └── pinned hermes-unsafe-autonomy release
```

The VM repository owns operating-system convergence and orchestration. The
autonomy repository owns the vault provider, health, recovery, MCP wiring, and
unsafe sudo rule. The builder downloads and verifies that release; it does not
duplicate the implementation.

The gateway remains a user systemd service. The `hermes` user is nevertheless
fully root-capable through the explicit unsafe sudo rule.

## Template lifecycle

```text
validated disposable VM
        │
        ├── guest sanitize + validate
        ├── capture source identity privately
        ├── clear Cloud-Init source credentials
        └── Proxmox template
                    │
                    ├── full clone + fresh Cloud-Init SSH key
                    ├── DHCP first boot regenerates identity/host keys
                    └── host identity + guest runtime/data validation
```

The guest scripts own state deletion and runtime invariants. The Proxmox
scripts own exact VM identity, stopped/template state, Cloud-Init inputs, and
cross-boot identity comparison. No provider credential, browser session, or
source identity value crosses into the public repository.
