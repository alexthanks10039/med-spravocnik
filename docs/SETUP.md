# Установка и запуск

## Windows: полная версия

1. Установите Python 3.11+, Flutter и Git.
2. Подключите приватную базу как `database/sqlite/med_docs.sqlite` или установите
   `MED_KB_DB_PATH`.
3. Выполните:

```powershell
.\scripts\setup.ps1
.\scripts\start-full.ps1
```

Launcher собирает Flutter web, запускает оба backend и открывает
`http://127.0.0.1:8787`.

## Ручной запуск Knowledge API

```powershell
cd services\knowledge-api
.\.venv\Scripts\python.exe -m medical_kb.api
```

## Ручной запуск Calculator API

```powershell
cd services\calculator-api
.\.venv\Scripts\python.exe -m uvicorn src.infrastructure.api.server:create_api_app `
  --factory --host 127.0.0.1 --port 8080
```

## Flutter отдельно

```powershell
cd apps\frontend-flutter
flutter pub get
flutter run -d chrome `
  --dart-define=CALCULATOR_API_URL=http://127.0.0.1:8080 `
  --dart-define=KNOWLEDGE_API_URL=http://127.0.0.1:8090
```

## Preview

```bash
python -m pip install -r preview-codeplace/requirements.txt
python -m uvicorn app:app --app-dir preview-codeplace --host 0.0.0.0 --port 8787
```

## Pipeline

Pipeline запускается отдельно и никогда автоматически:

```powershell
cd scripts\ingestion
python med_pipeline.py test-one --root "D:\path\to\pipeline" --no-embeddings
```

Подробности находятся в `scripts/ingestion/README.md`.
