#!/usr/bin/env python3
"""Run a command with a wall-clock timeout."""

from __future__ import annotations

import argparse
import subprocess


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run a command with a timeout.")
    parser.add_argument("timeout_sec", type=float)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.command:
        raise SystemExit("missing command")

    try:
        completed = subprocess.run(args.command, check=False, timeout=args.timeout_sec)
    except subprocess.TimeoutExpired:
        return 124
    return completed.returncode


if __name__ == "__main__":
    raise SystemExit(main())
