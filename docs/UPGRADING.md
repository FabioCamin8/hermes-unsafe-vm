# Upgrading

Treat each component as a separate pinned change:

1. make a private runtime backup;
2. select and verify the new Hermes, autonomy, Chrome MCP, CUA, or Codex pin;
3. run the relevant installer/provisioner and health checks;
4. run the automated tests and a real reboot gate;
5. retain the prior VM/template or restore from the reviewed backup if the
   health gate fails.

The builder does not perform automatic upgrades. Changing the autonomy tag
requires updating both `HERMES_AUTONOMY_VERSION` and its expected full commit.
