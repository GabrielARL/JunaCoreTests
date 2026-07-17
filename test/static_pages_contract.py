#!/usr/bin/env python3
"""Contract for the static JUNA Explorer GitHub Pages deployment."""

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
SOURCE = REPO / "docs" / "test_symbol_explorer.html"
BUILDER = REPO / "tools" / "build_static_pages.py"
WORKFLOW = REPO / ".github" / "workflows" / "pages.yml"
README = REPO / "README.md"
PAGES_URL = "https://gabrielarl.github.io/JunaCoreTests/"


class StaticPagesContract(unittest.TestCase):
    def test_builder_emits_an_offline_explorer_home_page(self):
        self.assertTrue(SOURCE.is_file())
        self.assertTrue(BUILDER.is_file())

        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            subprocess.run(
                [sys.executable, str(BUILDER), "--source", str(SOURCE), "--out-dir", str(output)],
                check=True,
            )

            index = output / "index.html"
            self.assertEqual(index.read_bytes(), SOURCE.read_bytes())
            self.assertTrue((output / ".nojekyll").is_file())

            html = index.read_text(encoding="utf-8")
            self.assertIn("DATA.served === true", html)
            self.assertNotIn('"served": true', html)
            self.assertIn("This is the static copy", html)

    def test_workflow_publishes_the_static_build_from_main(self):
        self.assertTrue(WORKFLOW.is_file())
        workflow = WORKFLOW.read_text(encoding="utf-8")

        for required in (
            "branches: [main]",
            "workflow_dispatch:",
            "pages: write",
            "id-token: write",
            "python3 tools/build_static_pages.py",
            "actions/configure-pages@v5",
            "actions/upload-pages-artifact@v4",
            "path: _site",
            "actions/deploy-pages@v4",
            "name: github-pages",
        ):
            self.assertIn(required, workflow)

    def test_repository_home_links_to_the_online_explorer(self):
        self.assertIn(PAGES_URL, README.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
