# Post-clone authentication

The public repository and template intentionally stop before authentication.
After validating a clone, an operator may separately:

- configure an LLM provider in the private Hermes home;
- authenticate Codex if specialist execution is wanted;
- log in to Chromium interactively;
- configure optional web or messaging services.

These values must never enter Git, Cloud-Init, a release archive, or a
reusable template. Codex MCP protocol initialization can pass while specialist
execution remains `BLOCKED_AUTH`.
