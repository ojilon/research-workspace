#!/usr/bin/env python3
"""The revise database: index, linked files, search, highlights.

    db.py init    --root DIR
    db.py index   --root DIR [--path FILE]      (incremental, by mtime and size)
    db.py files   --root DIR
    db.py link    --root DIR --path FILE [--alias NAME]
    db.py links   --root DIR
    db.py search  --root DIR QUERY [--limit N]
    db.py hl-add  --root DIR --path FILE --block ID --text TEXT [--color yellow]
    db.py hl-list --root DIR [--path FILE]
    db.py hl-remove --root DIR --id N

The database lives at <root>/.revise/revise.db (gitignored).  SQLite is
Python's own: FTS5 when it is compiled in, LIKE otherwise.

Tables: links(path, alias), files(path, mtime, size), fts(path, page, text),
highlights(path, block_id, text, color, created).  `page` is the PDF page
number, or the paragraph's index in a DOCX or text file.
"""

from __future__ import annotations

import os
import re
import sqlite3
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import extract as ex  # noqa: E402
import revise_common as rc  # noqa: E402

SKIP_DIRS = {
    ".revise",
    ".git",
    ".hg",
    ".svn",
    ".venv",
    "venv",
    "__pycache__",
    "node_modules",
    "zig-out",
    ".zig-cache",
    "zig-cache",
    "zig-pkg",
    "dist",
    "build",
    "target",
}
INDEXABLE = {".pdf", ".docx", ".md", ".markdown", ".txt"}

SCHEMA = [
    """CREATE TABLE IF NOT EXISTS links(
        path TEXT PRIMARY KEY,
        alias TEXT NOT NULL DEFAULT '')""",
    """CREATE TABLE IF NOT EXISTS files(
        path TEXT PRIMARY KEY,
        mtime INTEGER NOT NULL DEFAULT 0,
        size INTEGER NOT NULL DEFAULT 0)""",
    """CREATE TABLE IF NOT EXISTS highlights(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        path TEXT NOT NULL,
        block_id TEXT NOT NULL,
        text TEXT NOT NULL DEFAULT '',
        color TEXT NOT NULL DEFAULT 'yellow',
        created INTEGER NOT NULL DEFAULT 0)""",
    "CREATE INDEX IF NOT EXISTS highlights_path ON highlights(path)",
    "CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT NOT NULL DEFAULT '')",
]


def connect(root: str) -> sqlite3.Connection:
    path = rc.db_path(root)
    rc.ensure_dir(os.path.dirname(path))
    db = sqlite3.connect(path)
    db.row_factory = sqlite3.Row
    for sql in SCHEMA:
        db.execute(sql)
    _ensure_fts(db)
    db.commit()
    return db


def _fts5_ready(db: sqlite3.Connection) -> bool:
    row = db.execute("SELECT value FROM meta WHERE key='fts5'").fetchone()
    return row is not None and row["value"] == "1"


def _ensure_fts(db: sqlite3.Connection) -> None:
    """FTS5 when SQLite has it, a plain table searched with LIKE otherwise."""
    row = db.execute("SELECT value FROM meta WHERE key='fts5'").fetchone()
    if row is not None:
        if row["value"] != "1":
            db.execute("CREATE TABLE IF NOT EXISTS fts(path TEXT, page INTEGER, text TEXT)")
        return
    try:
        db.execute("CREATE VIRTUAL TABLE fts USING fts5(path, page UNINDEXED, text)")
        ok = True
    except sqlite3.OperationalError:
        db.execute("CREATE TABLE IF NOT EXISTS fts(path TEXT, page INTEGER, text TEXT)")
        ok = False
    db.execute("INSERT OR REPLACE INTO meta(key, value) VALUES('fts5', ?)", ("1" if ok else "0",))
    db.commit()


def _tokens(query: str) -> list[str]:
    return [t for t in re.findall(r"[^\s\"'()*:]+", query) if t]


def _snippet(text: str, tokens: list[str], width: int = 34):
    # One line, so a result reads as a sentence and wraps in the panel: the
    # page's blocks are joined by newlines, which are not wanted here.
    text = " ".join(text.split())
    lowered = text.lower()
    best = None
    for tok in tokens:
        i = lowered.find(tok.lower())
        if i < 0:
            continue
        if best is None or i < best[0]:
            best = (i, i + len(tok))
    if best is None:
        return (text[: width * 2], 0, 0)
    start = max(0, best[0] - width)
    end = min(len(text), best[1] + width)
    prefix = "…" if start > 0 else ""
    suffix = "…" if end < len(text) else ""
    snip = prefix + text[start:end] + suffix
    return (snip, len(prefix) + best[0] - start, len(prefix) + best[1] - start)


# --- indexing --------------------------------------------------------------


def iter_files(root: str, single: str | None = None):
    if single:
        yield rc.abspath(single)
        return
    for base, dirs, names in os.walk(root):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS and not d.startswith("."))
        for name in sorted(names):
            if os.path.splitext(name)[1].lower() in INDEXABLE:
                yield os.path.join(base, name)


