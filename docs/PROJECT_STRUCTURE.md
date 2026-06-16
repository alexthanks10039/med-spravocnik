# Структура проекта

```text
med-spravocnik/
├── .devcontainer/              GitHub Codespaces Preview
├── apps/
│   └── frontend-flutter/       активный Flutter-клиент
├── services/
│   ├── knowledge-api/          FastAPI + read-only SQLite/FTS5/TF-IDF
│   └── calculator-api/         FastAPI + 152 калькулятора
├── scripts/
│   ├── ingestion/              Docling/OCR pipeline
│   ├── setup.ps1
│   ├── start-full.ps1
│   └── test.ps1
├── database/
│   ├── sqlite/                 приватная med_docs.sqlite, не в Git
│   └── embeddings/             приватные индексы, не в Git
├── config/                     безопасные примеры конфигурации
├── preview-codeplace/          автономный synthetic-data Preview
├── assets/                     общие изображения
├── docs/                       документация активной версии
└── archive/
    └── node-postgres-mvp/      предыдущая реализация
```

## Границы ответственности

- Pipeline создает производные данные, но не запускается при старте приложения.
- Knowledge API читает корпус в режиме read-only.
- Calculator API не исполняет формулы, извлеченные из OCR.
- Flutter работает с двумя типизированными API-контрактами.
- Preview не зависит от production-корпуса и основных виртуальных окружений.

## Источник истины

Активным кодом считаются `apps`, `services`, `scripts/ingestion` и корневые
документы. Содержимое `archive` не участвует в сборке и сохраняется только для
истории и возможного извлечения отдельных идей.
