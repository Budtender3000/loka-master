import sys
import unittest
from pathlib import Path

# Add scripts directory to sys.path
SCRIPTS_DIR = Path(__file__).resolve().parent.parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from lib.frontmatter import (
    CANONICAL_DOMAINS,
    CANONICAL_KEY_ORDER,
    CANONICAL_STATUSES,
    CANONICAL_TYPES,
    Frontmatter,
    check_semantics,
    domain_title,
    domain_to_type,
    parse,
    render,
    type_to_domain,
)


class TestFrontmatterParser(unittest.TestCase):
    def test_parse_valid_standard(self):
        text = (
            "---\n"
            "id: test-artifact\n"
            "name: Test Artifact\n"
            "type: profile\n"
            "status: active\n"
            "description: A standard test artifact.\n"
            "---\n\n"
            "# Test Artifact\n\n"
            "Body content.\n"
        )
        fm, body, problems = parse(text)
        self.assertEqual(problems, [])
        self.assertEqual(fm.get("id"), "test-artifact")
        self.assertEqual(fm.get("name"), "Test Artifact")
        self.assertEqual(fm.get("type"), "profile")
        self.assertEqual(fm.get("status"), "active")
        self.assertEqual(fm.get("description"), "A standard test artifact.")
        self.assertEqual(body, "\n# Test Artifact\n\nBody content.\n")
        self.assertEqual(fm.closing_line, 7)

    def test_keys_normalized_to_lowercase(self):
        text = (
            "---\n"
            "ID: my-id\n"
            "NAME: My Name\n"
            "TYPE: tool\n"
            "DESCRIPTION: Desc\n"
            "---\n"
        )
        fm, _, _ = parse(text)
        self.assertEqual(fm["id"], "my-id")
        self.assertEqual(fm["name"], "My Name")
        self.assertIn("id", fm)
        self.assertIn("name", fm)

    def test_tolerant_quotes(self):
        text = (
            "---\n"
            'id: "quoted-id"\n'
            "name: 'Single Quoted Name'\n"
            'type: "tool"\n'
            'description: "Quoted description."\n'
            "---\n"
        )
        fm, body, problems = parse(text)
        self.assertEqual(problems, [])
        self.assertEqual(fm.get("id"), "quoted-id")
        self.assertEqual(fm.get("name"), "Single Quoted Name")
        self.assertEqual(fm.get("type"), "tool")
        self.assertEqual(fm.get("description"), "Quoted description.")

    def test_tolerant_blank_lines_and_whitespace(self):
        text = (
            "---\n"
            "   id   :   spaced-id   \n"
            "\n"
            "name: Spaced Name\n"
            "\n\n"
            "type: standard\n"
            "description: Tolerates blank lines.\n"
            "---\n"
        )
        fm, body, problems = parse(text)
        self.assertEqual(problems, [])
        self.assertEqual(fm.get("id"), "spaced-id")
        self.assertEqual(fm.get("name"), "Spaced Name")
        self.assertEqual(fm.get("type"), "standard")

    def test_sources_inline_list(self):
        text = (
            "---\n"
            "id: sources-test\n"
            "name: Sources Test\n"
            "type: meta\n"
            "description: Test sources inline array.\n"
            "sources: [https://example.com/a, 'https://example.com/b', \"https://example.com/c\"]\n"
            "---\n"
        )
        fm, body, problems = parse(text)
        self.assertEqual(problems, [])
        self.assertEqual(
            fm.get("sources"),
            ["https://example.com/a", "https://example.com/b", "https://example.com/c"],
        )

    def test_missing_opening_delimiter(self):
        text = "id: no-delim\nname: No Delim\n---\n"
        fm, body, problems = parse(text)
        self.assertTrue(any(p.code == "missing_opening_delimiter" for p in problems))

    def test_missing_closing_delimiter(self):
        text = "---\nid: no-close\nname: No Close\n"
        fm, body, problems = parse(text)
        self.assertTrue(any(p.code == "missing_closing_delimiter" for p in problems))

    def test_duplicate_key(self):
        text = (
            "---\n"
            "id: dup-test\n"
            "name: Dup 1\n"
            "type: tool\n"
            "description: Dup key test.\n"
            "name: Dup 2\n"
            "---\n"
        )
        fm, body, problems = parse(text)
        self.assertTrue(any(p.code == "duplicate_key" for p in problems))

    def test_invalid_syntax_line(self):
        text = (
            "---\n"
            "id: syntax-test\n"
            "this is not valid yaml line\n"
            "name: Valid Name\n"
            "---\n"
        )
        fm, body, problems = parse(text)
        self.assertTrue(any(p.code == "invalid_syntax" for p in problems))

    def test_parse_invalid_deprecated_and_sources_kept_raw(self):
        text = (
            "---\n"
            "id: raw-test\n"
            "name: Raw Test\n"
            "type: standard\n"
            "description: Desc\n"
            "deprecated: nope\n"
            "sources: nope\n"
            "---\n"
        )
        fm, body, problems = parse(text)
        codes = [p.code for p in problems]
        self.assertIn("invalid_deprecated", codes)
        self.assertIn("invalid_sources", codes)
        self.assertEqual(fm.get("deprecated"), "nope")
        self.assertEqual(fm.get("sources"), "nope")
        rendered = render(fm)
        self.assertIn("deprecated: nope\n", rendered)
        self.assertIn("sources: nope\n", rendered)


