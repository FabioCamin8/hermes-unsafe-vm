# Limitations

- This project is unsafe by design; root inside the VM is intentional.
- Existing mode refuses unmarked systems and remains experimental.
- Codex specialist execution may remain `BLOCKED_AUTH` until an operator logs
  in; bootstrap never starts OAuth.
- Debian Chromium is an empirical compatibility result for Chrome DevTools
  MCP, whose official target is Chrome/Chrome for Testing.
- CUA requires a live graphical X11 session; SSH-only checks are insufficient.
- Proxmox apply behavior is tested only against the recorded environment and
  parameterized storage/network settings; cross-backend portability is not
  implied.
- Template conversion and clone validation are separate gates and may be
  `NOT IMPLEMENTED` or `NOT VALIDATED` in an initial release.
- Upstream installers, package availability, browser behavior, and Hermes
  interfaces can change; refresh research when pins or major components move.
