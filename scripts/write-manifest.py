#!/usr/bin/env python3
"""Write the secret-free VM version manifest atomically."""

from __future__ import annotations

import argparse
import json
import os
import tempfile
from datetime import datetime, timezone
from pathlib import Path


def os_release() -> dict[str, str]:
    values: dict[str, str] = {}
    for line in Path("/etc/os-release").read_text(encoding="utf-8").splitlines():
        if "=" not in line or line.startswith("#"):
            continue
        key, value = line.split("=", 1)
        values[key] = value.strip().strip('"')
    return values


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--builder-version", required=True)
    parser.add_argument("--autonomy-version", required=True)
    parser.add_argument("--autonomy-commit", required=True)
    parser.add_argument("--hermes-version", required=True)
    parser.add_argument("--chromium-version", required=True)
    parser.add_argument("--node-version", required=True)
    parser.add_argument("--chrome-devtools-mcp-version", required=True)
    parser.add_argument("--cua-version", required=True)
    parser.add_argument("--codex-version", required=True)
    parser.add_argument("--cdp-port", type=int, required=True)
    parser.add_argument("--unsafe-root-enabled", action="store_true", required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if not 1 <= args.cdp_port <= 65535:
        raise SystemExit("--cdp-port must be between 1 and 65535")
    release = os_release()
    if release.get("ID") != "debian":
        raise SystemExit("manifest writer requires Debian")
    if not release.get("VERSION_ID"):
        raise SystemExit("Debian VERSION_ID is unavailable")
    if not args.output.parent.is_dir():
        raise SystemExit(f"manifest directory does not exist: {args.output.parent}")

    payload = {
        "schema": 1,
        "builder_version": args.builder_version,
        "debian_version": release["VERSION_ID"],
        "hermes_version": args.hermes_version,
        "autonomy_version": args.autonomy_version,
        "autonomy_commit": args.autonomy_commit,
        "chrome_devtools_mcp_version": args.chrome_devtools_mcp_version,
        "chromium_version": args.chromium_version,
        "cua_version": args.cua_version,
        "codex_version": args.codex_version,
        "node_version": args.node_version,
        "cdp": f"127.0.0.1:{args.cdp_port}",
        "provisioned_at": datetime.now(timezone.utc).isoformat(),
        "unsafe_root_enabled": True,
    }

    descriptor, temporary = tempfile.mkstemp(
        dir=args.output.parent,
        prefix=f".{args.output.name}.",
        suffix=".tmp",
        text=True,
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary, 0o644)
        os.replace(temporary, args.output)
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass


if __name__ == "__main__":
    main()
