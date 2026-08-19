"""
Research Workspace API.

Run from the backend folder (with .venv active):

    uvicorn app.main:app --reload --host 127.0.0.1 --port 8000

Endpoints in this first skeleton:
  GET  /api/health
  GET  /api/settings/storage-root
  POST /api/settings/storage-root   { "path": "D:\\Research" }
  GET  /api/tree                   file tree under storage root
  POST /api/files/save             save text content into a relative path
  POST /api/bookmarks              save a link into a folder
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from app.config import settings

app = FastAPI(
    title="Research Workspace API",
    version="0.1.0",
    description="Local-first backend for documents, bookmarks, and storage root.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def ensure_storage_root() -> Path:
    root = settings.storage_root.expanduser().resolve()
    root.mkdir(parents=True, exist_ok=True)
    # Small marker so we know this folder is managed by the app
    marker = root / ".rw-workspace"
    if not marker.exists():
        marker.write_text("research-workspace\n", encoding="utf-8")
    return root


def safe_join(root: Path, relative: str) -> Path:
    """Join relative path under root; reject path traversal."""
    rel = Path(relative)
    if rel.is_absolute() or ".." in rel.parts:
        raise HTTPException(status_code=400, detail="Invalid relative path")
    target = (root / rel).resolve()
    if not str(target).startswith(str(root.resolve())):
        raise HTTPException(status_code=400, detail="Path escapes storage root")
    return target


def build_tree(directory: Path, root: Path) -> list[dict[str, Any]]:
    """Return a nested list of nodes suitable for the frontend FileTree."""
    nodes: list[dict[str, Any]] = []
    try:
        entries = sorted(directory.iterdir(), key=lambda p: (not p.is_dir(), p.name.lower()))
    except PermissionError:
        return nodes

    for entry in entries:
        if entry.name.startswith("."):
            continue
        rel = str(entry.relative_to(root)).replace("\\", "/")
        if entry.is_dir():
            nodes.append(
                {
                    "id": f"folder:{rel}",
                    "name": entry.name,
                    "kind": "folder",
                    "path": rel,
                    "children": build_tree(entry, root),
                }
            )
        else:
            # Treat .url / .link style files as bookmarks later; for now all files are documents
            kind = "document"
            if entry.suffix.lower() in {".url", ".webloc"}:
                kind = "link"
            nodes.append(
                {
                    "id": f"{kind}:{rel}",
                    "name": entry.name,
                    "kind": kind,
                    "path": rel,
                }
            )
    return nodes


# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------

class StorageRootBody(BaseModel):
    path: str = Field(..., description="Absolute path to the local storage folder")


class SaveFileBody(BaseModel):
    """Save plain text (Markdown / notes) under the storage root."""
    relative_path: str = Field(..., description="Path relative to storage root, e.g. notes/summary.md")
    content: str = Field(..., description="File content as UTF-8 text")


class BookmarkBody(BaseModel):
    folder: str = Field("", description="Relative folder under storage root (empty = root)")
    title: str
    url: str


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/settings/storage-root")
def get_storage_root() -> dict[str, str]:
    root = ensure_storage_root()
    return {"path": str(root)}


@app.post("/api/settings/storage-root")
def set_storage_root(body: StorageRootBody) -> dict[str, str]:
    path = Path(body.path).expanduser()
    if not path.is_absolute():
        raise HTTPException(status_code=400, detail="Path must be absolute")
    path.mkdir(parents=True, exist_ok=True)
    settings.storage_root = path
    ensure_storage_root()
    return {"path": str(path.resolve())}


@app.get("/api/tree")
def get_tree() -> dict[str, Any]:
    root = ensure_storage_root()
    return {"root": str(root), "nodes": build_tree(root, root)}


@app.post("/api/files/save")
def save_file(body: SaveFileBody) -> dict[str, str]:
    root = ensure_storage_root()
    target = safe_join(root, body.relative_path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(body.content, encoding="utf-8")
    return {"path": str(target.relative_to(root)).replace("\\", "/")}


@app.post("/api/bookmarks")
def save_bookmark(body: BookmarkBody) -> dict[str, str]:
    """
    Save a bookmark as a simple .url file (Windows Internet Shortcut format).
    Opens correctly in Explorer and can be listed in the file tree later.
    """
    root = ensure_storage_root()
    folder = body.folder.strip().strip("/\\")
    # Sanitise filename
    safe_name = "".join(c for c in body.title if c not in '<>:"/\\|?*').strip() or "bookmark"
    if not safe_name.lower().endswith(".url"):
        safe_name += ".url"
    rel = f"{folder}/{safe_name}" if folder else safe_name
    target = safe_join(root, rel)
    target.parent.mkdir(parents=True, exist_ok=True)
    # Windows .url format
    content = f"[InternetShortcut]\nURL={body.url}\n"
    target.write_text(content, encoding="utf-8")
    return {"path": str(target.relative_to(root)).replace("\\", "/")}


@app.get("/api/files/read")
def read_file(relative_path: str) -> dict[str, str]:
    root = ensure_storage_root()
    target = safe_join(root, relative_path)
    if not target.is_file():
        raise HTTPException(status_code=404, detail="File not found")
    # Only text for now; PDF/DOCX extraction comes in a later step
    try:
        text = target.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        raise HTTPException(status_code=415, detail="Binary file – use extract endpoint later")
    return {"path": relative_path, "content": text}
