"""
Research Workspace API (+ optional packaged UI).

Dev:
    uvicorn app.main:app --reload --host 127.0.0.1 --port 8000

Packaged (from repo root):
    Start-Research-Workspace.bat
    or: backend\.venv\Scripts\python.exe run_app.py
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, Response
from pydantic import BaseModel, Field

from app.config import settings
from app.documents import extract_document, file_kind
from app.render import docx_to_html
from app.shell import open_in_explorer, save_as_dialog
from app.static_ui import mount_frontend
from app.storage import ensure_storage_root, resolve_default_storage_root

app = FastAPI(
    title="Research Workspace API",
    version="0.3.0",
    description="Local-first backend for documents, bookmarks, and storage root.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["Content-Disposition", "Content-Type", "Content-Length"],
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
                    "fileKind": "folder",
                    "path": rel,
                    "children": build_tree(entry, root),
                }
            )
        else:
            fk = file_kind(entry)
            kind = "link" if fk == "link" else "document"
            nodes.append(
                {
                    "id": f"{kind}:{rel}",
                    "name": entry.name,
                    "kind": kind,
                    "fileKind": fk,
                    "path": rel,
                }
            )
    return nodes


class StorageRootBody(BaseModel):
    path: str


class SaveFileBody(BaseModel):
    relative_path: str
    content: str


class BookmarkBody(BaseModel):
    folder: str = ""
    title: str
    url: str


class OpenFolderBody(BaseModel):
    relative_path: str = Field("", description="Subfolder under storage root")


class RevealBody(BaseModel):
    relative_path: str


class SaveAsBody(BaseModel):
    default_name: str = "Untitled.md"
    relative_dir: str = ""


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
            status_code=415,
            detail="Binary file – use /api/documents/extract or /api/files/raw",
        ) from exc
    return {"path": relative_path, "content": text}


@app.get("/api/documents/extract")
def documents_extract(relative_path: str) -> dict[str, Any]:
    root = current_root()
    target = safe_join(root, relative_path)
    if not target.is_file():
        raise HTTPException(status_code=404, detail="File not found")
    try:
        payload = extract_document(target)
    except Exception as exc:
        raise HTTPException(
            status_code=500, detail=f"Extraction failed: {exc}"
        ) from exc
    payload["relative_path"] = relative_path
    return payload


@app.get("/api/documents/html")
def documents_html(relative_path: str) -> HTMLResponse:
    root = current_root()
    target = safe_join(root, relative_path)
    if not target.is_file():
        raise HTTPException(status_code=404, detail="File not found")
    if target.suffix.lower() != ".docx":
        raise HTTPException(status_code=400, detail="HTML view is for .docx only")
    try:
        body = docx_to_html(target)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Render failed: {exc}") from exc
    return HTMLResponse(content=body)


@app.get("/api/files/raw")
def files_raw(relative_path: str) -> Response:
    root = current_root()
    target = safe_join(root, relative_path)
    if not target.is_file():
        raise HTTPException(status_code=404, detail="File not found")
    media = {
        ".pdf": "application/pdf",
        ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        ".doc": "application/msword",
        ".png": "image/png",
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".gif": "image/gif",
        ".webp": "image/webp",
    }.get(target.suffix.lower(), "application/octet-stream")
    data = target.read_bytes()
    return Response(
        content=data,
        media_type=media,
        headers={
            "Content-Disposition": f'inline; filename="{target.name}"',
            "Cache-Control": "no-cache",
            "Content-Length": str(len(data)),
        },
    )


@app.post("/api/shell/open-folder")
def shell_open_folder(body: OpenFolderBody = OpenFolderBody()) -> dict[str, str]:
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
    root = current_root()
    target = safe_join(root, body.relative_path)
    try:
        open_in_explorer(target, select=target.is_file())
    except OSError as exc:
        raise HTTPException(status_code=500, detail=f"Could not open Explorer: {exc}") from exc
    return {"opened": str(target)}


@app.post("/api/shell/save-as")
def shell_save_as(body: SaveAsBody = SaveAsBody()) -> dict[str, Any]:
    root = current_root()
    start = root
    if body.relative_dir.strip():
        start = safe_join(root, body.relative_dir.strip())
        start.mkdir(parents=True, exist_ok=True)

    chosen = save_as_dialog(
        initial_dir=start,
        default_name=body.default_name or "Untitled.md",
        title="Create document",
    )
    if chosen is None:
        return {"cancelled": True}

    try:
        rel = str(chosen.relative_to(root)).replace("\\", "/")
        under_root = True
    except ValueError:
        rel = str(chosen)
        under_root = False

    return {
        "cancelled": False,
        "path": rel,
        "absolute": str(chosen),
        "under_root": under_root,
        "name": chosen.name,
    }


# Packaged UI last so /api/* always wins
_UI_MOUNTED = mount_frontend(app)
