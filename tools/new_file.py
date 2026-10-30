#!/usr/bin/env python3
"""Creates an empty document of a kind revise can edit.

    new_file.py --root DIR --path DIR/NAME (--kind md|txt|docx | by extension)

A DOCX starts with one Heading 1 holding the file's name, so the summary it
becomes is not blank; Markdown and text files start empty.  Refuses to
overwrite: creation is what this tool does.
"""

from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import markers as mk  # noqa: E402
import revise_common as rc  # noqa: E402
import save_docx  # noqa: E402

KINDS = {"md": ".md", "markdown": ".md", "txt": ".txt", "docx": ".docx"}


def main(argv: list[str]) -> dict:
    root = rc.take_option(argv, "--root")
    path = rc.take_option(argv, "--path")
    kind = rc.take_option(argv, "--kind")
    if not path:
        raise rc.ToolError("usage: new_file.py --path FILE [--root DIR] [--kind md|txt|docx]")
    path = rc.abspath(path)
    if kind:
        ext = KINDS.get(kind.lower())
        if not ext:
            raise rc.ToolError("unknown kind: %s" % kind)
        if not os.path.splitext(path)[1]:
            path += ext
    ext = os.path.splitext(path)[1].lower()
    if ext not in (".md", ".txt", ".docx"):
        raise rc.ToolError("a new file must be .md, .txt or .docx")
    if os.path.exists(path):
        raise rc.ToolError("already exists: %s" % os.path.basename(path))

    title = os.path.splitext(os.path.basename(path))[0]
    if ext == ".docx":
        saved = save_docx.save(root, path, mk.paragraph_marker("Heading 1", [(title, False, False)]))
        if saved.get("error"):
            return saved
    else:
        rc.ensure_dir(os.path.dirname(path) or ".")
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write("")
    return {"ok": True, "path": path, "kind": rc.kind_of(path), "size": os.stat(path).st_size}


if __name__ == "__main__":
    rc.run(main)
