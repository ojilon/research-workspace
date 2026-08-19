"""
Application settings.

STORAGE_ROOT is the folder on disk where documents, summaries,
and bookmarks live.

Default resolution (see storage.py):
  1. STORAGE_ROOT environment variable, if set
  2. D:\\ResearchWorkspace  (preferred when D: is available and writable)
  3. ~/ResearchWorkspace     (fallback, usually on C:)

Can also be changed at runtime with POST /api/settings/storage-root.
"""

from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

from app.storage import resolve_default_storage_root


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Resolved once at import; POST /api/settings/storage-root can override later.
    storage_root: Path = resolve_default_storage_root()

    # CORS – Vite dev server
    cors_origins: list[str] = [
        "http://localhost:5173",
        "http://127.0.0.1:5173",
    ]

    host: str = "127.0.0.1"
    port: int = 8000


settings = Settings()
