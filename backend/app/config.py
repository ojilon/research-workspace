"""
Application settings.

STORAGE_ROOT is the folder on disk where documents, summaries,
and bookmarks live. The user picks this once (or we default to
~/ResearchWorkspace).
"""

from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Default local storage root. Override with STORAGE_ROOT env var
    # or POST /api/settings/storage-root from the frontend.
    storage_root: Path = Path.home() / "ResearchWorkspace"

    # CORS – Vite dev server
    cors_origins: list[str] = [
        "http://localhost:5173",
        "http://127.0.0.1:5173",
    ]

    host: str = "127.0.0.1"
    port: int = 8000


settings = Settings()
