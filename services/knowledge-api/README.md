# Medical Knowledge Base

Изолированный read-only сервис поиска и подготовки RAG-контекста для локального
корпуса медицинских протоколов. Проект не является калькулятором и не изменяет
`CALCULATOR BAZA`.

## Что уже используется

- SQLite подключается как `database/sqlite/med_docs.sqlite` или через
  `MED_KB_DB_PATH` и не хранится в Git.
- 1135 документов
- 16147 таблиц
- 155742 чанка
- 24855 структурированных сущностей
- SQLite FTS5, полный TF-IDF индекс, entity search и metadata filters

Полный TF-IDF индекс построен для всех 155742 chunks. Neural embeddings в
текущей базе отсутствуют. API работает без внешних AI-сервисов и возвращает RAG
evidence array с цитатами. Vector search можно добавить позже как дополнительный
канал retrieval.

## Запуск

```powershell
cd services\knowledge-api
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -e ".[dev]"
.\.venv\Scripts\python.exe -m medical_kb.api
```

По умолчанию API доступен на `http://127.0.0.1:8090`, документация на `/docs`.

Другой путь к базе:

```powershell
$env:MED_KB_DB_PATH="D:\path\to\med_docs.sqlite"
```

## Основные endpoints

- `GET /health`
- `GET /ready`
- `GET /api/pipeline/status`
- `GET /api/documents`
- `GET /api/documents/{doc_id}`
- `GET /api/documents/{doc_id}/presentation`
- `GET /api/document-families/{family_id}`
- `GET|POST /api/search`
- `POST /api/rag/query`
- `GET /api/tables/{table_id}`
- `GET /api/entities`
- `GET /api/quality/issues`
- `GET /api/clinical/categories`
- `GET /api/clinical/diseases`
- `GET /api/clinical/diseases/{doc_id}`
- `GET /api/clinical/diseases/{doc_id}/recommendations`

Presentation endpoint очищает только выдачу: декодирует HTML entities,
нормализует OCR-маркеры списков и формирует типизированные блоки для UI.
Таблицы с сомнительной структурой получают `render_mode=fallback`. Исходные
чанки и таблицы в SQLite не перезаписываются.

Пример RAG-запроса:

```powershell
Invoke-RestMethod -Method Post `
  -Uri http://127.0.0.1:8090/api/rag/query `
  -ContentType application/json `
  -Body '{"query":"диагностические критерии HELLP ЛДГ","max_evidence":5}'
```

`version_policy` по умолчанию равен `all`. Текущая автоматическая группировка
версий ненадежна для документов с общими OCR-заголовками, поэтому
`latest_known` нужно включать только после проверки конкретного семейства.

## Проверка

```powershell
.\.venv\Scripts\python.exe -m pytest -q
```

На 15 июня 2026 года проходят 12 тестов, включая read-only SQLite, отсутствие
базы, presentation blocks, references и fallback повреждённых таблиц.

## Что ещё не реализовано

- neural embeddings и vector search;
- генерация итогового ответа LLM;
- migrations/schema versioning;
- production authentication, audit log и ограниченный CORS;
- автоматическое исправление ошибочных document families и `section_id` таблиц.

Общая документация проекта:

- [архитектура](../../docs/ARCHITECTURE.md);
- [установка](../../docs/SETUP.md);
- [аудит миграции](../../docs/AUDIT_REPORT.md).
