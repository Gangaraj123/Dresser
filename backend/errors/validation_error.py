from __future__ import annotations

from .app_error import AppError


class ValidationError(AppError):
    def __init__(self, details: list[dict] | None = None) -> None:
        super().__init__("Validation failed", status_code=400, error_code="VALIDATION_ERROR")
        self.details = details or []
