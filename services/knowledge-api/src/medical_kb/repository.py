"""Read-only repository for the SQLite corpus produced by the local pipeline."""

from __future__ import annotations

import json
import pickle
import re
import sqlite3
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from medical_kb.presentation import clean_text, display_section_title, table_block, text_blocks


_TOKEN_PATTERN = re.compile(r"[\w]+", re.UNICODE)
_GENERIC_TITLES = {
    "",
    "клинический протокол",
    "клинический протокол диагностики и лечения",
    "клинический протокол медицинского вмешательства",
    "1. вводная часть",
    "i. вводная часть",
    "1. содержание",
}

_CLINICAL_CATEGORIES = {
    "infectious": ("Инфекционные болезни", "A", "B"),
    "oncology_hematology": ("Онкология и гематология", "C", "D"),
    "endocrinology": ("Эндокринология", "E",),
    "psychiatry": ("Психиатрия", "F",),
    "neurology": ("Неврология", "G",),
    "ophthalmology_ent": ("Офтальмология и ЛОР", "H",),
    "cardiology": ("Кардиология", "I",),
    "pulmonology": ("Пульмонология", "J",),
    "gastroenterology": ("Гастроэнтерология", "K",),
    "dermatology": ("Дерматология", "L",),
    "rheumatology_orthopedics": ("Ревматология и ортопедия", "M",),
    "nephrology_urology": ("Нефрология и урология", "N",),
    "obstetrics": ("Акушерство и гинекология", "O",),
    "pediatrics": ("Педиатрия и неонатология", "P", "Q"),
    "trauma": ("Травматология и неотложная помощь", "S", "T"),
    "general": ("Общая медицина", "R", "V", "W", "X", "Y", "Z"),
}

_TITLE_CATEGORY_HINTS = {
    "cardiology": ("ГИПЕРТЕНЗ", "СЕРДЦ", "КАРДИО", "АРИТМ", "АОРТ", "ИНФАРКТ"),
    "pulmonology": ("ПНЕВМОН", "АСТМ", "ЛЕГК", "БРОНХ", "ПЛЕВР"),
    "obstetrics": ("БЕРЕМЕН", "АКУШЕР", "ПРЕЭКЛАМП", "HELLP", "РОД"),
    "neurology": ("ИНСУЛЬТ", "ЭПИЛЕП", "НЕВРО", "ГОЛОВНОГО МОЗГА"),
    "gastroenterology": ("ПЕЧЕН", "ЖЕЛУД", "КИШ", "ПАНКРЕАТ", "ГАСТР"),
    "endocrinology": ("ДИАБЕТ", "ЩИТОВИД", "ЭНДОКРИН"),
    "nephrology_urology": ("ПОЧ", "МОЧЕ", "УРОЛОГ"),
    "oncology_hematology": ("ЛИМФОМ", "ЛЕЙКОЗ", "АНЕМИ", "ОПУХОЛ", "РАК "),
    "infectious": ("ИНФЕКЦ", "СЕПСИС", "ТУБЕРКУЛ", "ГЕПАТИТ"),
    "dermatology": ("ДЕРМАТ", "ПСОРИАЗ", "КОЖ"),
    "rheumatology_orthopedics": ("АРТРИТ", "АРТРОЗ", "СПОНДИЛ", "СУСТАВ"),
    "trauma": ("ТРАВМ", "ПОВРЕЖД", "ПЕРЕЛОМ", "ОЖОГ"),
    "pediatrics": ("У ДЕТЕЙ", "НОВОРОЖД", "НЕДОНОШ"),
}


def json_value(value: str | None, default: Any) -> Any:
    if value in (None, ""):
        return default
    try:
        return json.loads(value)
    except (TypeError, json.JSONDecodeError):
        return default


def fts_query(query: str) -> str:
    tokens = [token for token in _TOKEN_PATTERN.findall(query) if len(token) > 1 or token.isdigit()]
    return " OR ".join(f'"{token}"' for token in tokens[:20])