def index_file(db: sqlite3.Connection, root: str, path: str) -> dict:
    path = rc.abspath(path)
    if os.path.splitext(path)[1].lower() not in INDEXABLE:
        return {"path": path, "skipped": "not indexable"}
    try:
        st = os.stat(path)
    except OSError as e:
        return {"path": path, "error": str(e)}
    row = db.execute("SELECT mtime, size FROM files WHERE path=?", (path,)).fetchone()
    if row is not None and row["mtime"] == int(st.st_mtime_ns) and row["size"] == int(st.st_size):
        return {"path": path, "unchanged": True}
    try:
        data = ex.extract_cached(root, path)
    except Exception as e:  # noqa: BLE001 - one bad file never stops the index
        return {"path": path, "error": str(e)}
    db.execute("DELETE FROM fts WHERE path=?", (path,))
    rows = []
    if "pages" in data:
        for page in data["pages"]:
            text = "\n".join(b["text"] for b in page["blocks"])
            if text.strip():
                rows.append((path, page["n"], text))
    else:
        for i, para in enumerate(data.get("paragraphs", []), start=1):
            if para["text"].strip():
                rows.append((path, i, para["text"]))
    db.executemany("INSERT INTO fts(path, page, text) VALUES(?,?,?)", rows)
    db.execute(
        "INSERT INTO files(path, mtime, size) VALUES(?,?,?) "
        "ON CONFLICT(path) DO UPDATE SET mtime=excluded.mtime, size=excluded.size",
        (path, int(st.st_mtime_ns), int(st.st_size)),
    )
    return {"path": path, "chunks": len(rows)}


def index(db: sqlite3.Connection, root: str, single: str | None = None) -> dict:
    done = []
    errors = []
    for path in iter_files(root, single):
        r = index_file(db, root, path)
        if "error" in r:
            errors.append(r)
        elif not r.get("unchanged"):
            done.append(r)
    # Linked files, wherever they live.
    for link in db.execute("SELECT path FROM links").fetchall():
        r = index_file(db, root, link["path"])
        if "error" in r:
            errors.append(r)
        elif not r.get("unchanged"):
            done.append(r)
    db.commit()
    total = db.execute("SELECT COUNT(*) AS n FROM files").fetchone()["n"]
    return {"ok": True, "indexed": done, "errors": errors, "files": total}


# --- commands --------------------------------------------------------------


def cmd_files(argv: list[str]) -> dict:
    root = rc.take_option(argv, "--root")
    if not root:
        raise rc.ToolError("--root is required")
    db = connect(root)
    out = []
    seen = set()
    for row in db.execute("SELECT path, mtime, size FROM files ORDER BY path").fetchall():
        out.append({"path": row["path"], "mtime": row["mtime"], "size": row["size"], "linked": False})
        seen.add(row["path"])
    for row in db.execute("SELECT path, alias FROM links ORDER BY path").fetchall():
        if row["path"] in seen:
            for item in out:
                if item["path"] == row["path"]:
                    item["linked"] = True
                    item["alias"] = row["alias"]
            continue
        try:
            st = os.stat(row["path"])
            size = int(st.st_size)
        except OSError:
            size = 0
        out.append({"path": row["path"], "mtime": 0, "size": size, "linked": True, "alias": row["alias"]})
    return {"ok": True, "files": out}


def cmd_link(argv: list[str]) -> dict:
    root = rc.take_option(argv, "--root")
    path = rc.take_option(argv, "--path")
    alias = rc.take_option(argv, "--alias") or ""
    if not root or not path:
        raise rc.ToolError("usage: db.py link --root DIR --path FILE [--alias NAME]")
    path = rc.abspath(path)
    if not os.path.exists(path):
        raise rc.ToolError("not found: %s" % path)
    if rc.kind_of(path) not in ("pdf", "docx", "text"):
        raise rc.ToolError("only PDF, DOCX, Markdown and text files can be linked")
    db = connect(root)
    if not alias:
        alias = os.path.splitext(os.path.basename(path))[0]
    db.execute(
        "INSERT INTO links(path, alias) VALUES(?,?) ON CONFLICT(path) DO UPDATE SET alias=excluded.alias",
        (path, alias),
    )
    db.commit()
    return {"ok": True, "path": path, "alias": alias}


def cmd_links(argv: list[str]) -> dict:
    root = rc.take_option(argv, "--root")
    if not root:
        raise rc.ToolError("--root is required")
    db = connect(root)
    rows = db.execute("SELECT path, alias FROM links ORDER BY alias").fetchall()
    return {
        "ok": True,
        "links": [{"path": r["path"], "alias": r["alias"], "exists": os.path.exists(r["path"])} for r in rows],
    }


