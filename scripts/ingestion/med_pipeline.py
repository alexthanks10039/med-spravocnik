#!/usr/bin/env python3
"""Fully local MVP ingestion/RAG pipeline for medical PDF documents."""
from __future__ import annotations

import argparse
import csv
import hashlib
import html
import json
import logging
import os
import pickle
import re
import sqlite3
import sys
import traceback
import uuid
from collections import defaultdict
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Iterator, Optional

DEFAULT_MODEL = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
RESULT_DIRS = ("docling_out", "markdown_out", "json_out", "tables_out", "sqlite", "embeddings", "logs", "reports")
LOG_CSVS = ("docling_log.csv", "scan_log.csv", "ingest_log.csv", "embedding_log.csv", "errors.csv")


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def stable_id(prefix: str, value: str) -> str:
    return f"{prefix}_{hashlib.sha256(value.encode('utf-8')).hexdigest()[:20]}"


def normalize_ocr_artifacts(text: str) -> str:
    text = html.unescape(text or "")
    replacements = {
        "МКБ -10": "МКБ-10", "HELLPсиндром": "HELLP-синдром",
        "HELLP синдром": "HELLP-синдром", "HELLP -синдром": "HELLP-синдром",
        "AЛT": "АЛТ", "АCТ": "АСТ", "10 9 /л": "10^9/л",
        "МЕ /л": "МЕ/л", "мг / дл": "мг/дл",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text


def normalize_text(text: str) -> str:
    return re.sub(r"\s+", " ", normalize_ocr_artifacts(text)).strip()


def normalize_title(text: str) -> str:
    return normalize_text(text).strip(" .:-").casefold()


def normalize_icd10(value: str) -> str:
    return value.upper().replace("О", "O").replace("–", "-").replace("—", "-").replace(" ", "")


def normalize_units(value: str) -> str:
    value = normalize_text(value)
    mapping = {"МЕ/л": "IU/L", "мг/дл": "mg/dL", "%": "%", "мм3": "mm3", "мг": "mg", "г": "g", "г/ч": "g/h", "мг/час": "mg/h"}
    return mapping.get(value, value)


def normalize_medical_terms(text: str) -> str:
    return normalize_text(text).replace("ЛДГ", "лактатдегидрогеназа")


REFERENCE_RE = re.compile(r"\[(\d+(?:\s*[,;–—-]\s*\d+)*)\]")
PRIVATE_USE_RE = re.compile(r"[\ue000-\uf8ff]")


def normalize_display_text(raw_text: str) -> tuple[str, list[dict[str, Any]]]:
    """Normalize text for display without mutating the source chunk."""
    text = html.unescape(raw_text or "")
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = text.replace("\u00a0", " ").replace("\u00ad", "")
    text = re.sub(r"[\u200b-\u200f\u202a-\u202e\u2060\ufeff]", "", text)
    text = re.sub(r"(?m)^[\ue000-\uf8ff]\s*", "• ", text)
    text = PRIVATE_USE_RE.sub("", text).replace("�", "")
    text = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]", "", text)

    references: list[dict[str, Any]] = []
    seen: set[str] = set()

    def collect_reference(match: re.Match[str]) -> str:
        label = match.group(0)
        if label not in seen:
            seen.add(label)
            references.append({
                "label": label,
                "numbers": [int(value) for value in re.findall(r"\d+", match.group(1))],
            })
        return ""

    text = REFERENCE_RE.sub(collect_reference, text)
    text = text.replace(" - ", " — ")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r" +([,.;:!?])", r"\1", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip(), references


def split_display_paragraphs(text: str, target_chars: int = 650) -> list[str]:
    """Split display text into readable paragraphs while preserving its words."""
    explicit = [part.strip() for part in re.split(r"\n\s*\n", text) if part.strip()]
    paragraphs: list[str] = []
    for part in explicit:
        if len(part) <= target_chars:
            paragraphs.append(part)
            continue
        sentences = re.split(r"(?<=[.!?;:])\s+(?=[А-ЯЁA-Z•])", part)
        buffer = ""
        for sentence in sentences:
            sentence = sentence.strip()
            if not sentence:
                continue
            if buffer and len(buffer) + len(sentence) + 1 > target_chars:
                paragraphs.append(buffer)
                buffer = ""
            if len(sentence) > target_chars and not buffer:
                words = sentence.split()
                line = ""
                for word in words:
                    if line and len(line) + len(word) + 1 > target_chars:
                        paragraphs.append(line)
                        line = ""
                    line += (" " if line else "") + word
                buffer = line
            else:
                buffer += (" " if buffer else "") + sentence
        if buffer:
            paragraphs.append(buffer)
    return paragraphs or ([text] if text else [])


def _json_value(value: Any, default: Any) -> Any:
    if value in (None, ""):
        return default
    if isinstance(value, (dict, list)):
        return value
    try:
        return json.loads(value)
    except (TypeError, json.JSONDecodeError):
        return default


def _row_value(row: Any, key: str, default: Any = None) -> Any:
    if row is None:
        return default
    if isinstance(row, dict):
        return row.get(key, default)
    try:
        value = row[key]
    except (KeyError, IndexError, TypeError):
        return default
    return default if value is None else value


WRONG_ABBREVIATION_HEADERS_RE = re.compile(
    r"Колонка\s+([^:;]+):\s*([^;]*);\s*"
    r"Колонка\s+[-—–]:\s*[-—–];\s*"
    r"Колонка\s+([^:;]+):\s*([^;]*)(?:;|$)",
    re.I,
)


def _is_dash(value: Any) -> bool:
    return str(value or "").strip() in {"-", "—", "–"}


def _looks_like_abbreviation_pair(row: list[Any]) -> bool:
    if len(row) < 3 or not _is_dash(row[1]):
        return False
    term = normalize_text(str(row[0]))
    expansion = normalize_text(str(row[2]))
    if not term or not expansion or len(term) > 45:
        return False
    if len(expansion) <= len(term) and " " not in expansion:
        return False
    return not bool(re.search(r"[.!?;:]$", term))


def _table_markdown(columns: list[str], rows: list[list[str]]) -> str:
    def escape(value: Any) -> str:
        return str(value or "").replace("|", "\\|").replace("\n", "<br>")

    header = "| " + " | ".join(escape(value) for value in columns) + " |"
    separator = "|" + "|".join("---" for _ in columns) + "|"
    body = ["| " + " | ".join(escape(value) for value in row) + " |" for row in rows]
    return "\n".join([header, separator, *body])


def _table_cells(columns: list[str], rows: list[list[str]]) -> list[dict[str, Any]]:
    cells: list[dict[str, Any]] = []
    for row_index, row in enumerate([columns, *rows]):
        for column_index, value in enumerate(row):
            cells.append({
                "row": row_index,
                "column": column_index,
                "text": value,
                "column_header": row_index == 0,
                "row_header": False,
            })
    return cells


def restore_abbreviation_table(table: Any) -> dict[str, Any]:
    """Restore abbreviation tables where Docling promoted row 1 to headers."""
    source = dict(table) if isinstance(table, (dict, sqlite3.Row)) else {}
    source_flags = _json_value(source.get("quality_flags_json"), [])
    if (
        source.get("table_type") == "abbreviations"
        and "restored_from_wrong_headers" in source_flags
    ):
        return source
    columns = _json_value(source.get("columns_json", source.get("columns")), [])
    rows = _json_value(source.get("rows_json", source.get("rows")), [])
    plain_text = str(source.get("plain_text") or "")
    parsed_matches = list(WRONG_ABBREVIATION_HEADERS_RE.finditer(plain_text))

    candidate_rows: list[list[str]] = []
    if isinstance(columns, list) and isinstance(rows, list):
        combined = [columns, *rows]
        valid = [row for row in combined if isinstance(row, list) and len(row) >= 3]
        dash_ratio = (
            sum(1 for row in valid if _is_dash(row[1])) / len(valid)
            if valid
            else 0.0
        )
        pair_ratio = (
            sum(1 for row in valid if _looks_like_abbreviation_pair(row)) / len(valid)
            if valid
            else 0.0
        )
        if len(valid) >= 2 and dash_ratio >= 0.8 and pair_ratio >= 0.7:
            candidate_rows = [
                [normalize_text(str(row[0])), "—", normalize_text(str(row[2]))]
                for row in valid
            ]

    if not candidate_rows and len(parsed_matches) >= 1:
        first = parsed_matches[0]
        candidate_rows.append([
            normalize_text(first.group(1)),
            "—",
            normalize_text(first.group(3)),
        ])
        candidate_rows.extend(
            [normalize_text(match.group(2)), "—", normalize_text(match.group(4))]
            for match in parsed_matches
            if normalize_text(match.group(2)) or normalize_text(match.group(4))
        )

    if not candidate_rows:
        return source

    restored_columns = ["Сокращение", "—", "Расшифровка"]
    readable_text = "Сокращения: " + "; ".join(
        f"{row[0]} — {row[2]}" for row in candidate_rows
    )
    flags = list(dict.fromkeys([
        *source_flags,
        "restored_from_wrong_headers",
        "abbreviation_table",
    ]))
    source.update({
        "columns_json": j(restored_columns),
        "rows_json": j(candidate_rows),
        "cells_json": j(_table_cells(restored_columns, candidate_rows)),
        "markdown": _table_markdown(restored_columns, candidate_rows),
        "plain_text": readable_text,
        "table_type": "abbreviations",
        "quality_flags_json": j(flags),
    })
    return source


