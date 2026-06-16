# Локальный конвейер медицинских PDF

MVP обрабатывает PDF локально: Docling -> Markdown/JSON -> manifest -> SQLite ->
структурные chunks/entities/tables -> локальный индекс -> RAG JSONL и QC-отчёты.
Исходные PDF только читаются. Внешние AI API не используются.

## Подготовка

```bash
cd "/mnt/d/DEV/PDF MED"
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 med_pipeline.py init
```

На Windows замените активацию на `.venv\Scripts\activate` и используйте `python`.
Путь можно задать для любой команды: `--root "/mnt/d/DEV/PDF MED"`.

## Основные команды

```bash
python3 med_pipeline.py test-one --no-embeddings
python3 med_pipeline.py run-all --no-embeddings
python3 med_pipeline.py run-all --offline
python3 med_pipeline.py run-all --download-model
python3 med_pipeline.py search "HELLP диагностические критерии ЛДГ"
```

По шагам:

```bash
python3 med_pipeline.py init
python3 med_pipeline.py docling --limit 1
python3 med_pipeline.py scan
python3 med_pipeline.py ingest-one --base-name "HELLP-СИНДРОМ"
python3 med_pipeline.py ingest-all --resume
python3 med_pipeline.py build-embeddings --no-embeddings
python3 med_pipeline.py build-presentation
python3 med_pipeline.py export-presentation
python3 med_pipeline.py export-rag
python3 med_pipeline.py report
```

`--no-embeddings` полностью отключает neural embeddings и строит TF-IDF, если
установлен scikit-learn. Даже без него поиск работает через SQLite FTS5/LIKE.
`--offline` запрещает загрузку модели sentence-transformers. `--download-model`
разрешает первое скачивание модели; документы никуда не отправляются.

## Структура результата

Все производные данные находятся в `Результат`: `markdown_out`, `json_out`,
`tables_out`, `sqlite/med_docs.sqlite`, `embeddings`, `logs` и `reports`.
Manifest: `reports/manifest.csv` и `.json`. RAG export: `rag_chunks.jsonl`,
`rag_tables.jsonl`, `rag_entities.jsonl`, `rag_manifest.json`.

## Presentation layer

`build-presentation` создаёт и заполняет производную таблицу
`presentation_blocks`. Команда не изменяет `chunks.text`: display-текст,
ссылки, определения, сокращения, лабораторные пороги и таблицы хранятся
отдельно. Для table blocks используются `tables.columns_json` и
`tables.rows_json`.

`export-presentation` экспортирует таблицу в
`Результат/reports/presentation_blocks.jsonl`.

Для одного PDF используйте `test-one`; для корпуса — `run-all`. Ошибки смотрите
в `Результат/logs/pipeline.log`, `errors.csv` и специализированных CSV-логах.
