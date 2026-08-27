#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
output=$(mktemp)
trap 'rm -f -- "${output:-}"' EXIT

python3 "$repo_root/scripts/write-manifest.py" \
  --output "$output" \
  --builder-version 0.1.1 \
  --autonomy-version v0.1.2 \
  --autonomy-commit d85bed5126376af913c3ca3e607396bee5493461 \
  --hermes-version 'Hermes Agent v0.20.5' \
  --chromium-version 'Chromium 151.0.0' \
  --node-version v26.7.0 \
  --chrome-devtools-mcp-version 1.8.0 \
  --cua-version 0.22.1 \
  --codex-version 0.150.1 \
  --cdp-port 9222 \
  --unsafe-root-enabled

python3 - "$output" <<'PY'
import json
import os
import sys
from pathlib import Path

output = Path(sys.argv[1])
manifest = json.loads(output.read_text(encoding="utf-8"))
release = {}
for line in Path("/etc/os-release").read_text(encoding="utf-8").splitlines():
    if "=" in line and not line.startswith("#"):
        key, value = line.split("=", 1)
        release[key] = value.strip().strip('"')
assert manifest["debian_version"] == release["VERSION_ID"]
assert manifest["builder_version"] == "0.1.1"
assert manifest["cua_version"] == "0.22.1"
assert manifest["cdp"] == "127.0.0.1:9222"
assert manifest["unsafe_root_enabled"] is True
assert os.stat(output).st_mode & 0o777 == 0o644
assert not list(output.parent.glob(f".{output.name}.*.tmp"))
PY
printf '%s\n' 'MANIFEST_TEST=PASS'
