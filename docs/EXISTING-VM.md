# Existing VM mode

Existing mode is experimental. `bootstrap.sh --mode existing` first runs
`inspect-existing.sh`, which reports OS, Hermes, Chromium, Node, CUA,
autonomy, MCP configuration, and vault presence without modifying them.

The v0.1 implementation then refuses convergence, even for a marked VM, until
ownership and rollback are reviewed. An unmarked VM fails closed rather than
guessing ownership or overwriting unrelated configuration. Use fresh mode for
the supported v0.1 path.