def build_presentation_blocks(
    chunk: Any,
    section: Any,
    entities: list[Any],
    table: Any,
) -> list[dict[str, Any]]:
    """Build frontend-ready blocks from immutable SQLite source records."""
    chunk_id = str(_row_value(chunk, "chunk_id", ""))
    content_type = str(_row_value(chunk, "content_type", "text"))
    section_type_value = str(_row_value(section, "section_type", "unknown"))
    title = str(_row_value(section, "title", "") or _row_value(chunk, "section_path", ""))
    raw_text = str(_row_value(chunk, "text", "") or "")
    text, references = normalize_display_text(raw_text)
    blocks: list[dict[str, Any]] = []

    table_data = _json_value(_row_value(chunk, "table_json"), {})
    table_id = table_data.get("table_id") if isinstance(table_data, dict) else None
    if content_type in {"table", "table_row"}:
        restored_table = restore_abbreviation_table(table)
        columns = _json_value(_row_value(restored_table, "columns_json"), [])
        rows = _json_value(_row_value(restored_table, "rows_json"), [])
        displayed_rows = rows
        row_index = None
        if content_type == "table_row":
            requested_row = table_data.get("row") if isinstance(table_data, dict) else None
            row_index = next((index for index, row in enumerate(rows) if row == requested_row), None)
            displayed_rows = [rows[row_index]] if row_index is not None else []
        table_references: list[dict[str, Any]] = []
        normalized_columns = []
        for cell in columns:
            normalized, cell_refs = normalize_display_text(str(cell))
            normalized_columns.append(normalized)
            table_references.extend(cell_refs)
        normalized_rows = []
        for row in displayed_rows:
            normalized_row = []
            for cell in row:
                normalized, cell_refs = normalize_display_text(str(cell))
                normalized_row.append(normalized)
                table_references.extend(cell_refs)
            normalized_rows.append(normalized_row)
        restored_table_type = _row_value(restored_table, "table_type", "unknown")
        return [{
            "block_type": "table" if restored_table_type == "abbreviations" else content_type,
            "title": str(_row_value(restored_table, "title", "") or title),
            "body": {
                "table_id": table_id or _row_value(restored_table, "table_id"),
                "table_type": restored_table_type,
                "columns": normalized_columns,
                "rows": normalized_rows,
                "row_index": row_index,
                "readable_text": _row_value(restored_table, "plain_text", ""),
                "markdown": _row_value(restored_table, "markdown", ""),
                "quality_flags": _json_value(
                    _row_value(restored_table, "quality_flags_json"), []
                ),
            },
            "references": table_references,
        }]

    if section_type_value == "abbreviations":
        items = [line.strip() for line in text.splitlines() if line.strip()]
        if len(items) == 1:
            items = [part.strip() for part in re.split(r";\s*", items[0]) if part.strip()]
        blocks.append({
            "block_type": "abbreviations",
            "title": title,
            "body": {"items": items},
            "references": references,
        })
    else:
        definition = bool(
            re.search(r"\b(определение|дефиниция)\b", title, re.I)
            or re.match(r"^[^.!?]{2,100}\s+[—-]\s+", text)
        )
        base_type = "definition" if definition else (
            content_type if content_type != "text" else section_type_value
        )
        if base_type == "unknown":
            base_type = "paragraph"
        for index, paragraph in enumerate(split_display_paragraphs(text)):
            blocks.append({
                "block_type": base_type,
                "title": title if index == 0 else None,
                "body": {"text": paragraph},
                "references": references if index == 0 else [],
            })

    thresholds = [entity for entity in entities if _row_value(entity, "type") == "lab_threshold"]
    for entity in thresholds:
        blocks.append({
            "block_type": "lab_threshold",
            "title": _row_value(entity, "canonical_name") or "Лабораторный порог",
            "body": {
                "raw_text": _row_value(entity, "raw_text"),
                "canonical_name": _row_value(entity, "canonical_name"),
                "operator": _row_value(entity, "operator"),
                "value": _row_value(entity, "value"),
                "unit": _row_value(entity, "unit"),
                "normalized_unit": _row_value(entity, "normalized_unit"),
                "clinical_context": _row_value(entity, "clinical_context"),
            },
            "references": [],
        })
    return blocks or [{
        "block_type": "paragraph",
        "title": title,
        "body": {"text": text},
        "references": references,
    }]


def sha256(path: Optional[Path]) -> Optional[str]:
    if not path or not path.exists():
        return None
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def is_duplicate_name(path: Path) -> bool:
    return bool(re.search(r" \(\d+\)$", path.stem))


@dataclass
class Paths:
    root: Path

    @property
    def sources(self) -> Path: return self.root / "Исходники"
    @property
    def result(self) -> Path: return self.root / "Результат"
    @property
    def db(self) -> Path: return self.result / "sqlite" / "med_docs.sqlite"
    def out(self, name: str) -> Path: return self.result / name


