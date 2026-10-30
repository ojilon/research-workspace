import os
import sys
import tempfile
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
sys.path.insert(0, TOOLS)
sys.path.insert(0, HERE)

import extract  # noqa: E402
import fixtures  # noqa: E402
import markers as mk  # noqa: E402
import revise_common as rc  # noqa: E402
import save_docx  # noqa: E402
import save_text  # noqa: E402


class SaveDocxTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name
        self.path = os.path.join(self.root, "summary.docx")
        self.markers = "# Cells\n\n**Mitochondria** make ATP.\n\n- one\n- two\n"

    def tearDown(self):
        self.tmp.cleanup()

    def extract_record(self):
        extract.extract_cached(self.root, self.path)

    def test_creates_then_saves(self):
        result = save_docx.save(self.root, self.path, self.markers)
        self.assertTrue(result["ok"], result)
        self.assertTrue(result["created"])
        data = extract.extract(self.path)
        self.assertEqual(
            [p["text"] for p in data["paragraphs"]],
            ["Cells", "", "Mitochondria make ATP.", "", "one", "two"],
        )
        self.assertEqual(data["paragraphs"][2]["markers"], "**Mitochondria** make ATP.")
        # A second save, with the cache recording the file.
        self.extract_record()
        result2 = save_docx.save(self.root, self.path, "# Cells\n\nChanged text.\n")
        self.assertTrue(result2["ok"], result2)
        self.assertFalse(result2["created"])
        self.assertIsNotNone(result2["backup"])
        self.assertTrue(os.path.exists(result2["backup"]))
        self.assertEqual(extract.extract(self.path)["paragraphs"][2]["text"], "Changed text.")

    def test_conflict_when_file_changes(self):
        save_docx.save(self.root, self.path, self.markers)
        self.extract_record()
        time.sleep(0.01)
        with open(self.path, "ab") as f:  # something else wrote to it
            f.write(b"")
        os.utime(self.path, (time.time() + 5, time.time() + 5))
        before = rc.sha256_file(self.path)
        result = save_docx.save(self.root, self.path, "# Different\n")
        self.assertTrue(result.get("conflict"))
        self.assertEqual(rc.sha256_file(self.path), before)
        self.assertFalse(os.path.exists(os.path.join(self.root, ".revise", "backups")))

    def test_overwrite_flag_goes_ahead(self):
        save_docx.save(self.root, self.path, self.markers)
        self.extract_record()
        with open(self.path, "ab") as f:
            f.write(b"")
        os.utime(self.path, (time.time() + 5, time.time() + 5))
        result = save_docx.save(self.root, self.path, "# Forced\n", overwrite=True)
        self.assertTrue(result["ok"], result)
        self.assertEqual(extract.extract(self.path)["paragraphs"][0]["text"], "Forced")

    def test_verify_failure_keeps_original(self):
        save_docx.save(self.root, self.path, self.markers)
        self.extract_record()
        before = rc.sha256_file(self.path)
        original = save_docx.write_docx
        try:
            save_docx.write_docx = lambda path, text: original(path, "")  # writes nothing
            result = save_docx.save(self.root, self.path, "# Lost\n")
        finally:
            save_docx.write_docx = original
        self.assertEqual(result.get("error"), "verify failed")
        self.assertEqual(rc.sha256_file(self.path), before)

    def test_round_trip_of_markers(self):
        lines = [
            mk.paragraph_marker("Heading 2", [("Steps", False, False)]),
            mk.runs_to_markers([("plain ", False, False), ("bold", True, False)]),
            mk.runs_to_markers([("lit * star", False, False)]),
        ]
        result = save_docx.save(self.root, os.path.join(self.root, "rt.docx"), "\n".join(lines))
        self.assertTrue(result["ok"], result)
        back = extract.extract(os.path.join(self.root, "rt.docx"))
        self.assertEqual([p["markers"] for p in back["paragraphs"]], lines)
        self.assertEqual(back["paragraphs"][1]["style"], "Normal")
        self.assertEqual(back["paragraphs"][2]["text"], "lit * star")


class SaveTextTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = self.tmp.name
        self.path = os.path.join(self.root, "notes.md")
        fixtures.make_text(self.path, "# Old\n")

    def tearDown(self):
        self.tmp.cleanup()

    def test_saves_and_backs_up(self):
        extract.extract_cached(self.root, self.path)
        result = save_text.save(self.root, self.path, "# New\n\n- item\n")
        self.assertTrue(result["ok"], result)
        with open(self.path, encoding="utf-8") as f:
            self.assertEqual(f.read(), "# New\n\n- item\n")
        self.assertTrue(os.path.exists(result["backup"]))
        self.assertEqual(extract.extract(self.path)["paragraphs"][0]["text"], "New")

    def test_conflict(self):
        extract.extract_cached(self.root, self.path)
        with open(self.path, "a", encoding="utf-8") as f:
            f.write("other\n")
        os.utime(self.path, (time.time() + 5, time.time() + 5))
        result = save_text.save(self.root, self.path, "mine\n")
        self.assertTrue(result.get("conflict"))

    def test_creates_missing_file(self):
        new = os.path.join(self.root, "made.md")
        result = save_text.save(self.root, new, "hello\n")
        self.assertTrue(result["ok"], result)
        self.assertTrue(result["created"])
        self.assertTrue(os.path.exists(new))


if __name__ == "__main__":
    unittest.main()
