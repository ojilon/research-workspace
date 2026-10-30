import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import markers as mk  # noqa: E402


class RunsTests(unittest.TestCase):
    def test_round_trip_simple(self):
        runs = [("Plain ", False, False), ("bold", True, False), (" tail", False, False)]
        text = mk.runs_to_markers(runs)
        self.assertEqual(text, "Plain **bold** tail")
        self.assertEqual(mk.markers_to_runs(text), runs)

    def test_italic_and_space_handling(self):
        runs = [("Anaerobic", False, True), (" respiration", False, False)]
        self.assertEqual(mk.runs_to_markers(runs), "*Anaerobic* respiration")
        self.assertEqual(mk.markers_to_runs("*Anaerobic* respiration"), runs)

    def test_asterisk_escaped(self):
        runs = [("2 * 3 = 6", False, False)]
        text = mk.runs_to_markers(runs)
        self.assertEqual(text, "2 \\* 3 = 6")
        self.assertEqual(mk.markers_to_runs(text), runs)

    def test_backslash_escaped(self):
        runs = [("C:\\notes", False, False)]
        text = mk.runs_to_markers(runs)
        self.assertEqual(mk.markers_to_runs(text), runs)

    def test_unbalanced_marker_is_text(self):
        self.assertEqual(mk.markers_to_runs("* lone star"), [("* lone star", False, False)])

    def test_bold_marker_inside_plain(self):
        runs = [("x", False, False), ("y", True, False), ("z", False, False)]
        self.assertEqual(mk.markers_to_runs(mk.runs_to_markers(runs)), runs)


class StyleTests(unittest.TestCase):
    def test_heading_prefix(self):
        text = mk.paragraph_marker("Heading 1", [("Title", False, False)])
        self.assertEqual(text, "# Title")
        style, runs = mk.marker_paragraph(text)
        self.assertEqual(style, "Heading 1")
        self.assertEqual("".join(r[0] for r in runs), "Title")

    def test_heading_two_and_bullet(self):
        self.assertEqual(mk.paragraph_marker("Heading 2", [("A", False, False)]), "## A")
        self.assertEqual(mk.paragraph_marker("List Bullet", [("A", False, False)]), "- A")

    def test_hash_in_text_is_escaped(self):
        text = mk.paragraph_marker("Normal", [("# 1 hit", False, False)])
        self.assertTrue(text.startswith("\\#"))
        style, runs = mk.marker_paragraph(text)
        self.assertEqual(style, "Normal")
        self.assertEqual("".join(r[0] for r in runs), "# 1 hit")

    def test_bare_bullet_line_stays_normal(self):
        style, runs = mk.marker_paragraph("- dash start")
        self.assertEqual(style, "List Bullet")
        style2, runs2 = mk.marker_paragraph("\\- dash start")
        self.assertEqual(style2, "Normal")
        self.assertEqual(runs2, [("- dash start", False, False)])

    def test_paragraphs_trim_trailing_blank(self):
        paras = mk.markers_to_paragraphs("# H\n\ntext\n")
        self.assertEqual([p["style"] for p in paras], ["Heading 1", "Normal", "Normal"])
        self.assertEqual([p["text"] for p in paras], ["H", "", "text"])


if __name__ == "__main__":
    unittest.main()
