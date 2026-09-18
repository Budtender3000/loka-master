#!/usr/bin/env python3
"""index.py — Auto-Updating Index Generator for loka-brain Knowledge Artifacts."""

import os
import shutil
import sys
from pathlib import Path

# Add lib directory to sys.path
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR / "lib"))

from frontmatter import CANONICAL_DOMAINS, FrontmatterError, domain_to_type, parse_frontmatter

START_MARKER = "<!-- AUTO-INDEX:START -->"
END_MARKER = "<!-- AUTO-INDEX:END -->"


def resolve_brain_dir(arg_dir: str = None) -> Path:
    """Resolve loka-brain directory using argument, env, or fallback candidates."""
    if arg_dir:
        p = Path(arg_dir).resolve()
        if p.is_dir():
            return p

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

    return None


def domain_title(domain: str) -> str:
    """Map canonical domain directory name to section title."""
    titles = {
        "profiles": "Profiles",
        "behaviors": "Behaviors",
        "standards": "Standards",
        "workflows": "Workflows",
        "tools": "Tools",
        "meta": "Meta",
    }
    return titles.get(domain, domain)


def generate_index(brain_dir: Path) -> int:
    """Generate index between AUTO-INDEX markers in brain_dir/index.md."""
    index_file = brain_dir / "index.md"
    if not index_file.is_file():
        print(f"ERROR: Index file not found at {index_file}", file=sys.stderr)
        return 1

    try:
        content = index_file.read_text(encoding="utf-8")
    except Exception as e:
        print(f"ERROR: Cannot read index file at {index_file}: {e}", file=sys.stderr)
        return 1

    if START_MARKER not in content or END_MARKER not in content:
        print(f"ERROR: Index markers not found in {index_file}", file=sys.stderr)
        return 1

    # Build index block
    block_lines = []
    first_section = True

    for domain in CANONICAL_DOMAINS:
        domain_dir = brain_dir / domain
        if not domain_dir.is_dir():
            continue

        # Collect *.md files, excluding index.md, schema.md, and hidden files
        files = []
        for p in domain_dir.iterdir():
            if (
                p.is_file()
                and p.suffix == ".md"
                and p.name not in ("index.md", "schema.md")
                and not p.name.startswith(".")
            ):
                files.append(p)

        if not files:
            continue

        # Sort by full path (matching bash sort -z on find output)
        files.sort(key=lambda x: str(x))

        if not first_section:
            block_lines.append("")
        first_section = False

        block_lines.append(f"## {domain_title(domain)}")
        block_lines.append("")

        for file_path in files:
            try:
                fm = parse_frontmatter(file_path)
            except FrontmatterError:
                fm = {}

            file_stem = file_path.stem
            fid = fm.get("ID") or file_stem
            name = fm.get("NAME") or fid
            ftype = fm.get("TYPE") or domain_to_type(domain)
            status = fm.get("STATUS") or "draft"
            deprecated = fm.get("DEPRECATED") or "false"
            created = fm.get("CREATED") or "undated"
            description = fm.get("DESCRIPTION") or "No description provided."

            line = f"- [[{fid}|{name}]] (`{ftype}` | `{status}` | deprecated: `{deprecated}` | `{created}`) — {description}"
            block_lines.append(line)

    # Reconstruct index.md with updated block
    lines = content.splitlines()
    out_lines = []
    in_auto = False

    for line in lines:
        if START_MARKER in line:
            out_lines.append(line)
            out_lines.append("")
            out_lines.extend(block_lines)
            out_lines.append("")
            in_auto = True
            continue
        if END_MARKER in line:
            in_auto = False
            out_lines.append(line)
            continue
        if not in_auto:
            out_lines.append(line)

    new_content = "\n".join(out_lines) + "\n"

    # Atomic write with permission preservation
    temp_file = index_file.with_name(f".{index_file.name}.tmp.{os.getpid()}")
    try:
        temp_file.write_text(new_content, encoding="utf-8")
        try:
            shutil.copymode(index_file, temp_file)
        except Exception:
            pass
        os.replace(temp_file, index_file)
    finally:
        if temp_file.exists():
            temp_file.unlink(missing_ok=True)

    print(f"Index updated: {index_file}")
    return 0


def main() -> int:
    arg_dir = sys.argv[1] if len(sys.argv) > 1 else None
    brain_dir = resolve_brain_dir(arg_dir)

    if not brain_dir or not brain_dir.is_dir():
        print("ERROR: Could not resolve loka-brain directory.", file=sys.stderr)
        return 1

    return generate_index(brain_dir)


if __name__ == "__main__":
    sys.exit(main())
