# Codeplace Preview

Preview предназначен для быстрого знакомства с проектом в GitHub Codespaces
или локальном контейнере.

## Автоматический запуск в Codespaces

Откройте репозиторий в Codespaces. Dev Container:

1. устанавливает зависимости `preview-codeplace/requirements-dev.txt`;
2. запускает Uvicorn на порту `8787`;
3. открывает forwarded preview.

## Локальный запуск

```bash
docker compose -f preview-codeplace/compose.yaml up --build
```

или:

```bash
python -m pip install -r preview-codeplace/requirements.txt
python -m uvicorn app:app --app-dir preview-codeplace --host 0.0.0.0 --port 8787
```

## Отличия от полной версии

| Preview | Полная версия |
|---|---|
| 3 synthetic-документа | приватный корпус из 1135 документов |
| 2 demo-калькулятора | 152 калькулятора |
| простой in-memory поиск | FTS5, TF-IDF, entities, metadata |
| нет Flutter build | полноценный Flutter-клиент |
| нет persistence и auth | отдельные production-задачи |

Preview не должен подключаться к production SQLite или внешним секретам.