class TestFrontmatterRenderer(unittest.TestCase):
    def test_canonical_key_order(self):
        # Pass unordered keys
        fm = Frontmatter(
            {
                "description": "Desc first",
                "status": "draft",
                "name": "Name second",
                "type": "workflow",
                "id": "canon-test",
            }
        )
        rendered = render(fm)
        lines = [line for line in rendered.splitlines() if line != "---"]
        keys = [line.split(":")[0] for line in lines]
        self.assertEqual(keys, ["id", "name", "type", "status", "description"])

    def test_no_quotes_unless_required(self):
        fm = Frontmatter(
            {
                "id": "no-quotes",
                "name": "Simple Name",
                "type": "tool",
                "description": "Simple description without colons or brackets.",
            }
        )
        rendered = render(fm)
        self.assertIn("name: Simple Name\n", rendered)
        self.assertIn("description: Simple description without colons or brackets.\n", rendered)

    def test_quotes_when_required(self):
        fm = Frontmatter(
            {
                "id": "quotes-needed",
                "name": "Title: With Colon",
                "type": "tool",
                "description": "Contains [brackets] and : colon space.",
            }
        )
        rendered = render(fm)
        self.assertIn('name: "Title: With Colon"\n', rendered)
        self.assertIn('description: "Contains [brackets] and : colon space."\n', rendered)

    def test_sources_render(self):
        fm = Frontmatter(
            {
                "id": "sources-art",
                "name": "Sources Art",
                "type": "standard",
                "description": "Testing sources render",
                "sources": ["https://example.com/one", "https://example.com/two"],
            }
        )
        rendered = render(fm)
        self.assertIn(
            'sources: ["https://example.com/one", "https://example.com/two"]\n',
            rendered,
        )


