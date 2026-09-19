import sys
import tempfile
import unittest
from pathlib import Path

# Add scripts directory to sys.path
SCRIPTS_DIR = Path(__file__).resolve().parent.parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from lib.indexer import START_MARKER, END_MARKER, generate_index


class TestIndexer(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.vault = Path(self.temp_dir.name)
        # Create minimal index.md with markers
        self.index_file = self.vault / "index.md"
        self.index_file.write_text(
            f"# Test Vault Index\n\n{START_MARKER}\n{END_MARKER}\n",
            encoding="utf-8",
        )
        # Create canonical domain folders
        (self.vault / "profiles").mkdir()
        (self.vault / "tools").mkdir()

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_deterministic_generation(self):
        # Create two valid artifacts
        p1 = self.vault / "profiles" / "profile-b.md"
        p1.write_text(
            "---\n"
            "id: profile-b\n"
            "name: Profile B\n"
            "type: profile\n"
            "description: Second profile\n"
            "---\n",
            encoding="utf-8",
        )
        p2 = self.vault / "profiles" / "profile-a.md"
        p2.write_text(
            "---\n"
            "id: profile-a\n"
            "name: Profile A\n"
            "type: profile\n"
            "description: First profile\n"
            "---\n",
            encoding="utf-8",
        )

        exit_code, warnings = generate_index(self.vault)
        self.assertEqual(exit_code, 0)
        self.assertEqual(warnings, [])

        content = self.index_file.read_text(encoding="utf-8")
        self.assertIn("## Profiles", content)
        # Alphabetical / id-based ordering: profile-a before profile-b
        idx_a = content.find("[[profile-a|Profile A]]")
        idx_b = content.find("[[profile-b|Profile B]]")
        self.assertNotEqual(idx_a, -1)
        self.assertNotEqual(idx_b, -1)
        self.assertLess(idx_a, idx_b)

        # Idempotency check: second run produces identical content
        generate_index(self.vault)
        content_second = self.index_file.read_text(encoding="utf-8")
        self.assertEqual(content, content_second)

    def test_skips_unparseable_files_with_warning(self):
        bad = self.vault / "tools" / "broken-tool.md"
        bad.write_text(
            "no opening delimiter\nid: broken\n---\n",
            encoding="utf-8",
        )
        good = self.vault / "tools" / "good-tool.md"
        good.write_text(
            "---\n"
            "id: good-tool\n"
            "name: Good Tool\n"
            "type: tool\n"
            "description: A functioning tool\n"
            "---\n",
            encoding="utf-8",
        )

        # Default non-strict: exit code 0, returns warnings
        exit_code, warnings = generate_index(self.vault, strict=False)
        self.assertEqual(exit_code, 0)
        self.assertEqual(len(warnings), 1)

        content = self.index_file.read_text(encoding="utf-8")
        self.assertIn("[[good-tool|Good Tool]]", content)
        self.assertNotIn("broken-tool", content)

        # Strict mode: exit code 1
        exit_code_strict, _ = generate_index(self.vault, strict=True)
        self.assertEqual(exit_code_strict, 1)

    def test_names_missing_required_fields_in_warning(self):
        import io

        missing_file = self.vault / "profiles" / "missing-fields.md"
        missing_file.write_text(
            "---\n"
            "id: missing-fields\n"
            "name: Missing Fields\n"
            "---\n",
            encoding="utf-8",
        )
        captured_stderr = io.StringIO()
        old_stderr = sys.stderr
        try:
            sys.stderr = captured_stderr
            exit_code, warnings = generate_index(self.vault)
        finally:
            sys.stderr = old_stderr

        self.assertEqual(exit_code, 0)
        self.assertEqual(len(warnings), 1)
        self.assertIn("type, description", warnings[0])
        stderr_output = captured_stderr.getvalue()
        self.assertIn("missing required fields: type, description", stderr_output)

    def test_skips_semantically_invalid_artifacts_with_warning(self):
        import io

        (self.vault / "standards").mkdir(exist_ok=True)
        # Valid neighbor 1
        valid1 = self.vault / "standards" / "std-alpha.md"
        valid1.write_text(
            "---\n"
            "id: std-alpha\n"
            "name: Alpha Standard\n"
            "type: standard\n"
            "description: Valid alpha standard\n"
            "---\n",
            encoding="utf-8",
        )

        # 1. deprecated: nope
        bad_dep = self.vault / "standards" / "bad-dep.md"
        bad_dep.write_text(
            "---\n"
            "id: bad-dep\n"
            "name: Bad Dep\n"
            "type: standard\n"
            "description: Has invalid deprecated\n"
            "deprecated: nope\n"
            "---\n",
            encoding="utf-8",
        )

        # 2. sources: nope
        bad_sources_raw = self.vault / "standards" / "bad-sources-raw.md"
        bad_sources_raw.write_text(
            "---\n"
            "id: bad-sources-raw\n"
            "name: Bad Sources Raw\n"
            "type: standard\n"
            "description: Has invalid sources non-array\n"
            "sources: nope\n"
            "---\n",
            encoding="utf-8",
        )

        # 3. sources: [unquoted]
        bad_sources_unquoted = self.vault / "standards" / "bad-sources-unquoted.md"
        bad_sources_unquoted.write_text(
            "---\n"
            "id: bad-sources-unquoted\n"
            "name: Bad Sources Unquoted\n"
            "type: standard\n"
            "description: Has unquoted sources items\n"
            "sources: [unquoted]\n"
            "---\n",
            encoding="utf-8",
        )

        # 4. id != filename stem
        bad_stem = self.vault / "standards" / "bad-stem.md"
        bad_stem.write_text(
            "---\n"
            "id: mismatched-stem\n"
            "name: Bad Stem\n"
            "type: standard\n"
            "description: ID does not match stem\n"
            "---\n",
            encoding="utf-8",
        )

        # 5. invalid status
        bad_status = self.vault / "standards" / "bad-status.md"
        bad_status.write_text(
            "---\n"
            "id: bad-status\n"
            "name: Bad Status\n"
            "type: standard\n"
            "status: bogus\n"
            "description: Has invalid status\n"
            "---\n",
            encoding="utf-8",
        )

        # Valid neighbor 2
        valid2 = self.vault / "standards" / "std-omega.md"
        valid2.write_text(
            "---\n"
            "id: std-omega\n"
            "name: Omega Standard\n"
            "type: standard\n"
            "description: Valid omega standard\n"
            "---\n",
            encoding="utf-8",
        )

        captured_stderr = io.StringIO()
        old_stderr = sys.stderr
        try:
            sys.stderr = captured_stderr
            exit_code, warnings = generate_index(self.vault, strict=False)
        finally:
            sys.stderr = old_stderr

        # Non-strict mode: exit code 0
        self.assertEqual(exit_code, 0)
        self.assertEqual(len(warnings), 5)

        stderr_output = captured_stderr.getvalue()
        self.assertIn("bad-dep.md in index: Invalid deprecated 'nope'", stderr_output)
        self.assertIn("bad-sources-raw.md in index: Invalid sources 'nope'", stderr_output)
        self.assertIn("bad-sources-unquoted.md in index: Invalid sources '[unquoted]'", stderr_output)
        self.assertIn("bad-stem.md in index: ID 'mismatched-stem' does not match filename stem 'bad-stem'", stderr_output)
        self.assertIn("bad-status.md in index: Invalid status 'bogus'", stderr_output)

        # Valid neighbours still indexed
        content = self.index_file.read_text(encoding="utf-8")
        self.assertIn("[[std-alpha|Alpha Standard]]", content)
        self.assertIn("[[std-omega|Omega Standard]]", content)

        # Invalid entries excluded from index
        self.assertNotIn("bad-dep", content)
        self.assertNotIn("bad-sources-raw", content)
        self.assertNotIn("bad-sources-unquoted", content)
        self.assertNotIn("mismatched-stem", content)
        self.assertNotIn("bad-status", content)

        # Strict mode: exit code 1
        exit_code_strict, warnings_strict = generate_index(self.vault, strict=True)
        self.assertEqual(exit_code_strict, 1)
        self.assertEqual(len(warnings_strict), 5)


if __name__ == "__main__":
    unittest.main()