SCHEMA = """
CREATE TABLE IF NOT EXISTS source_files (id INTEGER PRIMARY KEY AUTOINCREMENT, source_id TEXT UNIQUE, base_name TEXT, source_pdf_path TEXT, markdown_path TEXT, docling_json_path TEXT, source_hash TEXT, markdown_hash TEXT, json_hash TEXT, has_pdf INTEGER, has_markdown INTEGER, has_json INTEGER, status TEXT, warnings_json TEXT, created_at TEXT, updated_at TEXT);
CREATE TABLE IF NOT EXISTS documents (id INTEGER PRIMARY KEY AUTOINCREMENT, doc_id TEXT UNIQUE, document_family_id TEXT, source_id TEXT, title TEXT, normalized_title TEXT, language TEXT, country TEXT, document_type TEXT, clinical_domain_json TEXT, icd10_codes_json TEXT, approval_date TEXT, revision_date TEXT, protocol_number TEXT, approval_authority TEXT, status TEXT, version_label TEXT, warnings_json TEXT, ocr_quality_flags_json TEXT, processing_json TEXT, created_at TEXT, updated_at TEXT);
CREATE TABLE IF NOT EXISTS document_families (id INTEGER PRIMARY KEY AUTOINCREMENT, document_family_id TEXT UNIQUE, canonical_title TEXT, canonical_disease TEXT, icd10_codes_json TEXT, country TEXT, document_type TEXT, clinical_domain_json TEXT, latest_doc_id TEXT, aliases_json TEXT, duplicate_groups_json TEXT, created_at TEXT, updated_at TEXT);
CREATE TABLE IF NOT EXISTS sections (id INTEGER PRIMARY KEY AUTOINCREMENT, section_id TEXT UNIQUE, doc_id TEXT, parent_section_id TEXT, section_path TEXT, title TEXT, normalized_title TEXT, level INTEGER, order_index INTEGER, section_type TEXT, page_start INTEGER, page_end INTEGER, quality_flags_json TEXT, created_at TEXT);
CREATE TABLE IF NOT EXISTS tables (id INTEGER PRIMARY KEY AUTOINCREMENT, table_id TEXT UNIQUE, doc_id TEXT, section_id TEXT, title TEXT, table_type TEXT, columns_json TEXT, rows_json TEXT, cells_json TEXT, markdown TEXT, plain_text TEXT, extracted_entities_json TEXT, page_hint_json TEXT, quality_flags_json TEXT, created_at TEXT);
CREATE TABLE IF NOT EXISTS entities (id INTEGER PRIMARY KEY AUTOINCREMENT, entity_id TEXT UNIQUE, doc_id TEXT, chunk_id TEXT, section_id TEXT, type TEXT, raw_text TEXT, normalized_text TEXT, canonical_name TEXT, value TEXT, operator TEXT, unit TEXT, normalized_unit TEXT, clinical_context TEXT, evidence_level TEXT, confidence REAL, source_location_json TEXT, created_at TEXT);
CREATE TABLE IF NOT EXISTS chunks (id INTEGER PRIMARY KEY AUTOINCREMENT, chunk_id TEXT UNIQUE, doc_id TEXT, document_family_id TEXT, section_id TEXT, section_path TEXT, content_type TEXT, text TEXT, table_json TEXT, keywords_json TEXT, entity_refs_json TEXT, icd10_codes_json TEXT, clinical_domain_json TEXT, version TEXT, page_hint_json TEXT, embedding_text TEXT, source_refs_json TEXT, quality_json TEXT, created_at TEXT);
CREATE TABLE IF NOT EXISTS embeddings (id INTEGER PRIMARY KEY AUTOINCREMENT, chunk_id TEXT UNIQUE, model_name TEXT, vector_json TEXT, vector_dim INTEGER, created_at TEXT);
CREATE TABLE IF NOT EXISTS presentation_blocks (id INTEGER PRIMARY KEY AUTOINCREMENT, block_id TEXT UNIQUE, doc_id TEXT, chunk_id TEXT, section_id TEXT, block_type TEXT, title TEXT, body_json TEXT, references_json TEXT, order_index INTEGER, created_at TEXT);
CREATE TABLE IF NOT EXISTS ingest_logs (id INTEGER PRIMARY KEY AUTOINCREMENT, run_id TEXT, source_id TEXT, step TEXT, status TEXT, message TEXT, created_at TEXT);
CREATE INDEX IF NOT EXISTS idx_chunks_doc ON chunks(doc_id); CREATE INDEX IF NOT EXISTS idx_entities_doc ON entities(doc_id); CREATE INDEX IF NOT EXISTS idx_source_status ON source_files(status);
CREATE INDEX IF NOT EXISTS idx_presentation_doc_order ON presentation_blocks(doc_id, order_index); CREATE INDEX IF NOT EXISTS idx_presentation_chunk ON presentation_blocks(chunk_id);
"""


def connect(paths: Paths) -> sqlite3.Connection:
    paths.db.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(paths.db)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA foreign_keys=ON")
    db.executescript(SCHEMA)
    try:
        db.execute("CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5(chunk_id UNINDEXED, title, section_path, text)")
    except sqlite3.OperationalError:
        pass
    return db


def setup(paths: Paths) -> None:
    paths.sources.mkdir(parents=True, exist_ok=True)
    for name in RESULT_DIRS: paths.out(name).mkdir(parents=True, exist_ok=True)
    for name in LOG_CSVS: (paths.out("logs") / name).touch(exist_ok=True)
    config = paths.root / "pipeline_config.json"
    if not config.exists():
        config.write_text(json.dumps({"model_name": DEFAULT_MODEL, "chunk_chars": 3500, "language": "ru"}, ensure_ascii=False, indent=2), encoding="utf-8")
    with connect(paths): pass


def configure_logging(paths: Paths) -> None:
    setup(paths)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s", handlers=[logging.FileHandler(paths.out("logs") / "pipeline.log", encoding="utf-8"), logging.StreamHandler()])


def rel(path: Optional[Path], root: Path) -> Optional[str]:
    if not path: return None
    try: return path.relative_to(root).as_posix()
    except ValueError: return str(path)


def csv_log(paths: Paths, filename: str, row: dict[str, Any]) -> None:
    target = paths.out("logs") / filename
    exists = target.exists() and target.stat().st_size > 0
    with target.open("a", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(row))
        if not exists: writer.writeheader()
        writer.writerow(row)


def command_init(paths: Paths, _args: argparse.Namespace) -> None:
    setup(paths)
    print(f"Инициализировано: {paths.root}\nSQLite: {paths.db}")


def pdfs(paths: Paths, include_duplicates: bool = False) -> list[Path]:
    found = sorted(paths.sources.glob("*.pdf"), key=lambda p: p.name.casefold())
    return found if include_duplicates else [p for p in found if not is_duplicate_name(p)]


def make_converter() -> Any:
    try:
        from docling.datamodel.pipeline_options import PdfPipelineOptions, TableFormerMode
        from docling.document_converter import DocumentConverter, PdfFormatOption
        from docling.datamodel.base_models import InputFormat
    except ImportError as exc:
        raise RuntimeError("Docling не установлен. Выполните: pip install docling") from exc
    options = PdfPipelineOptions()
    if hasattr(options, "do_table_structure"): options.do_table_structure = True
    table_options = getattr(options, "table_structure_options", None)
    if table_options is not None and hasattr(table_options, "mode"):
        try: table_options.mode = TableFormerMode.ACCURATE
        except Exception: pass
    return DocumentConverter(format_options={InputFormat.PDF: PdfFormatOption(pipeline_options=options)})


def process_pdf(paths: Paths, pdf: Path, force: bool = False) -> tuple[Path, Path]:
    md_path = paths.out("markdown_out") / f"{pdf.stem}_ocr.md"
    json_path = paths.out("json_out") / f"{pdf.stem}_ocr.json"
    if md_path.exists() and json_path.exists() and not force: return md_path, json_path
    converter = make_converter()
    result = converter.convert(str(pdf))
    document = result.document
    markdown = document.export_to_markdown()
    try:
        payload = document.export_to_dict()
    except AttributeError:
        payload = json.loads(document.model_dump_json())
    md_path.write_text(markdown, encoding="utf-8")
    json_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return md_path, json_path


def command_docling(paths: Paths, args: argparse.Namespace) -> None:
    items = pdfs(paths, args.include_duplicates)
    if args.limit: items = items[:args.limit]
    for pdf in progress(items, "Docling"):
        started = now()
        try:
            md, js = process_pdf(paths, pdf, args.force)
            csv_log(paths, "docling_log.csv", {"time": started, "file": rel(pdf, paths.root), "status": "ok", "markdown": rel(md, paths.root), "json": rel(js, paths.root), "message": ""})
        except Exception as exc:
            logging.exception("Docling error: %s", pdf)
            csv_log(paths, "docling_log.csv", {"time": started, "file": rel(pdf, paths.root), "status": "error", "markdown": "", "json": "", "message": str(exc)})


def progress(items: Iterable[Any], desc: str) -> Iterable[Any]:
    try:
        from tqdm import tqdm
        return tqdm(items, desc=desc)
    except ImportError: return items


def source_record(paths: Paths, base: str, pdf: Optional[Path], md: Optional[Path], js: Optional[Path], duplicate: bool = False) -> dict[str, Any]:
    has_pdf, has_md, has_js = bool(pdf and pdf.exists()), bool(md and md.exists()), bool(js and js.exists())
    warnings: list[str] = []
    if duplicate: status = "duplicate_candidate"
    elif not has_pdf: status = "orphan_markdown" if has_md else "orphan_json"
    elif not has_md: status = "missing_markdown"
    elif not has_js: status = "missing_json"
    else: status = "ready_for_ingest"
    return {"source_id": stable_id("src", sha256(pdf) or base), "base_name": base, "source_pdf_path": rel(pdf, paths.root), "markdown_path": rel(md, paths.root), "docling_json_path": rel(js, paths.root), "source_hash": sha256(pdf), "markdown_hash": sha256(md), "json_hash": sha256(js), "has_pdf": has_pdf, "has_markdown": has_md, "has_json": has_js, "status": status, "warnings": warnings}


