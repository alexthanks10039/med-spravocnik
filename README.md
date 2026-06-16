# МедСправочник

Медицинская база знаний и набор валидированных калькуляторов с Flutter-клиентом.
Активная версия синхронизирована с локальным проектом и состоит из двух
изолированных FastAPI-сервисов.

> Система предназначена для справочного использования. Preview содержит только
> синтетические данные и не подходит для медицинских решений.

## Компоненты

| Путь | Назначение |
|---|---|
| `apps/frontend-flutter` | Flutter web, Android, iOS и Windows клиент |
| `services/knowledge-api` | Поиск, evidence, citations и presentation blocks |
| `services/calculator-api` | 152 исполняемых медицинских калькулятора |
| `scripts/ingestion` | Локальный Docling/OCR pipeline |
| `database` | Место подключения приватной SQLite и индексов |
| `preview-codeplace` | Быстрый публичный Preview без приватного корпуса |
| `archive/node-postgres-mvp` | Предыдущий Node/PostgreSQL MVP |

Подробная схема: [docs/PROJECT_STRUCTURE.md](docs/PROJECT_STRUCTURE.md).

## Быстрый Preview

```bash
python -m venv .venv
python -m pip install -r preview-codeplace/requirements.txt
python -m uvicorn app:app --app-dir preview-codeplace --host 0.0.0.0 --port 8787
```

Откройте `http://localhost:8787`. В GitHub Codespaces Preview устанавливается и
запускается автоматически через `.devcontainer/devcontainer.json`.

## Полная локальная версия

Требования: Python 3.11+, Flutter 3.44+, существующий медицинский корпус.

```powershell
.\scripts\setup.ps1
$env:MED_KB_DB_PATH="D:\path\to\med_docs.sqlite"
.\scripts\start-full.ps1
```

По умолчанию knowledge API ищет базу в
`database/sqlite/med_docs.sqlite`. Приватную базу и PDF нельзя коммитить.

Ручной запуск сервисов описан в [docs/SETUP.md](docs/SETUP.md).

## Проверка

```powershell
.\scripts\test.ps1
```

Проверяются Knowledge API, Calculator API, Flutter и изолированный Preview.

## Переменные окружения

| Переменная | Назначение |
|---|---|
| `MED_KB_DB_PATH` | абсолютный путь к приватной SQLite |
| `MED_KB_HOST` | адрес Knowledge API, по умолчанию `127.0.0.1` |
| `MED_KB_PORT` | порт Knowledge API, по умолчанию `8090` |
| `CALCULATOR_API_URL` | compile-time URL для Flutter |
| `KNOWLEDGE_API_URL` | compile-time URL для Flutter |

## Нельзя коммитить

- `.env`, токены, ключи и пароли;
- исходные медицинские PDF и OCR-результаты;
- SQLite, embeddings, дампы и журналы;
- `.venv`, `node_modules`, Flutter `build`, `dist`, кэши IDE;
- hidden/internal benchmark splits калькуляторов.

## Документация

- [Установка](docs/SETUP.md)
- [Архитектура](docs/ARCHITECTURE.md)
- [Разработка](docs/DEVELOPMENT.md)
- [Codeplace Preview](docs/CODEPLACE_PREVIEW.md)
- [Аудит миграции](docs/AUDIT_REPORT.md)
- [История изменений](docs/CHANGELOG.md)
