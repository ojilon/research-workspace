#!/usr/bin/env python3
"""
Research Workspace – single-click launcher.

Starts FastAPI (API + packaged UI if frontend/dist exists) and opens the browser.
No second terminal required.

Usage (from repo root, with backend .venv available):

    .\\backend\\.venv\\Scripts\\python.exe run_app.py

or double-click Start-Research-Workspace.bat
"""

from __future__ import annotations

import os
import sys
import threading
import time
import webbrowser
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BACKEND = ROOT / "backend"
HOST = os.environ.get("RW_HOST", "127.0.0.1")
PORT = int(os.environ.get("RW_PORT", "8000"))
URL = f"http://{HOST}:{PORT}/"


def ensure_path() -> None:
    sys.path.insert(0, str(BACKEND))
    os.chdir(BACKEND)


def open_browser_later() -> None:
    time.sleep(1.2)
    webbrowser.open(URL)


def main() -> None:
    ensure_path()

    dist = ROOT / "frontend" / "dist" / "index.html"
    if not dist.is_file():
        print(
            "\n[!] frontend/dist not found.\n"
            "    Run once to build the UI:\n"
            "      cd frontend\n"
            "      npm install\n"
            "      npm run build\n"
            "    Then start again. Dev mode still works with two processes\n"
            "    (see docs/004-packaging.md).\n"
        )

    # Import after path setup
    import uvicorn

    print(f"Research Workspace → {URL}")
    print("Storage prefers D:\\ResearchWorkspace (see backend status strip).")
    print("Press Ctrl+C to stop.\n")

    threading.Thread(target=open_browser_later, daemon=True).start()

    uvicorn.run(
        "app.main:app",
        host=HOST,
        port=PORT,
        reload=False,
        log_level="info",
    )


if __name__ == "__main__":
    main()