def command_scan(paths: Paths, _args: argparse.Namespace) -> list[dict[str, Any]]:
    setup(paths)
    mapping: dict[str, dict[str, Path]] = defaultdict(dict)
    for p in paths.sources.glob("*.pdf"): mapping[p.stem]["pdf"] = p
    for p in paths.out("markdown_out").glob("*_ocr.md"): mapping[p.stem[:-4]]["md"] = p
    for p in paths.out("json_out").glob("*_ocr.json"): mapping[p.stem[:-4]]["json"] = p
    records = [source_record(paths, base, files.get("pdf"), files.get("md"), files.get("json"), bool(files.get("pdf") and is_duplicate_name(files["pdf"]))) for base, files in sorted(mapping.items())]
    db = connect(paths)
    with db:
        for r in records:
            db.execute("""INSERT INTO source_files(source_id,base_name,source_pdf_path,markdown_path,docling_json_path,source_hash,markdown_hash,json_hash,has_pdf,has_markdown,has_json,status,warnings_json,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(source_id) DO UPDATE SET base_name=excluded.base_name,source_pdf_path=excluded.source_pdf_path,markdown_path=excluded.markdown_path,docling_json_path=excluded.docling_json_path,source_hash=excluded.source_hash,markdown_hash=excluded.markdown_hash,json_hash=excluded.json_hash,has_pdf=excluded.has_pdf,has_markdown=excluded.has_markdown,has_json=excluded.has_json,status=excluded.status,warnings_json=excluded.warnings_json,updated_at=excluded.updated_at""", (r["source_id"],r["base_name"],r["source_pdf_path"],r["markdown_path"],r["docling_json_path"],r["source_hash"],r["markdown_hash"],r["json_hash"],int(r["has_pdf"]),int(r["has_markdown"]),int(r["has_json"]),r["status"],json.dumps(r["warnings"],ensure_ascii=False),now(),now()))
    report_json = paths.out("reports") / "manifest.json"
    report_json.write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8")
    with (paths.out("reports") / "manifest.csv").open("w", encoding="utf-8-sig", newline="") as handle:
        fields = list(records[0]) if records else ["source_id","base_name","status"]
        writer = csv.DictWriter(handle, fieldnames=fields); writer.writeheader()
        for r in records: writer.writerow({**r, "warnings": json.dumps(r["warnings"], ensure_ascii=False)})
    csv_log(paths, "scan_log.csv", {"time": now(), "status": "ok", "records": len(records), "message": ""})
    print(f"Manifest: {len(records)} записей")
    return records


def walk_json(obj: Any) -> Iterator[dict[str, Any]]:
    if isinstance(obj, dict):
        yield obj
        for value in obj.values(): yield from walk_json(value)
    elif isinstance(obj, list):
        for value in obj: yield from walk_json(value)


def text_of(obj: Any) -> str:
    if isinstance(obj, str): return obj
    if isinstance(obj, dict):
        for key in ("text", "orig", "content", "value"):
            if isinstance(obj.get(key), str): return obj[key]
    return ""


def parse_docling(payload: Any, markdown: str) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[str]]:
    blocks, tables, warnings = [], [], []
    seen: set[str] = set()
    order = 0
    for node in walk_json(payload):
        label = str(node.get("label") or node.get("type") or node.get("kind") or "").lower()
        text = normalize_text(text_of(node))
        if "table" in label or ("data" in node and isinstance(node.get("data"), dict) and "table" in str(node).lower()[:300]):
            table = parse_table_node(node, len(tables) + 1)
            if table: tables.append(table); order += 1; blocks.append({"block_id": f"block_{order:04d}", "type": "table", "table_id": table["table_id"], "order": order, "raw": {}})
        elif text and text not in seen:
            seen.add(text); order += 1
            kind = "heading" if any(x in label for x in ("title", "heading", "section_header")) else "paragraph"
            blocks.append({"block_id": f"block_{order:04d}", "type": kind, "text": text, "order": order, "raw": {}})
    if not blocks:
        warnings.append("docling_json_fallback_to_markdown")
        for line in markdown.splitlines():
            line = line.strip()
            if not line: continue
            order += 1; blocks.append({"block_id": f"block_{order:04d}", "type": "heading" if line.startswith("#") else "paragraph", "text": line.lstrip("# "), "order": order, "raw": {}})
    return blocks, tables, warnings


def parse_table_node(node: dict[str, Any], number: int) -> Optional[dict[str, Any]]:
    data = node.get("data") if isinstance(node.get("data"), dict) else node
    rows: list[list[str]] = []
    grid = data.get("grid") or data.get("rows")
    if isinstance(grid, list):
        for row in grid:
            if isinstance(row, list): rows.append([normalize_text(text_of(c) or str(c)) for c in row])
            elif isinstance(row, dict): rows.append([normalize_text(str(v)) for v in row.values()])
    cells = data.get("table_cells") or data.get("cells") or []
    if not rows and isinstance(cells, list):
        by_row: dict[int, dict[int, str]] = defaultdict(dict)
        for cell in cells:
            if not isinstance(cell, dict): continue
            r = int(cell.get("start_row_offset_idx", cell.get("row", 0)) or 0); c = int(cell.get("start_col_offset_idx", cell.get("col", 0)) or 0)
            by_row[r][c] = normalize_text(text_of(cell))
        rows = [[cols.get(i, "") for i in range(max(cols, default=-1)+1)] for _, cols in sorted(by_row.items())]
    if not rows: return None
    columns = rows[0]; body = rows[1:]
    markdown = "| " + " | ".join(columns) + " |\n| " + " | ".join(["---"] * len(columns)) + " |\n" + "\n".join("| " + " | ".join(r) + " |" for r in body)
    plain = "Таблица. " + "; ".join(f"Колонка {columns[i] if i < len(columns) else i+1}: {value}" for row in body for i, value in enumerate(row) if value)
    return {"table_id": f"tbl_{number:04d}", "title": "", "columns": columns, "rows": body, "cells": cells, "markdown": markdown, "plain_text": plain}


ICD_RE = re.compile(r"(?<![A-ZА-Я0-9])([A-ZА-Я]\d{2}(?:\.\d+)?(?:\s*[-–—]\s*[A-ZА-Я]?\d{2}(?:\.\d+)?)?)", re.I)
LAB_RE = re.compile(r"\b(ЛДГ|АСТ|АЛТ|тромбоцит(?:ы|ов)?|гаптоглобин|ADAMTS13|ПВ|АЧТВ)\s*(>|<|≥|≤|=)\s*(\d+(?:[.,]\d+)?)\s*([%А-Яа-яA-Za-z0-9^/³ ]{0,15})", re.I)
DRUGS = r"дексаметазон|сульфат магния|лабеталол|тромбоконцентрат|свежезамороженная плазма"
DRUG_RE = re.compile(rf"\b({DRUGS})\b[^.\n]{{0,45}}?\b(\d+(?:[.,]\d+)?)\s*(мг/час|мг|г/ч|г)\b", re.I)
EVIDENCE_RE = re.compile(r"(?:УД\s*-?\s*([ABCDАВСД])|уровень доказательности\s*([ABCDАВСД]))", re.I)


def extract_metadata(text: str, base: str) -> dict[str, Any]:
    clean = normalize_text(text); icds = sorted({normalize_icd10(m.group(1)) for m in ICD_RE.finditer(clean)})
    title = next((normalize_text(line.lstrip("# ")) for line in text.splitlines() if line.strip().startswith("#")), base)
    dates = re.findall(r"(?:от\s*[«\"]?(\d{1,2})[»\"]?\s+([а-я]+)\s+(\d{4})\s+года|\b(20\d{2})\s+год)", clean, re.I)
    approval_date = " ".join(x for x in dates[0][:3] if x) if dates else None
    protocol = re.search(r"(?:Протокол\s*)?№\s*(\d+[A-Za-zА-Яа-я/-]*)", clean, re.I)
    return {"title": title, "normalized_title": normalize_title(title), "language": "ru", "country": "KZ" if re.search(r"Казахстан|МЗ\s*РК|Министерств.{0,20}здравоохранения Республики Казахстан", clean, re.I) else None, "document_type": "clinical_protocol" if "клинический протокол" in clean.casefold() else "medical_document", "clinical_domain": ["obstetrics"] if re.search(r"HELLP|беременн|акушер", clean, re.I) else [], "icd10_codes": icds, "approval_date": approval_date, "revision_date": None, "protocol_number": protocol.group(1) if protocol else None, "approval_authority": "Министерство здравоохранения Республики Казахстан" if "Министерство здравоохранения Республики Казахстан" in clean else None, "version_label": f"{dates[0][2] or dates[0][3]}_protocol_{protocol.group(1)}" if dates and protocol else None}


