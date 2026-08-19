"""
Resolve and manage the local storage root.

Priority:
  1. Explicit value already set on settings (env STORAGE_ROOT or POST /api/settings)
  2. D:\\ResearchWorkspace  (preferred – keeps large files off a full C: drive)
  3. Fallback: Path.home() / "ResearchWorkspace"  (usually under C:\\Users\\...)

If D: is missing, not ready, or not writable, we silently fall back.
"""

from __future__ import annotations

import os
from pathlib import Path

WORKSPACE_DIR_NAME = "ResearchWorkspace"
MARKER_NAME = ".rw-workspace"


def _drive_ready(letter: str) -> bool:
    """True if the Windows drive letter exists and is accessible."""
    root = Path(f"{letter}:/")
    try:
        return root.exists() and root.is_dir()
    except OSError:
        return False


def _can_use_directory(path: Path) -> bool:
    """Try to create the folder and write a tiny probe file."""
    try:
        path.mkdir(parents=True, exist_ok=True)
        probe = path / ".rw-write-test"
        probe.write_text("ok", encoding="utf-8")
        probe.unlink(missing_ok=True)
        return True
    except OSError:
        return False


def resolve_default_storage_root() -> Path:
    """
    Pick the best default storage location on this machine.

    Prefers D:\\ResearchWorkspace when the D: drive is present and writable.
    Otherwise uses the user home directory (typically on C:).
    """
    # 1) Environment override always wins when set before process start
    env = os.environ.get("STORAGE_ROOT", "").strip()
    if env:
        return Path(env).expanduser()

    # 2) Prefer D: drive (user request – C: is nearly full)
    if os.name == "nt" and _drive_ready("D"):
        candidate = Path("D:/") / WORKSPACE_DIR_NAME
        if _can_use_directory(candidate):
            return candidate.resolve()

    # 3) Fallback – user profile (usually C:\\Users\\<name>\\ResearchWorkspace)
    fallback = Path.home() / WORKSPACE_DIR_NAME
    # Still attempt to create; if this also fails, caller will surface the error
    _can_use_directory(fallback)
    return fallback.resolve()


def ensure_storage_root(root: Path) -> Path:
    """
    Make sure the storage folder exists and has a small marker file.
    Returns the resolved absolute path.
    """
    root = root.expanduser().resolve()
    root.mkdir(parents=True, exist_ok=True)
    marker = root / MARKER_NAME
    if not marker.exists():
        marker.write_text("research-workspace\n", encoding="utf-8")
    return root
