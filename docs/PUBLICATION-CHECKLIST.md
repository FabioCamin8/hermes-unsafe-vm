# Publication checklist

- [ ] `git status --short` is clean after intended commits.
- [ ] No active `.env`, key, token, cookie, browser profile, vault, database,
  session, log, backup, or private URL is tracked.
- [ ] `scripts/validate-public-tree.sh` passes on the current tree.
- [ ] `scripts/validate-public-history.sh` reports `HISTORY_SCAN=PASS`, including
  the generated `git archive` path scan.
- [ ] Every reachable commit uses `FabioCamin8` and the canonical GitHub
  noreply email for both author and committer.
- [ ] Every release tag is annotated and uses the same canonical tagger.
- [ ] Git history intended for publication is a clean sanitized root.
- [ ] README leads with the unsafe-by-design warning.
- [ ] Autonomy dependency has a release tag and expected full commit.
- [ ] Fresh provisioning, second-run idempotency, real reboot, and health are
  recorded with secret-free evidence.
- [ ] Template conversion evidence records guest sanitation, source-key
  removal, stopped state, and `template: 1` without publishing source identity.
- [ ] Clone evidence records fresh Cloud-Init identity, runtime/data cleanup,
  and host/guest validation without publishing VMIDs, addresses, keys, or
  credentials.
- [ ] Private operator env files and source-identity evidence are outside Git.

## Initial-publication history correction

The initial v0.1.x Git metadata was canonicalized shortly after publication
to replace machine-generated author and tag identities with the project's
GitHub noreply identity. Source functionality and release intent were
preserved. This was a one-time correction; future release tags are immutable.
