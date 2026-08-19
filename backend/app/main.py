"""
Research Workspace API.

Run:
    uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from app.config import settings
from app.shell import open_in_explorer
from app.storage import ensure_storage_root, resolve_default_storage_root

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


def current_root() -> Path:
    return ensure_storage_root(settings.storage_root)


def safe_join(root: Path, relative: str) -> Path:
    rel = Path(relative)
    if rel.is_absolute() or ".." in rel.parts:
        raise HTTPException(status_code=400, detail="Invalid relative path")
    target = (root / rel).resolve()
    if not str(target).startswith(str(root.resolve())):
        raise HTTPException(status_code=400, detail="Path escapes storage root")
    return target


def build_tree(directory: Path, root: Path) -> list[dict[str, Any]]:
    nodes: list[dict[str, Any]] = []
    try:
        entries = sorted(
            directory.iterdir(), key=lambda p: (not p.is_dir(), p.name.lower())
        )
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


class StorageRootBody(BaseModel):
    path: str = Field(..., description="Absolute path to the local storage folder")


class SaveFileBody(BaseModel):
    relative_path: str
    content: str


class BookmarkBody(BaseModel):
    folder: str = ""
    title: str
    url: str


class OpenFolderBody(BaseModel):
    """Open Explorer at storage root, or at a relative subfolder."""
    relative_path: str = Field(
        "", description="Subfolder under storage root (empty = root itself)"
    )


class RevealBody(BaseModel):
    """Reveal a file or folder in Explorer (selected if it is a file)."""
    relative_path: str


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/settings/storage-root")
def get_storage_root() -> dict[str, str]:
    root = current_root()
    drive = root.drive or ""
    return {
        "path": str(root),
        "drive": drive.rstrip(":") if drive else "",
        "preferred": "D",
        "resolved_by": "settings",
    }


@app.post("/api/settings/storage-root")
def set_storage_root(body: StorageRootBody) -> dict[str, str]:
    path = Path(body.path).expanduser()
    if not path.is_absolute():
        raise HTTPException(status_code=400, detail="Path must be absolute")
    try:
        path.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        raise HTTPException(status_code=400, detail=f"Cannot create folder: {exc}") from exc
    settings.storage_root = path
    root = current_root()
    return {"path": str(root), "drive": root.drive.rstrip(":") if root.drive else ""}


@app.post("/api/settings/storage-root/reset-default")
def reset_storage_root_default() -> dict[str, str]:
    path = resolve_default_storage_root()
    settings.storage_root = path
    root = current_root()
    return {
        "path": str(root),
        "drive": root.drive.rstrip(":") if root.drive else "",
        "note": "Preferred D:\\ResearchWorkspace when available; else user home.",
    }


@app.get("/api/tree")
def get_tree() -> dict[str, Any]:
    root = current_root()
    return {"root": str(root), "nodes": build_tree(root, root)}


@app.post("/api/files/save")
def save_file(body: SaveFileBody) -> dict[str, str]:
    root = current_root()
    target = safe_join(root, body.relative_path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(body.content, encoding="utf-8")
    return {"path": str(target.relative_to(root)).replace("\\", "/")}


@app.post("/api/bookmarks")
def save_bookmark(body: BookmarkBody) -> dict[str, str]:
    root = current_root()
    folder = body.folder.strip().strip("/\\")
    safe_name = (
        "".join(c for c in body.title if c not in '<>:"/\\|?*').strip() or "bookmark"
    )
    if not safe_name.lower().endswith(".url"):
        safe_name += ".url"
    rel = f"{folder}/{safe_name}" if folder else safe_name
    target = safe_join(root, rel)
    target.parent.mkdir(parents=True, exist_ok=True)
    content = f"[InternetShortcut]\nURL={body.url}\n"
    target.write_text(content, encoding="utf-8")
    return {"path": str(target.relative_to(root)).replace("\\", "/")}


@app.get("/api/files/read")
def read_file(relative_path: str) -> dict[str, str]:
    root = current_root()
    target = safe_join(root, relative_path)
    if not target.is_file():
        raise HTTPException(status_code=404, detail="File not found")
    try:
        text = target.read_text(encoding="utf-8")
    except UnicodeDecodeError as exc:
        raise HTTPException(
            status_code=415, detail="Binary file – use extract endpoint later"
        ) from exc
    return {"path": relative_path, "content": text}


@app.post("/api/shell/open-folder")
def shell_open_folder(body: OpenFolderBody = OpenFolderBody()) -> dict[str, str]:
    """
    Open Windows Explorer at the storage root (or a subfolder).
    Use this for "Create folder/file" and "Open storage" from the UI.
    """
    root = current_root()
    if body.relative_path.strip():
        target = safe_join(root, body.relative_path.strip())
        target.mkdir(parents=True, exist_ok=True)
    else:
        target = root
    try:
        open_in_explorer(target, select=False)
    except OSError as exc:
        raise HTTPException(status_code=500, detail=f"Could not open Explorer: {exc}") from exc
    return {"opened": str(target)}


@app.post("/api/shell/reveal")
def shell_reveal(body: RevealBody) -> dict[str, str]:
    """Reveal a relative path in Explorer (file selected when possible)."""
    root = current_root()
    target = safe_join(root, body.relative_path)
    try:
        open_in_explorer(target, select=target.is_file())
    except OSError as exc:
        raise HTTPException(status_code=500, detail=f"Could not open Explorer: {exc}") from exc
    return {"opened": str(target)}
