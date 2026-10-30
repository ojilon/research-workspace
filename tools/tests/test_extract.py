import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
sys.path.insert(0, TOOLS)
sys.path.insert(0, HERE)

import extract  # noqa: E402
import fixtures  # noqa: E402
import revise_common as rc  # noqa: E402


class ExtractTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = self.tmp.name
        fixtures.workspace(self.dir)

    def tearDown(self):
        self.tmp.cleanup()

    def test_docx_paragraphs(self):
        data = extract.extract(os.path.join(self.dir, "biology.docx"))
        self.assertEqual(data["schema_version"], 1)
        self.assertEqual(data["source"]["kind"], "docx")
        self.assertGreater(data["source"]["size"], 0)
        self.assertEqual(len(data["source"]["sha256"]), 64)
        paragraphs = data["paragraphs"]
        self.assertEqual(paragraphs[0]["style"], "Heading 1")
        self.assertEqual(paragraphs[0]["text"], "Cell biology")
        self.assertEqual(paragraphs[0]["markers"], "# Cell biology")
        self.assertEqual(paragraphs[1]["text"], "Mitochondria make ATP by oxidative phosphorylation.")
        self.assertEqual(
            paragraphs[1]["markers"], "**Mitochondria** make ATP by oxidative phosphorylation."
        )
        self.assertEqual(paragraphs[2]["style"], "Heading 2")
        self.assertEqual(paragraphs[3]["style"], "List Bullet")
        self.assertEqual(paragraphs[5]["text"], "")
        self.assertEqual(paragraphs[6]["text"], "End of notes.")

    def test_pdf_pages_and_blocks(self):
        data = extract.extract(os.path.join(self.dir, "past-paper.pdf"))
        self.assertEqual(data["source"]["kind"], "pdf")
        self.assertEqual([p["n"] for p in data["pages"]], [1, 2])
        blocks = data["pages"][0]["blocks"]
        self.assertGreaterEqual(len(blocks), 2)
        self.assertEqual(blocks[0]["id"], "p1b1")
        self.assertIn("Page one heading", blocks[0]["text"])
        bbox = blocks[0]["bbox"]
        self.assertEqual(len(bbox), 4)
        self.assertLess(bbox[1], bbox[3])
        # Reading order: the first block is above the second on the page.
        self.assertLess(blocks[0]["bbox"][1], blocks[-1]["bbox"][1])
        self.assertIn("enzymes", data["pages"][1]["blocks"][0]["text"])

    def test_text_file(self):
        data = extract.extract(os.path.join(self.dir, "plan.md"))
        self.assertEqual(data["source"]["kind"], "text")
        self.assertEqual(data["paragraphs"][0]["style"], "Heading 1")
        self.assertEqual(data["paragraphs"][2]["markers"], "- Read chapter 3")

    def test_cache_is_used_and_invalidated(self):
        path = os.path.join(self.dir, "notes.txt")
        first = extract.extract_cached(self.dir, path)
        cache_file = rc.cache_path(self.dir, path)
        self.assertTrue(os.path.exists(cache_file))
        second = extract.extract_cached(self.dir, path)
        self.assertEqual(first["source"]["sha256"], second["source"]["sha256"])
        # Changing the file makes the cache stale.
        with open(path, "a", encoding="utf-8") as f:
            f.write("More.\n")
        third = extract.extract_cached(self.dir, path)
        self.assertNotEqual(third["source"]["sha256"], first["source"]["sha256"])

    def test_corrupt_input_fails_cleanly(self):
        bad = os.path.join(self.dir, "bad.pdf")
        with open(bad, "wb") as f:
            f.write(b"not a pdf at all")
        with self.assertRaises(rc.ToolError):
            extract.extract(bad)

    def test_cli_prints_one_json_object(self):
        out = subprocess.run(
            [sys.executable, os.path.join(TOOLS, "extract.py"), os.path.join(self.dir, "plan.md")],
            capture_output=True,
            text=True,
            check=True,
        )
        data = json.loads(out.stdout)
        self.assertEqual(data["schema_version"], 1)
        self.assertEqual(out.stderr, "")

    def test_cli_error_is_json_and_nonzero(self):
        out = subprocess.run(
            [sys.executable, os.path.join(TOOLS, "extract.py"), os.path.join(self.dir, "nope.md")],
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(out.returncode, 0)
        self.assertIn("error", json.loads(out.stdout))


if __name__ == "__main__":
    unittest.main()