def section_type(title: str) -> str:
    rules = [("МКБ", "icd10"),("сокращ", "abbreviations"),("классифика", "classification"),("фактор.{0,5}риска", "risk_factors"),("диагностическ.{0,10}критер", "diagnostic_criteria"),("дифференц", "differential_diagnosis"),("лаборатор", "lab_tests"),("инструмент", "instrumental_tests"),("госпитал", "hospitalization"),("медикамент", "drug_therapy"),("лечени", "treatment"),("хирург|операц", "surgery"),("наблюдени", "follow_up"),("эффективност", "effectiveness_indicators"),("литератур", "literature"),("приложени", "appendix")]
    low = title.casefold()
    for pattern, value in rules:
        if re.search(pattern, low): return value
    return "unknown"


def heading_level(text: str, block_type: str) -> Optional[int]:
    if block_type == "heading": return 1
    if re.match(r"^[IVXLCDM]+\.\s+", text, re.I): return 1
    m = re.match(r"^(\d+(?:\.\d+)+)\s+", text)
    if m: return min(4, m.group(1).count(".") + 1)
    if re.match(r"^(Таблица\s+\d+|Приложение)", text, re.I): return 2
    return None


def extract_entities(text: str, context: str) -> list[dict[str, Any]]:
    entities: list[dict[str, Any]] = []
    for m in ICD_RE.finditer(text): entities.append({"type":"icd10_code","raw_text":m.group(0),"normalized_text":normalize_icd10(m.group(1)),"canonical_name":"МКБ-10","value":normalize_icd10(m.group(1)),"operator":None,"unit":None,"normalized_unit":None,"clinical_context":context,"evidence_level":None,"confidence":0.98})
    canonical = {"лдг":"лактатдегидрогеназа","аст":"аспартатаминотрансфераза","алт":"аланинаминотрансфераза"}
    for m in LAB_RE.finditer(text):
        unit = normalize_text(m.group(4)).strip(" ,.;")
        entities.append({"type":"lab_threshold","raw_text":m.group(0),"normalized_text":normalize_text(m.group(0)),"canonical_name":canonical.get(m.group(1).casefold(),m.group(1).casefold()),"value":m.group(3).replace(",","."),"operator":m.group(2),"unit":unit,"normalized_unit":normalize_units(unit),"clinical_context":context,"evidence_level":None,"confidence":0.9})
    for m in DRUG_RE.finditer(text): entities.append({"type":"dosage","raw_text":m.group(0),"normalized_text":normalize_text(m.group(0)),"canonical_name":m.group(1).casefold(),"value":m.group(2).replace(",","."),"operator":None,"unit":m.group(3),"normalized_unit":normalize_units(m.group(3)),"clinical_context":context,"evidence_level":None,"confidence":0.88})
    for m in EVIDENCE_RE.finditer(text): entities.append({"type":"evidence_level","raw_text":m.group(0),"normalized_text":normalize_text(m.group(0)),"canonical_name":"уровень доказательности","value":None,"operator":None,"unit":None,"normalized_unit":None,"clinical_context":context,"evidence_level":m.group(1) or m.group(2),"confidence":0.95})
    return entities


def ingest_record(paths: Paths, record: sqlite3.Row, force: bool = False) -> dict[str, int]:
    root = paths.root; md_path = root / record["markdown_path"]; js_path = root / record["docling_json_path"]
    markdown = md_path.read_text(encoding="utf-8", errors="replace"); payload = json.loads(js_path.read_text(encoding="utf-8"))
    blocks, parsed_tables, warnings = parse_docling(payload, markdown); meta = extract_metadata(markdown, record["base_name"])
    doc_id = stable_id("doc", record["source_id"]); family_id = stable_id("fam", meta["normalized_title"]); run_id = uuid.uuid4().hex
    db = connect(paths)
    existing = db.execute("SELECT 1 FROM documents WHERE doc_id=?", (doc_id,)).fetchone()
    if existing and not force: return {"documents":0,"sections":0,"tables":0,"chunks":0,"entities":0,"skipped":1}
    with db:
        if existing:
            for table in ("entities","tables","sections","chunks"): db.execute(f"DELETE FROM {table} WHERE doc_id=?", (doc_id,))
            db.execute("DELETE FROM embeddings WHERE chunk_id NOT IN (SELECT chunk_id FROM chunks)"); db.execute("DELETE FROM documents WHERE doc_id=?", (doc_id,))
        db.execute("INSERT OR REPLACE INTO document_families(document_family_id,canonical_title,canonical_disease,icd10_codes_json,country,document_type,clinical_domain_json,latest_doc_id,aliases_json,duplicate_groups_json,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)",(family_id,meta["title"],meta["title"],j(meta["icd10_codes"]),meta["country"],meta["document_type"],j(meta["clinical_domain"]),doc_id,j([record["base_name"]]),j([]),now(),now()))
        db.execute("INSERT INTO documents(doc_id,document_family_id,source_id,title,normalized_title,language,country,document_type,clinical_domain_json,icd10_codes_json,approval_date,revision_date,protocol_number,approval_authority,status,version_label,warnings_json,ocr_quality_flags_json,processing_json,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",(doc_id,family_id,record["source_id"],meta["title"],meta["normalized_title"],meta["language"],meta["country"],meta["document_type"],j(meta["clinical_domain"]),j(meta["icd10_codes"]),meta["approval_date"],meta["revision_date"],meta["protocol_number"],meta["approval_authority"],"ingested",meta["version_label"],j(warnings),j([]),j({"parser":"mvp-v1"}),now(),now()))
        sections: list[dict[str, Any]] = []; stack: list[dict[str, Any]] = []
        current = None; paragraphs: list[str] = []
        def flush() -> None:
            nonlocal paragraphs
            if current and paragraphs: current["text"] = "\n".join(paragraphs); paragraphs = []
        for block in blocks:
            level = heading_level(block.get("text", ""), block["type"])
            if level:
                flush(); title = block["text"]
                while stack and stack[-1]["level"] >= level: stack.pop()
                parent = stack[-1] if stack else None; sec_id = stable_id("sec", f"{doc_id}:{len(sections)}:{title}")
                current = {"section_id":sec_id,"parent_section_id":parent["section_id"] if parent else None,"section_path":" > ".join([s["title"] for s in stack]+[title]),"title":title,"level":level,"order_index":len(sections),"section_type":section_type(title),"text":""}
                sections.append(current); stack.append(current)
            elif block["type"] == "paragraph":
                if current is None:
                    current={"section_id":stable_id("sec",f"{doc_id}:root"),"parent_section_id":None,"section_path":"Документ","title":"Документ","level":1,"order_index":0,"section_type":"unknown","text":""}; sections.append(current); stack=[current]
                paragraphs.append(block.get("text", ""))
        flush()
        source_refs={"source_pdf_path":record["source_pdf_path"],"docling_json_path":record["docling_json_path"],"markdown_path":record["markdown_path"]}
        all_chunks: list[dict[str, Any]]=[]; all_entities: list[dict[str, Any]]=[]
        for sec in sections:
            db.execute("INSERT INTO sections(section_id,doc_id,parent_section_id,section_path,title,normalized_title,level,order_index,section_type,page_start,page_end,quality_flags_json,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)",(sec["section_id"],doc_id,sec["parent_section_id"],sec["section_path"],sec["title"],normalize_title(sec["title"]),sec["level"],sec["order_index"],sec["section_type"],None,None,j([]),now()))
            for part_no, part in enumerate(split_text(sec["text"])):
                chunk_id=stable_id("chk",f"{doc_id}:{sec['section_id']}:{part_no}:{part}"); ents=extract_entities(part,sec["section_type"])
                refs=[]
                for e in ents:
                    e["entity_id"]=stable_id("ent",f"{chunk_id}:{len(all_entities)}:{e['raw_text']}"); e["chunk_id"]=chunk_id; e["section_id"]=sec["section_id"]; refs.append(e["entity_id"]); all_entities.append(e)
                content_type="text"
                if any(e["type"]=="lab_threshold" for e in ents): content_type="lab_threshold"
                elif any(e["type"]=="dosage" for e in ents): content_type="drug_dosage"
                all_chunks.append(chunk(chunk_id,doc_id,family_id,sec,content_type,part,None,refs,meta,source_refs))
        table_dir=paths.out("tables_out"); exported=[]
        for idx,t in enumerate(parsed_tables):
            tid=stable_id("tbl",f"{doc_id}:{idx}:{t['plain_text']}"); sec=sections[min(idx,len(sections)-1)] if sections else {"section_id":None,"section_path":"Документ","section_type":"unknown"}; t["table_id"]=tid
            ents=extract_entities(t["plain_text"],sec["section_type"]); ttype=table_type(t["plain_text"])
            db.execute("INSERT INTO tables(table_id,doc_id,section_id,title,table_type,columns_json,rows_json,cells_json,markdown,plain_text,extracted_entities_json,page_hint_json,quality_flags_json,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)",(tid,doc_id,sec["section_id"],t["title"],ttype,j(t["columns"]),j(t["rows"]),j(t["cells"]),t["markdown"],t["plain_text"],j(ents),j(None),j([]),now())); exported.append(t)
            all_chunks.append(chunk(stable_id("chk",tid),doc_id,family_id,sec,"table",t["plain_text"],t,[],meta,source_refs))
            for row_no,row in enumerate(t["rows"]):
                row_text="; ".join(f"{t['columns'][i] if i<len(t['columns']) else i+1}: {v}" for i,v in enumerate(row))
                all_chunks.append(chunk(stable_id("chk",f"{tid}:row:{row_no}"),doc_id,family_id,sec,"table_row",row_text,{"table_id":tid,"row":row},[],meta,source_refs))
        (table_dir/f"{record['base_name']}_tables.json").write_text(json.dumps(exported,ensure_ascii=False,indent=2),encoding="utf-8")
        for c in all_chunks:
            db.execute("INSERT INTO chunks(chunk_id,doc_id,document_family_id,section_id,section_path,content_type,text,table_json,keywords_json,entity_refs_json,icd10_codes_json,clinical_domain_json,version,page_hint_json,embedding_text,source_refs_json,quality_json,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",(c["chunk_id"],doc_id,family_id,c["section_id"],c["section_path"],c["content_type"],c["text"],j(c["table_json"]),j(c["keywords"]),j(c["entity_refs"]),j(c["icd10_codes"]),j(c["clinical_domain"]),c["version"],j(None),c["embedding_text"],j(source_refs),j({}),now()))
            try: db.execute("INSERT INTO chunks_fts(chunk_id,title,section_path,text) VALUES(?,?,?,?)",(c["chunk_id"],meta["title"],c["section_path"],c["text"]))
            except sqlite3.OperationalError: pass
        for e in all_entities:
            db.execute("INSERT INTO entities(entity_id,doc_id,chunk_id,section_id,type,raw_text,normalized_text,canonical_name,value,operator,unit,normalized_unit,clinical_context,evidence_level,confidence,source_location_json,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",(e["entity_id"],doc_id,e["chunk_id"],e["section_id"],e["type"],e["raw_text"],e["normalized_text"],e["canonical_name"],e["value"],e["operator"],e["unit"],e["normalized_unit"],e["clinical_context"],e["evidence_level"],e["confidence"],j({}),now()))
        db.execute("INSERT INTO ingest_logs(run_id,source_id,step,status,message,created_at) VALUES(?,?,?,?,?,?)",(run_id,record["source_id"],"ingest","ok",f"chunks={len(all_chunks)}",now()))
    return {"documents":1,"sections":len(sections),"tables":len(parsed_tables),"chunks":len(all_chunks),"entities":len(all_entities),"skipped":0}


