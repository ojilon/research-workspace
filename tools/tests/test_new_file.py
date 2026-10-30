import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
sys.path.insert(0, TOOLS)

import extract  # noqa: E402


def cli(*args):
    out = subprocess.run(
        [sys.executable, os.path.join(TOOLS, "new_file.py"), *args],
        capture_output=True,
        text=True,
    )
    return out.returncode, json.loads(out.stdout)


class NewFileTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def test_docx_starts_with_its_title(self):
        path = os.path.join(self.root, "cellular-respiration.docx")
        code, out = cli("--root", self.root, "--path", path)
        self.assertEqual(code, 0, out)
        self.assertTrue(out["ok"])
        data = extract.extract(path)
        self.assertEqual(data["paragraphs"][0]["style"], "Heading 1")
        self.assertEqual(data["paragraphs"][0]["text"], "cellular-respiration")

    def test_markdown_and_kind_extension(self):
        code, out = cli("--root", self.root, "--path", os.path.join(self.root, "notes"), "--kind", "md")
        self.assertEqual(code, 0, out)
        self.assertTrue(out["path"].endswith("notes.md"))
        self.assertEqual(os.path.getsize(out["path"]), 0)

    def test_refuses_to_overwrite(self):
        path = os.path.join(self.root, "taken.md")
        with open(path, "w", encoding="utf-8") as f:
            f.write("mine\n")
        code, out = cli("--root", self.root, "--path", path)
        self.assertNotEqual(code, 0)
        self.assertIn("already exists", out["error"])
        with open(path, encoding="utf-8") as f:
            self.assertEqual(f.read(), "mine\n")

    def test_refuses_other_extensions(self):
        code, out = cli("--root", self.root, "--path", os.path.join(self.root, "x.exe"))
        self.assertNotEqual(code, 0)
        self.assertIn("error", out)


if __name__ == "__main__":
    unittest.main()
