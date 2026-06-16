from fastapi.testclient import TestClient

from app import app


client = TestClient(app)


def test_preview_health() -> None:
    payload = client.get("/health").json()
    assert payload["status"] == "healthy"
    assert payload["mode"] == "public-demo"


def test_preview_search_and_presentation() -> None:
    results = client.get("/knowledge/api/search", params={"q": "HELLP"}).json()["results"]
    assert results[0]["doc_id"] == "demo-hellp"
    document = client.get("/knowledge/api/documents/demo-hellp/presentation").json()
    assert document["document"]["title"] == "HELLP-синдром"


def test_preview_calculator() -> None:
    response = client.post(
        "/calculator/api/v1/calculate/bmi",
        json={"params": {"weight_kg": 70, "height_cm": 175}},
    )
    assert response.status_code == 200
    assert response.json()["result"]["value"] == 22.9
