"""Fast, isolated repository preview with public demo data only."""

from __future__ import annotations

from math import pow
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel


ROOT = Path(__file__).resolve().parent

app = FastAPI(title="MedSpravochnik Codeplace Preview", version="1.0.0-preview")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:8787", "http://127.0.0.1:8787"],
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type"],
)


DOCUMENTS: list[dict[str, Any]] = [
    {
        "id": "demo-hellp",
        "title": "HELLP-синдром",
        "category": "Акушерство и гинекология",
        "icd10_codes": ["O14.2"],
        "approval_date": "2024-01-01",
        "version": "demo-2024",
        "protocol_number": "DEMO-001",
        "sections": [
            {
                "id": "hellp-definition",
                "title": "Диагностические критерии",
                "path": "HELLP-синдром > Диагностические критерии",
                "blocks": [
                    {
                        "type": "warning",
                        "text": "Демонстрационный фрагмент. Не использовать для клинических решений.",
                        "items": [],
                        "references": [],
                    },
                    {
                        "type": "criteria",
                        "text": "HELLP включает гемолиз, повышение печеночных ферментов и тромбоцитопению.",
                        "items": [
                            "ЛДГ повышена",
                            "АСТ/АЛТ повышены",
                            "Количество тромбоцитов снижено",
                        ],
                        "references": ["Demo source: synthetic preview record"],
                    },
                ],
            }
        ],
    },
    {
        "id": "demo-hypertension",
        "title": "Артериальная гипертензия",
        "category": "Кардиология",
        "icd10_codes": ["I10"],
        "approval_date": "2024-02-01",
        "version": "demo-2024",
        "protocol_number": "DEMO-002",
        "sections": [
            {
                "id": "hypertension-assessment",
                "title": "Первичная оценка",
                "path": "Артериальная гипертензия > Первичная оценка",
                "blocks": [
                    {
                        "type": "paragraph",
                        "text": "Подтверждение требует повторных корректных измерений и оценки факторов риска.",
                        "items": [],
                        "references": ["Demo source: synthetic preview record"],
                    }
                ],
            }
        ],
    },
    {
        "id": "demo-pneumonia",
        "title": "Внебольничная пневмония",
        "category": "Пульмонология",
        "icd10_codes": ["J18"],
        "approval_date": "2024-03-01",
        "version": "demo-2024",
        "protocol_number": "DEMO-003",
        "sections": [
            {
                "id": "pneumonia-routing",
                "title": "Маршрутизация",
                "path": "Внебольничная пневмония > Маршрутизация",
                "blocks": [
                    {
                        "type": "paragraph",
                        "text": "Место лечения определяется тяжестью состояния и сопутствующими заболеваниями.",
                        "items": [],
                        "references": ["Demo source: synthetic preview record"],
                    }
                ],
            }
        ],
    },
]


CALCULATORS = {
    "bmi": {
        "tool_id": "bmi",
        "name": "Индекс массы тела",
        "purpose": "Демонстрационный расчет BMI",
        "specialties": ["general"],
        "output_type": "number",
        "inputs": [
            {"id": "weight_kg", "label": "Масса", "description": "Масса тела", "type": "number", "required": True, "unit": "кг", "minimum": 1, "maximum": 500, "options": []},
            {"id": "height_cm", "label": "Рост", "description": "Рост", "type": "number", "required": True, "unit": "см", "minimum": 30, "maximum": 260, "options": []},
        ],
    },
    "egfr": {
        "tool_id": "egfr",
        "name": "eGFR CKD-EPI 2021",
        "purpose": "Демонстрационный расчет eGFR для взрослых",
        "specialties": ["nephrology"],
        "output_type": "number",
        "inputs": [
            {"id": "age", "label": "Возраст", "description": "Полных лет", "type": "integer", "required": True, "unit": "лет", "minimum": 18, "maximum": 120, "options": []},
            {"id": "creatinine", "label": "Креатинин", "description": "Сывороточный креатинин", "type": "number", "required": True, "unit": "мг/дл", "minimum": 0.1, "maximum": 20, "options": []},
            {"id": "sex", "label": "Пол", "description": "Биологический пол", "type": "string", "required": True, "unit": "", "options": ["female", "male"]},
        ],
    },
}


class CalculationRequest(BaseModel):
    params: dict[str, Any]


@app.get("/health")
@app.get("/knowledge/health")
@app.get("/calculator/health")
async def health() -> dict[str, Any]:
    return {"status": "healthy", "mode": "public-demo", "documents": len(DOCUMENTS), "calculators": len(CALCULATORS)}


@app.get("/ready")
@app.get("/knowledge/ready")
async def ready() -> dict[str, Any]:
    return {"ready": True, "mode": "public-demo", "production_corpus_loaded": False}


@app.get("/knowledge/api/clinical/categories")
async def categories() -> dict[str, Any]:
    grouped: dict[str, int] = {}
    for document in DOCUMENTS:
        grouped[document["category"]] = grouped.get(document["category"], 0) + 1
    return {"items": [{"id": title, "title": title, "disease_count": count} for title, count in sorted(grouped.items())]}


