"""Shared Frontmatter Parser, Canonical Renderer, and Domain Utilities for LOKA."""

import datetime
import re
from pathlib import Path
from typing import Any, Dict, List, NamedTuple, Optional, Tuple, Union

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

CANONICAL_VERIFIED: Tuple[str, ...] = (
    "human",
    "attested",
    "automated",
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

_DOMAIN_TITLES: Dict[str, str] = {
    "profiles": "Profiles",
    "behaviors": "Behaviors",
    "standards": "Standards",
    "workflows": "Workflows",
    "tools": "Tools",
    "meta": "Meta",
}

CANONICAL_TYPES: Tuple[str, ...] = tuple(
    _DOMAIN_TO_TYPE[d] for d in CANONICAL_DOMAINS
)

CANONICAL_KEY_ORDER: Tuple[str, ...] = (
    "id",
    "name",
    "type",
    "status",
    "deprecated",
    "description",
    "created",
    "stale_after",
    "owner",
    "verified",
    "sources",
)

ALLOWED_KEYS = set(CANONICAL_KEY_ORDER)

FATAL_PARSE_CODES: Tuple[str, ...] = (
    "missing_opening_delimiter",
    "missing_closing_delimiter",
    "duplicate_key",
    "invalid_syntax",
    "invalid_key_name",
)


def domain_to_type(domain: str) -> str:
    """Return artifact type corresponding to a canonical domain directory."""
    return _DOMAIN_TO_TYPE.get(domain, "")


def type_to_domain(artifact_type: str) -> str:
    """Return canonical domain directory corresponding to an artifact type."""
    return _TYPE_TO_DOMAIN.get(artifact_type, "")


def domain_title(domain: str) -> str:
    """Map canonical domain directory name to human-readable section title."""
    return _DOMAIN_TITLES.get(domain, domain.capitalize())


class Problem(NamedTuple):
    """Structured issue reported during parsing or semantic validation."""

    code: str
    message: str
    line: Optional[int] = None

    def __str__(self) -> str:
        loc = f"line {self.line}: " if self.line is not None else ""
        return f"[{self.code}] {loc}{self.message}"


class Frontmatter(dict):
    """Dict subclass storing parsed frontmatter fields with closing line metadata."""

    def __init__(
        self,
        *args,
        closing_line: int = 0,
        raw_sources: Optional[str] = None,
        **kwargs,
    ):
        super().__init__(*args, **kwargs)
        self.closing_line = closing_line
        self.raw_sources = raw_sources

    def get_closing_line(self) -> int:
        return self.closing_line


def _parse_inline_list(val_str: str) -> List[str]:
    """Parse YAML inline list such as [a, b] or ["foo", "bar"]."""
    inner = val_str[1:-1].strip()
    if not inner:
        return []
    items: List[str] = []
    # Match comma-separated items, respecting quotes
    for token in re.split(r",\s*", inner):
        item = token.strip()
        if (item.startswith('"') and item.endswith('"') and len(item) >= 2) or (
            item.startswith("'") and item.endswith("'") and len(item) >= 2
        ):
            item = item[1:-1]
        if item:
            items.append(item)
    return items


def _parse_sources_items(val_str: str) -> Tuple[bool, List[str]]:
    """Parse and validate inline sources array per schema: ["URI", ...].

    Returns (is_valid, parsed_items).
    """
    s = val_str.strip()
    if not (s.startswith("[") and s.endswith("]")):
        return False, []
    inner = s[1:-1].strip()
    if not inner:
        return True, []
    tokens: List[str] = []
    current: List[str] = []
    in_dquote = False
    escaped = False
    for c in inner:
        if escaped:
            current.append(c)
            escaped = False
        elif c == "\\":
            current.append(c)
            escaped = True
        elif c == '"':
            current.append(c)
            in_dquote = not in_dquote
        elif c == "," and not in_dquote:
            tokens.append("".join(current).strip())
            current = []
        else:
            current.append(c)
    if current:
        tokens.append("".join(current).strip())

    item_re = re.compile(r'^"([^"\\]|\\.)*"$')
    all_valid = True
    parsed_items: List[str] = []
    for t in tokens:
        if not item_re.match(t):
            all_valid = False
            parsed_items.append(t)
        else:
            parsed_items.append(_unescape_double_quoted(t[1:-1]))
    return all_valid, parsed_items


def _unescape_double_quoted(s: str) -> str:
    """Unescape escape sequences in a YAML double-quoted scalar."""
    def _replace_esc(match: re.Match) -> str:
        ch = match.group(1)
        if ch == '"':
            return '"'
        elif ch == "\\":
            return "\\"
        elif ch == "n":
            return "\n"
        elif ch == "t":
            return "\t"
        elif ch == "r":
            return "\r"
        return match.group(0)

    return re.sub(r"\\(.)", _replace_esc, s)


def parse(text: str) -> Tuple[Frontmatter, str, List[Problem]]:
    """Parse YAML frontmatter and body from markdown text tolerantly.

    Never raises exceptions on malformed input. Returns parsed Frontmatter,
    body text (after closing delimiter), and list of Problems.
    """
    problems: List[Problem] = []
    fm = Frontmatter()

    if not text:
        problems.append(
            Problem("missing_opening_delimiter", "Opening delimiter --- missing on line 1", 1)
        )
        return fm, "", problems

    lines = text.splitlines(keepends=True)
    first_line = lines[0].rstrip("\r\n")

    if not re.match(r"^---[ \t]*$", first_line):
        problems.append(
            Problem("missing_opening_delimiter", "Opening delimiter --- missing on line 1", 1)
        )
        return fm, text, problems

    closed = False
    closing_line = 0
    fm_end_index = 0
    seen_keys = set()

    for idx, raw_line in enumerate(lines[1:], start=2):
        line = raw_line.rstrip("\r\n")

        # Closing delimiter
        if re.match(r"^---[ \t]*$", line):
            closed = True
            closing_line = idx
            fm_end_index = idx - 1  # 0-based index in lines
            break

        # Tolerant: ignore blank lines inside frontmatter
        if not line.strip():
            continue

        # Ignore comments
        if line.strip().startswith("#"):
            continue

        colon_idx = line.find(":")
        if colon_idx == -1:
            problems.append(
                Problem("invalid_syntax", f"Invalid frontmatter syntax: '{line.strip()}'", idx)
            )
            continue

        key = line[:colon_idx].strip()
        val_str = line[colon_idx + 1:].strip()

        if not re.match(r"^[a-zA-Z0-9_]+$", key):
            problems.append(
                Problem("invalid_key_name", f"Invalid frontmatter key name: '{key}'", idx)
            )
            continue

        norm_key = key.lower()
        if norm_key in seen_keys:
            problems.append(
                Problem("duplicate_key", f"Duplicate frontmatter key: '{key}'", idx)
            )
            continue
        seen_keys.add(norm_key)

        # Check deprecated
        if norm_key == "deprecated":
            fm[norm_key] = val_str
            if val_str not in ("true", "false"):
                problems.append(
                    Problem("invalid_deprecated", f"Invalid deprecated '{val_str}' (must be true or false)", idx)
                )
            continue

        # Check sources
        if norm_key == "sources":
            fm.raw_sources = val_str
            if not re.match(r"^\[.*\]$", val_str):
                fm[norm_key] = val_str
                problems.append(
                    Problem("invalid_sources", f"Invalid sources '{val_str}' (must match ^\\[.*\\]$)", idx)
                )
            else:
                fm[norm_key] = _parse_inline_list(val_str)
            continue

        # Unquote single or double quoted values
        if val_str.startswith('"') and val_str.endswith('"') and len(val_str) >= 2:
            val_str = _unescape_double_quoted(val_str[1:-1])
        elif val_str.startswith("'") and val_str.endswith("'") and len(val_str) >= 2:
            val_str = val_str[1:-1].replace("''", "'")

        fm[norm_key] = val_str

    if not closed:
        problems.append(
            Problem("missing_closing_delimiter", "Closing delimiter --- missing", len(lines))
        )
        return fm, "", problems

    fm.closing_line = closing_line
    body = "".join(lines[fm_end_index + 1:])
    return fm, body, problems


def _render_value(key: str, val: Any) -> str:
    """Render frontmatter value into canonical YAML scalar or inline list."""
    if key == "sources":
        if isinstance(val, (list, tuple)):
            if not val:
                return "[]"
            rendered_items = []
            for item in val:
                item_str = str(item)
                escaped = item_str.replace("\\", "\\\\").replace('"', '\\"')
                rendered_items.append(f'"{escaped}"')
            return f"[{', '.join(rendered_items)}]"
        return str(val)

    if key == "deprecated":
        if isinstance(val, bool):
            return "true" if val else "false"
        s = str(val).strip()
        if s.lower() in ("true", "false"):
            return s.lower()
        return str(val)

    if key in ("id", "type", "status", "created", "stale_after", "owner", "verified"):
        return str(val).strip()

    # General strings (name, description, extra keys)
    s = str(val)
    if not s:
        return '""'

    needs_quotes = False
    if s != s.strip():
        needs_quotes = True
    elif s.startswith(("-", "?", ":", "[", "{", "]", "}", ",", "#", "&", "*", "!", "|", ">", "'", '"', "%", "@", "`")):
        needs_quotes = True
    elif s.endswith(":"):
        needs_quotes = True
    elif ": " in s:
        needs_quotes = True
    elif " #" in s:
        needs_quotes = True
    elif '"' in s:
        needs_quotes = True
    elif any(c in s for c in ("{", "}", "[", "]")):
        needs_quotes = True
    elif "\n" in s or "\t" in s or "\r" in s:
        needs_quotes = True
    elif s.lower() in ("true", "false", "yes", "no", "null", "~"):
        needs_quotes = True

    if needs_quotes:
        escaped = (
            s.replace("\\", "\\\\")
            .replace('"', '\\"')
            .replace("\n", "\\n")
            .replace("\t", "\\t")
            .replace("\r", "\\r")
        )
        return f'"{escaped}"'
    return s


def render(fm: Frontmatter) -> str:
    """Render Frontmatter object into canonical frontmatter block."""
    lines = ["---"]
    seen = set()

    for key in CANONICAL_KEY_ORDER:
        if key in fm:
            val_str = _render_value(key, fm[key])
            lines.append(f"{key}: {val_str}")
            seen.add(key)

    for key in sorted(fm.keys()):
        if key not in seen:
            val_str = _render_value(key, fm[key])
            lines.append(f"{key}: {val_str}")

    lines.append("---")
    return "\n".join(lines) + "\n"


def check_semantics(
    fm: Frontmatter, file_path: Optional[Union[str, Path]] = None
) -> List[Problem]:
    """Verify semantic validity of frontmatter fields against LOKA standards."""
    problems: List[Problem] = []

    # 1. Required fields
    for req in ("id", "name", "type", "description"):
        val = fm.get(req)
        if val is None or (isinstance(val, str) and not val.strip()):
            problems.append(
                Problem("missing_required_field", f"Missing required frontmatter field: '{req}'")
            )

    # 2. Type enum
    art_type = fm.get("type")
    if art_type and art_type not in CANONICAL_TYPES:
        problems.append(
            Problem(
                "invalid_type",
                f"Invalid type '{art_type}' (must be one of: {', '.join(CANONICAL_TYPES)})",
            )
        )

    # 3. Status enum
    status = fm.get("status")
    if status and status not in CANONICAL_STATUSES:
        problems.append(
            Problem(
                "invalid_status",
                f"Invalid status '{status}' (must be one of: {', '.join(CANONICAL_STATUSES)})",
            )
        )

    # Date fields (created, stale_after)
    for date_field in ("created", "stale_after"):
        d_val = fm.get(date_field)
        if d_val:
            d_str = str(d_val).strip()
            is_valid = False
            if re.match(r"^\d{4}-\d{2}-\d{2}$", d_str):
                try:
                    datetime.date.fromisoformat(d_str)
                    is_valid = True
                except ValueError:
                    is_valid = False
            if not is_valid:
                problems.append(
                    Problem(
                        "invalid_date",
                        f"Invalid {date_field} date '{d_str}' (must be valid YYYY-MM-DD calendar date)",
                    )
                )

    # Verified enum
    verified = fm.get("verified")
    if verified and verified not in CANONICAL_VERIFIED:
        problems.append(
            Problem(
                "invalid_verified",
                f"Invalid verified '{verified}' (must be one of: {', '.join(CANONICAL_VERIFIED)})",
            )
        )

    # Deprecated boolean
    if "deprecated" in fm:
        dep = fm.get("deprecated")
        if isinstance(dep, bool):
            pass
        elif isinstance(dep, str) and dep.strip() in ("true", "false"):
            pass
        else:
            problems.append(
                Problem(
                    "invalid_deprecated",
                    f"Invalid deprecated '{dep}' (must be true or false)",
                )
            )

    # Sources array
    if "sources" in fm:
        sources = fm.get("sources")
        if isinstance(sources, str):
            problems.append(
                Problem(
                    "invalid_sources",
                    f"Invalid sources '{sources}' (must be an inline array with double-quoted items: [\"...\"])",
                )
            )
        elif isinstance(sources, (list, tuple)):
            raw_s = getattr(fm, "raw_sources", None)
            if raw_s is not None:
                valid, _ = _parse_sources_items(raw_s)
                if not valid:
                    problems.append(
                        Problem(
                            "invalid_sources",
                            f"Invalid sources '{raw_s}' (every item must be double-quoted per schema: [\"...\"])",
                        )
                    )
            else:
                for item in sources:
                    if not isinstance(item, str):
                        problems.append(
                            Problem(
                                "invalid_sources",
                                f"Invalid sources item '{item}' (must be a string)",
                            )
                        )
                        break
        else:
            problems.append(
                Problem(
                    "invalid_sources",
                    f"Invalid sources '{sources}' (must be an inline array [...])",
                )
            )

    # 4. ID kebab-case
    fid = fm.get("id")
    if fid:
        if not re.match(r"^[a-z0-9-]+$", str(fid)):
            problems.append(
                Problem("invalid_id", f"ID '{fid}' must be lowercase kebab-case (^[a-z0-9-]+$)")
            )

    # 5. ID matches filename stem
    if file_path and fid:
        stem = Path(file_path).stem
        if fid != stem:
            problems.append(
                Problem("id_stem_mismatch", f"ID '{fid}' does not match filename stem '{stem}'")
            )

    # 6. Type matches parent folder
    if file_path and art_type:
        parent_name = Path(file_path).parent.name
        expected_type = domain_to_type(parent_name)
        if expected_type and art_type != expected_type:
            problems.append(
                Problem(
                    "type_domain_mismatch",
                    f"Type '{art_type}' does not match parent folder '{parent_name}' (expected '{expected_type}')",
                )
            )

    return problems
