"""LOKA Knowledge Artifact Auto-Formatter (Mechanical Auto-Fixer)."""

import os
import re
import shutil
from pathlib import Path
from typing import List, Optional, Set, Tuple, Union

from .frontmatter import Frontmatter, Problem, parse, render

FATAL_PARSE_CODES: Set[str] = {
    "missing_opening_delimiter",
    "missing_closing_delimiter",
    "duplicate_key",
    "invalid_syntax",
    "invalid_key_name",
}


def _process_body_lines(body: str) -> List[str]:
    """Strip trailing whitespace from body lines while preserving content in code fences."""
    body_lines = body.splitlines(keepends=False)
    processed: List[str] = []
    in_code = False
    fence_pattern = re.compile(r"^[ \t]*(```|~~~)")

    for line in body_lines:
        match = fence_pattern.match(line)
        if match:
            in_code = not in_code
            processed.append(line.rstrip(" \t"))
        elif in_code:
            # Inside code fence: preserve verbatim
            processed.append(line)
        else:
            # Outside code fence: strip trailing whitespace
            processed.append(line.rstrip(" \t"))
    return processed


def format_text(text: str) -> str:
    """Format markdown text mechanically.

    Fixes:
    - Frontmatter key order (canonical)
    - Redundant quotes in frontmatter
    - Blank lines in frontmatter
    - Trailing whitespace (whole document, preserving code fences)
    - Single trailing newline

    Returns unchanged text if frontmatter is unparseable.
    """
    if not text:
        return ""

    fm, body, problems = parse(text)
    if any(p.code in FATAL_PARSE_CODES for p in problems):
        return text

    # Canonical frontmatter block
    fm_block = render(fm)

    # Process body lines
    processed_lines = _process_body_lines(body)

    if not processed_lines:
        return fm_block

    joined_body = "\n".join(processed_lines).rstrip("\n")
    if not joined_body:
        return fm_block

    return fm_block + joined_body + "\n"


def detect_fix_categories(old_text: str, new_text: str) -> List[str]:
    """Detect which mechanical categories were changed between old and new text."""
    if old_text == new_text:
        return []

    categories: List[str] = []

    old_fm, _, _ = parse(old_text)
    new_fm, _, _ = parse(new_text)

    old_lines = old_text.splitlines(keepends=True)
    old_fm_lines: List[str] = []
    if old_lines and re.match(r"^---[ \t]*$", old_lines[0].rstrip("\r\n")):
        for line in old_lines[1:]:
            if re.match(r"^---[ \t]*$", line.rstrip("\r\n")):
                break
            old_fm_lines.append(line.rstrip("\r\n"))

    # Blank lines in frontmatter
    if any(not line.strip() for line in old_fm_lines):
        categories.append("blank_lines_frontmatter")

    # Key order
    old_keys = [
        line.split(":", 1)[0].strip().lower()
        for line in old_fm_lines
        if ":" in line and not line.strip().startswith("#")
    ]
    seen = set()
    unique_old_keys = [k for k in old_keys if not (k in seen or seen.add(k))]
    new_keys = list(new_fm.keys())
    if unique_old_keys != new_keys:
        categories.append("key_order")

    # Redundant quotes
    for line in old_fm_lines:
        if ":" in line:
            val = line.split(":", 1)[1].strip()
            if (val.startswith('"') and val.endswith('"') and len(val) >= 2) or (
                val.startswith("'") and val.endswith("'") and len(val) >= 2
            ):
                inner = val[1:-1]
                if not any(c in inner for c in (": ", "{", "}", "[", "]")):
                    if "redundant_quotes" not in categories:
                        categories.append("redundant_quotes")

    # Required quotes (unquoted special syntax characters like ': ' or brackets)
    for line in old_fm_lines:
        if ":" in line:
            val = line.split(":", 1)[1].strip()
            if not ((val.startswith('"') and val.endswith('"')) or (val.startswith("'") and val.endswith("'"))):
                if any(c in val for c in (": ", "{", "}", "[", "]")):
                    if "quotes_required" not in categories:
                        categories.append("quotes_required")

    # Trailing whitespace (whole document)
    for line in old_lines:
        clean = line.rstrip("\r\n")
        if clean and clean[-1] in (" ", "\t"):
            categories.append("trailing_whitespace")
            break

    # Trailing newline
    if not old_text.endswith("\n") or old_text.endswith("\n\n"):
        categories.append("trailing_newline")

    if not categories:
        categories.append("formatting_cleanup")

    return categories


def format_file(
    file_path: Path, check_only: bool = False
) -> Tuple[bool, List[Problem], List[str]]:
    """Format a file on disk atomically.

    Returns:
        (changed, problems, categories)
    """
    path = file_path.resolve()
    try:
        old_text = path.read_text(encoding="utf-8")
    except Exception as e:
        return False, [Problem("read_error", f"Cannot read {path}: {e}")], []

    fm, body, parse_problems = parse(old_text)
    fatal = [p for p in parse_problems if p.code in FATAL_PARSE_CODES]
    if fatal:
        return False, fatal, []

    new_text = format_text(old_text)
    if new_text == old_text:
        return False, [], []

    categories = detect_fix_categories(old_text, new_text)

    if check_only:
        return True, [], categories

    temp_file = path.with_name(f".{path.name}.tmp.{os.getpid()}")
    try:
        temp_file.write_text(new_text, encoding="utf-8")
        try:
            shutil.copymode(path, temp_file)
        except Exception:
            pass
        os.replace(temp_file, path)
    finally:
        if temp_file.exists():
            temp_file.unlink(missing_ok=True)

    return True, [], categories
