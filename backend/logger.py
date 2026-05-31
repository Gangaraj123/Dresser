"""Structured logger — single source of truth.

Development: colourised, human-readable console output via structlog.
Production:  JSON lines to stdout, ready for any log collector.
"""
from __future__ import annotations

import logging
import sys

import structlog

from config import settings

# ---------------------------------------------------------------------------
# stdlib logging → structlog bridge
# ---------------------------------------------------------------------------
logging.basicConfig(
    format="%(message)s",
    stream=sys.stdout,
    level=getattr(logging, settings.log_level.upper(), logging.DEBUG),
)

shared_processors: list = [
    structlog.contextvars.merge_contextvars,
    structlog.stdlib.add_logger_name,
    structlog.stdlib.add_log_level,
    structlog.processors.TimeStamper(fmt="iso"),
    structlog.processors.StackInfoRenderer(),
]

if settings.app_env == "development":
    renderer = structlog.dev.ConsoleRenderer(colors=sys.stdout.isatty())
else:
    renderer = structlog.processors.JSONRenderer()

structlog.configure(
    processors=shared_processors
    + [
        structlog.stdlib.ProcessorFormatter.wrap_for_formatter,
    ],
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

formatter = structlog.stdlib.ProcessorFormatter(
    processors=[
        structlog.stdlib.ProcessorFormatter.remove_processors_meta,
        renderer,
    ],
    foreign_pre_chain=shared_processors,
)

handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(formatter)

root_logger = logging.getLogger()
root_logger.handlers.clear()
root_logger.addHandler(handler)

# Silence noisy third-party libraries regardless of the app log level
for _noisy in ("httpx", "httpcore", "hpack", "h2", "urllib3", "asyncio"):
    logging.getLogger(_noisy).setLevel(logging.WARNING)

# ---------------------------------------------------------------------------
# Module-level logger bound with service name
# ---------------------------------------------------------------------------
logger = structlog.get_logger(service=settings.service_name)
