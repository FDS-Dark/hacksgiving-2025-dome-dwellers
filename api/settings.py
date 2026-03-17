from pathlib import Path
from pydantic import BaseModel, Field
from pydantic_settings import BaseSettings, SettingsConfigDict
from dotenv import load_dotenv

# Get the current directory and load the .env file with an absolute path
current_dir = Path(__file__).parent.absolute()
dotenv_path = current_dir / ".env"
load_dotenv(dotenv_path=dotenv_path)


class PostgresDatabaseConfig(BaseModel):
    host: str = Field(default="localhost")
    port: int = Field(default=5432)
    name: str = Field(default="domes")
    username: str = Field(default=None)
    password: str = Field(default=None)
    ssl: str = Field(default="disable")


class OpenAIConfig(BaseModel):
    api_key: str = Field(default="")


class Auth0Config(BaseModel):
    client_id: str = Field(default="")
    client_secret: str = Field(default="")
    domain: str = Field(default="")
    secret_id: str = Field(default="")
    management_api_key: str = Field(default="")
    audience: str = Field(default="")
    api_secret_dev: str = Field(default="")
    api_secret_prod: str = Field(default="")


class EnvironmentConfig(BaseModel):
    name: str = Field(default="dev")


class StripeConfig(BaseModel):
    api_key: str = Field(default="")
    publishable_key: str = Field(default="")


class SupabaseConfig(BaseModel):
    url: str = Field(default="http://127.0.0.1:54321")
    anon_key: str = Field(default="")
    service_role_key: str = Field(default="")
    database_url: str = Field(default="postgresql://postgres:postgres@127.0.0.1:54322/postgres")
    publishable_key: str = Field(default="")
    secret_key: str = Field(default="")


class TailscaleConfig(BaseModel):
    ip: str = Field(default="")


class AppConfig(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix="APP__", env_nested_delimiter="__", extra="ignore"
    )

    openai: OpenAIConfig
    database: PostgresDatabaseConfig
    auth0: Auth0Config
    environment: EnvironmentConfig
    stripe: StripeConfig
    supabase: SupabaseConfig = Field(default_factory=SupabaseConfig)
    tailscale: TailscaleConfig = Field(default_factory=TailscaleConfig)


config = AppConfig()
