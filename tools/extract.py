#!/usr/bin/env python3
"""Extracts a PDF, DOCX, Markdown or text document to the revise JSON form.

    extract.py PATH [--root DIR] [--out FILE] [--no-cache]

Prints one JSON object:

    {"schema_version":1,
     "source":{"path":..., "kind":"pdf|docx|text", "size":N, "mtime":N, "sha256":"..."},
     "pages":[{"n":1,"blocks":[{"id":"p1b1","text":"...","bbox":[x0,y0,x1,y1]}]}],   # pdf
     "paragraphs":[{"id":"d1","style":"Heading 1|Heading 2|Normal|List Bullet",
                    "text":"...", "markers":"# ..."}]}                            # docx/text

The same document is written to <root>/.revise/cache/<sha1-of-path>.json, so
the app does not extract it again on the next open.  The module's functions
are imported by db.py, which indexes the same extraction.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import markers as mk  # noqa: E402  (after sys.path)
import revise_common as rc  # noqa: E402

SCHEMA_VERSION = rc.SCHEMA_VERSION


# --- PDF -------------------------------------------------------------------


def _load_pymupdf():
    try:
        import pymupdf  # noqa: PLC0415 - optional at import time

        return pymupdf
    except ImportError:
        try:
            import fitz  # type: ignore # noqa: PLC0415

            return fitz
        except ImportError:
            raise rc.ToolError(
                "PyMuPDF is not installed (pip install -r requirements.txt)"
            ) from None


def _clean_block(text: str) -> str:
    """Joins the lines of one PDF block: wrapped lines get a space, a
    hyphen at a line end joins the word."""
    out = []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        if out:
            if out[-1].endswith("-"):
                out[-1] = out[-1][:-1] + line
                continue
            out.append(" " + line)
        else:
            out.append(line)
    return "".join(out).strip()


def extract_pdf(path: str) -> list[dict]:
    pymupdf = _load_pymupdf()
    pages = []
    try:
        doc = pymupdf.open(path)
    except Exception as e:  # noqa: BLE001
        raise rc.ToolError("not a readable PDF: %s" % e) from None
    try:
        if doc.needs_pass:
            raise rc.ToolError("the PDF is password protected")
        for index, page in enumerate(doc):
            blocks = []
            try:
                raw = page.get_text("blocks", sort=True)
            except Exception:  # noqa: BLE001 - an odd page is not fatal
                raw = []
            for b in raw:
                # (x0, y0, x1, y1, text, block_no, block_type): type 0 is text.
                if len(b) < 7 or b[6] != 0:
                    continue
                text = _clean_block(b[4] or "")
                if not text:
                    continue
                bbox = [round(float(v), 1) for v in b[0:4]]
                blocks.append(
                    {
                        "id": "p%db%d" % (index + 1, len(blocks) + 1),
                        "text": text,
                        "bbox": bbox,
                    }
                )
            pages.append({"n": index + 1, "blocks": blocks})
    finally:
        doc.close()
    return pages


# --- DOCX ------------------------------------------------------------------


def extract_docx(path: str) -> list[dict]:
    try:
        import docx  # noqa: PLC0415
    except ImportError:
        raise rc.ToolError(
            "python-docx is not installed (pip install -r requirements.txt)"
        ) from None
    try:
        document = docx.Document(path)
    except Exception as e:  # noqa: BLE001
        raise rc.ToolError("not a readable DOCX: %s" % e) from None

    paragraphs = []
    for p in document.paragraphs:
        style = "Normal"
        try:
            name = p.style.name if p.style is not None else None
        except Exception:  # noqa: BLE001
            name = None
        if name:
            if name in mk.STYLE_TO_PREFIX:
                style = name
            elif name.lower().startswith("heading"):
                digits = "".join(ch for ch in name if ch.isdigit())
                level = int(digits) if digits else 1
                style = "Heading %d" % max(1, min(level, 3))
        runs = []
        for r in p.runs:
            text = r.text or ""
            if not text:
                continue
            runs.append((text, bool(r.bold), bool(r.italic)))
        text = "".join(r[0] for r in runs)
        paragraphs.append(
            {
                "id": "d%d" % (len(paragraphs) + 1),
                "style": style,
                "text": text,
                "markers": mk.paragraph_marker(style, runs),
            }
        )
    return paragraphs


# --- Markdown / text -------------------------------------------------------


def extract_text_file(path: str) -> list[dict]:
    """A text file read as marker form: its own lines are the paragraphs."""
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        lines = f.read().split("\n")
    while lines and lines[-1] == "":
        lines.pop()
    paragraphs = []
    for line in lines:
        style, runs = mk.marker_paragraph(line)
        paragraphs.append(
            {
                "id": "d%d" % (len(paragraphs) + 1),
                "style": style,
                "text": "".join(r[0] for r in runs),
                "markers": line,
            }
        )
    return paragraphs


# --- one document ----------------------------------------------------------


def extract(path: str) -> dict:
    path = rc.abspath(path)
    if not os.path.exists(path):
        raise rc.ToolError("not found: %s" % path)
    kind = rc.kind_of(path)
    out = {"schema_version": SCHEMA_VERSION, "source": rc.file_info(path)}
    out["source"]["kind"] = kind
    if kind == "pdf":
        out["pages"] = extract_pdf(path)
    elif kind == "docx":
        out["paragraphs"] = extract_docx(path)
    else:
        out["paragraphs"] = extract_text_file(path)
    return out


def cached(root: str | None, path: str) -> dict | None:
    """The cached extraction, if it matches the file on disk."""
    if not root:
        return None
    data = rc.read_json(rc.cache_path(root, path))
    if not data or data.get("schema_version") != SCHEMA_VERSION:
        return None
    try:
        info = rc.file_info(path)
    except OSError:
        return None
    src = data.get("source") or {}
    if (
        src.get("sha256") == info["sha256"]
        and src.get("size") == info["size"]
        and src.get("mtime") == info["mtime"]
    ):
        return data
    return None


def extract_cached(root: str | None, path: str) -> dict:
    """Cached when it is still true, extracted and cached otherwise."""
    hit = cached(root, path)
    if hit is not None:
        return hit
    data = extract(path)
    if root:
        rc.write_json(rc.cache_path(root, path), data)
    return data


def main(argv: list[str]) -> dict:
    root = rc.take_option(argv, "--root")
    no_cache = rc.take_flag(argv, "--no-cache")
    if not argv:
        raise rc.ToolError("usage: extract.py PATH [--root DIR]")
    path = argv[0]
    if no_cache:
        data = extract(path)
        data["cached"] = False
        return data
    hit = cached(root, path)
    if hit is not None:
        hit["cached"] = True
        return hit
    data = extract(path)
    data["cached"] = False
    if root:
        rc.write_json(rc.cache_path(root, path), data)
    return data


if __name__ == "__main__":
    rc.run(main)
