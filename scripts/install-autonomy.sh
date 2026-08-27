#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$script_dir/lib/common.sh"

require_root
HERMES_USER=${HERMES_USER:-hermes}
HERMES_CDP_PORT=${HERMES_CDP_PORT:-9222}
HERMES_AUTONOMY_REPO=${HERMES_AUTONOMY_REPO:-}
HERMES_AUTONOMY_VERSION=${HERMES_AUTONOMY_VERSION:-}
HERMES_AUTONOMY_COMMIT=${HERMES_AUTONOMY_COMMIT:-}
require_var HERMES_AUTONOMY_REPO
require_var HERMES_AUTONOMY_VERSION
require_var HERMES_AUTONOMY_COMMIT
[[ $HERMES_AUTONOMY_REPO =~ ^https://github\.com/[A-Za-z0-9_.-]+/hermes-unsafe-autonomy\.git$ ]] || die 'autonomy repository must be the public GitHub repository over HTTPS'
[[ $HERMES_AUTONOMY_VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die 'autonomy version must be a release tag'
[[ $HERMES_AUTONOMY_COMMIT =~ ^[0-9a-fA-F]{40}$ ]] || die 'autonomy commit must be a full immutable SHA'
require_integer_range HERMES_CDP_PORT "$HERMES_CDP_PORT" 1 65535
home=$(hermes_home_for_user "$HERMES_USER")
target_root=/usr/local/share/hermes-unsafe-vm
target="$target_root/autonomy-$HERMES_AUTONOMY_VERSION"

normalize_checkout_permissions() {
  local checkout=$1
  find "$checkout" -type d -exec chmod 0755 {} +
  find "$checkout" -type f ! -perm /111 -exec chmod 0644 {} +
  find "$checkout" -type f -perm /111 -exec chmod 0755 {} +
}

if [[ -d "$target/.git" ]]; then
  resolved=$(git -C "$target" rev-parse HEAD)
  [[ $resolved == "$HERMES_AUTONOMY_COMMIT" ]] || die "existing autonomy checkout is $resolved, expected $HERMES_AUTONOMY_COMMIT"
else
  stage=$(mktemp -d /tmp/hermes-unsafe-autonomy.XXXXXX)
  trap 'rm -rf -- "${stage:-}"' EXIT
  git clone --quiet --depth 1 --branch "$HERMES_AUTONOMY_VERSION" "$HERMES_AUTONOMY_REPO" "$stage/source"
  resolved=$(git -C "$stage/source" rev-parse HEAD)
  [[ $resolved == "$HERMES_AUTONOMY_COMMIT" ]] || die "downloaded autonomy tag resolved to $resolved, expected $HERMES_AUTONOMY_COMMIT"
  install -d -m 0755 "$target_root"
  mv -- "$stage/source" "$target"
  rm -rf -- "$stage"
  trap - EXIT
fi
normalize_checkout_permissions "$target"
resolved=$(git -C "$target" rev-parse HEAD)
HERMES_HOME="$home/.hermes" HERMES_BIN="$home/.local/bin/hermes" HERMES_CDP_PORT="$HERMES_CDP_PORT" "$target/bootstrap.sh" --enable-unsafe-root
install -d -m 0755 /etc/hermes-unsafe-vm
printf 'version=%s\ncommit=%s\nrepo=%s\n' "$HERMES_AUTONOMY_VERSION" "$resolved" "$HERMES_AUTONOMY_REPO" > /etc/hermes-unsafe-vm/autonomy.env
chmod 0644 /etc/hermes-unsafe-vm/autonomy.env
printf '%s\n' 'AUTONOMY_INSTALL=PASS' "AUTONOMY_VERSION=$HERMES_AUTONOMY_VERSION" "AUTONOMY_COMMIT=$resolved"
