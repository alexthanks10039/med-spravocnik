import unittest

from med_pipeline import (
    build_presentation_blocks,
    normalize_display_text,
    restore_abbreviation_table,
)


class PresentationLayerTests(unittest.TestCase):
    def test_normalize_display_text_extracts_references(self) -> None:
        text, references = normalize_display_text(
            "HELLP - синдром&nbsp;[1, 2].\n\uf0b7 Протеинурия [3]"
        )

        self.assertEqual(text, "HELLP — синдром.\n• Протеинурия")
        self.assertEqual(
            references,
            [
                {"label": "[1, 2]", "numbers": [1, 2]},
                {"label": "[3]", "numbers": [3]},
            ],
        )

    def test_builds_definition_and_lab_threshold_blocks(self) -> None:
        chunk = {
            "chunk_id": "chunk-1",
            "content_type": "lab_threshold",
            "text": "HELLP-синдром - осложнение беременности [1].",
            "section_path": "Определение",
        }
        section = {"title": "Определение", "section_type": "unknown"}
        entities = [
            {
                "type": "lab_threshold",
                "raw_text": "ЛДГ > 600 МЕ/л",
                "canonical_name": "лактатдегидрогеназа",
                "operator": ">",
                "value": "600",
                "unit": "МЕ/л",
                "normalized_unit": "IU/L",
                "clinical_context": "diagnostic_criteria",
            }
        ]

        blocks = build_presentation_blocks(chunk, section, entities, None)

        self.assertEqual(blocks[0]["block_type"], "definition")
        self.assertEqual(
            blocks[0]["body"]["text"],
            "HELLP-синдром — осложнение беременности.",
        )
        self.assertEqual(blocks[0]["references"][0]["numbers"], [1])
        self.assertEqual(blocks[1]["block_type"], "lab_threshold")
        self.assertEqual(blocks[1]["body"]["value"], "600")

    def test_builds_abbreviation_block(self) -> None:
        blocks = build_presentation_blocks(
            {"chunk_id": "chunk-2", "content_type": "text", "text": "АД - артериальное давление; ЧСС - частота сердечных сокращений"},
            {"title": "Сокращения", "section_type": "abbreviations"},
            [],
            None,
        )

        self.assertEqual(blocks[0]["block_type"], "abbreviations")
        self.assertEqual(len(blocks[0]["body"]["items"]), 2)
        self.assertIn("АД — артериальное давление", blocks[0]["body"]["items"])

    def test_table_block_uses_rows_json_instead_of_chunk_text(self) -> None:
        blocks = build_presentation_blocks(
            {
                "chunk_id": "chunk-table",
                "content_type": "table",
                "text": "THIS RAW TEXT MUST NOT BE USED",
                "table_json": '{"table_id":"table-1"}',
            },
            {"title": "Критерии", "section_type": "diagnostic_criteria"},
            [],
            {
                "table_id": "table-1",
                "title": "Лабораторные критерии",
                "table_type": "diagnostic_criteria",
                "columns_json": '["Показатель","Порог"]',
                "rows_json": '[["ЛДГ","> 600 МЕ/л"]]',
            },
        )

        self.assertEqual(blocks[0]["block_type"], "table")
        self.assertEqual(blocks[0]["body"]["rows"], [["ЛДГ", "> 600 МЕ/л"]])
        self.assertNotIn("THIS RAW TEXT", str(blocks[0]["body"]))

    def test_restores_abbreviation_table_from_wrong_headers(self) -> None:
        restored = restore_abbreviation_table(
            {
                "table_id": "table-abbr",
                "columns_json": '["аГУС","-","атипичный гемолитико-уремический синдром"]',
                "rows_json": '[["АЛТ","-","аланинаминотрансфераза"],["АСТ","-","аспартатаминотрансфераза"],["АЧТВ","-","активированное частичное тромбопластиновое время"]]',
                "cells_json": "[]",
                "plain_text": "Таблица. Колонка аГУС: АЛТ; Колонка -: -; Колонка атипичный гемолитико-уремический синдром: аланинаминотрансфераза",
                "quality_flags_json": "[]",
            }
        )

        self.assertEqual(restored["table_type"], "abbreviations")
        self.assertEqual(
            restored["columns_json"],
            '["Сокращение", "—", "Расшифровка"]',
        )
        self.assertEqual(
            __import__("json").loads(restored["rows_json"])[0],
            ["аГУС", "—", "атипичный гемолитико-уремический синдром"],
        )
        self.assertIn("| аГУС | — | атипичный гемолитико-уремический синдром |", restored["markdown"])
        self.assertIn("аГУС — атипичный гемолитико-уремический синдром", restored["plain_text"])
        self.assertEqual(
            __import__("json").loads(restored["quality_flags_json"]),
            ["restored_from_wrong_headers", "abbreviation_table"],
        )
        self.assertTrue(__import__("json").loads(restored["cells_json"])[0]["column_header"])

    def test_presentation_uses_restored_abbreviation_table(self) -> None:
        blocks = build_presentation_blocks(
            {
                "chunk_id": "chunk-abbr",
                "content_type": "table",
                "text": "Таблица. Колонка аГУС: АЛТ; Колонка -: -",
                "table_json": '{"table_id":"table-abbr"}',
            },
            {"title": "Сокращения", "section_type": "abbreviations"},
            [],
            {
                "table_id": "table-abbr",
                "columns_json": '["аГУС","-","атипичный гемолитико-уремический синдром"]',
                "rows_json": '[["АЛТ","-","аланинаминотрансфераза"],["АСТ","-","аспартатаминотрансфераза"]]',
                "plain_text": "Таблица. Колонка аГУС: АЛТ; Колонка -: -; Колонка атипичный гемолитико-уремический синдром: аланинаминотрансфераза",
                "quality_flags_json": "[]",
            },
        )

        self.assertEqual(blocks[0]["block_type"], "table")
        self.assertEqual(blocks[0]["title"], "Сокращения")
        self.assertEqual(
            blocks[0]["body"]["columns"],
            ["Сокращение", "—", "Расшифровка"],
        )
        self.assertEqual(blocks[0]["body"]["table_type"], "abbreviations")
        self.assertIn("restored_from_wrong_headers", blocks[0]["body"]["quality_flags"])


if __name__ == "__main__":
    unittest.main()
