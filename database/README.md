# Runtime data

The production corpus is intentionally not committed to Git.

- Place the read-only corpus at `database/sqlite/med_docs.sqlite`, or set
  `MED_KB_DB_PATH` to another absolute path.
- Place the optional TF-IDF artifact at `database/embeddings/tfidf.pkl`.
- Keep source PDFs, OCR output, logs and neural vector files outside Git.

The `preview-codeplace` application uses its own small public demo dataset and
does not read this directory.