class TestSemanticChecks(unittest.TestCase):
    def test_valid_artifact(self):
        fm = Frontmatter(
            {
                "id": "valid-id",
                "name": "Valid Name",
                "type": "profile",
                "status": "active",
                "description": "Valid desc.",
            }
        )
        problems = check_semantics(fm, Path("profiles/valid-id.md"))
        self.assertEqual(problems, [])

    def test_missing_required_fields(self):
        fm = Frontmatter({"id": "some-id"})
        problems = check_semantics(fm)
        codes = [p.code for p in problems]
        self.assertIn("missing_required_field", codes)

    def test_invalid_type_and_status(self):
        fm = Frontmatter(
            {
                "id": "bad-enums",
                "name": "Bad Enums",
                "type": "nonexistent_type",
                "status": "invalid_status",
                "description": "Testing bad enums.",
            }
        )
        problems = check_semantics(fm)
        codes = [p.code for p in problems]
        self.assertIn("invalid_type", codes)
        self.assertIn("invalid_status", codes)

    def test_kebab_case_and_stem_mismatch(self):
        fm = Frontmatter(
            {
                "id": "Bad_ID",
                "name": "Bad ID",
                "type": "profile",
                "description": "Testing bad ID.",
            }
        )
        problems = check_semantics(fm, Path("profiles/other-id.md"))
        codes = [p.code for p in problems]
        self.assertIn("invalid_id", codes)
        self.assertIn("id_stem_mismatch", codes)

    def test_type_domain_mismatch(self):
        fm = Frontmatter(
            {
                "id": "misplaced",
                "name": "Misplaced",
                "type": "tool",
                "description": "Tool placed in profiles folder.",
            }
        )
        problems = check_semantics(fm, Path("profiles/misplaced.md"))
        codes = [p.code for p in problems]
        self.assertIn("type_domain_mismatch", codes)

    def test_valid_and_invalid_date_fields(self):
        # Valid date fields
        fm_valid = Frontmatter(
            {
                "id": "valid-dates",
                "name": "Valid Dates",
                "type": "standard",
                "description": "Desc",
                "created": "2026-09-19",
                "stale_after": "2027-09-19",
            }
        )
        problems = check_semantics(fm_valid)
        codes = [p.code for p in problems]
        self.assertNotIn("invalid_date", codes)

        # Invalid format
        fm_bad_fmt = Frontmatter(
            {
                "id": "bad-date-fmt",
                "name": "Bad Date Format",
                "type": "standard",
                "description": "Desc",
                "created": "2026/09/19",
            }
        )
        problems = check_semantics(fm_bad_fmt)
        codes = [p.code for p in problems]
        self.assertIn("invalid_date", codes)

        # Invalid calendar date (2026-02-30)
        fm_impossible_date = Frontmatter(
            {
                "id": "impossible-date",
                "name": "Impossible Date",
                "type": "standard",
                "description": "Desc",
                "created": "2026-02-30",
            }
        )
        problems = check_semantics(fm_impossible_date)
        codes = [p.code for p in problems]
        self.assertIn("invalid_date", codes)

        # Invalid stale_after calendar date
        fm_bad_stale = Frontmatter(
            {
                "id": "bad-stale",
                "name": "Bad Stale",
                "type": "standard",
                "description": "Desc",
                "stale_after": "2026-13-45",
            }
        )
        problems = check_semantics(fm_bad_stale)
        codes = [p.code for p in problems]
        self.assertIn("invalid_date", codes)

    def test_valid_and_invalid_verified(self):
        for val in ("human", "attested", "automated"):
            fm = Frontmatter(
                {
                    "id": "valid-verified",
                    "name": "Valid Verified",
                    "type": "standard",
                    "description": "Desc",
                    "verified": val,
                }
            )
            problems = check_semantics(fm)
            codes = [p.code for p in problems]
            self.assertNotIn("invalid_verified", codes)

        fm_bad = Frontmatter(
            {
                "id": "bad-verified",
                "name": "Bad Verified",
                "type": "standard",
                "description": "Desc",
                "verified": "manual",
            }
        )
        problems = check_semantics(fm_bad)
        codes = [p.code for p in problems]
        self.assertIn("invalid_verified", codes)

    def test_valid_and_invalid_deprecated(self):
        for val in ("true", "false", True, False):
            fm = Frontmatter(
                {
                    "id": "valid-dep",
                    "name": "Valid Dep",
                    "type": "standard",
                    "description": "Desc",
                    "deprecated": val,
                }
            )
            problems = check_semantics(fm)
            codes = [p.code for p in problems]
            self.assertNotIn("invalid_deprecated", codes)

        for bad_val in ("nope", "ture", "1", "yes", "none"):
            fm_bad = Frontmatter(
                {
                    "id": "bad-dep",
                    "name": "Bad Dep",
                    "type": "standard",
                    "description": "Desc",
                    "deprecated": bad_val,
                }
            )
            problems = check_semantics(fm_bad)
            codes = [p.code for p in problems]
            self.assertIn("invalid_deprecated", codes)

    def test_valid_and_invalid_sources(self):
        fm_valid = Frontmatter(
            {
                "id": "valid-sources",
                "name": "Valid Sources",
                "type": "standard",
                "description": "Desc",
                "sources": ["https://example.com/a", "https://example.com/b"],
            }
        )
        problems = check_semantics(fm_valid)
        codes = [p.code for p in problems]
        self.assertNotIn("invalid_sources", codes)

        fm_empty = Frontmatter(
            {
                "id": "empty-sources",
                "name": "Empty Sources",
                "type": "standard",
                "description": "Desc",
                "sources": [],
            }
        )
        problems = check_semantics(fm_empty)
        codes = [p.code for p in problems]
        self.assertNotIn("invalid_sources", codes)

        fm_nope = Frontmatter(
            {
                "id": "nope-sources",
                "name": "Nope Sources",
                "type": "standard",
                "description": "Desc",
                "sources": "nope",
            }
        )
        problems = check_semantics(fm_nope)
        codes = [p.code for p in problems]
        self.assertIn("invalid_sources", codes)

        fm_unquoted = Frontmatter(
            {
                "id": "unquoted-sources",
                "name": "Unquoted Sources",
                "type": "standard",
                "description": "Desc",
                "sources": ["unquoted"],
            },
            raw_sources="[unquoted]",
        )
        problems = check_semantics(fm_unquoted)
        codes = [p.code for p in problems]
        self.assertIn("invalid_sources", codes)


