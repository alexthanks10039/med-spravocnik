# Configuration

Configuration is supplied through environment variables. Local defaults favor developer convenience; public deployments must explicitly enable perimeter controls.

## Runtime

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_ENV` | `development` | Environment used by readiness checks |
| `LOG_LEVEL` | `INFO` | Python log level |
| `MCP_MODE` | `stdio` | MCP transport: `stdio`, `sse`, or `http` |
| `MCP_HOST` | `0.0.0.0` | MCP bind address |
| `MCP_PORT` | `8000` | MCP network port |
| `API_HOST` | `0.0.0.0` | REST API bind address |
| `API_PORT` | `8080` | REST API port |
| `DEBUG` | `false` | Enable Uvicorn reload for REST development |

## Authentication and Rate Limiting

| Variable | Default | Description |
|----------|---------|-------------|
| `SECURITY_AUTH_ENABLED` | `false` | Require an API key |
| `SECURITY_API_KEYS` | empty | Comma-separated keys, minimum 8 characters each |
| `SECURITY_AUTH_HEADER` | `X-API-Key` | API-key header name |
| `SECURITY_AUTH_PARAM` | `api_key` | Optional query parameter name |
| `SECURITY_RATE_LIMIT_ENABLED` | `false` | Enable application rate limiting |
| `SECURITY_RATE_LIMIT_RPM` | `60` | Requests per minute |
| `SECURITY_RATE_LIMIT_BURST` | `10` | Burst allowance |
| `SECURITY_RATE_LIMIT_BY_IP` | `true` | Partition limits by client IP |
| `SECURITY_LOG_REQUESTS` | `false` | Log requests through security middleware |
| `SECURITY_LOG_AUTH_FAILURES` | `true` | Log rejected authentication attempts |

Keys can be supplied with `X-API-Key`, the configured query parameter, or a Bearer token.

## CORS and TLS

| Variable | Default | Description |
|----------|---------|-------------|
| `CORS_ORIGINS` | `*` | Comma-separated allowed origins |
| `SSL_ENABLED` | `false` | Enable direct TLS for MCP network transports |
| `SSL_KEYFILE` | empty | Private key path |
| `SSL_CERTFILE` | empty | Certificate path |
| `SSL_CA_CERTS` | empty | Optional CA bundle |
| `SSL_CERT_REQUIRED` | `false` | Require a client certificate |
| `TRUST_REVERSE_PROXY_SSL` | `false` | Declare TLS termination at a trusted proxy |

## Tool Usage Logging

| Variable | Default | Description |
|----------|---------|-------------|
| `TOOL_USAGE_LOGGING_ENABLED` | `true` | Enable calculator usage events |
| `TOOL_USAGE_LOG_LEVEL` | `INFO` | Usage-event log level |
| `TOOL_USAGE_LOG_FILE` | empty | Optional log output file |

Do not log patient identifiers or protected health information.

## Development Example

```bash
APP_ENV=development LOG_LEVEL=DEBUG uv run python -m src.main
```

## Production-like REST Example

```bash
APP_ENV=production \
SECURITY_AUTH_ENABLED=true \
SECURITY_API_KEYS="replace-with-a-long-random-key" \
SECURITY_RATE_LIMIT_ENABLED=true \
CORS_ORIGINS="https://app.example.com" \
TRUST_REVERSE_PROXY_SSL=true \
API_PORT=8080 \
uv run python -m src.infrastructure.api.server
```

Validate the same profile before deployment:

```bash
uv run python scripts/check_production_readiness.py --service all --environment production
```

Production readiness requires authentication, rate limiting, restricted CORS and either direct TLS or trusted reverse-proxy TLS.
