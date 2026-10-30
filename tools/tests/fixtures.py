"""Generates the test documents. No hand-made binaries: every fixture is
built here, by python-docx and PyMuPDF, into a temporary directory."""

from __future__ import annotations

import os

import docx
import pymupdf


def make_docx(path: str, title: str = "Cell biology") -> str:
    d = docx.Document()
    d.add_paragraph(title, style="Heading 1")
    p = d.add_paragraph()
    run = p.add_run("Mitochondria ")
    run.bold = True
    p.add_run("make ATP by oxidative phosphorylation.")
    d.add_paragraph("Glycolysis happens in the cytoplasm.", style="Heading 2")
    d.add_paragraph("Glucose to pyruvate", style="List Bullet")
    q = d.add_paragraph()
    q.add_run("Anaerobic").italic = True
    q.add_run(" respiration yields lactate.")
    d.add_paragraph("")
    d.add_paragraph("End of notes.")
    d.save(path)
    return path


def make_pdf(path: str) -> str:
    doc = pymupdf.open()
    page = doc.new_page()
    page.insert_text((72, 72), "Page one heading", fontsize=14)
    page.insert_text((72, 110), "The first paragraph of the exam notes.", fontsize=10)
    page.insert_text((72, 150), "A second paragraph lower down.", fontsize=10)
    page2 = doc.new_page()
    page2.insert_text((72, 72), "Page two text about enzymes.", fontsize=10)
    doc.save(path)
    doc.close()
    return path


def make_text(path: str, body: str = "# Revision plan\n\n- Read chapter 3\n- Do past paper\n") -> str:
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(body)
    return path


def workspace(tmp: str) -> str:
    """A small folder of fixtures: a docx, a pdf, a markdown file."""
    os.makedirs(tmp, exist_ok=True)
    make_docx(os.path.join(tmp, "biology.docx"))
    make_pdf(os.path.join(tmp, "past-paper.pdf"))
    make_text(os.path.join(tmp, "plan.md"))
    make_text(os.path.join(tmp, "notes.txt"), "Enzymes lower activation energy.\n")
    return tmp