def j(value: Any) -> str: return json.dumps(value, ensure_ascii=False)


def split_text(text: str, limit: int = 3500) -> list[str]:
    text=normalize_ocr_artifacts(text).strip()
    if not text: return []
    paragraphs=re.split(r"\n\s*\n|(?<=[.!?])\s+(?=[А-ЯA-Z])",text); out=[]; buf=""
    for p in paragraphs:
        if len(buf)+len(p)+1>limit and buf: out.append(buf.strip()); buf=""
        buf += (" " if buf else "") + p
    if buf: out.append(buf.strip())
    return out


def chunk(cid: str, doc_id: str, family: str, sec: dict[str, Any], ctype: str, text: str, table: Any, refs: list[str], meta: dict[str, Any], sources: dict[str, Any]) -> dict[str, Any]:
    keywords=sorted(set(re.findall(r"[A-Za-zА-Яа-яЁё0-9-]{4,}",text.casefold())))[:50]
    return {"chunk_id":cid,"doc_id":doc_id,"document_family_id":family,"section_id":sec.get("section_id"),"section_path":sec.get("section_path"),"content_type":ctype,"text":text,"table_json":table,"keywords":keywords,"entity_refs":refs,"icd10_codes":meta["icd10_codes"],"clinical_domain":meta["clinical_domain"],"version":meta["version_label"],"embedding_text":f"{meta['title']}. {sec.get('section_path')}. {text}","source_refs":sources}


def table_type(text: str) -> str:
    for pattern,value in [("диагност", "diagnostic_criteria"),("дифференц", "differential_diagnosis"),("доз|мг|г/ч", "drug_dosage"),("доказатель", "evidence_scale"),("госпитал", "hospitalization_criteria"),("алгоритм", "algorithm"),("осложнен", "complications")]:
        if re.search(pattern,text,re.I): return value
    return "unknown"


def resolve_record(paths: Paths, args: argparse.Namespace) -> sqlite3.Row:
    db=connect(paths)
    if getattr(args,"base_name",None): row=db.execute("SELECT * FROM source_files WHERE base_name=?",(args.base_name,)).fetchone()
    elif getattr(args,"file",None): row=db.execute("SELECT * FROM source_files WHERE source_pdf_path=? OR base_name=?",(Path(args.file).as_posix(),Path(args.file).stem)).fetchone()
    else: row=None
    if not row: raise RuntimeError("Запись не найдена в manifest. Сначала выполните scan.")
    return row


def command_ingest_one(paths: Paths, args: argparse.Namespace) -> None:
    result=ingest_record(paths,resolve_record(paths,args),args.force); print(json.dumps(result,ensure_ascii=False))


def command_ingest_all(paths: Paths, args: argparse.Namespace) -> None:
    db=connect(paths); rows=db.execute("SELECT * FROM source_files WHERE status='ready_for_ingest' ORDER BY base_name").fetchall()
    if args.limit: rows=rows[:args.limit]
    totals=defaultdict(int)
    for row in progress(rows,"Ingest"):
        try:
            for key,value in ingest_record(paths,row,args.force).items(): totals[key]+=value
            csv_log(paths,"ingest_log.csv",{"time":now(),"source_id":row["source_id"],"base_name":row["base_name"],"status":"ok","message":""})
        except Exception as exc:
            logging.exception("Ingest error: %s",row["base_name"]); csv_log(paths,"ingest_log.csv",{"time":now(),"source_id":row["source_id"],"base_name":row["base_name"],"status":"error","message":str(exc)})
    print(json.dumps(totals,ensure_ascii=False))


def command_embeddings(paths: Paths, args: argparse.Namespace) -> None:
    db=connect(paths); rows=db.execute("SELECT c.chunk_id,c.embedding_text FROM chunks c LEFT JOIN embeddings e ON e.chunk_id=c.chunk_id WHERE e.chunk_id IS NULL ORDER BY c.id").fetchall()
    texts=[r["embedding_text"] for r in rows]
    if not texts: print("Нет новых chunks для индексации"); return
    if args.no_embeddings:
        build_tfidf(paths,db); return
    try:
        from sentence_transformers import SentenceTransformer
    except ImportError:
        print("sentence-transformers не установлен; создаю TF-IDF fallback."); build_tfidf(paths,db); return
    kwargs={}
    if args.offline: kwargs["local_files_only"]=True; os.environ["HF_HUB_OFFLINE"]="1"
    try: model=SentenceTransformer(args.model_name,**kwargs)
    except Exception as exc:
        if args.offline: print(f"Модель не найдена локально: {exc}\nСначала запустите с --download-model или используйте --no-embeddings."); return
        if not args.download_model: print("Загрузка модели не разрешена. Используйте --download-model, --offline или --no-embeddings."); return
        model=SentenceTransformer(args.model_name)
    vectors=model.encode(texts,batch_size=args.batch_size,show_progress_bar=True,normalize_embeddings=True)
    with db:
        for row,vector in zip(rows,vectors): db.execute("INSERT OR REPLACE INTO embeddings(chunk_id,model_name,vector_json,vector_dim,created_at) VALUES(?,?,?,?,?)",(row["chunk_id"],args.model_name,j(vector.tolist()),len(vector),now()))
    csv_log(paths,"embedding_log.csv",{"time":now(),"status":"ok","model":args.model_name,"count":len(rows),"message":""}); print(f"Embeddings: {len(rows)}")