def intent_types(query: str) -> set[str]:
    normalized = query.casefold()
    result: set[str] = set()
    if any(term in normalized for term in ("доз", "препарат", "лекар", "введение", "мг")):
        result.add("drug_dosage")
    if any(term in normalized for term in ("порог", "лаборатор", "анализ", "значение", "маркер", "лдг", "аст", "алт", "тромбоцит", "билирубин", "креатинин")):
        result.add("lab_threshold")
    if any(term in normalized for term in ("таблиц", "шкал", "критер", "балл", "классификац")):
        result.update(("table", "table_row"))
    return result


@dataclass(frozen=True)
class Filters:
    country: str | None = None
    document_type: str | None = None
    clinical_domain: str | None = None
    icd10_code: str | None = None
    content_type: str | None = None
    document_family_id: str | None = None
    version_policy: str = "all"


class Repository:
    """Provide traceable search without changing the generated corpus."""

    def __init__(self, database_path: str | Path) -> None:
        self.database_path = Path(database_path).expanduser()
        self.corpus_root = self.database_path.parent.parent.parent
        self.tfidf_path = self.database_path.parent.parent / "embeddings" / "tfidf.pkl"
        self._tfidf_data: dict[str, Any] | None = None

    @property
    def available(self) -> bool:
        return self.database_path.is_file()

    def connect(self) -> sqlite3.Connection:
        if not self.available:
            raise FileNotFoundError(f"Knowledge base not found: {self.database_path}")
        uri = f"file:{self.database_path.resolve().as_posix()}?mode=ro"
        connection = sqlite3.connect(uri, uri=True, timeout=10)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA query_only=ON")
        return connection

    def status(self) -> dict[str, Any]:
        if not self.available:
            return {"available": False, "database_path": str(self.database_path), "counts": {}, "warnings": []}

        with self.connect() as connection:
            counts = {
                table: int(connection.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0])
                for table in ("source_files", "documents", "document_families", "sections", "tables", "chunks", "entities", "embeddings")
            }
            unsafe_family_docs = int(
                connection.execute(
                    """
                    SELECT COUNT(*) FROM documents
                    WHERE document_family_id IN (
                        SELECT document_family_id FROM documents
                        GROUP BY document_family_id HAVING COUNT(*) > 1
                    ) AND normalized_title IN ({})
                    """.format(",".join("?" for _ in _GENERIC_TITLES)),
                    tuple(_GENERIC_TITLES),
                ).fetchone()[0]
            )

        tfidf_ready = self.tfidf_path.is_file()
        warnings = []
        if counts["embeddings"] == 0:
            warnings.append("Vector embeddings are absent; retrieval uses SQLite FTS5, entities and metadata.")
        if unsafe_family_docs:
            warnings.append(
                f"Version grouping is untrusted for {unsafe_family_docs} documents with generic OCR titles; version_policy=all is the safe default."
            )
        return {
            "available": True,
            "database_path": str(self.database_path),
            "database_bytes": self.database_path.stat().st_size,
            "counts": counts,
            "search_modes": ["fts5", "entity", "metadata"] + (["tfidf"] if tfidf_ready else []) + (["vector"] if counts["embeddings"] else []),
            "tfidf_index_ready": tfidf_ready,
            "tfidf_index_path": str(self.tfidf_path),
            "tfidf_index_bytes": self.tfidf_path.stat().st_size if tfidf_ready else 0,
            "vector_search_ready": counts["embeddings"] > 0,
            "warnings": warnings,
        }

    def search(self, query: str, *, limit: int = 10, filters: Filters | None = None) -> list[dict[str, Any]]:
        filters = filters or Filters()
        match = fts_query(query)
        if not match:
            return []

        candidates: dict[str, dict[str, Any]] = {}
        clauses, parameters = self.filter_sql(filters)
        where = " AND ".join(clauses)
        candidate_limit = max(30, limit * 6)
        with self.connect() as connection:
            for chunk_id, score in self.tfidf_candidates(query, candidate_limit):
                tfidf_clauses = [*clauses, "c.chunk_id=?"]
                row = connection.execute(
                    f"""
                    SELECT c.*, d.title, d.normalized_title, d.country, d.document_type,
                           d.approval_date, d.revision_date, d.protocol_number,
                           d.status AS document_status, df.latest_doc_id,
                           family_counts.document_count AS family_document_count
                    FROM chunks c
                    JOIN documents d ON d.doc_id=c.doc_id
                    LEFT JOIN document_families df ON df.document_family_id=c.document_family_id
                    LEFT JOIN (
                        SELECT document_family_id, COUNT(*) AS document_count
                        FROM documents GROUP BY document_family_id
                    ) family_counts ON family_counts.document_family_id=c.document_family_id
                    WHERE {' AND '.join(tfidf_clauses)}
                    """,
                    [*parameters, chunk_id],
                ).fetchone()
                if row is not None:
                    self.merge(candidates, row, float(score), "tfidf")

            rows = connection.execute(
                f"""
                SELECT c.*, d.title, d.normalized_title, d.country, d.document_type,
                       d.approval_date, d.revision_date, d.protocol_number,
                       d.status AS document_status, df.latest_doc_id,
                       family_counts.document_count AS family_document_count,
                       bm25(chunks_fts) AS fts_rank
                FROM chunks_fts
                JOIN chunks c ON c.chunk_id=chunks_fts.chunk_id
                JOIN documents d ON d.doc_id=c.doc_id
                LEFT JOIN document_families df ON df.document_family_id=c.document_family_id
                LEFT JOIN (
                    SELECT document_family_id, COUNT(*) AS document_count
                    FROM documents GROUP BY document_family_id
                ) family_counts ON family_counts.document_family_id=c.document_family_id
                WHERE chunks_fts MATCH ? AND {where}
                ORDER BY fts_rank LIMIT ?
                """,
                [match, *parameters, candidate_limit],
            ).fetchall()
            for row in rows:
                self.merge(candidates, row, 1.0 / (1.0 + abs(float(row["fts_rank"] or 0.0))), "fts5")

            terms = [token.casefold() for token in _TOKEN_PATTERN.findall(query) if len(token) >= 3][:8]
            if terms:
                entity_condition = " OR ".join("LOWER(e.normalized_text) LIKE ? OR LOWER(e.canonical_name) LIKE ?" for _ in terms)
                entity_values = [value for term in terms for value in (f"%{term}%", f"%{term}%")]
                rows = connection.execute(
                    f"""
                    SELECT c.*, d.title, d.normalized_title, d.country, d.document_type,
                           d.approval_date, d.revision_date, d.protocol_number,
                           d.status AS document_status, df.latest_doc_id,
                           family_counts.document_count AS family_document_count,
                           e.type AS matched_entity_type
                    FROM entities e
                    JOIN chunks c ON c.chunk_id=e.chunk_id
                    JOIN documents d ON d.doc_id=c.doc_id
                    LEFT JOIN document_families df ON df.document_family_id=c.document_family_id
                    LEFT JOIN (
                        SELECT document_family_id, COUNT(*) AS document_count
                        FROM documents GROUP BY document_family_id
                    ) family_counts ON family_counts.document_family_id=c.document_family_id
                    WHERE ({entity_condition}) AND {where}
                    LIMIT ?
                    """,
                    [*entity_values, *parameters, candidate_limit],
                ).fetchall()
                for row in rows:
                    self.merge(candidates, row, 0.75, "entity")

        preferred = intent_types(query)
        normalized_query = query.casefold()
        query_terms = list(dict.fromkeys(token.casefold() for token in _TOKEN_PATTERN.findall(query) if len(token) > 1))
        for item in candidates.values():
            title_text = item["title"].casefold()
            section_text = item["section_path"].casefold()
            searchable = f"{title_text} {section_text} {item['text']}".casefold()
            matched_terms = [term for term in query_terms if term in searchable]
            coverage = len(matched_terms) / len(query_terms) if query_terms else 0.0
            item["matched_terms"] = matched_terms
            item["term_coverage"] = round(coverage, 3)
            item["score"] += coverage * 1.5
            if coverage == 1.0:
                item["score"] += 0.75
            item["score"] += sum(0.75 for term in query_terms if term in title_text)
            item["score"] += sum(0.2 for term in query_terms if term in section_text)
            if item["content_type"] in preferred:
                item["score"] += 0.2
            if normalized_query in item["text"].casefold():
                item["score"] += 0.25
            if item["is_latest_known"] and item["version_group_trusted"]:
                item["score"] += 0.1
            if filters.icd10_code and filters.icd10_code.upper() in {code.upper() for code in item["icd10_codes"]}:
                item["score"] += 0.25
        return sorted(candidates.values(), key=lambda value: (-value["score"], value["title"]))[:limit]

    def tfidf_candidates(self, query: str, limit: int) -> list[tuple[str, float]]:
        if not self.tfidf_path.is_file():
            return []
        if self._tfidf_data is None:
            with self.tfidf_path.open("rb") as handle:
                self._tfidf_data = pickle.load(handle)  # noqa: S301 - trusted local pipeline artifact
        data = self._tfidf_data
        scores = (data["matrix"] @ data["vectorizer"].transform([query]).T).toarray().ravel()
        indexes = scores.argsort()[::-1][:limit]
        return [(str(data["chunk_ids"][index]), float(scores[index])) for index in indexes if scores[index] > 0]

    def list_documents(self, *, limit: int, offset: int, query: str | None = None) -> dict[str, Any]:
        where = "1=1"
        values: list[Any] = []
        if query:
            where += " AND (d.title LIKE ? OR d.normalized_title LIKE ?)"
            values.extend((f"%{query}%", f"%{query.casefold()}%"))
        with self.connect() as connection:
            total = int(connection.execute(f"SELECT COUNT(*) FROM documents d WHERE {where}", values).fetchone()[0])
            rows = connection.execute(
                f"""
                SELECT d.*,df.latest_doc_id,
                       (SELECT COUNT(*) FROM sections s WHERE s.doc_id=d.doc_id) section_count,
                       (SELECT COUNT(*) FROM tables t WHERE t.doc_id=d.doc_id) table_count,
                       (SELECT COUNT(*) FROM chunks c WHERE c.doc_id=d.doc_id) chunk_count
                FROM documents d LEFT JOIN document_families df ON df.document_family_id=d.document_family_id
                WHERE {where} ORDER BY d.title,d.approval_date DESC LIMIT ? OFFSET ?
                """,
                [*values, limit, offset],
            ).fetchall()
        return {"total": total, "items": [self.document(row) for row in rows]}

    def get_document(self, doc_id: str) -> dict[str, Any] | None:
        with self.connect() as connection:
            row = connection.execute(
                """
                SELECT d.*,sf.source_pdf_path,sf.markdown_path,sf.docling_json_path,df.latest_doc_id,
                       (SELECT COUNT(*) FROM sections s WHERE s.doc_id=d.doc_id) section_count,
                       (SELECT COUNT(*) FROM tables t WHERE t.doc_id=d.doc_id) table_count,
                       (SELECT COUNT(*) FROM chunks c WHERE c.doc_id=d.doc_id) chunk_count,
                       (SELECT COUNT(*) FROM entities e WHERE e.doc_id=d.doc_id) entity_count
                FROM documents d
                LEFT JOIN source_files sf ON sf.source_id=d.source_id
                LEFT JOIN document_families df ON df.document_family_id=d.document_family_id
                WHERE d.doc_id=?
                """,
                (doc_id,),
            ).fetchone()
            if row is None:
                return None
            result = self.document(row)
            result["sections"] = [
                dict(section)
                for section in connection.execute(
                    "SELECT section_id,parent_section_id,section_path,title,level,order_index,section_type,page_start,page_end FROM sections WHERE doc_id=? ORDER BY order_index",
                    (doc_id,),
                )
            ]
            return result

    def get_document_presentation(self, doc_id: str) -> dict[str, Any] | None:
        document = self.get_document(doc_id)
        if document is None:
            return None

        section_metadata = {
            section["section_id"]: section
            for section in document.get("sections", [])
            if section.get("section_id")
        }
        sections: dict[str, dict[str, Any]] = {}

        def ensure_section(section_id: str | None, section_path: str | None) -> dict[str, Any]:
            key = section_id or section_path or "document"
            if key not in sections:
                metadata = section_metadata.get(section_id or "", {})
                path = clean_text(section_path or metadata.get("section_path") or "Документ")
                title = display_section_title(metadata.get("title") or path)
                sections[key] = {
                    "id": section_id or key,
                    "title": title or "Документ",
                    "path": path or "Документ",
                    "level": metadata.get("level"),
                    "blocks": [],
                    "_seen_text": set(),
                }
            return sections[key]

        with self.connect() as connection:
            chunks = connection.execute(
                """
                SELECT rowid AS source_order,chunk_id,section_id,section_path,content_type,text,table_json,page_hint_json
                FROM chunks WHERE doc_id=? ORDER BY rowid
                """,
                (doc_id,),
            ).fetchall()
            tables = connection.execute(
                """
                SELECT t.rowid AS source_order,t.*,s.section_path,s.title AS section_title
                FROM tables t LEFT JOIN sections s ON s.section_id=t.section_id
                WHERE t.doc_id=? ORDER BY t.rowid
                """,
                (doc_id,),
            ).fetchall()

        for chunk in chunks:
            table_reference = json_value(chunk["table_json"], None)
            if chunk["content_type"] in {"table", "table_row"} or table_reference:
                continue
            if clean_text(chunk["text"]).startswith("Таблица. Колонка"):
                continue
            section = ensure_section(chunk["section_id"], chunk["section_path"])
            normalized = clean_text(chunk["text"])
            if not normalized or normalized in section["_seen_text"]:
                continue
            section["_seen_text"].add(normalized)
            blocks = text_blocks(
                chunk["text"],
                content_type=chunk["content_type"] or "text",
                section_title=section["title"],
            )
            page_hint = json_value(chunk["page_hint_json"], None)
            for block in blocks:
                block["source"] = {"chunk_id": chunk["chunk_id"], "page_hint": page_hint}
                section["blocks"].append(block)

        for table in tables:
            section = ensure_section(table["section_id"], table["section_path"])
            section["blocks"].append(
                table_block(
                    table_id=table["table_id"],
                    title=table["title"] or table["section_title"],
                    table_type=table["table_type"],
                    columns=json_value(table["columns_json"], []),
                    rows=json_value(table["rows_json"], []),
                    plain_text=table["plain_text"],
                    quality_flags=json_value(table["quality_flags_json"], []),
                )
            )

        presentation_sections = []
        for section in sections.values():
            section.pop("_seen_text", None)
            if section["blocks"]:
                presentation_sections.append(section)

        document.pop("sections", None)
        return {
            "document": document,
            "sections": presentation_sections,
            "presentation_version": 1,
            "raw_ocr_preserved": True,
            "empty": not presentation_sections,
        }

    def get_family(self, family_id: str) -> dict[str, Any] | None:
        with self.connect() as connection:
            family = connection.execute("SELECT * FROM document_families WHERE document_family_id=?", (family_id,)).fetchone()
            if family is None:
                return None
            versions = connection.execute(
                "SELECT doc_id,title,normalized_title,approval_date,revision_date,protocol_number,status,version_label FROM documents WHERE document_family_id=? ORDER BY approval_date DESC",
                (family_id,),
            ).fetchall()
        result = dict(family)
        for key in ("icd10_codes_json", "clinical_domain_json", "aliases_json", "duplicate_groups_json"):
            result[key.removesuffix("_json")] = json_value(result.pop(key), [])
        trusted = len(versions) == 1 or str(family["canonical_title"]).casefold() not in _GENERIC_TITLES
        result["version_group_trusted"] = trusted
        result["versions"] = [dict(version) | {"is_latest_known": version["doc_id"] == family["latest_doc_id"]} for version in versions]
        if not trusted:
            result["warning"] = "Documents share a generic OCR title and must not be treated as versions without review."
        return result

    def get_table(self, table_id: str) -> dict[str, Any] | None:
        with self.connect() as connection:
            row = connection.execute(
                "SELECT t.*,d.title,d.version_label,d.approval_date FROM tables t JOIN documents d ON d.doc_id=t.doc_id WHERE t.table_id=?",
                (table_id,),
            ).fetchone()
        if row is None:
            return None
        result = dict(row)
        for key, default in (("columns_json", []), ("rows_json", []), ("cells_json", []), ("extracted_entities_json", []), ("page_hint_json", None), ("quality_flags_json", [])):
            result[key.removesuffix("_json")] = json_value(result.pop(key), default)
        result["presentation"] = table_block(
            table_id=result["table_id"],
            title=result["title"],
            table_type=result["table_type"],
            columns=result["columns"],
            rows=result["rows"],
            plain_text=result["plain_text"],
            quality_flags=result["quality_flags"],
        )
        return result

    def list_entities(self, *, entity_type: str | None, query: str | None, limit: int) -> list[dict[str, Any]]:
        clauses = ["1=1"]
        values: list[Any] = []
        if entity_type:
            clauses.append("e.type=?")
            values.append(entity_type)
        if query:
            clauses.append("(e.raw_text LIKE ? OR e.normalized_text LIKE ? OR e.canonical_name LIKE ?)")
            values.extend((f"%{query}%", f"%{query}%", f"%{query}%"))
        with self.connect() as connection:
            rows = connection.execute(
                f"SELECT e.*,d.title,d.version_label FROM entities e JOIN documents d ON d.doc_id=e.doc_id WHERE {' AND '.join(clauses)} ORDER BY e.confidence DESC,e.id LIMIT ?",
                [*values, limit],
            ).fetchall()
        results = []
        for row in rows:
            item = dict(row)
            item["source_location"] = json_value(item.pop("source_location_json"), {})
            results.append(item)
        return results

    def quality_issues(self, *, limit: int) -> list[dict[str, Any]]:
        with self.connect() as connection:
            rows = connection.execute(
                """
                SELECT source_id,base_name,status,warnings_json,source_pdf_path,markdown_path,docling_json_path
                FROM source_files
                WHERE status<>'ready_for_ingest' OR COALESCE(warnings_json,'[]')<>'[]'
                ORDER BY status,base_name LIMIT ?
                """,
                (limit,),
            ).fetchall()
        return [dict(row) | {"warnings": json_value(row["warnings_json"], [])} for row in rows]

    def clinical_categories(self) -> list[dict[str, Any]]:
        counts: dict[str, int] = {}
        for item in self._clinical_protocol_rows():
            category_id = self._clinical_category(item["base_name"], json_value(item["icd10_codes_json"], []))
            counts[category_id] = counts.get(category_id, 0) + 1
        return [
            {"id": category_id, "title": _CLINICAL_CATEGORIES[category_id][0], "disease_count": count}
            for category_id, count in sorted(counts.items(), key=lambda pair: _CLINICAL_CATEGORIES[pair[0]][0])
        ]

    def clinical_diseases(
        self, *, category: str | None, query: str | None, limit: int, offset: int
    ) -> dict[str, Any]:
        normalized_query = (query or "").casefold().strip()
        items = []
        seen: set[str] = set()
        for row in self._clinical_protocol_rows():
            name = self._clean_protocol_name(row["base_name"])
            key = re.sub(r"\W+", " ", name.casefold()).strip()
            if not key or key in seen:
                continue
            category_id = self._clinical_category(name, json_value(row["icd10_codes_json"], []))
            if category and category_id != category:
                continue
            if normalized_query and normalized_query not in name.casefold():
                continue
            seen.add(key)
            items.append(self._clinical_summary(row, name, category_id))
        items.sort(key=lambda item: item["title"])
        return {"total": len(items), "items": items[offset : offset + limit]}

    def clinical_disease(self, doc_id: str) -> dict[str, Any] | None:
        with self.connect() as connection:
            row = connection.execute(
                """
                SELECT d.*,sf.base_name,sf.source_pdf_path
                FROM documents d JOIN source_files sf ON sf.source_id=d.source_id
                WHERE d.doc_id=?
                """,
                (doc_id,),
            ).fetchone()
            if row is None:
                return None
            chunks = connection.execute(
                """
                SELECT section_path,content_type,text,page_hint_json
                FROM chunks WHERE doc_id=? ORDER BY rowid
                """,
                (doc_id,),
            ).fetchall()
        name = self._clean_protocol_name(row["base_name"])
        codes = json_value(row["icd10_codes_json"], [])
        category_id = self._clinical_category(name, codes)
        sections: dict[str, list[str]] = {}
        for chunk in chunks:
            section = self._display_section(chunk["section_path"])
            bucket = sections.setdefault(section, [])
            text = self._clean_clinical_text(chunk["text"])
            if text and text not in bucket:
                bucket.append(text)
        compact_sections = {
            title: "\n\n".join(values)
            for title, values in sections.items()
            if values
        }
        return self._clinical_summary(row, name, category_id) | {
            "sections": compact_sections,
            "source_pdf_path": row["source_pdf_path"],
            "disclaimer": "Материал основан на локальном клиническом протоколе и требует проверки актуальности и применимости.",
        }

    def clinical_recommendations(self, doc_id: str, *, limit: int = 12) -> list[dict[str, Any]]:
        current = self.clinical_disease(doc_id)
        if current is None:
            return []
        codes = {self._normalize_icd(code) for code in current["icd10_codes"]}
        codes.discard("")
        candidates = []
        for row in self._clinical_protocol_rows():
            if row["doc_id"] == doc_id:
                continue
            row_codes = {self._normalize_icd(code) for code in json_value(row["icd10_codes_json"], [])}
            overlap = sorted(codes & row_codes)
            if not overlap:
                continue
            name = self._clean_protocol_name(row["base_name"])
            category_id = self._clinical_category(name, list(row_codes))
            candidates.append(self._clinical_summary(row, name, category_id) | {"shared_icd10": overlap})
        candidates.sort(key=lambda item: (-len(item["shared_icd10"]), item["title"]))
        return candidates[:limit]

    def _clinical_protocol_rows(self) -> list[sqlite3.Row]:
        with self.connect() as connection:
            return connection.execute(
                """
                SELECT d.*,sf.base_name,sf.source_pdf_path
                FROM documents d JOIN source_files sf ON sf.source_id=d.source_id
                WHERE d.document_type IN ('clinical_protocol','medical_rehabilitation_protocol')
                  AND sf.base_name IS NOT NULL AND TRIM(sf.base_name)<>''
                ORDER BY COALESCE(d.approval_date,'') DESC,d.doc_id
                """
            ).fetchall()

    @staticmethod
    def _clean_protocol_name(value: str) -> str:
        return clean_text(value).strip(" «»\".")

    @staticmethod
    def _normalize_icd(value: str) -> str:
        translations = str.maketrans({"А": "A", "В": "B", "С": "C", "Е": "E", "Н": "H", "К": "K", "М": "M", "О": "O", "Р": "P", "Т": "T", "Х": "X", "И": "I"})
        return str(value).upper().translate(translations).strip()

    @classmethod
    def _clinical_category(cls, title: str, codes: list[str]) -> str:
        upper_title = title.upper()
        for category_id, hints in _TITLE_CATEGORY_HINTS.items():
            if any(hint in upper_title for hint in hints):
                return category_id
        normalized_codes = [cls._normalize_icd(code) for code in codes]
        for category_id, (_, *prefixes) in _CLINICAL_CATEGORIES.items():
            if any(code.startswith(tuple(prefixes)) for code in normalized_codes if code):
                return category_id
        return "general"

    @staticmethod
    def _display_section(value: str | None) -> str:
        text = re.sub(r"\s+", " ", str(value or "Клиническая рекомендация")).strip()
        return text.split(" > ")[-1] or "Клиническая рекомендация"

    @staticmethod
    def _clean_clinical_text(value: str | None) -> str:
        text = str(value or "").replace("\r\n", "\n").replace("\r", "\n")
        # PDF fonts often encode list bullets as private-use Wingdings glyphs.
        text = re.sub(r"(?m)^[\ue000-\uf8ff]\s*", "• ", text)
        text = re.sub(r"[\ue000-\uf8ff]", "", text)
        return text.strip()

    @staticmethod
    def _clinical_summary(row: sqlite3.Row, name: str, category_id: str) -> dict[str, Any]:
        codes = json_value(row["icd10_codes_json"], [])
        return {
            "id": row["doc_id"],
            "title": name,
            "category_id": category_id,
            "category": _CLINICAL_CATEGORIES[category_id][0],
            "icd10_codes": codes,
            "approval_date": row["approval_date"],
            "revision_date": row["revision_date"],
            "protocol_number": row["protocol_number"],
            "version": row["version_label"],
            "document_type": row["document_type"],
        }

    @staticmethod
    def filter_sql(filters: Filters) -> tuple[list[str], list[Any]]:
        clauses = ["1=1"]
        values: list[Any] = []
        for value, clause in (
            (filters.country, "d.country=?"),
            (filters.document_type, "d.document_type=?"),
            (filters.content_type, "c.content_type=?"),
            (filters.document_family_id, "c.document_family_id=?"),
        ):
            if value:
                clauses.append(clause)
                values.append(value)
        if filters.clinical_domain:
            clauses.append("c.clinical_domain_json LIKE ?")
            values.append(f'%"{filters.clinical_domain}"%')
        if filters.icd10_code:
            clauses.append("c.icd10_codes_json LIKE ?")
            values.append(f'%"{filters.icd10_code.upper()}"%')
        if filters.version_policy == "latest_known":
            clauses.append("df.latest_doc_id=d.doc_id")
            clauses.append("LOWER(d.normalized_title) NOT IN ({})".format(",".join("?" for _ in _GENERIC_TITLES)))
            values.extend(sorted(_GENERIC_TITLES))
        return clauses, values

    def merge(self, candidates: dict[str, dict[str, Any]], row: sqlite3.Row, score: float, source: str) -> None:
        key = str(row["chunk_id"])
        existing = candidates.get(key)
        if existing:
            existing["score"] += score * 0.5
            if source not in existing["matched_by"]:
                existing["matched_by"].append(source)
            return

        source_refs = json_value(row["source_refs_json"], {})
        table_ref = json_value(row["table_json"], None)
        source_pdf_path = source_refs.get("source_pdf_path")
        source_pdf_absolute_path = None
        if source_pdf_path:
            source_pdf_absolute_path = str((self.corpus_root / source_pdf_path).resolve())
        family_size = int(row["family_document_count"] or 1)
        trusted = family_size == 1 or str(row["normalized_title"] or "").casefold() not in _GENERIC_TITLES
        candidates[key] = {
            "chunk_id": key,
            "doc_id": row["doc_id"],
            "document_family_id": row["document_family_id"],
            "title": row["title"],
            "section_id": row["section_id"],
            "section_path": row["section_path"],
            "content_type": row["content_type"],
            "text": row["text"],
            "display_text": clean_text(row["text"]),
            "version": row["version"],
            "approval_date": row["approval_date"],
            "revision_date": row["revision_date"],
            "protocol_number": row["protocol_number"],
            "document_status": row["document_status"],
            "family_document_count": family_size,
            "version_group_trusted": trusted,
            "is_latest_known": bool(row["latest_doc_id"] and row["latest_doc_id"] == row["doc_id"]),
            "version_warning": None if trusted else "Generic OCR title: version relationship is not verified.",
            "icd10_codes": json_value(row["icd10_codes_json"], []),
            "clinical_domain": json_value(row["clinical_domain_json"], []),
            "page_hint": json_value(row["page_hint_json"], None),
            "table_ref": table_ref,
            "source_refs": source_refs,
            "citation": {
                "title": row["title"],
                "version": row["version"],
                "approval_date": row["approval_date"],
                "section_path": row["section_path"],
                "page_hint": json_value(row["page_hint_json"], None),
                "source_pdf_path": source_pdf_path,
                "source_pdf_absolute_path": source_pdf_absolute_path,
            },
            "score": score,
            "matched_by": [source],
        }

    @staticmethod
    def document(row: sqlite3.Row) -> dict[str, Any]:
        result = dict(row)
        for key, default in (("clinical_domain_json", []), ("icd10_codes_json", []), ("warnings_json", []), ("ocr_quality_flags_json", []), ("processing_json", {})):
            if key in result:
                result[key.removesuffix("_json")] = json_value(result.pop(key), default)
        if "latest_doc_id" in result:
            result["is_latest_known"] = bool(result["latest_doc_id"] and result["latest_doc_id"] == result["doc_id"])
        return result
