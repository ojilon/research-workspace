"""
Mount the built React UI (frontend/dist) so one process serves API + app.
"""

from __future__ import annotations

from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles


def frontend_dist() -> Path | None:
    """Resolve frontend/dist relative to the repo root."""
    # backend/app/static_ui.py → backend/app → backend → repo
    repo = Path(__file__).resolve().parents[2]
    dist = repo / "frontend" / "dist"
    if (dist / "index.html").is_file():
        return dist
    return None


def mount_frontend(app: FastAPI) -> bool:
    """
    If a production build exists, serve it and SPA-fallback to index.html.
    Returns True when mounted.
    """
    dist = frontend_dist()
    if dist is None:
        return False

    assets = dist / "assets"
    if assets.is_dir():
        app.mount("/assets", StaticFiles(directory=str(assets)), name="assets")

    index = dist / "index.html"

    @app.get("/")
    def spa_index() -> FileResponse:
        return FileResponse(index)

    # Catch-all for client-side routes (not /api/*)
    @app.get("/{full_path:path}")
    def spa_fallback(full_path: str) -> FileResponse:
        candidate = dist / full_path
        if candidate.is_file():
            return FileResponse(candidate)
        return FileResponse(index)

    return True
