import sys
import unittest
from pathlib import Path

# Add scripts directory to sys.path
SCRIPTS_DIR = Path(__file__).resolve().parent.parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from lib.formatter import detect_fix_categories, format_text


class TestFormatter(unittest.TestCase):
    def test_reorders_keys_and_strips_quotes(self):
        text = (
            "---\n"
            'description: "Unordered and quoted"\n'
            'name: "My Artifact"\n'
            'id: "my-artifact"\n'
            'type: "tool"\n'
            "---\n\n"
            "# My Artifact\n"
        )
        formatted = format_text(text)
        expected = (
            "---\n"
            "id: my-artifact\n"
            "name: My Artifact\n"
            "type: tool\n"
            "description: Unordered and quoted\n"
            "---\n\n"
            "# My Artifact\n"
        )
        self.assertEqual(formatted, expected)

    def test_removes_blank_lines_in_frontmatter(self):
        text = (
            "---\n"
            "id: blank-lines\n"
            "\n"
            "name: Blank Lines\n"
            "\n\n"
            "type: standard\n"
            "description: Test blank lines\n"
            "---\n\n"
            "# Content\n"
        )
        formatted = format_text(text)
        self.assertNotIn("\n\nname:", formatted)
        self.assertNotIn("\n\ntype:", formatted)
        self.assertTrue(formatted.startswith("---\nid: blank-lines\nname: Blank Lines\n"))

    def test_strips_trailing_whitespace_whole_document(self):
        text = (
            "---\n"
            "id: trailing-spaces   \n"
            "name: Trailing Spaces\t\n"
            "type: profile\n"
            "description: Test trailing whitespace.  \n"
            "---\n\n"
            "# Heading with spaces   \n\n"
            "Paragraph with trailing tabs.\t\t\n"
        )
        formatted = format_text(text)
        for line in formatted.splitlines():
            self.assertEqual(line, line.rstrip(" \t"))

    def test_preserves_content_inside_code_fences(self):
        text = (
            "---\n"
            "id: code-fence-test\n"
            "name: Code Fence Test\n"
            "type: tool\n"
            "description: Testing code fence preservation.\n"
            "---\n\n"
            "# Title   \n\n"
            "```python\n"
            "def untouched_func():  \n"
            "    # Line with spaces   \n"
            "    pass   \n"
            "```\n\n"
            "Outside code fence line.   \n"
        )
        formatted = format_text(text)
        # Outside heading and paragraph stripped:
        self.assertIn("# Title\n", formatted)
        self.assertIn("Outside code fence line.\n", formatted)
        # Inside code fence preserved verbatim:
        self.assertIn("def untouched_func():  \n", formatted)
        self.assertIn("    # Line with spaces   \n", formatted)
        self.assertIn("    pass   \n", formatted)

    def test_idempotency(self):
        sample = (
            "---\n"
            'description: "Quoted description: here"\n'
            "status: draft\n"
            "name: Sample Name\n"
            "type: workflow\n"
            "id: sample-art\n"
            "---\n\n"
            "# Sample Name\n\n"
            "Paragraph one.   \n\n"
            "```bash\n"
            "echo 'inside code'   \n"
            "```\n\n"
            "Final line.  \n\n\n"
        )
        run_1 = format_text(sample)
        run_2 = format_text(run_1)
        self.assertEqual(run_1, run_2)

    def test_unparseable_leaves_file_untouched(self):
        # Missing opening delimiter
        no_opening = "id: bad\nname: Bad\n---\n# Bad\n"
        self.assertEqual(format_text(no_opening), no_opening)

        # Duplicate keys
        dup_keys = (
            "---\n"
            "id: dup\n"
            "name: Dup 1\n"
            "type: tool\n"
            "name: Dup 2\n"
            "description: Desc\n"
            "---\n"
        )
        self.assertEqual(format_text(dup_keys), dup_keys)

    def test_detect_fix_categories(self):
        old = (
            "---\n"
            'name: "Quoted Name"\n'
            "id: test-cat\n"
            "type: tool\n"
            "\n"
            "description: Desc\n"
            "---\n\n"
            "# Heading  \n"
        )
        new = format_text(old)
        categories = detect_fix_categories(old, new)
        self.assertIn("key_order", categories)
        self.assertIn("redundant_quotes", categories)
        self.assertIn("blank_lines_frontmatter", categories)
        self.assertIn("trailing_whitespace", categories)

    def test_sources_array_no_false_positive_quotes_required(self):
        """Regression test: artifact with valid sources array yields no changes and format --check exits 0."""
        import subprocess
        import tempfile

        artifact = (
            "---\n"
            "id: test-sources-regression\n"
            "name: Test Sources Regression\n"
            "type: standard\n"
            "description: Regression test for sources array quoting.\n"
            'sources: ["https://example.org/x"]\n'
            "---\n\n"
            "# Test Sources Regression\n\n"
            "## Context\n\n"
            "Context here.\n\n"
            "## Mechanism\n\n"
            "Mechanism here.\n\n"
            "## Rules\n\n"
            "- **DO** keep valid sources unchanged.\n"
        )
        formatted = format_text(artifact)
        self.assertEqual(formatted, artifact)
        self.assertEqual(detect_fix_categories(artifact, formatted), [])

        with tempfile.TemporaryDirectory() as tmpdir:
            file_path = Path(tmpdir) / "test-sources-regression.md"
            file_path.write_text(artifact, encoding="utf-8")

            # format --check via CLI must exit 0
            proc = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPTS_DIR / "loka.py"),
                    "format",
                    "--check",
                    str(file_path),
                ],
                capture_output=True,
                text=True,
            )
            self.assertEqual(
                proc.returncode,
                0,
                f"format --check failed with code {proc.returncode}: {proc.stderr}",
            )
            self.assertIn("Files needing changes: 0", proc.stdout)

    def test_formatter_rejects_invalid_deprecated_and_sources(self):
        """Confirm format_file and format CLI reject invalid deprecated and sources without modifying files."""
        from lib.formatter import format_file
        import subprocess
        import tempfile

        test_cases = [
            ("bad-dep-nope", "deprecated: nope", "invalid_deprecated"),
            ("bad-dep-ture", "deprecated: ture", "invalid_deprecated"),
            ("bad-sources-nope", "sources: nope", "invalid_sources"),
            ("bad-sources-unquoted", "sources: [unquoted]", "invalid_sources"),
        ]

        for case_id, field_line, expected_code in test_cases:
            content = (
                "---\n"
                f"id: {case_id}\n"
                f"name: {case_id}\n"
                "type: standard\n"
                "description: Test rejection.\n"
                f"{field_line}\n"
                "---\n\n"
                f"# {case_id}\n"
            )

            # 1. format_text must leave content untouched
            self.assertEqual(format_text(content), content)

            with tempfile.TemporaryDirectory() as tmpdir:
                file_path = Path(tmpdir) / f"{case_id}.md"
                file_path.write_text(content, encoding="utf-8")

                # 2. format_file must not modify file and report problem
                changed, problems, categories = format_file(file_path)
                self.assertFalse(changed)
                self.assertTrue(any(p.code == expected_code for p in problems))
                self.assertEqual(file_path.read_text(encoding="utf-8"), content)

                # 3. CLI loka format must exit 1 and leave file unchanged
                proc = subprocess.run(
                    [sys.executable, str(SCRIPTS_DIR / "loka.py"), "format", str(file_path)],
                    capture_output=True,
                    text=True,
                )
                self.assertEqual(proc.returncode, 1)
                self.assertEqual(file_path.read_text(encoding="utf-8"), content)

                # 4. CLI loka format --check must exit 1
                proc_check = subprocess.run(
                    [sys.executable, str(SCRIPTS_DIR / "loka.py"), "format", "--check", str(file_path)],
                    capture_output=True,
                    text=True,
                )
                self.assertEqual(proc_check.returncode, 1)


if __name__ == "__main__":
    unittest.main()
