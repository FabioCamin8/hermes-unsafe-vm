#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"
for script in scripts/*.sh scripts/lib/*.sh proxmox/*.sh; do
  bash -n "$script"
done
grep -q 'UNSAFE BY DESIGN' README.md
grep -q -- '--enable-unsafe-root' scripts/install-autonomy.sh
grep -q 'HERMES_AUTONOMY_COMMIT' scripts/install-autonomy.sh config/defaults.env.example
grep -q 'rev-parse HEAD' scripts/install-autonomy.sh
grep -q 'HERMES_CDP_PORT' scripts/hermes-session-start.sh scripts/validate.sh
grep -q 'NOPASSWD: ALL' SECURITY.md
! rg -n '(@latest|curl[^\n]*\|[^\n]*bash)' scripts config proxmox
printf '%s\n' 'CONTRACT_TESTS=PASS'
