# Quick Start

The service exposes the same calculator registry through MCP and REST transports.

## 1. Install

```bash
git clone https://github.com/u9401066/medical-calc-mcp.git
cd medical-calc-mcp
uv sync
```

## 2. Choose a Transport

### Local MCP stdio

```bash
uv run python -m src.main
```

Use this mode for Claude Desktop, VS Code Copilot and other local MCP clients.

### Remote MCP SSE

```bash
uv run python -m src.main --mode sse --host 0.0.0.0 --port 8000
```

### Streamable HTTP MCP

```bash
uv run python -m src.main --mode http --host 0.0.0.0 --port 8000
```

### REST API

```bash
API_PORT=8080 uv run python -m src.infrastructure.api.server
```

On PowerShell:

```powershell
$env:API_PORT = "8080"
uv run python -m src.infrastructure.api.server
```

Swagger UI is available at `http://localhost:8080/docs`.

## 3. Discover Before Calculating

Recommended agent workflow:

```text
discover -> get_tool_schema -> calculate
```

REST example:

```bash
curl "http://localhost:8080/api/v1/search?q=renal"
curl "http://localhost:8080/api/v1/calculators/ckd_epi_2021/schema"
curl -X POST "http://localhost:8080/api/v1/calculate/ckd_epi_2021" \
  -H "Content-Type: application/json" \
  -d '{"params":{"serum_creatinine":1.2,"age":65,"sex":"male"}}'
```

## 4. Verify Readiness

```bash
curl http://localhost:8080/health
curl http://localhost:8080/ready
```

`/health` is liveness. `/ready` evaluates registry, provenance and production perimeter requirements.

## Next Steps

- [Configuration](configuration.md)
- [REST API](../api/rest-api.md)
- [Calculator catalog](../calculators/index.md)
- [Deployment](https://github.com/u9401066/medical-calc-mcp/blob/main/docs/DEPLOYMENT.md)
