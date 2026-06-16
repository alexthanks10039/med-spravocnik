#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec python -m uvicorn app:app --app-dir "$REPO_ROOT/preview-codeplace" --host 0.0.0.0 --port "${PORT:-8787}"
