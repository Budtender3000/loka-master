import hashlib
import sys
import tempfile
import unittest
from pathlib import Path

# Add scripts directory to sys.path
SCRIPTS_DIR = Path(__file__).resolve().parent.parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from lib.frontmatter import CANONICAL_DOMAINS, parse
from lib.indexer import END_MARKER, START_MARKER
from lib.lifecycle import (
    LifecycleError,
    deprecate_artifact,
    mint_artifact,
    promote_artifact,
    sha256_file,
    undeprecate_artifact,
)


class TestLifecycle(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.vault = Path(self.temp_dir.name)
        # Create minimal index.md with markers
        self.index_file = self.vault / "index.md"
        self.index_file.write_text(
            f"# Test Vault Index\n\n{START_MARKER}\n{END_MARKER}\n",
            encoding="utf-8",
        )
        # Create all canonical domain folders
        for d in CANONICAL_DOMAINS:
            (self.vault / d).mkdir()

    def tearDown(self):
        self.temp_dir.cleanup()

    def _create_artifact(
        self,
        domain: str,
        name: str,
        content_lines: list,
    ) -> Path:
        target = self.vault / domain / f"{name}.md"
        target.write_text("\n".join(content_lines) + "\n", encoding="utf-8")
        return target

    # =========================================================================
    # PROMOTE TESTS
    # =========================================================================

    def test_promote_draft_to_test(self):
        p = self._create_artifact(
            "standards",
            "test-std",
            [
                "---",
                "id: test-std",
                "name: Test Standard",
                "type: standard",
                "status: draft",
                "description: A standard under test",
                "---",
                "# Test Standard",
                "",
                "Body content.",
            ],
        )

        old_status, new_status = promote_artifact(p, brain_dir=self.vault)
        self.assertEqual(old_status, "draft")
        self.assertEqual(new_status, "test")

        fm, body, _ = parse(p.read_text(encoding="utf-8"))
        self.assertEqual(fm["status"], "test")

        # Verify index was regenerated with status 'test'
        index_content = self.index_file.read_text(encoding="utf-8")
        self.assertIn("`test`", index_content)

    def test_promote_test_to_active(self):
        p = self._create_artifact(
            "standards",
            "test-std",
            [
                "---",
                "id: test-std",
                "name: Test Standard",
                "type: standard",
                "status: test",
                "description: A standard under test",
                "---",
                "# Test Standard",
            ],
        )

        old_status, new_status = promote_artifact(p, brain_dir=self.vault)
        self.assertEqual(old_status, "test")
        self.assertEqual(new_status, "active")

        fm, _, _ = parse(p.read_text(encoding="utf-8"))
        self.assertEqual(fm["status"], "active")

        index_content = self.index_file.read_text(encoding="utf-8")
        self.assertIn("`active`", index_content)

    def test_promote_omitted_status_treated_as_draft(self):
        p = self._create_artifact(
            "standards",
            "test-std",
            [
                "---",
                "id: test-std",
                "name: Test Standard",
                "type: standard",
                "description: A standard with default status",
                "---",
                "# Test Standard",
            ],
        )

        old_status, new_status = promote_artifact(p, brain_dir=self.vault)
        self.assertEqual(old_status, "draft")
        self.assertEqual(new_status, "test")

    def test_promote_active_fails(self):
        p = self._create_artifact(
            "standards",
            "test-std",
            [
                "---",
                "id: test-std",
                "name: Test Standard",
                "type: standard",
                "status: active",
                "description: Already active standard",
                "---",
                "# Test Standard",
            ],
        )

        with self.assertRaises(LifecycleError) as ctx:
            promote_artifact(p, brain_dir=self.vault)
        self.assertIn("already active", str(ctx.exception).lower())

    def test_promote_deprecated_fails(self):
        p = self._create_artifact(
            "standards",
            "test-std",
            [
                "---",
                "id: test-std",
                "name: Test Standard",
                "type: standard",
                "status: draft",
                "deprecated: true",
                "description: Deprecated draft",
                "---",
                "# Test Standard",
            ],
        )

        with self.assertRaises(LifecycleError) as ctx:
            promote_artifact(p, brain_dir=self.vault)
        self.assertIn("cannot promote deprecated", str(ctx.exception).lower())

    def test_promote_semantic_error_fails(self):
        # ID does not match filename stem
        p = self._create_artifact(
            "standards",
            "test-std",
            [
                "---",
                "id: wrong-id",
                "name: Test Standard",
                "type: standard",
                "description: Broken standard",
                "---",
                "# Test Standard",
            ],
        )

        with self.assertRaises(LifecycleError) as ctx:
            promote_artifact(p, brain_dir=self.vault)
        self.assertIn("semantic validation failed", str(ctx.exception).lower())

    def test_promote_outside_vault_fails(self):
        with tempfile.NamedTemporaryFile(suffix=".md") as tmp:
            tmp.write(b"---\nid: x\nname: X\ntype: standard\ndescription: X\n---\n")
            tmp.flush()
            with self.assertRaises(LifecycleError) as ctx:
                promote_artifact(tmp.name, brain_dir=self.vault)
            self.assertIn("outside brain vault", str(ctx.exception).lower())

    def test_lifecycle_rejects_invalid_date_and_verified(self):
        """Confirm promote, deprecate, and mint reject artifacts with invalid dates or verified."""
        # 1. promote rejects artifact with invalid calendar date (2026-02-30)
        p_bad_date = self._create_artifact(
            "standards",
            "bad-date-std",
            [
                "---",
                "id: bad-date-std",
                "name: Bad Date Standard",
                "type: standard",
                "description: Testing invalid calendar date",
                "created: 2026-02-30",
                "---",
                "# Bad Date Standard",
            ],
        )
        with self.assertRaises(LifecycleError) as ctx:
            promote_artifact(p_bad_date, brain_dir=self.vault)
        self.assertIn("semantic validation failed", str(ctx.exception).lower())
        self.assertIn("invalid created date", str(ctx.exception).lower())

        # 2. deprecate rejects artifact with invalid verified enum
        p_bad_ver = self._create_artifact(
            "tools",
            "bad-ver-tool",
            [
                "---",
                "id: bad-ver-tool",
                "name: Bad Ver Tool",
                "type: tool",
                "description: Testing invalid verified enum",
                "verified: manual",
                "---",
                "# Bad Ver Tool",
            ],
        )
        with self.assertRaises(LifecycleError) as ctx:
            deprecate_artifact(p_bad_ver, brain_dir=self.vault)
        self.assertIn("semantic validation failed", str(ctx.exception).lower())
        self.assertIn("invalid verified", str(ctx.exception).lower())

        # 3. mint rejects draft with invalid stale_after date
        with tempfile.NamedTemporaryFile(mode="w", suffix=".md", delete=False) as draft:
            draft.write(
                "---\n"
                "id: mint-bad-date\n"
                "name: Mint Bad Date\n"
                "type: standard\n"
                "description: Testing mint rejection on invalid stale date\n"
                "stale_after: 2026-02-30\n"
                "---\n\n"
                "# Mint Bad Date\n"
            )
            draft_path = draft.name

        target_path = self.vault / "standards" / "mint-bad-date.md"
        with self.assertRaises(LifecycleError) as ctx:
            mint_artifact(
                action="NEW_MINT",
                target_path=target_path,
                draft_file=draft_path,
                brain_dir=self.vault,
            )
        self.assertIn("semantic validation failed", str(ctx.exception).lower())
        self.assertIn("invalid stale_after date", str(ctx.exception).lower())

    def test_lifecycle_rejects_invalid_deprecated_and_sources_and_leaves_bytes_unchanged(self):
        """Confirm promote, deprecate, and mint reject invalid deprecated/sources and leave file bytes untouched."""
        import subprocess

        test_cases = [
            ("bad-dep-nope", "deprecated: nope", "invalid deprecated"),
            ("bad-dep-ture", "deprecated: ture", "invalid deprecated"),
            ("bad-sources-nope", "sources: nope", "invalid sources"),
            ("bad-sources-unquoted", "sources: [unquoted]", "invalid sources"),
        ]

        for case_id, field_line, expected_msg in test_cases:
            p = self._create_artifact(
                "standards",
                case_id,
                [
                    "---",
                    f"id: {case_id}",
                    f"name: {case_id}",
                    "type: standard",
                    "description: Testing lifecycle rejection",
                    field_line,
                    "---",
                    f"# {case_id}",
                ],
            )
            bytes_before = p.read_bytes()

            # 1. promote_artifact must raise LifecycleError and leave bytes unchanged
            with self.assertRaises(LifecycleError) as ctx:
                promote_artifact(p, brain_dir=self.vault)
            self.assertIn("semantic validation failed", str(ctx.exception).lower())
            self.assertIn(expected_msg, str(ctx.exception).lower())
            self.assertEqual(p.read_bytes(), bytes_before)

            # 2. deprecate_artifact must raise LifecycleError and leave bytes unchanged
            with self.assertRaises(LifecycleError) as ctx:
                deprecate_artifact(p, brain_dir=self.vault)
            self.assertIn("semantic validation failed", str(ctx.exception).lower())
            self.assertIn(expected_msg, str(ctx.exception).lower())
            self.assertEqual(p.read_bytes(), bytes_before)

            # 3. CLI loka promote must exit 1 and leave bytes untouched
            proc = subprocess.run(
                [sys.executable, str(SCRIPTS_DIR / "loka.py"), "promote", str(p), "--vault", str(self.vault)],
                capture_output=True,
                text=True,
            )
            self.assertEqual(proc.returncode, 1)
            self.assertEqual(p.read_bytes(), bytes_before)

    # =========================================================================
    # DEPRECATE / UNDEPRECATE TESTS
    # =========================================================================

    def test_deprecate_and_undeprecate(self):
        p = self._create_artifact(
            "tools",
            "my-tool",
            [
                "---",
                "id: my-tool",
                "name: My Tool",
                "type: tool",
                "status: active",
                "description: A tool to deprecate",
                "---",
                "# My Tool",
            ],
        )

        # 1. Deprecate
        res = deprecate_artifact(p, brain_dir=self.vault)
        self.assertTrue(res)

        fm, _, _ = parse(p.read_text(encoding="utf-8"))
        self.assertEqual(fm["deprecated"], "true")
        index_content = self.index_file.read_text(encoding="utf-8")
        self.assertIn("deprecated: `true`", index_content)

        # Deprecating again should fail
        with self.assertRaises(LifecycleError) as ctx:
            deprecate_artifact(p, brain_dir=self.vault)
        self.assertIn("already deprecated", str(ctx.exception).lower())

        # 2. Undeprecate
        res = undeprecate_artifact(p, brain_dir=self.vault)
        self.assertTrue(res)

        fm, _, _ = parse(p.read_text(encoding="utf-8"))
        self.assertEqual(fm["deprecated"], "false")
        index_content = self.index_file.read_text(encoding="utf-8")
        self.assertIn("deprecated: `false`", index_content)

        # Undeprecating again should fail
        with self.assertRaises(LifecycleError) as ctx:
            undeprecate_artifact(p, brain_dir=self.vault)
        self.assertIn("not deprecated", str(ctx.exception).lower())

    # =========================================================================
    # MINT TESTS (NEW_MINT & MERGE)
    # =========================================================================

    def test_new_mint_success(self):
        draft_content = (
            "---\n"
            "id: newly-minted\n"
            "name: Newly Minted\n"
            "type: workflow\n"
            "description: Brand new workflow\n"
            "---\n"
            "# Newly Minted\n\n"
            "Workflow description.\n"
        )
        draft_file = self.vault / "draft.tmp"
        draft_file.write_text(draft_content, encoding="utf-8")
        expected_hash = hashlib.sha256(draft_file.read_bytes()).hexdigest()

        target_path = self.vault / "workflows" / "newly-minted.md"
        action, target = mint_artifact(
            action="NEW_MINT",
            target_path=target_path,
            draft_file=draft_file,
            expected_hash=expected_hash,
            brain_dir=self.vault,
        )

        self.assertEqual(action, "NEW_MINT")
        self.assertTrue(target_path.is_file())

        index_content = self.index_file.read_text(encoding="utf-8")
        self.assertIn("[[newly-minted|Newly Minted]]", index_content)

    def test_new_mint_target_already_exists_fails(self):
        p = self._create_artifact(
            "workflows",
            "existing-wf",
            [
                "---",
                "id: existing-wf",
                "name: Existing Workflow",
                "type: workflow",
                "description: Already exists",
                "---",
            ],
        )
        draft_file = self.vault / "draft.tmp"
        draft_file.write_text("dummy", encoding="utf-8")

        with self.assertRaises(LifecycleError) as ctx:
            mint_artifact(
                action="NEW_MINT",
                target_path=p,
                draft_file=draft_file,
                brain_dir=self.vault,
            )
        self.assertIn("already exists", str(ctx.exception).lower())

    def test_new_mint_hash_mismatch_fails(self):
        draft_file = self.vault / "draft.tmp"
        draft_file.write_text("some content", encoding="utf-8")

        target_path = self.vault / "workflows" / "new-wf.md"
        with self.assertRaises(LifecycleError) as ctx:
            mint_artifact(
                action="NEW_MINT",
                target_path=target_path,
                draft_file=draft_file,
                expected_hash="deadbeef" * 8,
                brain_dir=self.vault,
            )
        self.assertIn("does not match expected", str(ctx.exception).lower())
        self.assertFalse(target_path.exists())

    def test_merge_success(self):
        target = self._create_artifact(
            "behaviors",
            "my-behavior",
            [
                "---",
                "id: my-behavior",
                "name: My Behavior",
                "type: behavior",
                "description: Base version",
                "---",
                "# My Behavior",
                "",
                "Base text.",
            ],
        )
        base_hash = sha256_file(target)

        merged_content = (
            "---\n"
            "id: my-behavior\n"
            "name: My Behavior\n"
            "type: behavior\n"
            "description: Updated version\n"
            "---\n"
            "# My Behavior\n\n"
            "Updated text.\n"
        )
        draft_file = self.vault / "merged.tmp"
        draft_file.write_text(merged_content, encoding="utf-8")
        expected_hash = sha256_file(draft_file)

        action, res_target = mint_artifact(
            action="MERGE",
            target_path=target,
            draft_file=draft_file,
            expected_hash=expected_hash,
            base_hash=base_hash,
            brain_dir=self.vault,
        )

        self.assertEqual(action, "MERGE")
        fm, body, _ = parse(target.read_text(encoding="utf-8"))
        self.assertEqual(fm["description"], "Updated version")
        self.assertIn("Updated text.", body)

    def test_merge_base_hash_mismatch_fails(self):
        target = self._create_artifact(
            "behaviors",
            "my-behavior",
            [
                "---",
                "id: my-behavior",
                "name: My Behavior",
                "type: behavior",
                "description: Base version",
                "---",
            ],
        )
        draft_file = self.vault / "draft.tmp"
        draft_file.write_text(target.read_text(encoding="utf-8"), encoding="utf-8")

        with self.assertRaises(LifecycleError) as ctx:
            mint_artifact(
                action="MERGE",
                target_path=target,
                draft_file=draft_file,
                base_hash="badhash" * 8,
                brain_dir=self.vault,
            )
        self.assertIn("does not match expected base-hash", str(ctx.exception).lower())

    def test_lifecycle_operations_succeed_despite_unrelated_invalid_artifacts_in_vault(self):
        """Confirm promote/deprecate/undeprecate/mint succeed when unrelated invalid artifacts exist elsewhere in vault."""
        # 1. Create an unrelated invalid artifact in standards/
        self._create_artifact(
            "standards",
            "unrelated-broken",
            [
                "---",
                "id: unrelated-broken",
                "name: Unrelated Broken",
                "type: standard",
                "description: Has invalid deprecated value",
                "deprecated: nope",
                "---",
                "# Unrelated Broken",
            ],
        )

        # 2. Create a valid draft target in standards/
        target = self._create_artifact(
            "standards",
            "valid-target",
            [
                "---",
                "id: valid-target",
                "name: Valid Target",
                "type: standard",
                "status: draft",
                "description: Target to promote",
                "---",
                "# Valid Target",
            ],
        )

        # Promote valid target: must succeed (generate_index runs non-strict)
        old_status, new_status = promote_artifact(target, brain_dir=self.vault)
        self.assertEqual(old_status, "draft")
        self.assertEqual(new_status, "test")

        # Confirm target is promoted on disk and in index; broken is skipped in index
        fm, _, _ = parse(target.read_text(encoding="utf-8"))
        self.assertEqual(fm["status"], "test")
        index_content = self.index_file.read_text(encoding="utf-8")
        self.assertIn("[[valid-target|Valid Target]]", index_content)
        self.assertNotIn("unrelated-broken", index_content)

        # Deprecate valid target: must also succeed
        res = deprecate_artifact(target, brain_dir=self.vault)
        self.assertTrue(res)
        index_content_dep = self.index_file.read_text(encoding="utf-8")
        self.assertIn("deprecated: `true`", index_content_dep)
        self.assertNotIn("unrelated-broken", index_content_dep)

        # Undeprecate valid target: must also succeed
        res_undep = undeprecate_artifact(target, brain_dir=self.vault)
        self.assertTrue(res_undep)
        index_content_undep = self.index_file.read_text(encoding="utf-8")
        self.assertIn("deprecated: `false`", index_content_undep)
        self.assertNotIn("unrelated-broken", index_content_undep)

        # Mint new artifact: must also succeed despite unrelated invalid artifact
        draft_file = self.vault / "mint_draft.tmp"
        draft_content = (
            "---\n"
            "id: newly-minted\n"
            "name: Newly Minted\n"
            "type: standard\n"
            "description: Minted while vault has broken files\n"
            "---\n\n"
            "# Newly Minted\n"
        )
        draft_file.write_text(draft_content, encoding="utf-8")
        expected_hash = hashlib.sha256(draft_file.read_bytes()).hexdigest()

        mint_target = self.vault / "standards" / "newly-minted.md"
        action, t_path = mint_artifact(
            action="NEW_MINT",
            target_path=mint_target,
            draft_file=draft_file,
            expected_hash=expected_hash,
            brain_dir=self.vault,
        )
        self.assertEqual(action, "NEW_MINT")
        self.assertTrue(mint_target.is_file())
        index_content_mint = self.index_file.read_text(encoding="utf-8")
        self.assertIn("[[newly-minted|Newly Minted]]", index_content_mint)
        self.assertNotIn("unrelated-broken", index_content_mint)


class TestLifecycleCLI(unittest.TestCase):
    def setUp(self):
        import subprocess
        self.subprocess = subprocess
        self.temp_dir = tempfile.TemporaryDirectory()
        self.vault = Path(self.temp_dir.name)
        self.index_file = self.vault / "index.md"
        self.index_file.write_text(
            f"# Test Vault Index\n\n{START_MARKER}\n{END_MARKER}\n",
            encoding="utf-8",
        )
        for d in CANONICAL_DOMAINS:
            (self.vault / d).mkdir()
        self.loka_py = SCRIPTS_DIR / "loka.py"

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_cli_promote_deprecate_undeprecate(self):
        target = self.vault / "standards" / "cli-std.md"
        target.write_text(
            "---\n"
            "id: cli-std\n"
            "name: CLI Standard\n"
            "type: standard\n"
            "status: draft\n"
            "description: CLI test standard\n"
            "---\n"
            "# CLI Standard\n",
            encoding="utf-8",
        )

        # 1. Promote
        res = self.subprocess.run(
            [sys.executable, str(self.loka_py), "promote", str(target), "--vault", str(self.vault)],
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 0)
        self.assertIn("[PROMOTED]", res.stdout)
        self.assertIn("(draft -> test)", res.stdout)

        # 2. Deprecate
        res = self.subprocess.run(
            [sys.executable, str(self.loka_py), "deprecate", str(target), "--vault", str(self.vault)],
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 0)
        self.assertIn("[DEPRECATED]", res.stdout)

        # 3. Undeprecate
        res = self.subprocess.run(
            [sys.executable, str(self.loka_py), "undeprecate", str(target), "--vault", str(self.vault)],
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 0)
        self.assertIn("[UNDEPRECATED]", res.stdout)

    def test_cli_mint(self):
        draft_file = self.vault / "draft.tmp"
        draft_file.write_text(
            "---\n"
            "id: cli-tool\n"
            "name: CLI Tool\n"
            "type: tool\n"
            "description: Minted via CLI\n"
            "---\n"
            "# CLI Tool\n",
            encoding="utf-8",
        )
        target = self.vault / "tools" / "cli-tool.md"
        h = hashlib.sha256(draft_file.read_bytes()).hexdigest()

        res = self.subprocess.run(
            [
                sys.executable,
                str(self.loka_py),
                "mint",
                "--action",
                "NEW_MINT",
                "--target",
                str(target),
                "--draft-file",
                str(draft_file),
                "--expected-hash",
                h,
                "--vault",
                str(self.vault),
            ],
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 0)
        self.assertIn("STATUS: MINT_APPLIED", res.stdout)
        self.assertTrue(target.is_file())


if __name__ == "__main__":
    unittest.main()
