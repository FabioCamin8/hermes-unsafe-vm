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
cua_version=$(runuser -u "$HERMES_USER" -- env HOME="$home" PATH="$home/.local/bin:$home/.hermes/node/bin:/usr/local/bin:/usr/bin:/bin" "$home/.local/bin/cua-driver" --version 2>/dev/null | awk 'NR == 1 { print $2 }' || true)
[[ -n $cua_version ]] || die 'unable to resolve the installed CUA version'
python3 "$script_dir/write-manifest.py" \
  --output /etc/hermes-unsafe-vm/manifest.json \
  --builder-version 0.1.1 \
  --autonomy-version "$autonomy_version" \
  --autonomy-commit "$autonomy_commit" \
  --hermes-version "$hermes_version" \
  --chromium-version "$chromium_version" \
  --node-version "$node_version" \
  --chrome-devtools-mcp-version "${CHROME_DEVTOOLS_MCP_VERSION:-unknown}" \
  --cua-version "$cua_version" \
  --codex-version "${CODEX_VERSION:-unknown}" \
  --cdp-port "$HERMES_CDP_PORT" \
  --unsafe-root-enabled
"$script_dir/validate.sh"
printf '%s\n' 'BOOTSTRAP=PASS' 'MANIFEST=/etc/hermes-unsafe-vm/manifest.json'
