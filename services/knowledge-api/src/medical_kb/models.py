"""API request models."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


VersionPolicy = Literal["all", "latest_known"]


class SearchRequest(BaseModel):
    query: str = Field(min_length=2, max_length=500)
    limit: int = Field(default=10, ge=1, le=50)
    country: str | None = None
    document_type: str | None = None
    clinical_domain: str | None = None
    icd10_code: str | None = None
    content_type: str | None = None
    document_family_id: str | None = None
    version_policy: VersionPolicy = "all"


class RagRequest(SearchRequest):
    max_evidence: int = Field(default=6, ge=1, le=15)
