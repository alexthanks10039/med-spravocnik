#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if command -v powershell.exe >/dev/null 2>&1 && command -v wslpath >/dev/null 2>&1; then
  WINDOWS_SCRIPT="$(wslpath -w "$SCRIPT_DIR/start_project.ps1")"
  exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WINDOWS_SCRIPT" "$@"
fi

cat >&2 <<EOF
The full launcher currently targets Windows/WSL.
For a portable browser preview run:
  cd "$REPO_ROOT"
  python -m pip install -r preview-codeplace/requirements.txt
  python -m uvicorn app:app --app-dir preview-codeplace --host 0.0.0.0 --port 8787
EOF
exit 2
