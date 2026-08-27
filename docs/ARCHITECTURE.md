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
