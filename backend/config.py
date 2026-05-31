from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    supabase_url: str
    supabase_service_key: str
    supabase_jwt_secret: str = ""  # unused, kept for .env backwards compat
    database_url: str = ""
    gemini_api_key: str = ""
    gemini_model: str = "gemini-2.5-flash"
    firebase_credentials_path: str = "./firebase-credentials.json"
    app_env: str = "development"
    log_level: str = "info"
    service_name: str = "dresser-api"
    # Stored as a comma-separated string to avoid pydantic-settings JSON parsing
    allowed_origins: str = "*"
    port: int = 8000

    @property
    def origins_list(self) -> list[str]:
        return [o.strip() for o in self.allowed_origins.split(",")]

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
