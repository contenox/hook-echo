import logging
from os import environ
from typing import Any

import structlog
from fastapi import FastAPI
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from prometheus_fastapi_instrumentator import Instrumentator
from pydantic import BaseModel

from config import settings

environ['TZ'] = 'UTC'


def setup_logging() -> None:
    """Configures structured logging using structlog."""
    structlog.configure(
        processors=[
            structlog.stdlib.add_log_level,
            structlog.processors.TimeStamper(fmt="iso", utc=True),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.JSONRenderer(),
        ],
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )
    logging.basicConfig(format="%(message)s", level=settings.LOG_LEVEL.upper())


def setup_tracing(app: FastAPI) -> None:
    """Configures OpenTelemetry tracing if OTEL_EXPORTER_OTLP_ENDPOINT is set."""
    if not settings.OTEL_EXPORTER_OTLP_ENDPOINT:
        logger.info("Tracing disabled because OTEL_EXPORTER_OTLP_ENDPOINT is empty")
        return

    resource = Resource(
        attributes={
            "service.name": settings.APP_NAME,
            "service.version": settings.APP_VERSION,
        },
    )

    provider = TracerProvider(resource=resource)
    trace.set_tracer_provider(provider)

    exporter = OTLPSpanExporter(endpoint=settings.OTEL_EXPORTER_OTLP_ENDPOINT)
    processor = BatchSpanProcessor(exporter)
    provider.add_span_processor(processor)

    FastAPIInstrumentor.instrument_app(app)
    logger.info(f"Tracing enabled, exporting to {settings.OTEL_EXPORTER_OTLP_ENDPOINT}")


def setup_metrics(app: FastAPI) -> None:
    """Configures Prometheus metrics, exposing a /metrics endpoint."""
    Instrumentator().instrument(app).expose(app, tags=["Monitoring"])


setup_logging()
logger = structlog.get_logger()

tags_metadata = [
    {
        "name": "Echo",
        "description": "The core echo functionality of the service.",
    },
    {
        "name": "Monitoring",
        "description": "Endpoints for monitoring service health and metrics.",
    },
]

app = FastAPI(
    title=settings.APP_NAME,
    description="A simple echo tool for LLM agents.",
    version=settings.APP_VERSION,
    openapi_tags=tags_metadata,
    contact={
        "name": settings.CONTACT_NAME,
        "url": settings.CONTACT_URL,
        "email": settings.CONTACT_EMAIL,
    },
    servers=settings.SERVERS,
)

setup_tracing(app)
setup_metrics(app)


class ToolInput(BaseModel):
    input: str


@app.post("/echo", operation_id="echo", tags=["Echo"])
async def echo(payload: ToolInput) -> dict[str, Any]:
    """Echoes back whatever input is given. Useful for testing or placeholder."""
    logger.info("echo.request", input=payload.input)
    result = f"Echo: {payload.input}"
    logger.info("echo.response", output=result)
    return {"output": result}


@app.get(
    "/health",
    operation_id="health_check_get",
    summary="Health Check",
    tags=["Monitoring"],
)
@app.head(
    "/health",
    operation_id="health_check_head",
    summary="Health Check (HEAD)",
    tags=["Monitoring"],
)
async def health_check() -> dict[str, str]:
    """
    Simple health check endpoint to confirm the server is running.
    For HEAD requests, FastAPI automatically returns an empty response.
    """
    logger.info("health.check")
    return {"status": "ok"}


@app.get(
    "/ready", operation_id="ready_check", summary="Readiness Check", tags=["Monitoring"],
)
async def ready_check() -> dict[str, str]:
    """
    Readiness check endpoint to confirm the service is ready to accept traffic.
    For this simple service, readiness is the same as health.
    """
    logger.info("ready.check")
    return {"status": "ok"}