def build_tfidf(paths: Paths, db: sqlite3.Connection) -> None:
    rows=db.execute("SELECT chunk_id,embedding_text FROM chunks ORDER BY id").fetchall()
    try:
        from sklearn.feature_extraction.text import TfidfVectorizer
    except ImportError:
        print("scikit-learn не установлен. FTS/LIKE поиск остаётся доступен. Установка: pip install scikit-learn"); return
    vectorizer=TfidfVectorizer(lowercase=True,ngram_range=(1,2),max_features=100000); matrix=vectorizer.fit_transform([r["embedding_text"] for r in rows])
    with (paths.out("embeddings")/"tfidf.pkl").open("wb") as handle: pickle.dump({"vectorizer":vectorizer,"matrix":matrix,"chunk_ids":[r["chunk_id"] for r in rows]},handle)
    print(f"TF-IDF: {len(rows)} chunks")


def jsonl(path: Path, rows: Iterable[dict[str, Any]]) -> int:
    count=0
    with path.open("w",encoding="utf-8") as handle:
        for row in rows: handle.write(json.dumps(row,ensure_ascii=False)+"\n"); count+=1
    return count


def command_export(paths: Paths, _args: argparse.Namespace) -> None:
    db=connect(paths); report=paths.out("reports")
    chunks=[]
    for r in db.execute("SELECT c.*,d.title,d.country,d.document_type FROM chunks c JOIN documents d ON d.doc_id=c.doc_id ORDER BY c.id"):
        chunks.append({"chunk_id":r["chunk_id"],"doc_id":r["doc_id"],"document_family_id":r["document_family_id"],"title":r["title"],"section_path":r["section_path"],"content_type":r["content_type"],"text":r["text"],"embedding_text":r["embedding_text"],"source_refs":json.loads(r["source_refs_json"]),"metadata":{"country":r["country"],"document_type":r["document_type"],"icd10_codes":json.loads(r["icd10_codes_json"] or "[]")}})
    tables=[dict(r) for r in db.execute("SELECT * FROM tables ORDER BY id")]; entities=[dict(r) for r in db.execute("SELECT * FROM entities ORDER BY id")]
    counts={"chunks":jsonl(report/"rag_chunks.jsonl",chunks),"tables":jsonl(report/"rag_tables.jsonl",tables),"entities":jsonl(report/"rag_entities.jsonl",entities),"created_at":now()}
    (report/"rag_manifest.json").write_text(json.dumps(counts,ensure_ascii=False,indent=2),encoding="utf-8"); print(json.dumps(counts,ensure_ascii=False))


def chunks_text_fingerprint(db: sqlite3.Connection) -> str:
    digest = hashlib.sha256()
    for row in db.execute("SELECT chunk_id,text FROM chunks ORDER BY id"):
        digest.update(str(row["chunk_id"]).encode("utf-8"))
        digest.update(b"\0")
        digest.update(str(row["text"] or "").encode("utf-8"))
        digest.update(b"\0")
    return digest.hexdigest()


def command_build_presentation(paths: Paths, _args: argparse.Namespace) -> None:
    db = connect(paths)
    source_fingerprint = chunks_text_fingerprint(db)
    created_at = now()
    inserted = 0
    processed_chunks = 0
    documents = db.execute("SELECT doc_id FROM documents ORDER BY id").fetchall()

    with db:
        db.execute("DELETE FROM presentation_blocks")
        for document in progress(documents, "Presentation"):
            doc_id = document["doc_id"]
            chunks = db.execute(
                """
                SELECT c.*,s.title AS section_title,s.section_type,s.order_index AS section_order
                FROM chunks c
                LEFT JOIN sections s ON s.section_id=c.section_id
                WHERE c.doc_id=? ORDER BY c.id
                """,
                (doc_id,),
            ).fetchall()
            entities_by_chunk: dict[str, list[sqlite3.Row]] = defaultdict(list)
            for entity in db.execute("SELECT * FROM entities WHERE doc_id=? ORDER BY id", (doc_id,)):
                entities_by_chunk[str(entity["chunk_id"])].append(entity)
            tables = {
                str(table["table_id"]): restore_abbreviation_table(table)
                for table in db.execute("SELECT * FROM tables WHERE doc_id=? ORDER BY id", (doc_id,))
            }

            order_index = 0
            for chunk_row in chunks:
                section = {
                    "section_id": chunk_row["section_id"],
                    "title": chunk_row["section_title"] or chunk_row["section_path"],
                    "section_type": chunk_row["section_type"] or "unknown",
                    "order_index": chunk_row["section_order"],
                }
                table_json = _json_value(chunk_row["table_json"], {})
                table_id = table_json.get("table_id") if isinstance(table_json, dict) else None
                blocks = build_presentation_blocks(
                    chunk_row,
                    section,
                    entities_by_chunk.get(str(chunk_row["chunk_id"]), []),
                    tables.get(str(table_id)) if table_id else None,
                )
                for block_number, block in enumerate(blocks):
                    block_id = stable_id(
                        "pblock",
                        f"{chunk_row['chunk_id']}:{block_number}:{block['block_type']}",
                    )
                    db.execute(
                        """
                        INSERT INTO presentation_blocks(
                            block_id,doc_id,chunk_id,section_id,block_type,title,
                            body_json,references_json,order_index,created_at
                        ) VALUES(?,?,?,?,?,?,?,?,?,?)
                        """,
                        (
                            block_id,
                            doc_id,
                            chunk_row["chunk_id"],
                            chunk_row["section_id"],
                            block["block_type"],
                            block.get("title"),
                            j(block["body"]),
                            j(block.get("references", [])),
                            order_index,
                            created_at,
                        ),
                    )
                    inserted += 1
                    order_index += 1
                processed_chunks += 1

    if chunks_text_fingerprint(db) != source_fingerprint:
        raise RuntimeError("Safety check failed: chunks.text changed during presentation build")
    chunks_without_blocks = db.execute(
        """
        SELECT COUNT(*) FROM chunks c
        WHERE NOT EXISTS (
            SELECT 1 FROM presentation_blocks p WHERE p.chunk_id=c.chunk_id
        )
        """
    ).fetchone()[0]
    if chunks_without_blocks:
        raise RuntimeError(f"Presentation blocks missing for {chunks_without_blocks} chunks")
    print(j({
        "documents": len(documents),
        "chunks": processed_chunks,
        "presentation_blocks": inserted,
        "chunks_text_fingerprint": source_fingerprint,
    }))


def command_export_presentation(paths: Paths, _args: argparse.Namespace) -> None:
    db = connect(paths)
    target = paths.out("reports") / "presentation_blocks.jsonl"

    def rows() -> Iterator[dict[str, Any]]:
        for row in db.execute("SELECT * FROM presentation_blocks ORDER BY doc_id,order_index,id"):
            item = dict(row)
            item["body"] = _json_value(item.pop("body_json"), {})
            item["references"] = _json_value(item.pop("references_json"), [])
            yield item

    count = jsonl(target, rows())
    print(j({"presentation_blocks": count, "path": str(target), "created_at": now()}))


