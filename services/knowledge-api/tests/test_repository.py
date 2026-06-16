from __future__ import annotations

import json
import sqlite3
from pathlib import Path

import pytest

from medical_kb.repository import Filters, Repository
from medical_kb.presentation import clean_text, table_block, text_blocks


def test_private_use_pdf_bullets_are_normalized() -> None:
    text = Repository._clean_clinical_text("\uf0b7 протеинурия;\n\uf0b7 гипертония;")
    assert text == "• протеинурия;\n• гипертония;"


def test_display_text_decodes_html_and_normalizes_medical_spacing() -> None:
    assert clean_text("ЛДГ&amp;gt;600 МЕ/л; МКБ - 10; HELLP - синдром") == (
        "ЛДГ > 600 МЕ/л; МКБ-10; HELLP-синдром"
    )


def test_abbreviation_table_gets_explicit_headers() -> None:
    block = table_block(
        table_id="table1",
        title="",
        table_type="unknown",
        columns=["ЛДГ", "-", "лактатдегидрогеназа"],
        rows=[["АСТ", "-", "аспартатаминотрансфераза"]],
        plain_text="",
        quality_flags=[],
    )
    assert block["render_mode"] == "structured"
    assert block["columns"] == ["Сокращение", "—", "Расшифровка"]
    assert block["rows"][0] == ["ЛДГ", "-", "лактатдегидрогеназа"]


def test_broken_table_uses_text_fallback() -> None:
    block = table_block(
        table_id="broken",
        title="Поврежденная таблица",
        table_type="unknown",
        columns=["Показатель", "Значение"],
        rows=[["ЛДГ"], ["", ""]],
        plain_text="ЛДГ > 600 МЕ/л",
        quality_flags=["shape_mismatch"],
    )
    assert block["render_mode"] == "fallback"
    assert block["rows"] == []
    assert block["fallback_text"] == "ЛДГ > 600 МЕ/л"


def test_reference_markers_are_moved_out_of_display_text() -> None:
    blocks = text_blocks("Критерий описан в протоколе [1, 2].")
    assert blocks[0]["text"] == "Критерий описан в протоколе."
    assert blocks[0]["references"] == ["1,2"]


@pytest.fixture()
def database(tmp_path: Path) -> Path:
    path = tmp_path / "kb.sqlite"
    connection = sqlite3.connect(path)
    connection.executescript(
        """
        CREATE TABLE source_files(source_id TEXT,base_name TEXT,status TEXT,warnings_json TEXT,source_pdf_path TEXT,markdown_path TEXT,docling_json_path TEXT);
        CREATE TABLE documents(doc_id TEXT,document_family_id TEXT,source_id TEXT,title TEXT,normalized_title TEXT,language TEXT,country TEXT,document_type TEXT,clinical_domain_json TEXT,icd10_codes_json TEXT,approval_date TEXT,revision_date TEXT,protocol_number TEXT,approval_authority TEXT,status TEXT,version_label TEXT,warnings_json TEXT,ocr_quality_flags_json TEXT,processing_json TEXT,created_at TEXT,updated_at TEXT);
        CREATE TABLE document_families(document_family_id TEXT,canonical_title TEXT,canonical_disease TEXT,icd10_codes_json TEXT,country TEXT,document_type TEXT,clinical_domain_json TEXT,latest_doc_id TEXT,aliases_json TEXT,duplicate_groups_json TEXT,created_at TEXT,updated_at TEXT);
        CREATE TABLE sections(section_id TEXT,doc_id TEXT,parent_section_id TEXT,section_path TEXT,title TEXT,normalized_title TEXT,level INTEGER,order_index INTEGER,section_type TEXT,page_start INTEGER,page_end INTEGER,quality_flags_json TEXT,created_at TEXT);
        CREATE TABLE tables(table_id TEXT,doc_id TEXT,section_id TEXT,title TEXT,table_type TEXT,columns_json TEXT,rows_json TEXT,cells_json TEXT,markdown TEXT,plain_text TEXT,extracted_entities_json TEXT,page_hint_json TEXT,quality_flags_json TEXT,created_at TEXT);
        CREATE TABLE chunks(chunk_id TEXT,doc_id TEXT,document_family_id TEXT,section_id TEXT,section_path TEXT,content_type TEXT,text TEXT,table_json TEXT,keywords_json TEXT,entity_refs_json TEXT,icd10_codes_json TEXT,clinical_domain_json TEXT,version TEXT,page_hint_json TEXT,embedding_text TEXT,source_refs_json TEXT,quality_json TEXT,created_at TEXT);
        CREATE TABLE entities(entity_id TEXT,doc_id TEXT,chunk_id TEXT,section_id TEXT,type TEXT,raw_text TEXT,normalized_text TEXT,canonical_name TEXT,value TEXT,operator TEXT,unit TEXT,normalized_unit TEXT,clinical_context TEXT,evidence_level TEXT,confidence REAL,source_location_json TEXT,created_at TEXT);
        CREATE TABLE embeddings(chunk_id TEXT);
        CREATE VIRTUAL TABLE chunks_fts USING fts5(chunk_id UNINDEXED,title,section_path,text);
        """
    )
    connection.execute("INSERT INTO source_files VALUES(?,?,?,?,?,?,?)", ("src1", "HELLP", "ready_for_ingest", "[]", "HELLP.pdf", "HELLP.md", "HELLP.json"))
    connection.execute(
        "INSERT INTO documents VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        ("doc1", "fam1", "src1", "HELLP-синдром", "hellp-синдром", "ru", "KZ", "clinical_protocol", '["obstetrics"]', '["O14.2"]', "2023", None, "177", None, "ingested", "2023_protocol_177", "[]", "[]", "{}", "now", "now"),
    )
    connection.execute("INSERT INTO document_families VALUES(?,?,?,?,?,?,?,?,?,?,?,?)", ("fam1", "HELLP-синдром", "HELLP-синдром", '["O14.2"]', "KZ", "clinical_protocol", '["obstetrics"]', "doc1", '["HELLP"]', "[]", "now", "now"))
    connection.execute("INSERT INTO sections VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)", ("sec1", "doc1", None, "Диагностические критерии", "Диагностические критерии", "диагностические критерии", 1, 1, "diagnostic_criteria", None, None, "[]", "now"))
    connection.execute("INSERT INTO chunks VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", ("chunk1", "doc1", "fam1", "sec1", "Диагностические критерии", "lab_threshold", "ЛДГ > 600 МЕ/л", "null", "[]", '["ent1"]', '["O14.2"]', '["obstetrics"]', "2023_protocol_177", "null", "HELLP ЛДГ 600", json.dumps({"source_pdf_path": "HELLP.pdf"}), "{}", "now"))
    connection.execute("INSERT INTO chunks_fts VALUES(?,?,?,?)", ("chunk1", "HELLP-синдром", "Диагностические критерии", "ЛДГ > 600 МЕ/л"))
    connection.execute("INSERT INTO entities VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", ("ent1", "doc1", "chunk1", "sec1", "lab_threshold", "ЛДГ > 600 МЕ/л", "ЛДГ > 600 МЕ/л", "лактатдегидрогеназа", "600", ">", "МЕ/л", "IU/L", "diagnostic_criteria", None, 0.9, "{}", "now"))
    connection.execute(
        "INSERT INTO tables VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (
            "table1", "doc1", "sec1", "Сокращения", "unknown",
            '["ЛДГ", "-", "лактатдегидрогеназа"]',
            '[["АСТ", "-", "аспартатаминотрансфераза"]]',
            "[]", "", "", "[]", "null", "[]", "now",
        ),
    )
    connection.commit()
    connection.close()
    return path


