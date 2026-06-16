"""Convert OCR-derived corpus records into conservative UI presentation blocks."""

from __future__ import annotations

import html
import re
from typing import Any, Iterable


_BULLET_RE = re.compile(r"^\s*(?:[\u2022\u25cf\u25e6\u2043\uf0b7\uf0a7]|[-*])\s+")
_PRIVATE_USE_RE = re.compile(r"[\ue000-\uf8ff]")
_CELL_OBJECT_RE = re.compile(r"^\s*\{.*(?:row_span|col_span|start_row_offset_idx).+\}\s*$", re.DOTALL)
_REFERENCE_RE = re.compile(r"\[(\d+(?:\s*(?:,|-)\s*\d+)*)\]")
_LAB_VALUE_RE = re.compile(
    r"(?i)(?:\b(?:ЛДГ|АСТ|АЛТ|гемоглобин|тромбоцит\w*|билирубин|креатинин|гаптоглобин)\b.{0,35})"
    r"(?:>=|<=|>|<|≥|≤|=)\s*\d"
)


def clean_text(value: Any) -> str:
    """Normalize display-only OCR artifacts without changing the stored source."""

    text = str(value or "").replace("\r\n", "\n").replace("\r", "\n")
    for _ in range(3):
        decoded = html.unescape(text)
        if decoded == text:
            break
        text = decoded
    text = text.replace("\u00a0", " ").replace("\u00ad", "")
    text = re.sub(r"(?m)^\s*[\ue000-\uf8ff]\s*", "• ", text)
    text = _PRIVATE_USE_RE.sub("", text)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\s+([,.;:!?])", r"\1", text)
    text = re.sub(r"(?i)\bHELLP\s*-\s*", "HELLP-", text)
    text = re.sub(r"(?i)\bМКБ\s*-\s*10\b", "МКБ-10", text)
    text = re.sub(r"(?<=\w)\s*([<>]=?|[≥≤])\s*(?=\d)", r" \1 ", text)
    text = re.sub(r"(?<=\d)\s+(?=(?:мг|мкг|г|мл|л|МЕ|мм|мкмоль|ммоль|клеток)\b)", " ", text, flags=re.IGNORECASE)
    text = re.sub(r"\n[ \t]+", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def clean_cell(value: Any) -> str:
    text = clean_text(value)
    if _CELL_OBJECT_RE.match(text):
        return ""
    return text


def display_section_title(value: Any) -> str:
    text = clean_text(value or "Документ").split(" > ")[-1]
    text = _without_reference_markers(text)
    if len(text) <= 160:
        return text or "Документ"
    prefix = text.split(":", 1)[0].strip()
    if 2 <= len(prefix) <= 160:
        return prefix
    sentence = re.split(r"(?<=[.!?])\s+", text, maxsplit=1)[0]
    if len(sentence) <= 160:
        return sentence
    return f"{text[:157].rstrip()}…"


def references_in(text: str) -> list[str]:
    return list(dict.fromkeys(match.group(1).replace(" ", "") for match in _REFERENCE_RE.finditer(text)))


def text_blocks(text: Any, *, content_type: str = "text", section_title: str = "") -> list[dict[str, Any]]:
    normalized = clean_text(text)
    if not normalized:
        return []

    lines = [line.strip() for line in normalized.splitlines()]
    blocks: list[dict[str, Any]] = []
    paragraph_lines: list[str] = []
    bullet_items: list[str] = []

    def flush_paragraph() -> None:
        if not paragraph_lines:
            return
        value = " ".join(paragraph_lines).strip()
        paragraph_lines.clear()
        if not value:
            return
        for part in _paragraph_parts(value):
            blocks.append(_text_block(part, content_type=content_type, section_title=section_title))

    def flush_bullets() -> None:
        if not bullet_items:
            return
        raw_items = list(bullet_items)
        bullet_items.clear()
        references = references_in(" ".join(raw_items))
        items = [_without_reference_markers(item) for item in raw_items]
        blocks.append({"type": "bullet_list", "items": items, "references": references})

    for line in lines:
        if not line:
            flush_paragraph()
            flush_bullets()
            continue
        if _BULLET_RE.match(line):
            flush_paragraph()
            bullet_items.append(_BULLET_RE.sub("", line, count=1).strip())
            continue
        flush_bullets()
        paragraph_lines.append(line)
    flush_paragraph()
    flush_bullets()
    return blocks


def _text_block(text: str, *, content_type: str, section_title: str) -> dict[str, Any]:
    references = references_in(text)
    text = _without_reference_markers(text)
    normalized_context = f"{section_title} {text}".casefold()
    if "nb!" in normalized_context or "внимание" in normalized_context or "противопоказан" in normalized_context:
        block_type = "warning"
    elif "определение" in section_title.casefold():
        block_type = "definition"
    elif content_type == "drug_dosage" or any(term in normalized_context for term in ("дозиров", "мг/кг", "мг в/м", "мг в/в")):
        block_type = "drug_card"
    elif content_type == "lab_threshold" or _LAB_VALUE_RE.search(text):
        block_type = "lab_value"
    elif "критери" in normalized_context or "классификац" in normalized_context:
        block_type = "criteria"
    elif any(term in section_title.casefold() for term in ("литератур", "источник", "библиограф")):
        block_type = "references"
    else:
        block_type = "paragraph"
    return {"type": block_type, "text": text, "references": references}


def _without_reference_markers(text: str) -> str:
    value = _REFERENCE_RE.sub("", text)
    value = re.sub(r"\s+([,.;:!?])", r"\1", value)
    return re.sub(r" {2,}", " ", value).strip()


def _paragraph_parts(text: str, *, target_length: int = 650) -> list[str]:
    if len(text) <= target_length:
        return [text]
    sentences = re.split(r"(?<=[.!?])\s+(?=[А-ЯA-Z0-9])", text)
    if len(sentences) == 1:
        return [text]
    parts: list[str] = []
    current: list[str] = []
    current_length = 0
    for sentence in sentences:
        if current and current_length + len(sentence) + 1 > target_length:
            parts.append(" ".join(current))
            current = []
            current_length = 0
        current.append(sentence)
        current_length += len(sentence) + 1
    if current:
        parts.append(" ".join(current))
    return parts


def table_block(
    *,
    table_id: str,
    title: Any,
    table_type: Any,
    columns: Any,
    rows: Any,
    plain_text: Any,
    quality_flags: Any,
) -> dict[str, Any]:
    raw_columns = list(columns) if isinstance(columns, list) else []
    raw_rows = list(rows) if isinstance(rows, list) else []
    headers = [clean_cell(value) for value in raw_columns]
    normalized_rows = [
        [clean_cell(value) for value in row]
        for row in raw_rows
        if isinstance(row, list)
    ]
    width = len(headers)
    shape_valid = width > 0 and all(len(row) == width for row in normalized_rows)
    all_rows = ([headers] if headers else []) + normalized_rows

    if _looks_like_abbreviation_table(all_rows):
        width = 3
        headers = ["Сокращение", "—", "Расшифровка"]
        normalized_rows = [row[:3] for row in all_rows]
        shape_valid = True

    total_cells = sum(len(row) for row in normalized_rows)
    empty_cells = sum(not cell for row in normalized_rows for cell in row)
    empty_ratio = empty_cells / total_cells if total_cells else 1.0
    duplicate_ratio = _duplicate_row_ratio(normalized_rows)
    flags = [clean_text(flag) for flag in quality_flags] if isinstance(quality_flags, list) else []
    broken = not shape_valid or not normalized_rows or empty_ratio > 0.45 or duplicate_ratio > 0.75

    return {
        "type": "table",
        "table_id": table_id,
        "title": clean_text(title) or "Таблица",
        "table_type": clean_text(table_type) or "unknown",
        "render_mode": "fallback" if broken else "structured",
        "columns": headers if not broken else [],
        "rows": normalized_rows if not broken else [],
        "fallback_text": clean_text(plain_text) if broken else "",
        "message": "Таблица не распознана полностью. Показан текстовый вариант." if broken else "",
        "quality_flags": [flag for flag in flags if flag],
    }


def _looks_like_abbreviation_table(rows: Iterable[list[str]]) -> bool:
    values = [row for row in rows if len(row) == 3]
    if len(values) < 2:
        return False
    separators = sum(row[1].strip() in {"-", "—", ""} for row in values)
    short_left = sum(0 < len(row[0]) <= 20 for row in values)
    explanatory_right = sum(len(row[2]) > len(row[0]) for row in values)
    return separators / len(values) >= 0.7 and short_left / len(values) >= 0.7 and explanatory_right / len(values) >= 0.7


def _duplicate_row_ratio(rows: list[list[str]]) -> float:
    if not rows:
        return 1.0
    duplicated = sum(len(set(cell for cell in row if cell)) <= 1 and len(row) > 1 for row in rows)
    return duplicated / len(rows)
