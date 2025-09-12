# 🔄 Echo Tool Service

A minimal **FastAPI** microservice that simply echoes back its input — perfect for testing, debugging, or serving as a placeholder in larger systems.

**Version:** 0.1.13

## 🚀 Quick Start

Spin up the service with Docker Compose:

```bash
docker compose up --build
```

The API will be available at **[http://localhost:8000](http://localhost:8000)**.

---

Example:

```bash
curl -X POST http://localhost:8000/echo \
  -H "Content-Type: application/json" \
  -d '{"input": "Hello, world!"}'
```

Expected response:

```json
{"output": "Echo: Hello, world!"}
```

---

## 🧪 Test It Locally

The service exposes a `/health` endpoint for readiness checks:

```bash
curl -X GET http://localhost:8000/health
```

Expected response:

```json
{"status": "ok"}
```

---

## ⚙️ Configuration & Observability

The service can be configured using environment variables.

### Key Variables

| Variable                      | Description                                                                | Default                 |
| ----------------------------- | -------------------------------------------------------------------------- | ----------------------- |
| `LOG_LEVEL`                   | Sets the application's log level.                                          | `INFO`                  |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | The gRPC endpoint of a OpenTelemetry collector (e.g., Jaeger, Datadog). | `"" |

### Example Production Configuration

```yaml
services:
  echo-tool:
    build: .
    ports:
      - "8000:8000"
    environment:
      - LOG_LEVEL=debug
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://my-otel-collector:4317
```
