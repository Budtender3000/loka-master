#!/usr/bin/env python3
"""LOKA Knowledge Artifact Tooling Suite — Phase 1 CLI.

Subcommands:
  format    Auto-format frontmatter and body mechanics.
  index     Generate deterministic index.md catalogue.
"""

import argparse
import sys
from pathlib import Path
from typing import Dict, List

# Ensure scripts dir is in sys.path
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from lib.formatter import format_file
from lib.frontmatter import CANONICAL_DOMAINS
from lib.indexer import generate_index, resolve_brain_dir


def cmd_format(args: argparse.Namespace) -> int:
    """Handle 'format' subcommand."""
    files_to_format: List[Path] = []

    if args.all:
        brain_dir = resolve_brain_dir()
        if not brain_dir or not brain_dir.is_dir():
            sys.stderr.write("ERROR: Could not resolve loka-brain directory for --all.\n")
            return 1

        for domain in CANONICAL_DOMAINS:
            domain_dir = brain_dir / domain
            if not domain_dir.is_dir():
                continue
            for p in domain_dir.iterdir():
                if (
                    p.is_file()
                    and p.suffix == ".md"
                    and p.name not in ("index.md", "schema.md")
                    and not p.name.startswith(".")
                ):
                    files_to_format.append(p)
        files_to_format.sort()
    elif args.files:
        for f in args.files:
            p = Path(f)
            if not p.is_file():
                sys.stderr.write(f"ERROR: File not found: {f}\n")
                return 1
            files_to_format.append(p)
    else:
        sys.stderr.write("ERROR: Specify one or more files to format, or use --all.\n")
        return 1

    if not files_to_format:
        print("No files found to format.")
        return 0

    total_checked = len(files_to_format)
    files_modified = 0
    category_counts: Dict[str, int] = {}

    for file_path in files_to_format:
        changed, problems, categories = format_file(file_path, check_only=args.check)
        if problems:
            for prob in problems:
                sys.stderr.write(f"WARNING: Skipping {file_path}: {prob.message}\n")
            continue

        if changed:
            files_modified += 1
            for cat in categories:
                category_counts[cat] = category_counts.get(cat, 0) + 1
            action = "would be modified" if args.check else "formatted"
            cat_summary = ", ".join(categories) if categories else "cleaned"
            print(f"[{action.upper()}] {file_path} ({cat_summary})")

    print("\nFormat Summary:")
    print(f"  Files checked:  {total_checked}")
    if args.check:
        print(f"  Files needing changes: {files_modified}")
    else:
        print(f"  Files modified: {files_modified}")

    if category_counts:
        print("  Fix categories:")
        for cat, count in sorted(category_counts.items()):
            print(f"    - {cat}: {count}")

    if args.check and files_modified > 0:
        return 1
    return 0


def cmd_index(args: argparse.Namespace) -> int:
    """Handle 'index' subcommand."""
    brain_dir = resolve_brain_dir(args.vault)
    if not brain_dir or not brain_dir.is_dir():
        sys.stderr.write("ERROR: Could not resolve loka-brain directory.\n")
        return 1

    exit_code, _ = generate_index(brain_dir, strict=args.strict)
    return exit_code


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="loka",
        description="LOKA Knowledge Artifact Tooling Suite (Phase 1)",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Subcommand: format
    parser_format = subparsers.add_parser(
        "format",
        help="Auto-format frontmatter and body mechanics",
    )
    parser_format.add_argument(
        "files",
        nargs="*",
        default=[],
        help="Target markdown files to format",
    )
    parser_format.add_argument(
        "--all",
        action="store_true",
        help="Format all knowledge artifacts across canonical domains in vault",
    )
    parser_format.add_argument(
        "--check",
        action="store_true",
        help="Check formatting without modifying files (exit 1 if changes needed)",
    )

    # Subcommand: index
    parser_index = subparsers.add_parser(
        "index",
        help="Generate deterministic index.md catalogue",
    )
    parser_index.add_argument(
        "vault",
        nargs="?",
        default=None,
        help="Path to loka-brain vault (optional)",
    )
    parser_index.add_argument(
        "--strict",
        action="store_true",
        help="Exit with non-zero code if any files fail validation and are skipped",
    )

    args = parser.parse_args()

    if args.command == "format":
        return cmd_format(args)
    elif args.command == "index":
        return cmd_index(args)

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
