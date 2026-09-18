#!/usr/bin/env python3
"""audit.py — LOKA Knowledge Artifact Audit & Lifecycle Engine (v0.2.3)."""

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# Add lib directory to sys.path
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR / "lib"))

from frontmatter import (
    CANONICAL_DOMAINS,
    Frontmatter,
    FrontmatterError,
    domain_to_type,
    parse_frontmatter,
)

# ------------------------------------------------------------------------------
# Colors & Output Configuration
# ------------------------------------------------------------------------------
USE_COLOR = sys.stdout.isatty() and not os.environ.get("NO_COLOR")
if USE_COLOR:
    GREEN = "\033[0;32m"
    RED = "\033[0;31m"
    YELLOW = "\033[0;33m"
    CYAN = "\033[0;36m"
    BOLD = "\033[1m"
    NC = "\033[0m"
else:
    GREEN = RED = YELLOW = CYAN = BOLD = NC = ""

TOTAL_CHECKS = 0
PASSED_CHECKS = 0
FAILED_CHECKS = 0


def pass_check(msg: str) -> None:
    global TOTAL_CHECKS, PASSED_CHECKS
    TOTAL_CHECKS += 1
    PASSED_CHECKS += 1
    sys.stdout.write(f"    [{GREEN}PASS{NC}] {msg}\n")


def fail_check(msg: str, file: Optional[str] = None) -> None:
    global TOTAL_CHECKS, FAILED_CHECKS
    TOTAL_CHECKS += 1
    FAILED_CHECKS += 1
    if file:
        sys.stderr.write(f"    [{RED}FAIL{NC}] {msg} ({file})\n")
    else:
        sys.stderr.write(f"    [{RED}FAIL{NC}] {msg}\n")


# ------------------------------------------------------------------------------
# Vault Resolution
# ------------------------------------------------------------------------------
def resolve_brain_dir(context_path: Optional[Path] = None) -> Optional[Path]:
    """Resolve the active loka-brain directory."""
    env_root = os.environ.get("LOKA_BRAIN_ROOT")
    if env_root:
        p = Path(env_root).resolve()
        if p.is_dir():
            return p

    candidates = [
        SCRIPT_DIR / "../../../loka-brain",
        SCRIPT_DIR / "../../loka-brain",
        Path("./.agents/loka-brain"),
        Path("./loka-brain"),
    ]
    for cand in candidates:
        if cand.is_dir():
            return cand.resolve()

    if context_path:
        cand_parent = context_path.resolve().parent
        cand_grandparent = cand_parent.parent
        if cand_parent.name in CANONICAL_DOMAINS and cand_grandparent.is_dir():
            return cand_grandparent

    return None


# ------------------------------------------------------------------------------
# Core Audit Function
# ------------------------------------------------------------------------------
KEY_RANKS: Dict[str, int] = {
    "ID": 1,
    "NAME": 2,
    "TYPE": 3,
    "STATUS": 4,
    "DEPRECATED": 5,
    "DESCRIPTION": 6,
    "CREATED": 7,
    "STALE_AFTER": 8,
    "OWNER": 9,
    "VERIFIED": 10,
    "SOURCES": 11,
}

DECLARED_KEYS = set(KEY_RANKS.keys())


