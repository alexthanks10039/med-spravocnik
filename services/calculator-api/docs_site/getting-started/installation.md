# Installation

## Requirements

| Requirement | Version |
|-------------|---------|
| Python | 3.11, 3.12, or 3.13 |
| Package manager | `uv` recommended |
| OS | Windows, macOS, Linux |
| Docker | Optional |

Python 3.12 is the primary development and documentation environment. CI verifies Python 3.11-3.13.

## Install with uv

```bash
git clone https://github.com/u9401066/medical-calc-mcp.git
cd medical-calc-mcp
uv sync
```

Development dependencies:

```bash
uv sync --frozen --extra dev --group dev
```

## Verify Installation

```bash
uv run python -c "from src import __version__; print(__version__)"
uv run python scripts/check_project_consistency.py
uv run pytest tests/ -q
```

The current project version is `1.6.2`.

## Docker

```bash
docker build -t medical-calc-mcp:1.6.2 .
docker run --rm -p 8000:8000 medical-calc-mcp:1.6.2
```

Run both MCP and REST services:

```bash
docker compose up --build
```

MCP SSE is exposed on port `8000`; REST API is exposed on port `8080`.

## Editor Integration

The repository includes `.vscode/mcp.json`. Open the repository in VS Code with MCP discovery enabled to expose the local stdio server to Copilot.

## Troubleshooting

- If `uv` is unavailable, install it from the official Astral documentation before running project commands.
- Do not use `src.rest_server`; the REST entry point is `src.infrastructure.api.server`.
- If imports fail, run commands from the repository root.
- If generated documentation is stale, run the generation commands listed in the contributor guide.