def command_search(paths: Paths, args: argparse.Namespace) -> None:
    db=connect(paths); results: dict[str,float]={}; query=args.query
    tfidf=paths.out("embeddings")/"tfidf.pkl"
    if tfidf.exists():
        try:
            with tfidf.open("rb") as handle: data=pickle.load(handle)
            scores=(data["matrix"] @ data["vectorizer"].transform([query]).T).toarray().ravel()
            for idx in scores.argsort()[::-1][:args.top_k*2]:
                if scores[idx]>0: results[data["chunk_ids"][idx]]=float(scores[idx])
        except Exception: logging.exception("TF-IDF search failed")
    try:
        terms=" OR ".join(re.findall(r"[\w-]+",query))
        for r in db.execute("SELECT chunk_id,bm25(chunks_fts) score FROM chunks_fts WHERE chunks_fts MATCH ? ORDER BY score LIMIT ?",(terms,args.top_k*2)): results[r["chunk_id"]]=max(results.get(r["chunk_id"],0),1/(1+abs(r["score"])))
    except sqlite3.OperationalError: pass
    if not results:
        terms=[t for t in normalize_text(query).split() if len(t)>2]
        for r in db.execute("SELECT chunk_id,text FROM chunks"):
            score=sum(r["text"].casefold().count(t.casefold()) for t in terms)
            if score: results[r["chunk_id"]]=float(score)
    for rank,(cid,score) in enumerate(sorted(results.items(),key=lambda x:x[1],reverse=True)[:args.top_k],1):
        r=db.execute("SELECT c.*,d.title FROM chunks c JOIN documents d ON d.doc_id=c.doc_id WHERE c.chunk_id=?",(cid,)).fetchone(); sources=json.loads(r["source_refs_json"])
        print(f"\n{rank}. score={score:.4f} | {r['title']}\n   {r['section_path']} | {r['content_type']}\n   {r['text'][:350]}\n   {sources.get('source_pdf_path')}")


def command_report(paths: Paths, _args: argparse.Namespace) -> None:
    db=connect(paths); count=lambda table: db.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
    stats={"PDF":len(list(paths.sources.glob("*.pdf"))),"Markdown":len(list(paths.out("markdown_out").glob("*.md"))),"JSON":len(list(paths.out("json_out").glob("*.json"))),"Documents":count("documents"),"Tables":count("tables"),"Chunks":count("chunks"),"Entities":count("entities"),"Embeddings":count("embeddings")}
    problems=[dict(r) for r in db.execute("SELECT base_name,status,warnings_json FROM source_files WHERE status<>'ready_for_ingest'")]
    with (paths.out("reports")/"qc_report.csv").open("w",encoding="utf-8-sig",newline="") as h:
        w=csv.DictWriter(h,fieldnames=["base_name","status","warnings_json"]); w.writeheader(); w.writerows(problems)
    errors=[]
    for name in ("docling_log.csv","ingest_log.csv"):
        p=paths.out("logs")/name
        if p.stat().st_size:
            with p.open(encoding="utf-8-sig") as h: errors.extend([{**r,"log":name} for r in csv.DictReader(h) if r.get("status")=="error"])
    fields=sorted({k for r in errors for k in r}) or ["log","status","message"]
    with (paths.out("reports")/"errors.csv").open("w",encoding="utf-8-sig",newline="") as h:
        w=csv.DictWriter(h,fieldnames=fields,extrasaction="ignore"); w.writeheader(); w.writerows(errors)
    md="# Сводный отчёт\n\n"+"\n".join(f"- {k}: {v}" for k,v in stats.items())+f"\n- Проблемных записей: {len(problems)}\n- Ошибок: {len(errors)}\n"
    (paths.out("reports")/"summary_report.md").write_text(md,encoding="utf-8"); print(md)


def command_test_one(paths: Paths, args: argparse.Namespace) -> None:
    items=pdfs(paths,False)
    requested = getattr(args, "base_name", None)
    if requested:
        items = [item for item in items if item.stem.casefold() == requested.casefold()]
    if not items: raise RuntimeError(f"В {paths.sources} нет PDF")
    pdf=items[0]; process_pdf(paths,pdf,args.force); command_scan(paths,args)
    db=connect(paths); row=db.execute("SELECT * FROM source_files WHERE base_name=?",(pdf.stem,)).fetchone(); result=ingest_record(paths,row,args.force)
    command_report(paths,args); print(f"\nPDF: {pdf}\nMarkdown: {paths.out('markdown_out')/(pdf.stem+'_ocr.md')}\nJSON: {paths.out('json_out')/(pdf.stem+'_ocr.json')}\nSQLite: {paths.db}\n{result}")
    for label,sql,limit in [("CHUNKS","SELECT content_type,section_path,text FROM chunks WHERE doc_id=?",5),("TABLES","SELECT table_type,plain_text FROM tables WHERE doc_id=?",5),("ENTITIES","SELECT type,raw_text,normalized_text FROM entities WHERE doc_id=?",10)]:
        print(f"\n{label}")
        for r in db.execute(sql+" LIMIT ?",(stable_id("doc",row["source_id"]),limit)): print(dict(r))


def command_run_all(paths: Paths, args: argparse.Namespace) -> None:
    command_init(paths,args); command_docling(paths,args); command_scan(paths,args); command_ingest_all(paths,args)
    if not args.no_embeddings or args.no_embeddings: command_embeddings(paths,args)
    command_build_presentation(paths,args); command_export_presentation(paths,args)
    command_export(paths,args); command_report(paths,args)


def parser() -> argparse.ArgumentParser:
    p=argparse.ArgumentParser(description="Локальный pipeline медицинских PDF")
    p.add_argument("--root",default=os.environ.get("MED_PIPELINE_ROOT",str(Path(__file__).resolve().parent))); p.add_argument("--limit",type=int); p.add_argument("--force",action="store_true"); p.add_argument("--resume",action="store_true"); p.add_argument("--include-duplicates",action="store_true"); p.add_argument("--no-embeddings",action="store_true"); p.add_argument("--offline",action="store_true"); p.add_argument("--download-model",action="store_true"); p.add_argument("--model-name",default=DEFAULT_MODEL); p.add_argument("--batch-size",type=int,default=32)
    sub=p.add_subparsers(dest="command",required=True)
    def add_common(command_parser: argparse.ArgumentParser) -> None:
        # SUPPRESS keeps a value supplied before the subcommand intact.
        command_parser.add_argument("--root", default=argparse.SUPPRESS)
        command_parser.add_argument("--limit", type=int, default=argparse.SUPPRESS)
        command_parser.add_argument("--force", action="store_true", default=argparse.SUPPRESS)
        command_parser.add_argument("--resume", action="store_true", default=argparse.SUPPRESS)
        command_parser.add_argument("--include-duplicates", action="store_true", default=argparse.SUPPRESS)
        command_parser.add_argument("--no-embeddings", action="store_true", default=argparse.SUPPRESS)
        command_parser.add_argument("--offline", action="store_true", default=argparse.SUPPRESS)
        command_parser.add_argument("--download-model", action="store_true", default=argparse.SUPPRESS)
        command_parser.add_argument("--model-name", default=argparse.SUPPRESS)
        command_parser.add_argument("--batch-size", type=int, default=argparse.SUPPRESS)
    for name in ("init","docling","scan","ingest-all","build-embeddings","build-presentation","export-presentation","export-rag","report","run-all","test-one"):
        command_parser = sub.add_parser(name)
        add_common(command_parser)
        if name == "test-one": command_parser.add_argument("--base-name")
    one=sub.add_parser("ingest-one"); add_common(one); one.add_argument("--file"); one.add_argument("--base-name")
    search=sub.add_parser("search"); add_common(search); search.add_argument("query"); search.add_argument("--top-k",type=int,default=10)
    return p


def main() -> int:
    args=parser().parse_args(); paths=Paths(Path(args.root).expanduser().resolve()); configure_logging(paths)
    commands={"init":command_init,"docling":command_docling,"scan":command_scan,"ingest-one":command_ingest_one,"ingest-all":command_ingest_all,"build-embeddings":command_embeddings,"build-presentation":command_build_presentation,"export-presentation":command_export_presentation,"export-rag":command_export,"search":command_search,"report":command_report,"run-all":command_run_all,"test-one":command_test_one}
    try: commands[args.command](paths,args); return 0
    except Exception as exc:
        logging.error("%s",traceback.format_exc()); csv_log(paths,"errors.csv",{"time":now(),"command":args.command,"status":"error","message":str(exc)}); print(f"Ошибка: {exc}",file=sys.stderr); return 1


if __name__ == "__main__": raise SystemExit(main())