def cmd_search(argv: list[str]) -> dict:
    root = rc.take_option(argv, "--root")
    limit = rc.take_option(argv, "--limit")
    if not root:
        raise rc.ToolError("--root is required")
    query = " ".join(argv).strip()
    tokens = _tokens(query)
    if not tokens:
        return {"ok": True, "query": query, "results": [], "fts5": _fts5_ready(connect(root))}
    db = connect(root)
    fts5 = _fts5_ready(db)
    limit_n = int(limit) if limit and limit.isdigit() else 100
    rows = []
    if fts5:
        match = " AND ".join('"%s"*' % t.replace('"', '""') for t in tokens)
        try:
            rows = db.execute(
                "SELECT f.path AS path, f.page AS page, f.text AS text "
                "FROM fts f JOIN files fl ON fl.path = f.path "
                "WHERE fts MATCH ? ORDER BY bm25(fts, 0.0, 0.0, 1.0) LIMIT ?",
                (match, limit_n),
            ).fetchall()
        except sqlite3.OperationalError:
            rows = []
    if not rows:
        where = " AND ".join("lower(text) LIKE ?" for _ in tokens)
        args = ["%" + t.lower() + "%" for t in tokens]
        rows = db.execute(
            "SELECT path, page, text FROM fts WHERE " + where + " LIMIT ?", (*args, limit_n)
        ).fetchall()
    kinds = {}
    for row in db.execute("SELECT path FROM files").fetchall():
        kinds[row["path"]] = rc.KIND_BY_EXT.get(os.path.splitext(row["path"])[1].lower(), "text")
    out = []
    for row in rows:
        snip, hit0, hit1 = _snippet(row["text"], tokens)
        out.append(
            {
                "path": row["path"],
                "page": row["page"],
                "kind": kinds.get(row["path"], "text"),
                "snippet": snip,
                "hit": [hit0, hit1],
            }
        )
    return {"ok": True, "query": query, "fts5": fts5, "results": out}


def cmd_hl_add(argv: list[str]) -> dict:
    root = rc.take_option(argv, "--root")
    path = rc.take_option(argv, "--path")
    block = rc.take_option(argv, "--block")
    text = rc.take_option(argv, "--text") or ""
    color = rc.take_option(argv, "--color") or "yellow"
    if not root or not path or not block:
        raise rc.ToolError("usage: db.py hl-add --root DIR --path FILE --block ID --text TEXT")
    path = rc.abspath(path)
    db = connect(root)
    row = db.execute("SELECT id FROM highlights WHERE path=? AND block_id=?", (path, block)).fetchone()
    if row is not None:
        db.execute("UPDATE highlights SET text=?, color=? WHERE id=?", (text, color, row["id"]))
        hid = row["id"]
    else:
        cur = db.execute(
            "INSERT INTO highlights(path, block_id, text, color, created) VALUES(?,?,?,?,?)",
            (path, block, text, color, int(time.time())),
        )
        hid = cur.lastrowid
    db.commit()
    return {"ok": True, "id": hid, "path": path, "block_id": block, "color": color}


def cmd_hl_list(argv: list[str]) -> dict:
    root = rc.take_option(argv, "--root")
    path = rc.take_option(argv, "--path")
    if not root:
        raise rc.ToolError("--root is required")
    db = connect(root)
    if path:
        rows = db.execute(
            "SELECT id, path, block_id, text, color, created FROM highlights WHERE path=? ORDER BY id",
            (rc.abspath(path),),
        ).fetchall()
    else:
        rows = db.execute(
            "SELECT id, path, block_id, text, color, created FROM highlights ORDER BY path, id"
        ).fetchall()
    return {"ok": True, "highlights": [dict(r) for r in rows]}


def cmd_hl_remove(argv: list[str]) -> dict:
    root = rc.take_option(argv, "--root")
    hid = rc.take_option(argv, "--id")
    if not root or not hid:
        raise rc.ToolError("usage: db.py hl-remove --root DIR --id N")
    db = connect(root)
    db.execute("DELETE FROM highlights WHERE id=?", (int(hid),))
    db.commit()
    return {"ok": True, "removed": int(hid)}


def cmd_init(argv: list[str]) -> dict:
    root = rc.take_option(argv, "--root")
    if not root:
        raise rc.ToolError("--root is required")
    db = connect(root)
    return {"ok": True, "fts5": _fts5_ready(db)}


def cmd_index(argv: list[str]) -> dict:
    root = rc.take_option(argv, "--root")
    if not root:
        raise rc.ToolError("--root is required")
    return index(connect(root), root, rc.take_option(argv, "--path"))


COMMANDS = {
    "init": cmd_init,
    "index": cmd_index,
    "files": cmd_files,
    "link": cmd_link,
    "links": cmd_links,
    "search": cmd_search,
    "hl-add": cmd_hl_add,
    "hl-list": cmd_hl_list,
    "hl-remove": cmd_hl_remove,
}


def main(argv: list[str]) -> dict:
    if not argv or argv[0] not in COMMANDS:
        raise rc.ToolError("usage: db.py {%s} ..." % ",".join(sorted(COMMANDS)))
    command = argv[0]
    rest = argv[1:]
    root = None
    for i, a in enumerate(rest):
        if a == "--root" and i + 1 < len(rest):
            root = rest[i + 1]
            break
    if not root:
        raise rc.ToolError("--root is required")
    connect(root)  # creates the schema when it is missing
    value = COMMANDS[command](rest)
    value.setdefault("db", rc.db_path(root))
    return value


if __name__ == "__main__":
    rc.run(main)
