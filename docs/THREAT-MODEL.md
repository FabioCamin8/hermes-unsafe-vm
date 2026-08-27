# Threat model

This is an unsafe-by-design runtime. Web content, browser state, external MCP
responses, dependencies, and model output are untrusted inputs. Any successful
prompt injection or agent error can reach root and the authenticated browser
inside the VM.

The containment boundary is the dedicated VM and its deliberately minimal
network exposure. Residual blast radius includes all guest files, guest
credentials, browser sessions, outbound destinations, and services reachable
from the guest. The project does not promise a sandbox, account isolation, or
safe autonomous decisions.

Recovery measures include immutable release pins, SQLite/provider health,
private backups owned by the autonomy layer, clean template preparation, and
secret-free publication scans. These controls improve auditability and
recoverability; they do not reduce the selected internal root capability.