@app.get("/knowledge/api/clinical/diseases")
async def diseases(
    q: str = "",
    category: str = "",
    limit: int = Query(200, ge=1, le=200),
) -> dict[str, Any]:
    query = q.casefold().strip()
    items = [document for document in DOCUMENTS if (not category or document["category"] == category)]
    if query:
        items = [document for document in items if query in f"{document['title']} {' '.join(document['icd10_codes'])}".casefold()]
    return {"items": [{key: item[key] for key in ("id", "title", "category", "icd10_codes", "approval_date", "version", "protocol_number")} for item in items[:limit]]}


@app.get("/knowledge/api/search")
async def search(q: str = Query(min_length=2), limit: int = Query(20, ge=1, le=50)) -> dict[str, Any]:
    terms = [term for term in q.casefold().split() if term]
    results: list[dict[str, Any]] = []
    for document in DOCUMENTS:
        for section in document["sections"]:
            for block in section["blocks"]:
                text = " ".join([document["title"], section["title"], block.get("text", ""), *block.get("items", [])])
                normalized = text.casefold()
                score = sum(normalized.count(term) for term in terms)
                if score:
                    results.append({
                        "doc_id": document["id"],
                        "title": document["title"],
                        "section_path": section["path"],
                        "display_text": block.get("text", ""),
                        "content_type": block["type"],
                        "version": document["version"],
                        "approval_date": document["approval_date"],
                        "score": float(score),
                        "version_warning": "Preview uses synthetic demo records.",
                        "citation": {"doc_id": document["id"], "section": section["title"], "source": "synthetic-preview"},
                    })
    results.sort(key=lambda item: (-item["score"], item["title"]))
    return {"query": q, "results": results[:limit], "mode": "public-demo"}


@app.get("/knowledge/api/documents/{doc_id}/presentation")
async def presentation(doc_id: str) -> dict[str, Any]:
    document = next((item for item in DOCUMENTS if item["id"] == doc_id), None)
    if document is None:
        raise HTTPException(status_code=404, detail="Demo document not found")
    return {
        "document": {
            "doc_id": document["id"],
            "title": document["title"],
            "version_label": document["version"],
            "approval_date": document["approval_date"],
            "protocol_number": document["protocol_number"],
            "icd10_codes": document["icd10_codes"],
        },
        "sections": document["sections"],
        "empty": False,
        "mode": "public-demo",
    }


@app.get("/calculator/api/v1/calculators")
async def calculator_list(limit: int = Query(200, ge=1, le=200)) -> dict[str, Any]:
    return {"tools": [{key: value[key] for key in ("tool_id", "name", "purpose", "specialties", "output_type")} for value in list(CALCULATORS.values())[:limit]]}


@app.get("/calculator/api/v1/search")
async def calculator_search(q: str = "", limit: int = Query(50, ge=1, le=200)) -> dict[str, Any]:
    query = q.casefold().strip()
    values = [value for value in CALCULATORS.values() if not query or query in f"{value['name']} {value['purpose']}".casefold()]
    return {"tools": [{key: value[key] for key in ("tool_id", "name", "purpose", "specialties", "output_type")} for value in values[:limit]]}


@app.get("/calculator/api/v1/calculators/{tool_id}/schema")
async def calculator_schema(tool_id: str) -> dict[str, Any]:
    calculator = CALCULATORS.get(tool_id)
    if calculator is None:
        raise HTTPException(status_code=404, detail="Demo calculator not found")
    return {"tool_id": tool_id, "inputs": calculator["inputs"]}


@app.post("/calculator/api/v1/calculate/{tool_id}")
async def calculate(tool_id: str, request: CalculationRequest) -> dict[str, Any]:
    try:
        if tool_id == "bmi":
            weight = float(request.params["weight_kg"])
            height = float(request.params["height_cm"]) / 100
            value = round(weight / (height * height), 1)
            summary = "Демонстрационный BMI рассчитан. Интерпретация требует клинического контекста."
            unit = "кг/м²"
        elif tool_id == "egfr":
            age = int(request.params["age"])
            creatinine = float(request.params["creatinine"])
            sex = str(request.params["sex"])
            k = 0.7 if sex == "female" else 0.9
            alpha = -0.241 if sex == "female" else -0.302
            ratio = creatinine / k
            value = round(142 * pow(min(ratio, 1), alpha) * pow(max(ratio, 1), -1.2) * pow(0.9938, age) * (1.012 if sex == "female" else 1))
            summary = "Демонстрационный eGFR рассчитан по CKD-EPI 2021 для взрослого."
            unit = "мл/мин/1,73 м²"
        else:
            raise HTTPException(status_code=404, detail="Demo calculator not found")
    except (KeyError, TypeError, ValueError, ZeroDivisionError) as error:
        raise HTTPException(status_code=422, detail=f"Invalid demo input: {error}") from error
    return {
        "success": True,
        "result": {
            "score_name": CALCULATORS[tool_id]["name"],
            "value": value,
            "unit": unit,
            "component_scores": {},
            "interpretation": {
                "summary": summary,
                "severity": "demo",
                "recommendation": "Не использовать Preview для медицинских решений.",
            },
        },
        "mode": "public-demo",
    }


@app.get("/", include_in_schema=False)
async def index() -> FileResponse:
    return FileResponse(ROOT / "index.html")