def test_status_and_search(database: Path) -> None:
    repository = Repository(database)
    status = repository.status()
    assert status["available"] is True
    assert status["counts"]["documents"] == 1
    results = repository.search("HELLP критерии ЛДГ", filters=Filters(icd10_code="O14.2"))
    assert results
    assert results[0]["doc_id"] == "doc1"
    assert results[0]["citation"]["source_pdf_path"] == "HELLP.pdf"
    assert results[0]["term_coverage"] == 1.0


def test_database_is_read_only(database: Path) -> None:
    repository = Repository(database)
    with repository.connect() as connection, pytest.raises(sqlite3.OperationalError):
        connection.execute("DELETE FROM documents")


def test_document_presentation_contains_typed_blocks_and_table(database: Path) -> None:
    item = Repository(database).get_document_presentation("doc1")

    assert item is not None
    assert item["raw_ocr_preserved"] is True
    assert item["empty"] is False
    blocks = item["sections"][0]["blocks"]
    assert blocks[0]["type"] == "lab_value"
    assert blocks[0]["text"] == "ЛДГ > 600 МЕ/л"
    assert blocks[-1]["type"] == "table"
    assert blocks[-1]["render_mode"] == "structured"
    with sqlite3.connect(database) as connection:
        raw_text = connection.execute(
            "SELECT text FROM chunks WHERE chunk_id='chunk1'"
        ).fetchone()[0]
    assert raw_text == "ЛДГ > 600 МЕ/л"


def test_empty_document_returns_explicit_empty_state(database: Path) -> None:
    connection = sqlite3.connect(database)
    connection.execute(
        "INSERT INTO source_files VALUES(?,?,?,?,?,?,?)",
        ("src2", "Пустой протокол", "ready_for_ingest", "[]", "empty.pdf", "", ""),
    )
    connection.execute(
        "INSERT INTO documents VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (
            "doc2", "fam2", "src2", "Пустой протокол", "пустой протокол",
            "ru", "KZ", "clinical_protocol", "[]", "[]", None, None, None,
            None, "ingested", "", "[]", "[]", "{}", "now", "now",
        ),
    )
    connection.commit()
    connection.close()

    item = Repository(database).get_document_presentation("doc2")

    assert item is not None
    assert item["empty"] is True
    assert item["sections"] == []


def test_clinical_disease_does_not_truncate_regulated_text(database: Path) -> None:
    long_title = "Нормативный раздел " + "А" * 140
    long_text = "Начало нормативного текста\n" + "Т" * 13000 + "\nКонец нормативного текста"
    connection = sqlite3.connect(database)
    connection.execute(
        "INSERT INTO chunks VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (
            "chunk2", "doc1", "fam1", "sec1", long_title, "narrative", long_text,
            "null", "[]", "[]", '["O14.2"]', '["obstetrics"]',
            "2023_protocol_177", "null", "", "{}", "{}", "now",
        ),
    )
    connection.commit()
    connection.close()

    item = Repository(database).clinical_disease("doc1")

    assert item is not None
    assert long_title in item["sections"]
    assert item["sections"][long_title] == long_text