def audit_file(file_path: Union[str, Path], brain_dir: Optional[Path] = None) -> bool:
    """Audit a single Knowledge Artifact against the 10 schema & quality check categories."""
    file_str = str(file_path)
    file_p = Path(file_path)
    file_fails = 0

    sys.stdout.write(f"\n  {BOLD}Auditing:{NC} {CYAN}{file_str}{NC}\n")

    if not file_p.is_file():
        fail_check("File does not exist or is not a regular file", file_str)
        return False

    if not brain_dir:
        brain_dir = resolve_brain_dir(file_p)

    filename = file_p.name
    file_stem = file_p.stem

    try:
        with open(file_p, "r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
    except Exception as e:
        fail_check(f"Cannot read file: {e}", file_str)
        return False

    content = "".join(lines)

    # 1. Delimiter & Frontmatter basic syntax
    if not lines or not re.match(r"^---[ \t]*$", lines[0].rstrip("\r\n")):
        fail_check("Line 1 is not opening delimiter ---", file_str)
        file_fails += 1
    else:
        pass_check("Opening delimiter --- present on line 1")

    fm: Optional[Frontmatter] = None
    err: Optional[str] = None
    try:
        fm = parse_frontmatter(file_p)
    except FrontmatterError as e:
        err = str(e)

    if err:
        fail_check(f"Frontmatter parsing error: {err}", file_str)
        file_fails += 1
    else:
        pass_check("YAML frontmatter syntax valid")

    # Schema Purity Check
    unknown_keys = []
    if fm is not None:
        unknown_keys = [k for k in fm.keys() if k not in DECLARED_KEYS]

    if unknown_keys:
        fail_check(
            f"Schema purity violation: undeclared frontmatter key(s): {' '.join(unknown_keys)}",
            file_str,
        )
        file_fails += 1
    else:
        pass_check("Schema purity verified (zero undeclared keys)")

    # Closing Delimiter Line Arithmetic
    if fm is not None and fm.closing_line > 0:
        field_count = len(fm)
        expected_closing_line = field_count + 2
        if fm.closing_line != expected_closing_line:
            fail_check(
                f"Closing delimiter line mismatch (line {fm.closing_line}, expected {expected_closing_line} for {field_count} fields)",
                file_str,
            )
            file_fails += 1
        else:
            pass_check(
                f"Closing delimiter arithmetic valid (line {fm.closing_line} matches {field_count} fields)"
            )

    # Canonical Key Order Check
    order_valid = True
    if fm is not None:
        current_rank = 0
        for k in fm.keys():
            rank = KEY_RANKS.get(k, 99)
            if rank <= current_rank and rank != 99:
                order_valid = False
            current_rank = rank

    if not order_valid:
        fail_check("Frontmatter keys violate canonical relative order", file_str)
        file_fails += 1
    else:
        pass_check("Canonical key order verified")

    # 2. Mandatory Fields
    id_val = fm.get("ID", "") if fm else ""
    name_val = fm.get("NAME", "") if fm else ""
    type_val = fm.get("TYPE", "") if fm else ""
    desc_val = fm.get("DESCRIPTION", "") if fm else ""

    if not id_val or not name_val or not type_val or not desc_val:
        fail_check(
            "Missing mandatory frontmatter fields (id, name, type, description)",
            file_str,
        )
        file_fails += 1
    else:
        pass_check("All mandatory frontmatter fields present")

    # 3. ID Validation
    if not re.match(r"^[a-z0-9-]+$", id_val):
        fail_check(f"ID '{id_val}' is not lowercase kebab-case", file_str)
        file_fails += 1
    elif id_val != file_stem:
        fail_check(
            f"ID '{id_val}' does not match filename stem '{file_stem}'",
            file_str,
        )
        file_fails += 1
    else:
        pass_check(f"ID matches filename stem ('{id_val}')")

    # 4. Type & Domain Alignment
    parent_dir = file_p.resolve().parent.name
    expected_type = domain_to_type(parent_dir)

    if not expected_type:
        fail_check(
            f"File is not directly inside a canonical domain folder (parent: '{parent_dir}')",
            file_str,
        )
        file_fails += 1
    elif type_val != expected_type:
        fail_check(
            f"Type '{type_val}' does not match domain folder '{parent_dir}' (expected '{expected_type}')",
            file_str,
        )
        file_fails += 1
    else:
        pass_check(
            f"Domain alignment valid (folder '{parent_dir}' matches type '{type_val}')"
        )

    # 5. Optional Enum & Trust Signal Validations
    status_val = fm.get("STATUS", "") if fm else ""
    if status_val:
        if status_val not in ("draft", "test", "active"):
            fail_check(
                f"Invalid status '{status_val}' (must be draft, test, or active)",
                file_str,
            )
            file_fails += 1
        else:
            pass_check(f"Status '{status_val}' is valid")

    dep_val = fm.get("DEPRECATED", "") if fm else ""
    if dep_val:
        if dep_val not in ("true", "false"):
            fail_check(
                f"Invalid deprecated value '{dep_val}' (must be true or false)",
                file_str,
            )
            file_fails += 1
        else:
            pass_check(f"Deprecated flag is valid ({dep_val})")

    created_val = fm.get("CREATED", "") if fm else ""
    if created_val:
        if not re.match(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$", created_val):
            fail_check(
                f"Invalid created date '{created_val}' (must be YYYY-MM-DD)",
                file_str,
            )
            file_fails += 1
        else:
            pass_check(f"Created date is valid ({created_val})")

    stale_val = fm.get("STALE_AFTER", "") if fm else ""
    if stale_val:
        if not re.match(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$", stale_val):
            fail_check(
                f"Invalid stale_after date '{stale_val}' (must be YYYY-MM-DD)",
                file_str,
            )
            file_fails += 1
        else:
            pass_check(f"Freshness trust signal (stale_after) is valid ({stale_val})")

    verified_val = fm.get("VERIFIED", "") if fm else ""
    if verified_val:
        if verified_val not in ("human", "attested", "automated"):
            fail_check(
                f"Invalid verified value '{verified_val}' (must be human, attested, or automated)",
                file_str,
            )
            file_fails += 1
        else:
            pass_check(f"Trustworthiness signal (verified) is valid ({verified_val})")

    sources_val = fm.get("SOURCES", "") if fm else ""
    if sources_val:
        if not re.match(r"^\[.*\]$", sources_val):
            fail_check(
                f"Invalid sources format '{sources_val}' (must be inline array matching ^\\[.*\\]$)",
                file_str,
            )
            file_fails += 1
        else:
            pass_check("Provenance signal (sources) is valid")

    owner_val = fm.get("OWNER", "") if fm else ""
    if owner_val:
        if not re.match(r"^[a-zA-Z0-9_-]+$", owner_val):
            fail_check(f"Invalid owner format '{owner_val}'", file_str)
            file_fails += 1
        else:
            pass_check(f"Custodian owner signal is valid ({owner_val})")

    # 6. De-identification & Isolation
    if re.search(r"(/home/|/mnt/|/tmp/)", content):
        fail_check(
            "Hardcoded host filesystem paths detected (/home/, /mnt/, /tmp/)",
            file_str,
        )
        file_fails += 1
    else:
        pass_check("De-identification verified (no hardcoded host paths)")

    if re.search(r"(BUDTENDER_KERNEL|buds_)", content, re.IGNORECASE):
        fail_check(
            "Runtime isolation leak detected (buds_* or BUDTENDER_KERNEL)",
            file_str,
        )
        file_fails += 1
    else:
        pass_check("Runtime isolation verified (zero buds_* leaks)")

    # 7. Document Structure, H1 Heading & Depth
    # Scan lines for frontmatter boundary, code fences, headings, tags, wikilinks
    in_fm = False
    in_code = False
    h1_lines = []
    invalid_depth_line = None
    h2_headings_list = []
    untagged_code_line = None
    forbidden_tags_found = False
    raw_wikilinks = []

    for idx, raw_line in enumerate(lines, start=1):
        raw = raw_line.rstrip("\r\n")

        if idx == 1 and re.match(r"^---", raw):
            in_fm = True
            continue
        if in_fm:
            if re.match(r"^---", raw):
                in_fm = False
            continue

        if re.match(r"^```", raw):
            if not in_code:
                in_code = True
                if untagged_code_line is None and re.match(r"^```[ \t]*$", raw):
                    untagged_code_line = idx
            else:
                in_code = False
            continue

        if in_code:
            continue

        # Outside code block and frontmatter
        if re.match(r"^# ", raw):
            h1_lines.append((idx, raw))

        if invalid_depth_line is None and re.match(r"^####", raw):
            invalid_depth_line = idx

        if re.match(r"^## ", raw):
            h2_heading = re.sub(r"^## +", "", raw).strip()
            h2_headings_list.append(h2_heading)

        # Obsidian tag check: match (^|[ \t])#[a-zA-Z0-9_-]+ unless heading ^[ \t]*#[ \t]
        if not re.match(r"^[ \t]*#[ \t]", raw):
            if re.search(r"(?:^|[ \t])#[a-zA-Z0-9_-]+", raw):
                forbidden_tags_found = True

        # Collect internal wikilinks
        for match in re.finditer(r"\[\[([a-z0-9-]+)(?:\|[^]]+)?\]\]", raw):
            raw_wikilinks.append(match.group(1))

    h1_count = len(h1_lines)
    if h1_count != 1:
        fail_check(
            f"Document must contain exactly one level-1 heading (# <Title>), found {h1_count}",
            file_str,
        )
        file_fails += 1
    else:
        pass_check("Exactly one level-1 heading present")

    if not h1_lines:
        fail_check(
            "Missing level-1 heading (# <Title>) after frontmatter",
            file_str,
        )
        file_fails += 1
    else:
        first_h1_text = h1_lines[0][1]
        h1_title = re.sub(r"^# +", "", first_h1_text)
        if not h1_title:
            fail_check(
                "Missing level-1 heading (# <Title>) after frontmatter",
                file_str,
            )
            file_fails += 1
        elif h1_title != name_val:
            fail_check(
                f"H1 title '{h1_title}' does not match frontmatter name '{name_val}'",
                file_str,
            )
            file_fails += 1
        else:
            pass_check(f"H1 title matches frontmatter name verbatim ('{h1_title}')")

    if invalid_depth_line is not None:
        fail_check(
            f"Prohibited heading depth (#### or deeper) on line {invalid_depth_line}",
            file_str,
        )
        file_fails += 1
    else:
        pass_check("Heading depth constraints verified (level 1-3 only)")

    # 8. Section Sequence & Tokens (Excluding Code Blocks)
    h2_headings = ",".join(h2_headings_list)
    if h2_headings not in (
        "Context,Mechanism,Rules",
        "Context,Mechanism,Implementation,Rules",
    ):
        fail_check(
            f"H2 sections must be 'Context -> Mechanism -> Rules' or 'Context -> Mechanism -> Implementation -> Rules' (found: '{h2_headings}')",
            file_str,
        )
        file_fails += 1
    else:
        pass_check(f"H2 section sequence valid ({h2_headings})")

    if "**Problem:**" not in content or "**Solution:**" not in content:
        fail_check(
            "## Context missing mandatory **Problem:** or **Solution:** tokens",
            file_str,
        )
        file_fails += 1
    else:
        pass_check("Context tokens present (**Problem:**, **Solution:**)")

    if "- **Principle:**" not in content or "- **Structure:**" not in content:
        fail_check(
            "## Mechanism missing mandatory - **Principle:** or - **Structure:** items",
            file_str,
        )
        file_fails += 1
    else:
        pass_check("Mechanism tokens present (- **Principle:**, - **Structure:**)")

    # 9. Code Fences & Obsidian Tags
    if untagged_code_line is not None:
        fail_check(
            f"Untagged code fence on line {untagged_code_line} (explicit language tag required)",
            file_str,
        )
        file_fails += 1
    else:
        pass_check("Code fence syntax verified (all fences tagged)")

    if forbidden_tags_found:
        fail_check(
            "Forbidden Obsidian tags found outside code blocks",
            file_str,
        )
        file_fails += 1
    else:
        pass_check("Obsidian tag check passed (zero forbidden #tags found)")

    # 10. Wikilinks & Whitespace Hygiene
    if re.search(r"^\|.*\[\[.*\]\].*\|", content, re.MULTILINE):
        fail_check(
            "Forbidden navigational wikilinks inside markdown table cells",
            file_str,
        )
        file_fails += 1
    else:
        pass_check("Wikilink table placement check passed")

    # Internal Wikilink Integrity Check
    broken_links = []
    for link_target in raw_wikilinks:
        if not link_target:
            continue
        found = False
        if brain_dir and brain_dir.is_dir():
            for d in CANONICAL_DOMAINS:
                cand_file = brain_dir / d / f"{link_target}.md"
                if cand_file.is_file():
                    found = True
                    break
        if not found:
            broken_links.append(link_target)

    if broken_links:
        fail_check(
            f"Broken internal wikilink(s): {' '.join(broken_links)}",
            file_str,
        )
        file_fails += 1
    else:
        pass_check("Internal wikilink integrity verified")

    # Trailing whitespace check
    has_trailing = False
    for line in lines:
        line_clean = line.rstrip("\r\n")
        if line_clean and (line_clean[-1] in " \t" or re.search(r"[ \t]+$", line_clean)):
            has_trailing = True
            break

    if has_trailing:
        fail_check("Trailing whitespace detected", file_str)
        file_fails += 1
    else:
        pass_check("Whitespace hygiene verified (zero trailing whitespace)")

    if file_fails == 0:
        sys.stdout.write(f"    {GREEN}{BOLD}Result: APPROVED{NC}\n")
        return True
    else:
        sys.stdout.write(
            f"    {RED}{BOLD}Result: REJECTED ({file_fails} failures){NC}\n"
        )
        return False


# ------------------------------------------------------------------------------
# Promotion & Deprecation Helpers
# ------------------------------------------------------------------------------
def update_frontmatter_field(target_file: Path, field_name: str, field_value: str) -> None:
    """Update or insert a frontmatter field while maintaining canonical placement."""
    with open(target_file, "r", encoding="utf-8") as f:
        lines = f.readlines()

    out_lines = []
    in_fm = False
    replaced = False

    # Check if field already exists in frontmatter
    field_exists = False
    for idx, line in enumerate(lines, start=1):
        raw = line.rstrip("\r\n")
        if idx == 1 and re.match(r"^---[ \t]*$", raw):
            in_fm = True
            continue
        if in_fm:
            if re.match(r"^---[ \t]*$", raw):
                break
            if re.match(rf"^{re.escape(field_name)}:", raw):
                field_exists = True
                break

    in_fm = False
    for idx, line in enumerate(lines, start=1):
        raw = line.rstrip("\r\n")
        if idx == 1 and re.match(r"^---[ \t]*$", raw):
            in_fm = True
            out_lines.append(raw + "\n")
            continue

        if in_fm and re.match(r"^---[ \t]*$", raw):
            if not replaced and not field_exists:
                out_lines.append(f"{field_name}: {field_value}\n")
                replaced = True
            in_fm = False
            out_lines.append(raw + "\n")
            continue

        if in_fm:
            if re.match(rf"^{re.escape(field_name)}:", raw):
                out_lines.append(f"{field_name}: {field_value}\n")
                replaced = True
                continue
            if not field_exists and not replaced:
                if field_name == "status" and re.match(r"^type:", raw):
                    out_lines.append(raw + "\n")
                    out_lines.append(f"{field_name}: {field_value}\n")
                    replaced = True
                    continue
                if field_name == "deprecated" and (
                    re.match(r"^status:", raw) or re.match(r"^type:", raw)
                ):
                    out_lines.append(raw + "\n")
                    out_lines.append(f"{field_name}: {field_value}\n")
                    replaced = True
                    continue

        out_lines.append(raw + "\n")

    temp_file = target_file.with_name(f".{target_file.name}.tmp.{os.getpid()}")
    try:
        temp_file.write_text("".join(out_lines), encoding="utf-8")
        try:
            shutil.copymode(target_file, temp_file)
        except Exception:
            pass
        os.replace(temp_file, target_file)
    finally:
        if temp_file.exists():
            temp_file.unlink(missing_ok=True)


def run_index(brain_dir: Path) -> None:
    """Trigger internal index regeneration via index.py."""
    index_script = SCRIPT_DIR / "index.py"
    if index_script.is_file() and brain_dir and brain_dir.is_dir():
        subprocess.run([sys.executable, str(index_script), str(brain_dir)], check=False)


def promote_file(target: Path, brain_dir: Optional[Path]) -> int:
    """Promote candidate artifact to status: active with atomic rollback protection."""
    target = target.resolve()
    if not audit_file(target, brain_dir=brain_dir):
        sys.stderr.write(
            f"\n{RED}Cannot promote: target artifact failed initial audit.{NC}\n"
        )
        return 1

    backup_path: Optional[Path] = None
    try:
        with tempfile.NamedTemporaryFile(
            delete=False, prefix="ka_promote_backup_", suffix=".tmp"
        ) as tf:
            backup_path = Path(tf.name)
        shutil.copy2(target, backup_path)

        update_frontmatter_field(target, "status", "active")

        if not audit_file(target, brain_dir=brain_dir):
            sys.stderr.write(
                f"\n{RED}Cannot promote: artifact failed audit after modification.{NC}\n"
            )
            shutil.copy2(backup_path, target)
            return 1

        sys.stdout.write(f"\n{GREEN}Promoted to active:{NC} {target}\n")
        if brain_dir:
            run_index(brain_dir)
        return 0
    except BaseException:
        if backup_path and backup_path.exists():
            try:
                shutil.copy2(backup_path, target)
            except Exception:
                pass
        raise
    finally:
        if backup_path and backup_path.exists():
            try:
                backup_path.unlink()
            except Exception:
                pass


def set_deprecation(target: Path, state: str, brain_dir: Optional[Path]) -> int:
    """Set deprecated flag to state (true/false) with atomic rollback protection."""
    target = target.resolve()
    if not audit_file(target, brain_dir=brain_dir):
        sys.stderr.write(
            f"\n{RED}Cannot modify: target artifact failed initial audit.{NC}\n"
        )
        return 1

    backup_path: Optional[Path] = None
    try:
        with tempfile.NamedTemporaryFile(
            delete=False, prefix="ka_dep_backup_", suffix=".tmp"
        ) as tf:
            backup_path = Path(tf.name)
        shutil.copy2(target, backup_path)

        update_frontmatter_field(target, "deprecated", state)

        if not audit_file(target, brain_dir=brain_dir):
            sys.stderr.write(
                f"\n{RED}Cannot modify: artifact failed audit after modification.{NC}\n"
            )
            shutil.copy2(backup_path, target)
            return 1

        sys.stdout.write(
            f"\n{GREEN}Updated deprecation flag (deprecated: {state}):{NC} {target}\n"
        )
        if brain_dir:
            run_index(brain_dir)
        return 0
    except BaseException:
        if backup_path and backup_path.exists():
            try:
                shutil.copy2(backup_path, target)
            except Exception:
                pass
        raise
    finally:
        if backup_path and backup_path.exists():
            try:
                backup_path.unlink()
            except Exception:
                pass


# ------------------------------------------------------------------------------
# Argument Parsing & Main Dispatcher
# ------------------------------------------------------------------------------
class CustomArgumentParser(argparse.ArgumentParser):
    """ArgumentParser that exits with code 1 on CLI usage errors."""

    def error(self, message: str) -> None:
        self.print_usage(sys.stderr)
        sys.stderr.write(f"{self.prog}: error: {message}\n")
        sys.exit(1)


def main() -> int:
    parser = CustomArgumentParser(
        prog="audit.py",
        description="LOKA Knowledge Artifact Audit & Lifecycle Engine (v0.2.3)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Examples:
  audit.py ./.agents/loka-brain/profiles/my-profile.md
  audit.py --all
  audit.py --promote ./.agents/loka-brain/workflows/my-workflow.md""",
    )

    parser.add_argument(
        "--all",
        action="store_true",
        help="Audit all knowledge artifacts across all 6 canonical domains",
    )
    parser.add_argument(
        "--promote",
        metavar="<file>",
        help="Audit and advance candidate artifact to status: active",
    )
    parser.add_argument(
        "--deprecate",
        metavar="<file>",
        help="Set deprecated: true",
    )
    parser.add_argument(
        "--undeprecate",
        metavar="<file>",
        help="Set deprecated: false",
    )
    parser.add_argument(
        "file",
        nargs="?",
        default=None,
        help="Target knowledge artifact file to audit",
    )

    args = parser.parse_args()

    # Validate mutual exclusivity of modes
    modes_set = [
        bool(args.all),
        bool(args.promote),
        bool(args.deprecate),
        bool(args.undeprecate),
        bool(args.file),
    ]
    if sum(modes_set) > 1 and not (args.file and not any([args.promote, args.deprecate, args.undeprecate])):
        # If --all and file are both specified, or multiple actions
        if sum([bool(args.all), bool(args.promote), bool(args.deprecate), bool(args.undeprecate)]) > 1:
            parser.error("mutually exclusive actions specified")

    brain_dir = resolve_brain_dir()

    if args.promote:
        return promote_file(Path(args.promote), brain_dir)
    elif args.deprecate:
        return set_deprecation(Path(args.deprecate), "true", brain_dir)
    elif args.undeprecate:
        return set_deprecation(Path(args.undeprecate), "false", brain_dir)
    elif args.file and not args.all:
        target_path = Path(args.file)
        success = audit_file(target_path, brain_dir)
        return 0 if success else 1

    # Default to --all mode
    if not brain_dir or not brain_dir.is_dir():
        sys.stderr.write("ERROR: Could not resolve loka-brain directory.\n")
        return 1

    artifacts: List[Path] = []
    for domain in CANONICAL_DOMAINS:
        domain_dir = brain_dir / domain
        if not domain_dir.is_dir():
            continue
        domain_files = [
            f
            for f in domain_dir.iterdir()
            if f.is_file()
            and f.suffix == ".md"
            and f.name not in ("index.md", "schema.md")
        ]
        domain_files.sort(key=lambda x: str(x))
        artifacts.extend(domain_files)

    artifact_count = len(artifacts)
    if artifact_count == 0:
        print(f"No artifacts found in {brain_dir} across canonical domains.")
        return 0

    failed_artifacts = 0
    for art in artifacts:
        if not audit_file(art, brain_dir):
            failed_artifacts += 1

    sys.stdout.write("\n=== Audit Summary ===\n")
    sys.stdout.write(f"Total Artifacts: {artifact_count}\n")
    sys.stdout.write(f"Total Checks:    {TOTAL_CHECKS}\n")
    sys.stdout.write(f"Passed Checks:   {PASSED_CHECKS}\n")
    sys.stdout.write(f"Failed Checks:   {FAILED_CHECKS}\n")

    if failed_artifacts == 0:
        sys.stdout.write(f"{GREEN}{BOLD}Result: AUDIT PASSED{NC}\n")
        return 0
    else:
        sys.stdout.write(
            f"{RED}{BOLD}Result: AUDIT FAILED ({failed_artifacts} artifacts failed){NC}\n"
        )
        return 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)

