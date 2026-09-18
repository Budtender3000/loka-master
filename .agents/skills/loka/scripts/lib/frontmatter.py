#!/usr/bin/env python3
"""Shared Frontmatter Parser and Domain Utilities for LOKA Knowledge Artifacts."""

import os
import re
from pathlib import Path
from typing import Dict, Optional, Tuple, Union

CANONICAL_DOMAINS: Tuple[str, ...] = (
    "profiles",
    "behaviors",
    "standards",
    "workflows",
    "tools",
    "meta",
)

CANONICAL_STATUSES: Tuple[str, ...] = (
    "draft",
    "test",
    "active",
)

_DOMAIN_TO_TYPE: Dict[str, str] = {
    "profiles": "profile",
    "behaviors": "behavior",
    "standards": "standard",
    "workflows": "workflow",
    "tools": "tool",
    "meta": "meta",
}

_TYPE_TO_DOMAIN: Dict[str, str] = {
    "profile": "profiles",
    "behavior": "behaviors",
    "standard": "standards",
    "workflow": "workflows",
    "tool": "tools",
    "meta": "meta",
}


def domain_to_type(domain: str) -> str:
    """Return the artifact type corresponding to a canonical domain directory."""
    return _DOMAIN_TO_TYPE.get(domain, "")


def type_to_domain(artifact_type: str) -> str:
    """Return the canonical domain directory corresponding to an artifact type."""
    return _TYPE_TO_DOMAIN.get(artifact_type, "")


CANONICAL_TYPES: Tuple[str, ...] = tuple(
    domain_to_type(d) for d in CANONICAL_DOMAINS
)


class FrontmatterError(Exception):
    """Raised when frontmatter parsing fails due to syntax, delimiter, or schema error."""
    pass


class Frontmatter(dict):
    """Dict subclass storing parsed frontmatter fields with closing line metadata."""

    def __init__(self, *args, closing_line: int = 0, **kwargs):
        super().__init__(*args, **kwargs)
        self.closing_line = closing_line

    def get_closing_line(self) -> int:
        return self.closing_line


def parse_frontmatter(target_file: Union[str, Path]) -> Frontmatter:
    """Parse YAML frontmatter from a markdown file according to LOKA specifications.

    Exact parsing semantics:
    - Target file must exist and be a regular file.
    - Line 1 must match opening delimiter `---`.
    - Delimited block ends at matching closing delimiter `---`.
    - Keys are normalized to uppercase.
    - Insertion order is preserved.
    - Surrounding single or double quotes around values are stripped.
    - Duplicate keys (case-insensitive) raise FrontmatterError.
    - Invalid syntax lines raise FrontmatterError.
    - Missing closing delimiter raises FrontmatterError.

    Returns:
        Frontmatter (dict subclass) containing uppercase key-value pairs and closing_line.
    """
    path = Path(target_file)
    if not path.is_file():
        raise FrontmatterError(f"File does not exist: {path}")

    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
    except Exception as e:
        raise FrontmatterError(f"Cannot read file {path}: {e}")

    if not lines:
        raise FrontmatterError("Opening delimiter --- missing on line 1")

    first_line = lines[0].rstrip("\r\n")
    if not re.match(r"^---[ \t]*$", first_line):
        raise FrontmatterError("Opening delimiter --- missing on line 1")

    in_fm = True
    closed = False
    closing_line = 0
    seen = set()
    result = Frontmatter()

    for idx, raw_line in enumerate(lines[1:], start=2):
        line = raw_line.rstrip("\r\n")
        if re.match(r"^---[ \t]*$", line):
            closed = True
            closing_line = idx
            break

        if not re.match(r"^[a-zA-Z0-9_]+:[ \t]*", line):
            raise FrontmatterError(f"Invalid frontmatter syntax on line {idx}: {line}")

        colon_idx = line.find(":")
        key = line[:colon_idx].strip()
        val = line[colon_idx + 1:].strip()

        # Strip surrounding single or double quotes
        if (val.startswith('"') and val.endswith('"') and len(val) >= 2) or (
            val.startswith("'") and val.endswith("'") and len(val) >= 2
        ):
            val = val[1:-1]

        toupper_key = key.upper()
        if toupper_key in seen:
            raise FrontmatterError(f"Duplicate frontmatter key: {key}")
        seen.add(toupper_key)
        result[toupper_key] = val

    if not closed:
        raise FrontmatterError("Closing delimiter --- missing")

    result.closing_line = closing_line
    return result
