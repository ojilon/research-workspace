"""Shared helpers for revise's Python tools.

Every tool in this directory is a one-shot command: it prints exactly one
JSON object to stdout (or writes it to the file named by --out) and exits
non-zero with {"error": "..."} when something went wrong.  Zig never parses
PDF, DOCX or SQLite itself; it calls these scripts.

Layout of a workspace (the folder open in the app):

    <root>/.revise/cache/<sha1-of-path>.json     extracted documents
    <root>/.revise/revise.db                     index, links, highlights
    <root>/.revise/backups/<name>.<stamp>.<ext>  copies made before a save
    <root>/.revise/summaries/<name>-summary.docx summaries kept out of the way
    <root>/.revise/tmp/                          scratch files
"""

from __future__ import annotations

import hashlib
import json
import os
import sys
import tempfile
import time

SCHEMA_VERSION = 1

KIND_BY_EXT = {
    ".pdf": "pdf",
    ".docx": "docx",
    ".md": "text",
    ".markdown": "text",
    ".txt": "text",
}

EDITABLE_EXTS = {".docx", ".md", ".markdown", ".txt"}


class ToolError(Exception):
    """An expected failure; becomes {"error": "..."} on stdout."""


def kind_of(path: str) -> str:
    ext = os.path.splitext(path)[1].lower()
    if ext not in KIND_BY_EXT:
        raise ToolError("unsupported file type: %s" % (ext or path))
    return KIND_BY_EXT[ext]


def abspath(path: str) -> str:
    return os.path.abspath(os.path.expanduser(path))


def norm(path: str) -> str:
    """A comparable identity for a path (absolute, case-folded on Windows)."""
    return os.path.normcase(os.path.abspath(path))


def cache_key(path: str) -> str:
    return hashlib.sha1(norm(path).encode("utf-8", "surrogateescape")).hexdigest()


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def file_info(path: str) -> dict:
    st = os.stat(path)
    return {
        "path": abspath(path),
        "kind": kind_of(path),
        "size": int(st.st_size),
        "mtime": int(st.st_mtime_ns),
        "sha256": sha256_file(path),
    }


# --- workspace layout -------------------------------------------------------


def revise_dir(root: str) -> str:
    return os.path.join(abspath(root), ".revise")


def cache_dir(root: str) -> str:
    return os.path.join(revise_dir(root), "cache")


def tmp_dir(root: str) -> str:
    return os.path.join(revise_dir(root), "tmp")


def backups_dir(root: str) -> str:
    return os.path.join(revise_dir(root), "backups")


def summaries_dir(root: str) -> str:
    return os.path.join(revise_dir(root), "summaries")


def db_path(root: str) -> str:
    return os.path.join(revise_dir(root), "revise.db")


def cache_path(root: str, path: str) -> str:
    return os.path.join(cache_dir(root), cache_key(path) + ".json")


def ensure_dir(path: str) -> str:
    os.makedirs(path, exist_ok=True)
    return path


def read_json(path: str):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return None
    except (OSError, ValueError):
        return None


def write_json(path: str, value) -> None:
    """Writes atomically: a reader never sees half a file."""
    ensure_dir(os.path.dirname(path))
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".tmp-", suffix=".json")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(value, f, ensure_ascii=False, indent=None, separators=(",", ":"))
            f.write("\n")
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def write_text_atomic(path: str, text: str) -> None:
    ensure_dir(os.path.dirname(path))
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".tmp-", suffix=".txt")
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def read_text(path: str) -> str:
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


def backup_path(root: str, path: str) -> str:
    """`.revise/backups/<name>.<timestamp>.<ext>` for `path`."""
    stamp = time.strftime("%Y%m%d-%H%M%S")
    name, ext = os.path.splitext(os.path.basename(path))
    d = ensure_dir(backups_dir(root))
    candidate = os.path.join(d, "%s.%s%s" % (name, stamp, ext))
    n = 1
    while os.path.exists(candidate):
        candidate = os.path.join(d, "%s.%s-%d%s" % (name, stamp, n, ext))
        n += 1
    return candidate


def copy_file(src: str, dst: str) -> None:
    with open(src, "rb") as a, open(dst, "wb") as b:
        while True:
            chunk = a.read(1 << 20)
            if not chunk:
                break
            b.write(chunk)


# --- tool protocol ---------------------------------------------------------


def emit(value, out: str | None = None) -> None:
    text = json.dumps(value, ensure_ascii=False)
    if out:
        ensure_dir(os.path.dirname(abspath(out)))
        with open(out, "w", encoding="utf-8") as f:
            f.write(text + "\n")
    else:
        sys.stdout.write(text + "\n")
        sys.stdout.flush()


def run(main) -> None:
    """Runs a tool's `main(argv)` returning the JSON value to print."""
    argv = sys.argv[1:]
    out = None
    if "--out" in argv:
        i = argv.index("--out")
        if i + 1 >= len(argv):
            emit({"error": "--out needs a file name"})
            sys.exit(2)
        out = argv[i + 1]
        del argv[i : i + 2]
    try:
        value = main(argv)
    except ToolError as e:
        emit({"error": str(e)}, out)
        sys.exit(1)
    except FileNotFoundError as e:
        emit({"error": "not found: %s" % (e.filename or e)}, out)
        sys.exit(1)
    except Exception as e:  # noqa: BLE001 - a tool never dies with a traceback
        emit({"error": "%s: %s" % (type(e).__name__, e)}, out)
        sys.exit(1)
    emit(value, out)


def take_option(argv: list[str], name: str) -> str | None:
    if name in argv:
        i = argv.index(name)
        if i + 1 >= len(argv):
            raise ToolError("%s needs a value" % name)
        value = argv[i + 1]
        del argv[i : i + 2]
        return value
    return None


def take_flag(argv: list[str], name: str) -> bool:
    if name in argv:
        argv.remove(name)
        return True
    return False


def require_root(argv: list[str]) -> str | None:
    return take_option(argv, "--root")
