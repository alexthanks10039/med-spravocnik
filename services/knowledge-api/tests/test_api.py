from __future__ import annotations

from fastapi.testclient import TestClient

from medical_kb.api import app, repository


def test_health() -> None:
    with TestClient(app) as client:
        response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


def test_missing_database_keeps_service_alive(monkeypatch, tmp_path) -> None:
    monkeypatch.setenv("MED_KB_DB_PATH", str(tmp_path / "missing.sqlite"))
    repository.cache_clear()
    try:
        with TestClient(app) as client:
            health = client.get("/health")
            ready = client.get("/ready")
            status = client.get("/api/pipeline/status")
        assert health.status_code == 200
        assert ready.status_code == 503
        assert status.status_code == 200
        assert status.json()["available"] is False
    finally:
        repository.cache_clear()
