# Requirements and version policy

## Supported baseline

| Component | Policy |
| --- | --- |
| Guest | Debian 13 (Trixie), x86_64 |
| Proxmox | `qm`, `pvesm`, OVMF, VirtIO; exact tested version recorded per run |
| Hermes | official installer, pinned full commit in private config |
| Chromium | Debian package, fresh profile, CDP loopback-only |
| Node/npm | Debian packages unless Hermes supplies a newer managed runtime |
| Chrome DevTools MCP | `1.8.0`, never `@latest` |
| Codex CLI | `@openai/codex` `0.150.1`, never `@latest` |
| autonomy | `v0.1.2` at `d85bed5126376af913c3ca3e607396bee5493461` |

The tested image baseline is `debian-13-genericcloud-amd64-20260826-2582.qcow2`
from the matching dated Debian cloud-image directory. Update the date and
review its SHA-512 manifest deliberately when refreshing the image.

## Primary sources

- Hermes installer: https://hermes-agent.nousresearch.com/install.sh
- Hermes source: https://github.com/NousResearch/hermes-agent
- Debian cloud images: https://cloud.debian.org/images/cloud/
- Debian Chromium: https://packages.debian.org/trixie/chromium
- Chrome DevTools MCP: https://github.com/ChromeDevTools/chrome-devtools-mcp
- Chrome DevTools Protocol: https://chromedevtools.github.io/devtools-protocol/
- Codex MCP: https://developers.openai.com/codex/mcp-server
- CUA: https://github.com/trycua/cua

The installer digest and release pins are configuration inputs so an operator
can review them against current upstream metadata before a fresh run.