class TestRoundTripEdgeCases(unittest.TestCase):
    """Verify format -> parse round-trips losslessly for all edge cases."""

    def _assert_roundtrip(self, key: str, value: str, should_be_quoted: bool):
        from lib.formatter import format_text

        fm = Frontmatter(
            {
                "id": "edge-case-test",
                "name": "Edge Case Test" if key != "name" else value,
                "type": "tool",
                "description": "Standard desc" if key != "description" else value,
            }
        )
        rendered = render(fm)

        # Verify quoting rule
        matching_lines = [line for line in rendered.splitlines() if line.startswith(f"{key}:")]
        self.assertEqual(len(matching_lines), 1)
        val_rendered = matching_lines[0].split(":", 1)[1].strip()

        if should_be_quoted:
            self.assertTrue(
                val_rendered.startswith('"') and val_rendered.endswith('"'),
                f"Expected {key} to be quoted, got: {val_rendered}",
            )
        else:
            self.assertFalse(
                val_rendered.startswith('"') and val_rendered.endswith('"'),
                f"Expected {key} to be UNQUOTED, got: {val_rendered}",
            )

        # parse(render(x)) == x
        parsed_fm, body, problems = parse(rendered)
        self.assertEqual(problems, [])
        self.assertEqual(parsed_fm.get(key), value)

        # Full document format -> parse round-trip
        full_doc = f"{rendered}\n# Title\n\nBody text.\n"
        formatted_doc = format_text(full_doc)
        parsed_fmt_fm, _, fmt_problems = parse(formatted_doc)
        self.assertEqual(fmt_problems, [])
        self.assertEqual(parsed_fmt_fm.get(key), value)

    def test_double_quotes(self):
        # Value containing double quotes and colon
        self._assert_roundtrip(
            "description", 'Uses "strict" mode: on', should_be_quoted=True
        )
        # Value containing double quotes without colon
        self._assert_roundtrip(
            "description", 'Says "hello" world', should_be_quoted=True
        )

    def test_single_quotes_apostrophe(self):
        # With colon: must be quoted because of colon
        self._assert_roundtrip(
            "description", "Timo's rule: keep it small", should_be_quoted=True
        )
        # Without colon: MUST NOT be quoted (rule: quote only when required!)
        self._assert_roundtrip("name", "Timo's rule", should_be_quoted=False)

    def test_starting_with_special_chars(self):
        special_chars = ["#", "[", "{", ">", "|", "*", "&", "!", "%", "@", "`"]
        for ch in special_chars:
            val = f"{ch} Special value with {ch}"
            self._assert_roundtrip("description", val, should_be_quoted=True)

    def test_ending_with_colon(self):
        self._assert_roundtrip("name", "Header section:", should_be_quoted=True)
        self._assert_roundtrip(
            "description", "Follow these rules:", should_be_quoted=True
        )

    def test_value_containing_space_hash(self):
        self._assert_roundtrip(
            "description", "Resolves issue #42", should_be_quoted=True
        )
        # Without space before hash: should NOT be quoted
        self._assert_roundtrip("name", "C# language", should_be_quoted=False)

    def test_leading_and_trailing_spaces(self):
        self._assert_roundtrip(
            "description", "  leading spaces", should_be_quoted=True
        )
        self._assert_roundtrip(
            "description", "trailing spaces  ", should_be_quoted=True
        )
        self._assert_roundtrip("name", "  both spaces  ", should_be_quoted=True)

    def test_empty_value(self):
        self._assert_roundtrip("description", "", should_be_quoted=True)


if __name__ == "__main__":
    unittest.main()
