# Project status

Updated: 2026-09-23

## Current baseline

Main: `33b3c329dde3bd3cd83689943a0c53889a220e22`

### Backend

- PostgreSQL + Prisma 6.19.3
- JWT auth with USER/ADMIN roles
- Diseases, drugs, articles, calculators and RAG endpoints
- Enterprise Data Store:
  - collections
  - lossless JSON/MCP payload storage
  - search + pagination
  - import/export
  - checksums and idempotent external IDs
  - immutable record version snapshots
  - rollback
  - bulk status changes
  - audit log
- Backend CI has PostgreSQL migration + seed + TypeScript check + smoke tests.
- The latest CI run before the current fix failed only at TypeScript type-check because the versioned import transaction and Prisma JSON null typing were incorrect. That failure is being fixed in this commit.

## Backlog

### P0. Backend correctness and data safety

1. [x] Enterprise data schema and migrations
2. [x] Lossless MCP/JSON normalization
3. [x] Version history and rollback
4. [x] Import/export API
5. [x] Audit log
6. [x] Fix Prisma JSON typing and transaction API
7. [ ] Re-run CI and make main green
8. [ ] Add automated tests for import, versioning, rollback, bulk status and MCP envelopes
9. [ ] Make concurrent imports safe and idempotent under retries

### P1. Large-data ingestion

10. [ ] Convert synchronous import into durable background jobs
11. [ ] Progress endpoint with processed/imported/rejected counters
12. [ ] Cancel and retry jobs
13. [ ] Persist import source outside request memory for large files
14. [ ] Stream NDJSON/JSONL instead of loading the full payload into memory
15. [ ] Import error log with row-level diagnostics
16. [ ] Import idempotency key and retry-safe semantics

### P1. Query and storage performance

17. [ ] PostgreSQL full-text/trigram search over normalized fields
18. [ ] JSONB path/filter API for arbitrary MCP fields
19. [ ] Cursor pagination for large collections
20. [ ] Bulk upsert optimized for 100k+ records
21. [ ] Export streaming and server-side filtering
22. [ ] Retention policy for old record versions

### P1. Medical data model

23. [ ] Source/provenance model: source, URL/file, publisher, publication date, reviewed date
24. [ ] Medical content revision workflow
25. [ ] Clinical document metadata and evidence level
26. [ ] Separate canonical medical entities from raw imported records
27. [ ] Validation profiles for known medical schemas

### P2. Security and operations

28. [ ] Rate limits on admin data endpoints
29. [ ] Request size limits per endpoint
30. [ ] Structured audit events for imports, exports and rollbacks
31. [ ] Health/readiness details and DB latency
32. [ ] Metrics and structured logging
33. [ ] Backup/restore verification
34. [ ] Production migration/rollback runbook

### P2. Client integration

35. [ ] Connect Flutter client to REST API
36. [ ] Replace offline repository progressively
37. [ ] Auth/session persistence
38. [ ] Server-side search and pagination in Flutter
39. [ ] MCP/JSON record inspector in Flutter

## Execution order

Backend work is executed strictly in this order:

P0 correctness -> CI -> automated tests -> concurrency/idempotency -> background ingestion -> performance -> medical provenance -> security/operations -> Flutter integration.

A backlog item is considered done only after code, migration/tests where applicable, documentation, and CI verification are complete.
