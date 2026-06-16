"""FastAPI application exposing search and RAG-ready evidence arrays."""

from __future__ import annotations

from functools import lru_cache
from typing import Any

import uvicorn
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

from medical_kb import __version__
from medical_kb.config import Settings
from medical_kb.models import RagRequest, SearchRequest
from medical_kb.repository import Filters, Repository


app = FastAPI(
    title="Medical Knowledge Base API",
    version=__version__,
    description="Read-only search, structured evidence and RAG context over local medical protocols.",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)


@lru_cache(maxsize=1)
def repository() -> Repository:
    return Repository(Settings.from_env().database_path)


def require_repository() -> Repository:
    value = repository()
    if not value.available:
        raise HTTPException(status_code=503, detail=f"Knowledge base is unavailable: {value.database_path}")
    return value


def request_filters(request: SearchRequest) -> Filters:
    return Filters(
        country=request.country,
        document_type=request.document_type,
        clinical_domain=request.clinical_domain,
        icd10_code=request.icd10_code,
        content_type=request.content_type,
        document_family_id=request.document_family_id,
        version_policy=request.version_policy,
    )


@app.get("/")
async def root() -> dict[str, Any]:
    return {
        "service": "Medical Knowledge Base API",
        "version": __version__,
        "purpose": "search_and_rag_evidence",
        "docs": "/docs",
        "health": "/health",
        "ready": "/ready",
    }


@app.get("/health")
async def health() -> dict[str, Any]:
    return {"status": "healthy", "service": "medical-knowledge-base", "version": __version__}


@app.get("/ready")
async def ready() -> dict[str, Any]:
    status = repository().status()
    if not status["available"]:
        raise HTTPException(status_code=503, detail=status)
    return {"ready": True, **status}


@app.get("/api/pipeline/status")
async def pipeline_status() -> dict[str, Any]:
    return repository().status()


@app.get("/api/documents")
async def documents(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    q: str | None = Query(None, min_length=2, max_length=300),
) -> dict[str, Any]:
    return require_repository().list_documents(limit=limit, offset=offset, query=q)


@app.get("/api/documents/{doc_id}")
async def document(doc_id: str) -> dict[str, Any]:
    result = require_repository().get_document(doc_id)
    if result is None:
        raise HTTPException(status_code=404, detail=f"Document '{doc_id}' not found")
    return result


@app.get("/api/documents/{doc_id}/presentation")
async def document_presentation(doc_id: str) -> dict[str, Any]:
    result = require_repository().get_document_presentation(doc_id)
    if result is None:
        raise HTTPException(status_code=404, detail=f"Document '{doc_id}' not found")
    return result


@app.get("/api/document-families/{family_id}")
async def document_family(family_id: str) -> dict[str, Any]:
    result = require_repository().get_family(family_id)
    if result is None:
        raise HTTPException(status_code=404, detail=f"Document family '{family_id}' not found")
    return result


@app.get("/api/search")
async def search_get(
    q: str = Query(min_length=2, max_length=500),
    limit: int = Query(10, ge=1, le=50),
    country: str | None = None,
    document_type: str | None = None,
    clinical_domain: str | None = None,
    icd10_code: str | None = None,
    content_type: str | None = None,
    document_family_id: str | None = None,
    version_policy: str = Query("all", pattern="^(all|latest_known)$"),
) -> dict[str, Any]:
    request = SearchRequest(
        query=q,
        limit=limit,
        country=country,
        document_type=document_type,
        clinical_domain=clinical_domain,
        icd10_code=icd10_code,
        content_type=content_type,
        document_family_id=document_family_id,
        version_policy=version_policy,
    )
    results = require_repository().search(request.query, limit=request.limit, filters=request_filters(request))
    return {"query": request.query, "count": len(results), "retrieval": "fts5+entities+metadata", "results": results}


@app.post("/api/search")
async def search_post(request: SearchRequest) -> dict[str, Any]:
    results = require_repository().search(request.query, limit=request.limit, filters=request_filters(request))
    return {"query": request.query, "count": len(results), "retrieval": "fts5+entities+metadata", "results": results}


@app.post("/api/rag/query")
async def rag_query(request: RagRequest) -> dict[str, Any]:
    results = require_repository().search(
        request.query,
        limit=max(request.limit, request.max_evidence),
        filters=request_filters(request),
    )
    evidence = results[: request.max_evidence]
    return {
        "query": request.query,
        "mode": "evidence_array",
        "sufficient_evidence": bool(evidence),
        "warning": None if evidence else "No grounded evidence was found in the local corpus.",
        "context": [
            {
                "evidence_id": index,
                "text": item["text"],
                "content_type": item["content_type"],
                "section_path": item["section_path"],
                "citation": item["citation"],
                "version_warning": item["version_warning"],
                "score": item["score"],
            }
            for index, item in enumerate(evidence, start=1)
        ],
        "sources": [item["citation"] for item in evidence],
    }


@app.get("/api/tables/{table_id}")
async def table(table_id: str) -> dict[str, Any]:
    result = require_repository().get_table(table_id)
    if result is None:
        raise HTTPException(status_code=404, detail=f"Table '{table_id}' not found")
    return result


@app.get("/api/entities")
async def entities(
    type: str | None = None,
    q: str | None = Query(None, min_length=2, max_length=300),
    limit: int = Query(50, ge=1, le=200),
) -> dict[str, Any]:
    items = require_repository().list_entities(entity_type=type, query=q, limit=limit)
    return {"count": len(items), "items": items}


@app.get("/api/quality/issues")
async def quality_issues(limit: int = Query(100, ge=1, le=500)) -> dict[str, Any]:
    items = require_repository().quality_issues(limit=limit)
    return {"count": len(items), "items": items}


@app.get("/api/clinical/categories")
async def clinical_categories() -> dict[str, Any]:
    items = require_repository().clinical_categories()
    return {"count": len(items), "items": items}


@app.get("/api/clinical/diseases")
async def clinical_diseases(
    category: str | None = None,
    q: str | None = Query(None, min_length=2, max_length=300),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
) -> dict[str, Any]:
    return require_repository().clinical_diseases(category=category, query=q, limit=limit, offset=offset)


@app.get("/api/clinical/diseases/{doc_id}")
async def clinical_disease(doc_id: str) -> dict[str, Any]:
    item = require_repository().clinical_disease(doc_id)
    if item is None:
        raise HTTPException(status_code=404, detail=f"Clinical protocol '{doc_id}' not found")
    return item


@app.get("/api/clinical/diseases/{doc_id}/recommendations")
async def clinical_recommendations(doc_id: str, limit: int = Query(12, ge=1, le=50)) -> dict[str, Any]:
    items = require_repository().clinical_recommendations(doc_id, limit=limit)
    return {"count": len(items), "items": items}


def main() -> None:
    settings = Settings.from_env()
    uvicorn.run("medical_kb.api:app", host=settings.host, port=settings.port)


if __name__ == "__main__":
    main()
