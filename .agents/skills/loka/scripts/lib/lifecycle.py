"""LOKA Knowledge Artifact Lifecycle Transitions and Transactional Engine.

Governs state progression (draft -> test -> active), deprecation/undeprecation,
and transactional mint/merge execution with realpath containment and rollbacks.
"""

import hashlib
from pathlib import Path
from typing import Optional, Tuple, Union

from .formatter import format_file
from .frontmatter import (
    CANONICAL_DOMAINS,
    CANONICAL_STATUSES,
    FATAL_PARSE_CODES,
    check_semantics,
    parse,
    render,
)
from .indexer import generate_index, resolve_brain_dir


class LifecycleError(Exception):
    """Raised when a lifecycle transition or mint operation fails."""

    pass


def sha256_file(path: Path) -> str:
    """Compute hex SHA-256 digest of a file."""
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()


def _validate_target_path(
    target_path: Union[str, Path],
    brain_dir: Path,
    must_exist: bool = False,
) -> Path:
    """Validate target path containment within canonical domains of loka-brain."""
    p = Path(target_path)
    if not p.is_absolute():
        if p.is_file() or (not must_exist and p.parent.is_dir()):
            cand = p.resolve()
        else:
            parts = list(p.parts)
            if len(parts) >= 2 and parts[0] in (".agents", "") and parts[1] == "loka-brain":
                parts = parts[2:]
            elif parts and parts[0] == "loka-brain":
                parts = parts[1:]
            cand = (brain_dir / Path(*parts)).resolve()
    else:
        cand = p.resolve()

    if p.is_symlink() or cand.is_symlink():
        raise LifecycleError(f"Symlink targets are prohibited: {target_path}")

    try:
        rel = cand.relative_to(brain_dir)
    except ValueError:
        raise LifecycleError(f"Target path outside brain vault containment: {cand}")

    if len(rel.parts) != 2 or rel.parts[0] not in CANONICAL_DOMAINS:
        raise LifecycleError(
            f"Target file must reside directly under a canonical domain directory ({', '.join(CANONICAL_DOMAINS)}): {rel}"
        )

    if cand.name in ("index.md", "schema.md"):
        raise LifecycleError(f"Target file cannot be {cand.name}")

    if not cand.name.endswith(".md"):
        raise LifecycleError(f"Target file must have .md extension: {cand.name}")

    if must_exist and not cand.is_file():
        raise LifecycleError(f"Target file does not exist: {cand}")

    return cand


def _apply_and_sync(
    target: Path,
    raw_new_text: str,
    old_text: Optional[str],
    brain_dir: Path,
) -> None:
    """Write new text, format atomically, regenerate index, with rollback on failure."""
    target.parent.mkdir(parents=True, exist_ok=True)
    try:
        target.write_text(raw_new_text, encoding="utf-8")
        changed, problems, _ = format_file(target)
        if problems:
            raise LifecycleError(f"Format error on {target.name}: {problems[0].message}")
        exit_code, warnings = generate_index(brain_dir)
        if exit_code != 0:
            raise LifecycleError(f"Index regeneration failed: {', '.join(warnings)}")
    except Exception as e:
        if old_text is not None:
            target.write_text(old_text, encoding="utf-8")
        elif target.exists():
            target.unlink(missing_ok=True)
        generate_index(brain_dir)
        raise LifecycleError(f"Mutation failed and was rolled back: {e}") from e


def promote_artifact(
    file_path: Union[str, Path],
    brain_dir: Optional[Union[str, Path]] = None,
) -> Tuple[str, str]:
    """Advance an artifact exactly one lifecycle step (draft -> test -> active).

    Returns:
        (old_status, new_status)
    """
    resolved_brain = resolve_brain_dir(brain_dir)
    if not resolved_brain or not resolved_brain.is_dir():
        raise LifecycleError("Could not resolve valid loka-brain vault directory")

    target = _validate_target_path(file_path, resolved_brain, must_exist=True)

    old_text = target.read_text(encoding="utf-8")
    fm, body, parse_problems = parse(old_text)
    fatal = [p for p in parse_problems if p.code in FATAL_PARSE_CODES]
    if fatal:
        raise LifecycleError(f"Cannot parse frontmatter in {target.name}: {fatal[0].message}")

    sem_problems = check_semantics(fm, target)
    if sem_problems:
        raise LifecycleError(f"Semantic validation failed for {target.name}: {sem_problems[0].message}")

    dep = str(fm.get("deprecated", "")).strip().lower()
    if dep in ("true", "1", "yes"):
        raise LifecycleError(f"Cannot promote deprecated artifact: {target.name}")

    old_status = str(fm.get("status") or "draft").strip().lower()
    if old_status == "draft":
        new_status = "test"
    elif old_status == "test":
        new_status = "active"
    elif old_status == "active":
        raise LifecycleError(f"Artifact {target.name} is already active (terminal lifecycle state)")
    else:
        raise LifecycleError(f"Invalid current status '{old_status}' in {target.name}")

    fm["status"] = new_status
    new_fm_block = render(fm)
    raw_new_text = new_fm_block + body

    _apply_and_sync(target, raw_new_text, old_text, resolved_brain)
    return old_status, new_status


