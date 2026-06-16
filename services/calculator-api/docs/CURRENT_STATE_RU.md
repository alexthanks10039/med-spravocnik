# Текущее состояние проекта

Дата актуализации: 14 июня 2026 года. Версия: `1.6.2`.

## Назначение

Medical Calculator MCP Server предоставляет проверяемые медицинские формулы и шкалы для AI-агентов и HTTP-клиентов. Языковая модель выбирает инструмент и извлекает параметры, а расчёт выполняется детерминированным Python-кодом с валидацией и ссылками на публикации.

Это программный компонент поддержки решений, а не медицинское изделие и не замена клинической оценки.

## Фактический объём

- 152 калькулятора;
- 31 основная медицинская специальность;
- 2095 тестов зарегистрированы в актуальном pytest cache и документации;
- Python 3.11-3.13 проверяются в CI;
- 287 PMID и 245 DOI указаны в текущем quality snapshot;
- MCP stdio, MCP SSE, MCP streamable HTTP и REST API;
- версия OpenAPI и пакета: `1.6.2`.

Каталог генерируется из live registry: [CALCULATOR_CATALOG.md](CALCULATOR_CATALOG.md).

## Архитектура

```text
src/
├── domain/          калькуляторы, registry, validation, value objects
├── application/     use cases и DTO
├── infrastructure/
│   ├── mcp/         FastMCP, tools, resources и prompts
│   ├── api/         FastAPI REST API
│   ├── security/    API keys и rate limiting
│   └── logging/     события использования инструментов
└── shared/          provenance, benchmarking и readiness
```

Domain не зависит от транспортов. MCP и REST используют общий registry и application use cases, поэтому формулы не дублируются.

## Точки входа

| Сценарий | Команда | Порт |
|----------|---------|------|
| MCP stdio | `uv run python -m src.main` | нет |
| MCP SSE | `uv run python -m src.main --mode sse` | 8000 |
| MCP HTTP | `uv run python -m src.main --mode http` | 8000 |
| REST API | `uv run python -m src.infrastructure.api.server` | 8080 |
| Docker Compose | `docker compose up --build` | 8000 и 8080 |

Старый режим `src.main --mode api` больше не является действительной точкой входа REST.

## REST API

Основные endpoints:

- `GET /health` — liveness;
- `GET /ready` — readiness и production perimeter;
- `GET /api/v1/calculators` — список, до 250 записей;
- `GET /api/v1/calculators/{tool_id}` — метаданные;
- `GET /api/v1/calculators/{tool_id}/schema` — поля формы, типы, диапазоны и варианты;
- `GET /api/v1/search` — поиск;
- `GET /api/v1/specialties` и `/contexts` — таксономия;
- `POST /api/v1/calculate/{tool_id}` — универсальный расчёт;
- `POST /api/v1/ckd-epi` и `/sofa` — быстрые endpoints.

Полный контракт генерируется из FastAPI OpenAPI в `docs_site/api/openapi.json` и `docs_site/api/rest-api.md`.

## Безопасность

В development API keys и rate limiting отключены по умолчанию. Production readiness требует:

1. `SECURITY_AUTH_ENABLED=true` и непустой `SECURITY_API_KEYS`;
2. `SECURITY_RATE_LIMIT_ENABLED=true`;
3. ограниченный `CORS_ORIGINS`, не `*`;
4. `SSL_ENABLED=true` либо `TRUST_REVERSE_PROXY_SSL=true`;
5. загруженный registry и полное покрытие formula provenance.

Проверка: `uv run python scripts/check_production_readiness.py --service all --environment production`.

## Документация и генерация

Не редактируются вручную:

- `docs/CALCULATOR_CATALOG.md`;
- `docs_site/api/openapi.json`;
- `docs_site/api/rest-api.md`.

Команды обновления:

```bash
uv run python scripts/generate_tool_catalog_docs.py
uv run python scripts/generate_openapi_spec.py
uv run python scripts/generate_rest_api_docs.py
uv run python scripts/check_project_consistency.py --check-tests
```

## Тестирование

CI выполняет Ruff, форматирование, mypy, consistency checks, pytest с минимальным coverage 70%, production readiness, benchmark smoke, Docker test и release pipeline.

```bash
uv sync --frozen --extra dev --group dev
uv run ruff check .
uv run ruff format src tests scripts --check
uv run mypy --no-incremental src tests
uv run python scripts/check_project_consistency.py --check-tests
uv run pytest tests --cov=src --cov-report=term-missing --cov-fail-under=70
```

## Локальные незакоммиченные изменения

На дату актуализации рабочая копия содержит изменения Docker-сборки и REST API:

- в Docker image добавлены `README.md`, `LICENSE` и каталог `data/`;
- REST-сервис Compose запускается через `src.infrastructure.api.server`;
- лимит списка калькуляторов увеличен до 200 по умолчанию и 250 максимум;
- добавлен endpoint `/api/v1/calculators/{tool_id}/schema` для динамических UI-форм.

Эти изменения ещё не входят в коммит `45f648d` и должны пройти CI перед публикацией.

## Известные ограничения

- сервис не хранит пациентов и не должен получать PHI;
- API-key модель подходит для service-to-service доступа, но не заменяет полноценную пользовательскую IAM;
- in-memory rate limiter не является распределённым;
- отсутствуют централизованные метрики, tracing, SIEM-аудит, vault/KMS и формальные disaster-recovery процедуры;
- перед коммерческим медицинским использованием необходимы регуляторная оценка, клиническая валидация и процесс управления изменениями формул.

## Ближайшие шаги

1. Завершить и протестировать текущий dynamic schema API.
2. Исправить legacy REST-команду в HTTPS Compose.
3. Перегенерировать OpenAPI и REST reference.
4. Прогнать полный CI на Python 3.11-3.13.
5. Добавить contract tests для schema endpoint и динамических форм.
6. Определить production observability, secret management и compliance boundary.
