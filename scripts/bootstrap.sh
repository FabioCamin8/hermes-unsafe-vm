#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/lib/common.sh
source "$script_dir/lib/common.sh"
require_root
config_file=
mode=fresh
while (($#)); do
  case $1 in
    --config) (($# >= 2)) || die '--config requires a file'; config_file=$2; shift 2 ;;
    --mode) (($# >= 2)) || die '--mode requires fresh or existing'; mode=$2; shift 2 ;;
    -h|--help) printf '%s\n' 'Usage: bootstrap.sh [--config FILE] [--mode fresh|existing]'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done
[[ $mode == fresh || $mode == existing ]] || die 'mode must be fresh or existing'
load_env "$config_file"
HERMES_USER=${HERMES_USER:-hermes}
HERMES_CDP_PORT=${HERMES_CDP_PORT:-9222}
ENABLE_AUTOLOGIN=${ENABLE_AUTOLOGIN:-true}
export HERMES_USER HERMES_CDP_PORT ENABLE_AUTOLOGIN
if [[ $mode == existing ]]; then
  "$script_dir/inspect-existing.sh"
  [[ -f /etc/hermes-unsafe-vm/managed ]] || die 'existing mode requires a project-managed VM marker; refusing an unknown system'
  die 'existing mode is inspection-only in v0.1; refusing convergence until ownership and rollback are reviewed'
fi
"$script_dir/preflight.sh"
"$script_dir/provision-os.sh"
"$script_dir/provision-desktop.sh"
"$script_dir/provision-browser.sh"
"$script_dir/provision-hermes.sh"
"$script_dir/provision-cua.sh"
"$script_dir/install-autonomy.sh"

home=$(hermes_home_for_user "$HERMES_USER")
autonomy_version=${HERMES_AUTONOMY_VERSION:-unknown}
autonomy_commit=${HERMES_AUTONOMY_COMMIT:-unknown}
hermes_version=$(runuser -u "$HERMES_USER" -- env HOME="$home" PATH="$home/.local/bin:$home/.hermes/node/bin:/usr/local/bin:/usr/bin:/bin" "$home/.local/bin/hermes" --version | head -n 1)
chromium_version=$(/usr/bin/chromium --version 2>/dev/null || true)
node_version=$(node --version)
python3 - "$autonomy_version" "$autonomy_commit" "$hermes_version" "$chromium_version" "$node_version" "$HERMES_CDP_PORT" <<'PY'
import json
import os
import platform
import sys
from datetime import datetime, timezone

version, commit, hermes, chromium, node, port = sys.argv[1:]
payload = {
    "schema": 1,
    "builder_version": "0.1.0",
    "debian_version": platform.release(),
    "hermes_version": hermes,
    "autonomy_version": version,
    "autonomy_commit": commit,
    "chrome_devtools_mcp_version": os.environ.get("CHROME_DEVTOOLS_MCP_VERSION", "unknown"),
    "chromium_version": chromium,
    "cua_version": "installed-by-hermes",
    "codex_version": os.environ.get("CODEX_VERSION", "unknown"),
    "node_version": node,
    "cdp": f"127.0.0.1:{port}",
    "provisioned_at": datetime.now(timezone.utc).isoformat(),
    "unsafe_root_enabled": True,
}
with open("/etc/hermes-unsafe-vm/manifest.json", "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2, sort_keys=True)
    handle.write("\n")
os.chmod("/etc/hermes-unsafe-vm/manifest.json", 0o644)
PY
"$script_dir/validate.sh"
printf '%s\n' 'BOOTSTRAP=PASS' 'MANIFEST=/etc/hermes-unsafe-vm/manifest.json'
