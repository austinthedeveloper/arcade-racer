"""tools/changelog.py: a version's section for the release notes, and --json for the
what's new the export bundles (PR-17)."""
import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import changelog  # noqa: E402

TEXT = """# Changelog

## [Unreleased]

## [0.5.0] - 2026-12-01

### Added

- Photo key (PR-21): F12 saves a picture.

## [0.4.0] - 2026-11-02

### Fixed

- Something.
"""


class ChangelogTest(unittest.TestCase):
    def run_tool(self, *args):
        with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as f:
            f.write(TEXT)
        try:
            return subprocess.run([sys.executable, os.path.join(HERE, "changelog.py")] + list(args) + [f.name],
                                  capture_output=True, text=True)
        finally:
            os.unlink(f.name)

    def test_sections(self):
        self.assertEqual(changelog.notes(TEXT, "0.5.0"), "### Added\n\n- Photo key (PR-21): F12 saves a picture.")
        self.assertEqual(changelog.notes(TEXT, "0.5.0-beta"), changelog.notes(TEXT, "0.5.0"))
        self.assertIsNone(changelog.notes(TEXT, "0.6.0"))

    def test_plain_output(self):
        out = self.run_tool("0.4.0")
        self.assertEqual(out.returncode, 0)
        self.assertEqual(out.stdout.strip(), "### Fixed\n\n- Something.")

    def test_json_output_for_the_export(self):
        out = self.run_tool("--json", "v0.5.0")
        self.assertEqual(out.returncode, 0)
        data = json.loads(out.stdout)
        self.assertEqual(data, {"version": "0.5.0", "notes": changelog.notes(TEXT, "0.5.0")})

    def test_no_section_fails(self):
        self.assertEqual(self.run_tool("--json", "0.9.0").returncode, 1)


if __name__ == "__main__":
    unittest.main()
