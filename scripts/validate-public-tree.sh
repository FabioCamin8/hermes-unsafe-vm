#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"
status=0
while IFS= read -r -d '' path; do
  case "$path" in
    .env|.env.*|*.db|*.db-wal|*.db-shm|*.sqlite*|*.pem|*.key|*.pub|*.token|*.secret|*.credentials|*.cookie|auth.json|*/browser-profile/*|*/chromium-profile/*|*/sessions/*|*/backups/*)
      printf 'FORBIDDEN_PUBLIC_PATH %s\n' "$path" >&2
      status=1
      ;;
  esac
done < <(git ls-files -co --exclude-standard -z)

if rg -n --hidden --glob '!.git/**' \
  --regexp '-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----|\b(sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{16,}|AIza[A-Za-z0-9_-]{24,})\b' .; then
  printf '%s\n' 'OBVIOUS_SECRET_PATTERN_FOUND' >&2
  status=1
fi
if rg -n --hidden --glob '!.git/**' --regexp '192\.168\.|\b10\.(?:[0-9]{1,3}\.){2}[0-9]{1,3}\b|\b172\.(?:1[6-9]|2[0-9]|3[0-1])\.' .; then
  printf '%s\n' 'PRIVATE_NETWORK_LITERAL_FOUND' >&2
  status=1
fi
if rg -n --hidden --glob '!.git/**' --glob '!*.example*' \
  --regexp '(^|/)(\.env|auth\.json|[^/]+\.(db|db-wal|db-shm|sqlite|sqlite3|cookie|token|secret|credentials))$|(^|/)(browser-profile|chromium-profile|sessions|backups)(/|$)' \
  < <(git ls-files); then
  printf '%s\n' 'RUNTIME_FILENAME_FOUND' >&2
  status=1
fi
if ((status == 0)); then
  printf '%s\n' 'PUBLIC_TREE_SCAN=PASS'
else
  printf '%s\n' 'PUBLIC_TREE_SCAN=FAIL'
fi
exit "$status"
