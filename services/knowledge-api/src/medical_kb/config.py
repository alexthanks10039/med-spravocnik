"""Runtime configuration for the isolated knowledge base service."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[4]
DEFAULT_DATABASE_PATH = REPOSITORY_ROOT / "database" / "sqlite" / "med_docs.sqlite"


@dataclass(frozen=True)
class Settings:
    database_path: Path
    host: str = "127.0.0.1"
    port: int = 8090

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            database_path=Path(os.environ.get("MED_KB_DB_PATH", DEFAULT_DATABASE_PATH)),
            host=os.environ.get("MED_KB_HOST", "127.0.0.1"),
            port=int(os.environ.get("MED_KB_PORT", "8090")),
        )
