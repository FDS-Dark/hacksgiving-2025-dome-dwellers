from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine
from sqlalchemy.engine import URL as SQL_ALCHEMY_URL
from structlog import get_logger
from engine.base_engine import BaseEngine
from settings import config

logger = get_logger()


class PostgresDBEngine(BaseEngine):
    def __init__(self, db_url: str | None = None) -> None:
        super().__init__(self.create_engine(db_url))

    def create_engine(self, db_url: str | None = None) -> AsyncEngine:
        if db_url:
            logger.info("Creating Postgres database engine from URL")
            return create_async_engine(db_url, pool_pre_ping=True)

        url = self._make_url()
        logger.info("Creating Postgres database engine", url=url)
        return create_async_engine(url, pool_pre_ping=True)

    def _make_url(self) -> SQL_ALCHEMY_URL:
        cfg = config.database
        logger.info(
            "Authenticating to DB via username/password",
            username=cfg.username,
            password=cfg.password,
        )
        return SQL_ALCHEMY_URL.create(
            drivername="postgresql+asyncpg",
            database=cfg.name,
            username=cfg.username,
            password=cfg.password,
            host=cfg.host,
            port=cfg.port,
            query={"ssl": cfg.ssl},
        )
