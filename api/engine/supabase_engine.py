from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine
from structlog import get_logger
from engine.base_engine import BaseEngine
from settings import config

logger = get_logger()


class SupabaseDBEngine(BaseEngine):
    """Supabase database engine - uses asyncpg driver for PostgreSQL/Supabase"""

    def __init__(self) -> None:
        # Create engine with Supabase connection string
        logger.info("Initializing Supabase database engine")
        super().__init__(self.create_engine())
        logger.info(f"Connected to Supabase database at {self._sanitize_url(config.supabase.database_url)}")

    def create_engine(self) -> AsyncEngine:
        """Create async engine with asyncpg driver"""
        # Convert postgresql:// to postgresql+asyncpg://
        db_url = config.supabase.database_url
        if db_url.startswith("postgresql://"):
            db_url = db_url.replace("postgresql://", "postgresql+asyncpg://", 1)
        
        logger.info("Creating Supabase database engine with asyncpg driver")
        return create_async_engine(
            db_url,
            pool_pre_ping=True,
            pool_size=10,
            max_overflow=20,
            echo=config.environment.name == "dev",  # Log SQL in dev mode
        )

    def _make_url(self) -> str:
        """Create the database connection URL"""
        # Convert postgresql:// to postgresql+asyncpg://
        db_url = config.supabase.database_url
        if db_url.startswith("postgresql://"):
            db_url = db_url.replace("postgresql://", "postgresql+asyncpg://", 1)
        return db_url

    def _sanitize_url(self, url: str) -> str:
        """Sanitize database URL for logging (remove password)"""
        if "@" in url:
            parts = url.split("@")
            if ":" in parts[0]:
                creds = parts[0].split(":")
                return f"{creds[0]}:***@{parts[1]}"
        return url

