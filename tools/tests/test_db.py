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

import db  # noqa: E402
import fixtures  # noqa: E402
import revise_common as rc  # noqa: E402


def cli(*args):
    out = subprocess.run(
        [sys.executable, os.path.join(TOOLS, "db.py"), *args],
        capture_output=True,
        text=True,
    )
    return out.returncode, json.loads(out.stdout)


class DbTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = fixtures.workspace(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_index_finds_all_files(self):
        code, out = cli("index", "--root", self.root)
        self.assertEqual(code, 0, out)
        indexed = {os.path.basename(item["path"]) for item in out["indexed"]}
        self.assertEqual(indexed, {"biology.docx", "past-paper.pdf", "plan.md", "notes.txt"})
        self.assertEqual(out["errors"], [])
        self.assertTrue(os.path.exists(rc.db_path(self.root)))

    def test_incremental_index_skips_unchanged(self):
        cli("index", "--root", self.root)
        code, out = cli("index", "--root", self.root)
        self.assertEqual(code, 0)
        self.assertEqual(out["indexed"], [])

    def test_search_finds_pdf_and_docx(self):
        cli("index", "--root", self.root)
        code, out = cli("search", "--root", self.root, "enzymes")
        self.assertEqual(code, 0, out)
        hits = {(os.path.basename(r["path"]), r["page"]) for r in out["results"]}
        self.assertIn(("past-paper.pdf", 2), hits)
        code, out = cli("search", "--root", self.root, "mitochondria")
        self.assertTrue(any(os.path.basename(r["path"]) == "biology.docx" for r in out["results"]))
        top = out["results"][0]
        self.assertIn("itochondria", top["snippet"])
        start, end = top["hit"]
        self.assertEqual(top["snippet"][start:end].lower(), "mitochondria")

    def test_snippet_is_one_line_around_the_hit(self):
        self.assertEqual(db._snippet("a\nb\nwater here\nmore", ["water"])[0].count("\n"), 0)
        snip, start, end = db._snippet("one\ntwo\nthree water four\nfive", ["water"])
        self.assertEqual(snip[start:end], "water")
        self.assertNotIn("\n", snip)

    def test_search_is_case_insensitive_and_multiword(self):
        cli("index", "--root", self.root)
        code, out = cli("search", "--root", self.root, "PAST PAPER")
        self.assertEqual(code, 0)

    def test_empty_query_returns_nothing(self):
        cli("index", "--root", self.root)
        code, out = cli("search", "--root", self.root, "   ")
        self.assertEqual(code, 0)
        self.assertEqual(out["results"], [])

    def test_linked_file_is_indexed_and_listed(self):
        outside = tempfile.TemporaryDirectory()
        self.addCleanup(outside.cleanup)
        path = fixtures.make_text(os.path.join(outside.name, "spec.md"), "Foreign spec about ribs.\n")
        code, out = cli("link", "--root", self.root, "--path", path, "--alias", "spec")
        self.assertEqual(code, 0, out)
        self.assertEqual(out["alias"], "spec")
        cli("index", "--root", self.root)
        code, out = cli("search", "--root", self.root, "ribs")
        self.assertTrue(any(r["path"] == rc.abspath(path) for r in out["results"]))
        code, out = cli("files", "--root", self.root)
        linked = [f for f in out["files"] if f["linked"]]
        self.assertEqual([os.path.basename(f["path"]) for f in linked], ["spec.md"])

    def test_highlights_add_list_and_update(self):
        code, out = cli(
            "hl-add", "--root", self.root, "--path", os.path.join(self.root, "biology.docx"),
            "--block", "d2", "--text", "Mitochondria", "--color", "yellow",
        )
        self.assertEqual(code, 0, out)
        hid = out["id"]
        code, out = cli("hl-list", "--root", self.root)
        self.assertEqual(len(out["highlights"]), 1)
        self.assertEqual(out["highlights"][0]["block_id"], "d2")
        # The same block again updates rather than duplicates.
        code, out = cli(
            "hl-add", "--root", self.root, "--path", os.path.join(self.root, "biology.docx"),
            "--block", "d2", "--text", "Mitochondria", "--color", "green",
        )
        self.assertEqual(out["id"], hid)
        code, out = cli("hl-list", "--root", self.root)
        self.assertEqual(len(out["highlights"]), 1)
        self.assertEqual(out["highlights"][0]["color"], "green")
        code, out = cli("hl-remove", "--root", self.root, "--id", str(hid))
        self.assertEqual(code, 0)
        code, out = cli("hl-list", "--root", self.root)
        self.assertEqual(out["highlights"], [])

    def test_missing_root_is_an_error(self):
        code, out = cli("search", "x")
        self.assertNotEqual(code, 0)
        self.assertIn("error", out)


class FallbackTests(unittest.TestCase):
    """The LIKE path when FTS5 is unavailable."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = fixtures.workspace(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_like_search_matches(self):
        database = db.connect(self.root)
        database.execute("DROP TABLE IF EXISTS fts")
        database.execute("CREATE TABLE fts(path TEXT, page INTEGER, text TEXT)")
        database.execute("INSERT OR REPLACE INTO meta(key, value) VALUES('fts5','0')")
        database.execute(
            "INSERT INTO fts(path, page, text) VALUES(?,?,?)",
            (os.path.join(self.root, "plan.md"), 1, "Revision plan with Enzymes and ATP"),
        )
        database.commit()
        database.close()
        code, out = cli("search", "--root", self.root, "enzymes")
        self.assertEqual(code, 0, out)
        self.assertFalse(out["fts5"])
        self.assertEqual(len(out["results"]), 1)
        self.assertIn("Enzymes", out["results"][0]["snippet"])


if __name__ == "__main__":
    unittest.main()
