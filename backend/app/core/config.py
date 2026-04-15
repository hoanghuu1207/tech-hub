from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    # App config
    APP_NAME: str = "TechShop API"
    DEBUG: bool = True
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # DB config
    POSTGRES_HOST: str
    POSTGRES_PORT: int
    POSTGRES_DB: str
    POSTGRES_USER: str
    POSTGRES_PASSWORD: str
    DATABASE_URL: str

    # Qdrant config
    QDRANT_HOST: str
    QDRANT_PORT: int

    # AI Config
    OPENAI_API_KEY: str

    # Payment config
    PAYOS_CLIENT_ID: str
    PAYOS_API_KEY: str
    PAYOS_CHECKSUM_KEY: str

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore" # Ignore extra env variables not declared here
    )

settings = Settings()
