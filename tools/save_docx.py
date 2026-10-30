#!/usr/bin/env python3
"""Writes marker text back to a DOCX, safely.

    save_docx.py --root DIR --path SOURCE.docx --markers MARKERS.txt

The safety protocol, in this order:

  a) The file on disk is compared with the size/mtime/sha256 recorded when it
     was extracted (the cache JSON).  If they differ nothing is written and
     {"conflict":true} is printed, so the UI can ask Overwrite / Save a copy /
     Cancel.
  b) The original is copied to <root>/.revise/backups/<name>.<stamp>.docx.
  c) The new document is written to a temp file beside the original and
     extracted again; its paragraph texts must equal the ones the markers say,
     or the original stays and {"error":"verify failed"} is printed.
  d) Only then is the original replaced, and the cache's recorded source
     info updated to the new file.

No other code path may modify a source file.  Pass --overwrite to go ahead
after the UI's Overwrite choice, and --recorded-size/--recorded-mtime/
--recorded-sha256 to use the app's own record instead of the cache.
"""

from __future__ import annotations

import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import extract as ex  # noqa: E402
import markers as mk  # noqa: E402
import revise_common as rc  # noqa: E402


def recorded_info(root: str | None, path: str) -> dict | None:
    if not root:
        return None
    data = rc.read_json(rc.cache_path(root, path))
    if not data:
        return None
    return data.get("source")


def same_source(record: dict, actual: dict) -> bool:
    return (
        record.get("size") == actual.get("size")
        and record.get("mtime") == actual.get("mtime")
        and record.get("sha256") == actual.get("sha256")
    )


# --- writing ---------------------------------------------------------------


def write_docx(path: str, marker_text: str) -> None:
    import docx  # noqa: PLC0415

    document = docx.Document()
    for para in mk.markers_to_paragraphs(marker_text):
        style = para["style"] if para["style"] in mk.MARKER_STYLES else "Normal"
        try:
            p = document.add_paragraph(style=style)
        except KeyError:  # a template without the style
            p = document.add_paragraph()
        for text, bold, italic in para["runs"]:
            if not text:
                continue
            run = p.add_run(text)
            if bold:
                run.bold = True
            if italic:
                run.italic = True
    document.save(path)


def plain_texts(paragraphs) -> list[str]:
    out = [p.get("text", "") for p in paragraphs]
    while out and out[-1] == "":
        out.pop()
    return out


def expected_texts(marker_text: str) -> list[str]:
    out = [p["text"] for p in mk.markers_to_paragraphs(marker_text)]
    while out and out[-1] == "":
        out.pop()
    return out


def save(
    root: str | None,
    path: str,
    marker_text: str,
    overwrite: bool = False,
    record: dict | None = None,
) -> dict:
    path = rc.abspath(path)
    created = not os.path.exists(path)
    if not created:
        actual = rc.file_info(path)
        recorded = record or recorded_info(root, path)
        if recorded and not overwrite and not same_source(recorded, actual):
            return {
                "conflict": True,
                "reason": "the file changed on disk since it was opened",
                "source": actual,
            }

    directory = os.path.dirname(path) or "."
    rc.ensure_dir(directory)
    backup = None
    if not created:
        backup = rc.backup_path(root, path) if root else path + ".bak"
        rc.copy_file(path, backup)

    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".revise-tmp-", suffix=".docx")
    os.close(fd)
    try:
        write_docx(tmp, marker_text)
        # c) verify: what the file says must be what the markers said.
        check = ex.extract(tmp)
        got = plain_texts(check.get("paragraphs", []))
        want = expected_texts(marker_text)
        if got != want:
            for i in range(min(len(got), len(want))):
                if got[i] != want[i]:
                    return {
                        "error": "verify failed",
                        "at": i,
                        "wrote": got[i][:200],
                        "expected": want[i][:200],
                    }
            return {
                "error": "verify failed",
                "paragraphs_written": len(got),
                "paragraphs_expected": len(want),
            }
        # d) replace, then record the new file.
        os.replace(tmp, path)
        tmp = None
    finally:
        if tmp and os.path.exists(tmp):
            try:
                os.unlink(tmp)
            except OSError:
                pass

    data = ex.extract(path)
    if root:
        rc.write_json(rc.cache_path(root, path), data)
    return {
        "ok": True,
        "path": path,
        "created": created,
        "backup": backup,
        "source": data["source"],
        "paragraphs": len(data.get("paragraphs", [])),
    }


def main(argv: list[str]) -> dict:
    root = rc.take_option(argv, "--root")
    path = rc.take_option(argv, "--path")
    marker_file = rc.take_option(argv, "--markers")
    overwrite = rc.take_flag(argv, "--overwrite")
    if not path or not marker_file:
        raise rc.ToolError(
            "usage: save_docx.py --path FILE.docx --markers FILE.txt [--root DIR] [--overwrite]"
        )
    marker_text = rc.read_text(marker_file)
    return save(root, path, marker_text, overwrite=overwrite)


if __name__ == "__main__":
    rc.run(main)
