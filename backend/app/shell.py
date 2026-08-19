"""
Open the system file manager (Windows Explorer) at a folder or file.

Used by the UI for:
  - Create folder / file  → user works in Explorer, then refreshes the tree
  - Reveal saved file
  - First-time orientation to the storage root on D:
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path


def open_in_explorer(path: Path, select: bool = False) -> None:
    """
    Open Explorer at `path`.

    If select=True and path is a file, Explorer opens with that file selected.
    On non-Windows, falls back to xdg-open / open (best effort).
    """
    path = path.resolve()
    if os.name == "nt":
        if select and path.is_file():
            # /select, selects the file in its parent folder
            subprocess.Popen(["explorer", f"/select,{path}"])
        elif path.is_dir():
            subprocess.Popen(["explorer", str(path)])
        else:
            # File missing or folder – open parent if possible
            target = path if path.is_dir() else path.parent
            target.mkdir(parents=True, exist_ok=True)
            subprocess.Popen(["explorer", str(target)])
        return

    # Best-effort for other OSes (dev machines)
    opener = "open" if os.name == "posix" and Path("/usr/bin/open").exists() else "xdg-open"
    subprocess.Popen([opener, str(path if path.is_dir() else path.parent)])
