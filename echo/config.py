
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Manages application configuration using Pydantic.
    It automatically reads environment variables to override defaults.
    """
    model_config = SettingsConfigDict(
        env_file='.env',
        env_file_encoding='utf-8',
        extra='ignore',
    )

    # Application info
    APP_NAME: str = "Echo Tool Server"
    LOG_LEVEL: str = "WARN"
    APP_VERSION: str = "0.1.12"

    # Contact info
    CONTACT_NAME: str = "API Support"
    CONTACT_URL: str = "https://www.example.com/support"
    CONTACT_EMAIL: str = "support@example.com"

    # Servers list
    SERVERS: list[dict[str, str]] = [
        {"url": "http://localhost:8000", "description": "Development Server"},
    ]

    # Optional OpenTelemetry collector endpoint (leave empty to disable tracing)
    OTEL_EXPORTER_OTLP_ENDPOINT: str = ""


settings = Settings()
