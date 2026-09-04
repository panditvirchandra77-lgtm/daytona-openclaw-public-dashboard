#!/usr/bin/env python3
"""
check-origins.py
Audit which origins are currently allowed in OpenClaw config.

Usage:
    ./check-origins.py
    ./check-origins.py --config /path/to/openclaw.json
    ./check-origins.py --check https://18789-XXXX.daytonaproxy01.net

Exit codes:
    0 = all checked origins allowed
    1 = config not found
    2 = JSON invalid
    3 = some checked origins not allowed
"""
import argparse
import json
import os
import sys
from pathlib import Path


def load_config(path: Path) -> dict:
    if not path.exists():
        print(f"✗ Config not found: {path}", file=sys.stderr)
        sys.exit(1)
    try:
        with path.open() as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        print(f"✗ Invalid JSON: {e}", file=sys.stderr)
        sys.exit(2)


def get_origins(cfg: dict) -> list:
    return (
        cfg.get("gateway", {})
        .get("controlUi", {})
        .get("allowedOrigins", [])
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "--config",
        default=os.environ.get("OPENCLAW_CONFIG", str(Path.home() / ".openclaw" / "openclaw.json")),
        help="Path to openclaw.json (default: ~/.openclaw/openclaw.json)",
    )
    parser.add_argument(
        "--check",
        action="append",
        default=[],
        metavar="ORIGIN",
        help="Origin to check (can be repeated). Exits non-zero if any not allowed.",
    )
    args = parser.parse_args()

    cfg = load_config(Path(args.config))
    origins = get_origins(cfg)

    print(f"Config: {args.config}")
    print(f"Total allowed origins: {len(origins)}")
    print()
    print("Current allowed origins:")
    for o in origins:
        print(f"  • {o}")
    print()

    if not args.check:
        return

    # Check requested origins
    missing = []
    for target in args.check:
        if target in origins:
            print(f"✓ {target}  (allowed)")
        else:
            print(f"✗ {target}  (NOT allowed)")
            # Suggest adding all 4 schemes
            host = target.replace("wss://", "").replace("ws://", "").replace("https://", "").replace("http://", "")
            print(f"  Hint: add all 4 schemes for host {host}:")
            for scheme in ("wss://", "ws://", "https://", "http://"):
                print(f"    {scheme}{host}")
            missing.append(target)

    if missing:
        print(f"\n✗ {len(missing)} origin(s) missing from allowedOrigins", file=sys.stderr)
        sys.exit(3)
    else:
        print(f"\n✓ All {len(args.check)} checked origin(s) allowed")


if __name__ == "__main__":
    main()
