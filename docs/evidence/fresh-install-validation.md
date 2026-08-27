# Fresh install validation evidence

Status: ACCEPTED WITH MODEL-CAPACITY NOTE
Date: 2026-08-27

## Baseline

- Guest: Debian GNU/Linux 13, x86_64.
- Hermes Agent: v0.20.5 at the configured full commit.
- Autonomy: public `v0.1.2` at `d85bed5126376af913c3ca3e607396bee5493461`.
- Chrome DevTools MCP: 1.8.0.
- Codex MCP: 0.150.1.
- CUA driver: 0.22.1.

## Acceptance results

- Final first-install bootstrap: PASS, including `BOOTSTRAP=PASS`, autonomy
  installation, immutable release verification, Vault/SQLite integrity, and
  aggregate health.
- Second and third bootstrap reruns: PASS. The autonomy checkout remained at
  the expected SHA, protected Hermes configuration/database/service hashes and
  FTS/application counts were preserved, the browser-profile boundary remained
  unchanged, and exactly one unsafe-root policy file remained. Each rerun adds
  the expected append-only integrity audit event and private pre-autonomy
  backup; byte-identical Vault files are not an invariant.
- Live runtime gates: PASS for `hermes_vault`, SQLite/FTS integrity, durable
  checkpoint/journal search, gateway, loopback CDP, Chrome MCP, Codex MCP
  initialize/tools-list, graphical CUA doctor, and `hermes-health`.
- Real guest reboot: PASS. The boot identity changed; the user bus, gateway,
  desktop, Chromium/CDP, Chrome MCP, Codex MCP, CUA, and aggregate validator
  recovered automatically.
- Native session-search command: PASS; no validation-source rows existed in
  this run because no inference provider was configured.
- Synthetic direct-memory record: PASS for upsert, FTS search, checkpoint
  journal search, soft-forget, and post-cleanup integrity; no active marker
  remained.
- Fresh-VM cross-session recall A/B: PASS with a temporary per-run model
  override to `minimax/minimax-m3:free`. Session A and B exited successfully,
  the automatic-recall indicator appeared, the exact synthetic value matched,
  cleanup/soft-forget passed, active search was empty, and SQLite integrity
  passed. The configured default model was unchanged.

## External boundary

The default configured model was not independently probed in this run because
the provider allowed only a small remaining budget while that model reserved
128K tokens. The A/B proof therefore uses only the temporary per-run model
override above; it does not claim that the default model is currently usable.
No credential was added or persisted, and no OAuth flow was started.

## Defects fixed during acceptance

- Root-created release checkouts are normalized to user-traversable modes.
- The VM exposes a conflict-protected compatibility link for the autonomy
  graphical-session default path.
- Codex aggregate health probing retries within a bounded window.
- SSH effective-config validation avoids the `pipefail`/`grep -q` SIGPIPE false
  negative.

No credentials, addresses, VM identifiers, hostnames, keys, browser
titles/URLs, raw logs, session IDs, or runtime database contents are recorded
here.