def deprecate_artifact(
    file_path: Union[str, Path],
    brain_dir: Optional[Union[str, Path]] = None,
) -> bool:
    """Mark an artifact as deprecated (deprecated: true)."""
    resolved_brain = resolve_brain_dir(brain_dir)
    if not resolved_brain or not resolved_brain.is_dir():
        raise LifecycleError("Could not resolve valid loka-brain vault directory")

    target = _validate_target_path(file_path, resolved_brain, must_exist=True)

    old_text = target.read_text(encoding="utf-8")
    fm, body, parse_problems = parse(old_text)
    fatal = [p for p in parse_problems if p.code in FATAL_PARSE_CODES]
    if fatal:
        raise LifecycleError(f"Cannot parse frontmatter in {target.name}: {fatal[0].message}")

    sem_problems = check_semantics(fm, target)
    if sem_problems:
        raise LifecycleError(f"Semantic validation failed for {target.name}: {sem_problems[0].message}")

    dep = str(fm.get("deprecated", "")).strip().lower()
    if dep in ("true", "1", "yes"):
        raise LifecycleError(f"Artifact {target.name} is already deprecated")

    fm["deprecated"] = "true"
    new_fm_block = render(fm)
    raw_new_text = new_fm_block + body

    _apply_and_sync(target, raw_new_text, old_text, resolved_brain)
    return True


def undeprecate_artifact(
    file_path: Union[str, Path],
    brain_dir: Optional[Union[str, Path]] = None,
) -> bool:
    """Clear deprecation status on an artifact (deprecated: false)."""
    resolved_brain = resolve_brain_dir(brain_dir)
    if not resolved_brain or not resolved_brain.is_dir():
        raise LifecycleError("Could not resolve valid loka-brain vault directory")

    target = _validate_target_path(file_path, resolved_brain, must_exist=True)

    old_text = target.read_text(encoding="utf-8")
    fm, body, parse_problems = parse(old_text)
    fatal = [p for p in parse_problems if p.code in FATAL_PARSE_CODES]
    if fatal:
        raise LifecycleError(f"Cannot parse frontmatter in {target.name}: {fatal[0].message}")

    sem_problems = check_semantics(fm, target)
    if sem_problems:
        raise LifecycleError(f"Semantic validation failed for {target.name}: {sem_problems[0].message}")

    dep = str(fm.get("deprecated", "")).strip().lower()
    if dep not in ("true", "1", "yes"):
        raise LifecycleError(f"Artifact {target.name} is not deprecated")

    fm["deprecated"] = "false"
    new_fm_block = render(fm)
    raw_new_text = new_fm_block + body

    _apply_and_sync(target, raw_new_text, old_text, resolved_brain)
    return True


def mint_artifact(
    action: str,
    target_path: Union[str, Path],
    draft_file: Union[str, Path],
    expected_hash: Optional[str] = None,
    base_hash: Optional[str] = None,
    brain_dir: Optional[Union[str, Path]] = None,
) -> Tuple[str, str]:
    """Execute transactional mint or merge against the loka-brain vault.

    Returns:
        (action, target_real_path)
    """
    resolved_brain = resolve_brain_dir(brain_dir)
    if not resolved_brain or not resolved_brain.is_dir():
        raise LifecycleError("Could not resolve valid loka-brain vault directory")

    if action not in ("NEW_MINT", "MERGE"):
        raise LifecycleError(f"Invalid action '{action}' (must be NEW_MINT or MERGE)")

    draft_p = Path(draft_file).resolve()
    if not draft_p.is_file():
        raise LifecycleError(f"Draft file not found: {draft_file}")

    if expected_hash:
        actual_hash = sha256_file(draft_p)
        if actual_hash.lower() != expected_hash.lower():
            raise LifecycleError(
                f"Draft file hash ({actual_hash}) does not match expected ({expected_hash})"
            )

    must_exist = (action == "MERGE")
    target = _validate_target_path(target_path, resolved_brain, must_exist=must_exist)

    if action == "NEW_MINT" and target.exists():
        raise LifecycleError(f"Target already exists under NEW_MINT: {target}")

    old_text: Optional[str] = None
    if action == "MERGE":
        if not target.is_file():
            raise LifecycleError(f"Target does not exist for MERGE: {target}")
        if base_hash:
            actual_base_hash = sha256_file(target)
            if actual_base_hash.lower() != base_hash.lower():
                raise LifecycleError(
                    f"Target base hash ({actual_base_hash}) does not match expected base-hash ({base_hash})"
                )
        old_text = target.read_text(encoding="utf-8")

    draft_text = draft_p.read_text(encoding="utf-8")
    fm, body, parse_problems = parse(draft_text)
    fatal = [p for p in parse_problems if p.code in FATAL_PARSE_CODES]
    if fatal:
        raise LifecycleError(f"Cannot parse draft frontmatter: {fatal[0].message}")

    sem_problems = check_semantics(fm, target)
    if sem_problems:
        raise LifecycleError(
            f"Draft semantic validation failed for {target.name}: {sem_problems[0].message}"
        )

    _apply_and_sync(target, draft_text, old_text, resolved_brain)
    return action, str(target)
