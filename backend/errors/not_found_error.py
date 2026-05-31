from .app_error import AppError


class NotFoundError(AppError):
    def __init__(self, resource: str = "Resource") -> None:
        super().__init__(f"{resource} not found", status_code=404, error_code="NOT_FOUND")
