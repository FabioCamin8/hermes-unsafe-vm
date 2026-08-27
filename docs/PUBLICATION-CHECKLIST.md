# Publication checklist

- [ ] `git status --short` is clean after intended commits.
- [ ] No active `.env`, key, token, cookie, browser profile, vault, database,
  session, log, backup, or private URL is tracked.
- [ ] `scripts/validate-public-tree.sh` passes on the current tree.
- [ ] Git history intended for publication is a clean sanitized root.
- [ ] README leads with the unsafe-by-design warning.
- [ ] Autonomy dependency has a release tag and expected full commit.
- [ ] Fresh provisioning, second-run idempotency, real reboot, and health are
  recorded with secret-free evidence.
- [ ] Template/clone claims are made only when their gates were executed.
