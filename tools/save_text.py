#!/usr/bin/env python3
"""Writes marker text back to a Markdown or plain-text file, safely.

    save_text.py --root DIR --path NOTES.md --markers MARKERS.txt [--overwrite]

The same protocol as save_docx.py: compare the size/mtime/sha256 recorded at
extraction (conflict if they differ), copy the original into .revise/backups/,
write a temp file beside it and read it back (it must equal the markers byte
for byte), then replace the original and update the cache.
"""

from __future__ import annotations

import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import extract as ex  # noqa: E402
import revise_common as rc  # noqa: E402
from save_docx import recorded_info, same_source  # noqa: E402


def save(root: str | None, path: str, marker_text: str, overwrite: bool = False) -> dict:
    path = rc.abspath(path)
    created = not os.path.exists(path)
    if not created:
        actual = rc.file_info(path)
        recorded = recorded_info(root, path)
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

    # The file ends with one newline; the editor's trailing newline is not
    # significant, so the text is written as it is and read back with it.
    data = marker_text
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".revise-tmp-", suffix=".txt")
    os.close(fd)
    try:
        with open(tmp, "w", encoding="utf-8", newline="\n") as f:
            f.write(data)
        with open(tmp, "r", encoding="utf-8", newline="\n") as f:
            if f.read() != data:
                return {"error": "verify failed"}
        os.replace(tmp, path)
        tmp = None
    finally:
        if tmp and os.path.exists(tmp):
            try:
                os.unlink(tmp)
            except OSError:
                pass

    extracted = ex.extract(path)
    if root:
        rc.write_json(rc.cache_path(root, path), extracted)
    return {
        "ok": True,
        "path": path,
        "created": created,
        "backup": backup,
        "source": extracted["source"],
    }


def main(argv: list[str]) -> dict:
    root = rc.take_option(argv, "--root")
    path = rc.take_option(argv, "--path")
    marker_file = rc.take_option(argv, "--markers")
    overwrite = rc.take_flag(argv, "--overwrite")
    if not path or not marker_file:
        raise rc.ToolError(
            "usage: save_text.py --path FILE --markers FILE.txt [--root DIR] [--overwrite]"
        )
    return save(root, path, rc.read_text(marker_file), overwrite=overwrite)


if __name__ == "__main__":
    rc.run(main)
