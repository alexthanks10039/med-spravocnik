# Codeplace Preview

This is an isolated public demo. It does not load the production SQLite corpus,
OCR documents, embeddings, secrets or patient data.

Run with Python:

```bash
python -m venv .venv
python -m pip install -r preview-codeplace/requirements.txt
python -m uvicorn app:app --app-dir preview-codeplace --host 0.0.0.0 --port 8787
```

Or with Docker:

```bash
docker compose -f preview-codeplace/compose.yaml up --build
```

Open `http://localhost:8787`. API documentation is available at `/docs`.

Differences from the full application:

- three synthetic documents instead of the private corpus;
- two demonstration calculators instead of the full calculator service;
- no Flutter build, neural embeddings, authentication or persistence;
- endpoints are compatible only with the main user flows required for preview.
