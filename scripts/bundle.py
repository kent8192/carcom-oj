#!/usr/bin/env python3
"""Build a single-file Rust submission by appending local cp-lib sources."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


PUB_MOD_RE = re.compile(r"^(\s*)pub\s+mod\s+([A-Za-z_][A-Za-z0-9_]*)\s*;\s*(?://.*)?$")


class BundleError(Exception):
    pass


def module_source_path(base_dir: Path, name: str) -> Path:
    for candidate in (base_dir / f"{name}.rs", base_dir / name / "mod.rs"):
        if candidate.is_file():
            return candidate
    raise BundleError(
        f"module source not found for pub mod {name}; looked for "
        f"{base_dir / f'{name}.rs'} and {base_dir / name / 'mod.rs'}"
    )


def expand_pub_mods(source_path: Path, active: tuple[Path, ...] = ()) -> str:
    source_path = source_path.resolve()
    if source_path in active:
        cycle = " -> ".join(str(path) for path in (*active, source_path))
        raise BundleError(f"cyclic module expansion: {cycle}")

    try:
        source = source_path.read_text(encoding="utf-8")
    except OSError as exc:
        raise BundleError(f"failed to read {source_path}: {exc}") from exc

    expanded: list[str] = []
    base_dir = source_path.parent
    next_active = (*active, source_path)

    for line in source.splitlines():
        match = PUB_MOD_RE.match(line)
        if match is None:
            expanded.append(line)
            continue

        indent, name = match.groups()
        child_path = module_source_path(base_dir, name)
        child_source = expand_pub_mods(child_path, next_active)
        expanded.append(f"{indent}pub mod {name} {{")
        if child_source:
            expanded.extend(f"{indent}    {child_line}" for child_line in child_source.splitlines())
        expanded.append(f"{indent}}}")

    return "\n".join(expanded)


def bundle(root: Path, contest: str, alias: str) -> str:
    bin_source_path = root / "contests" / contest / "src" / "bin" / f"{alias}.rs"
    cp_lib_path = root / "cp-lib" / "src" / "lib.rs"

    if not bin_source_path.is_file():
        raise BundleError(f"bin source not found: {bin_source_path}")
    if not cp_lib_path.is_file():
        raise BundleError(f"cp-lib root not found: {cp_lib_path}")

    try:
        bin_source = bin_source_path.read_text(encoding="utf-8").rstrip()
    except OSError as exc:
        raise BundleError(f"failed to read {bin_source_path}: {exc}") from exc

    cp_lib_source = expand_pub_mods(cp_lib_path)
    return f"{bin_source}\n\n#[allow(unused)]\nmod cp_lib {{\n{indent(cp_lib_source)}\n}}\n"


def indent(source: str) -> str:
    if not source:
        return ""
    return "\n".join(f"    {line}" if line else "" for line in source.splitlines())


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Append cp-lib to a contest bin source as mod cp_lib."
    )
    parser.add_argument("contest", help="contest directory name under contests/")
    parser.add_argument("alias", help="problem alias, matching src/bin/<alias>.rs")
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="repository root (defaults to this script's parent repository)",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        sys.stdout.write(bundle(args.root.resolve(), args.contest, args.alias))
    except BundleError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
