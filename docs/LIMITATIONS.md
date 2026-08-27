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
- Template conversion and clone validation are separate operational gates. A
  template is not accepted merely because guest sanitation passed, and a clone
  is not accepted until it has booted and passed both host and guest gates.
- Clone validation compares identity and clean state; it does not authenticate
  providers, log into websites, or prove that a future operator will keep
  credentials out of the clone.
- Upstream installers, package availability, browser behavior, and Hermes
  interfaces can change; refresh research when pins or major components move.
