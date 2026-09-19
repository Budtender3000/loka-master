"""Deterministic Index Generator for LOKA Knowledge Artifacts."""

import os
import shutil
import sys
from pathlib import Path
from typing import List, Optional, Tuple, Union

from .frontmatter import (
    CANONICAL_DOMAINS,
    check_semantics,
    domain_title,
    domain_to_type,
    parse,
)

START_MARKER = "<!-- AUTO-INDEX:START -->"
END_MARKER = "<!-- AUTO-INDEX:END -->"

FATAL_PARSE_CODES = {
    "missing_opening_delimiter",
    "missing_closing_delimiter",
    "duplicate_key",
    "invalid_syntax",
    "invalid_key_name",
}


def resolve_brain_dir(arg_dir: Optional[Union[str, Path]] = None) -> Optional[Path]:
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

    script_dir = Path(__file__).resolve().parent
    candidates = [
        script_dir / "../../../loka-brain",
        script_dir / "../../loka-brain",
        Path("./.agents/loka-brain"),
        Path("./loka-brain"),
    ]
    for cand in candidates:
        if cand.is_dir():
            return cand.resolve()

    cwd = Path.cwd().resolve()
    for cur in [cwd, *cwd.parents]:
        cand = cur / ".agents" / "loka-brain"
        if cand.is_dir():
            return cand.resolve()
        cand2 = cur / "loka-brain"
        if cand2.is_dir():
            return cand2.resolve()

    return None


def generate_index(
    brain_dir: Path, strict: bool = False
) -> Tuple[int, List[str]]:
    """Generate index between AUTO-INDEX markers in brain_dir/index.md.

    Returns:
        (exit_code, warnings)
    """
    index_file = brain_dir / "index.md"
    if not index_file.is_file():
        sys.stderr.write(f"ERROR: Index file not found at {index_file}\n")
        return 1, [f"Index file not found at {index_file}"]

    try:
        content = index_file.read_text(encoding="utf-8")
    except Exception as e:
        sys.stderr.write(f"ERROR: Cannot read index file at {index_file}: {e}\n")
        return 1, [f"Cannot read index file: {e}"]

    if START_MARKER not in content or END_MARKER not in content:
        sys.stderr.write(f"ERROR: Index markers not found in {index_file}\n")
        return 1, ["Index markers not found"]

    block_lines: List[str] = []
    warnings: List[str] = []
    first_section = True

    for domain in CANONICAL_DOMAINS:
        domain_dir = brain_dir / domain
        if not domain_dir.is_dir():
            continue

        files: List[Path] = []
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

        # Deterministic sort by path / filename (id.md)
        files.sort(key=lambda x: str(x))

        domain_lines: List[str] = []
        for file_path in files:
            try:
                file_content = file_path.read_text(encoding="utf-8")
            except Exception as e:
                warn = f"Cannot read {file_path}: {e}"
                warnings.append(warn)
                sys.stderr.write(f"WARNING: Skipping {file_path} in index: {e}\n")
                continue

            fm, body, problems = parse(file_content)

            # Check parse problems
            if problems:
                warn = f"{problems[0].message} in {file_path}"
                warnings.append(warn)
                sys.stderr.write(f"WARNING: Skipping {file_path} in index: {problems[0].message}\n")
                continue

            # Check required fields
            missing = [
                f for f in ("id", "name", "type", "description")
                if not fm.get(f) or not str(fm.get(f)).strip()
            ]
            if missing:
                missing_str = ", ".join(missing)
                warn = f"Missing required fields ({missing_str}) in {file_path}"
                warnings.append(warn)
                sys.stderr.write(
                    f"WARNING: Skipping {file_path} in index: missing required fields: {missing_str}\n"
                )
                continue

            # Check semantic validity
            sem_problems = [
                p for p in check_semantics(fm, file_path)
                if p.code != "missing_required_field"
            ]
            if sem_problems:
                warn = f"{sem_problems[0].message} in {file_path}"
                warnings.append(warn)
                sys.stderr.write(f"WARNING: Skipping {file_path} in index: {sem_problems[0].message}\n")
                continue

            fid = fm.get("id")
            name = fm.get("name")
            ftype = fm.get("type")
            description = fm.get("description")

            file_stem = file_path.stem
            fid = fid or file_stem
            name = name or fid
            ftype = ftype or domain_to_type(domain)
            status = fm.get("status") or "draft"
            dep_val = fm.get("deprecated")
            if isinstance(dep_val, bool):
                deprecated = "true" if dep_val else "false"
            elif dep_val is not None and str(dep_val).strip():
                deprecated = str(dep_val).strip().lower()
            else:
                deprecated = "false"
            created = fm.get("created") or "undated"
            description = description or "No description provided."

            line = (
                f"- [[{fid}|{name}]] (`{ftype}` | `{status}` | "
                f"deprecated: `{deprecated}` | `{created}`) — {description}"
            )
            domain_lines.append(line)

        if not domain_lines:
            continue

        if not first_section:
            block_lines.append("")
        first_section = False

        block_lines.append(f"## {domain_title(domain)}")
        block_lines.append("")
        block_lines.extend(domain_lines)

    lines = content.splitlines()
    out_lines: List[str] = []
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

    if strict and warnings:
        return 1, warnings

    return 0, warnings
