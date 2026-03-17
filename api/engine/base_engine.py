from abc import ABC, abstractmethod
from sqlalchemy.engine import Engine
from sqlalchemy.ext.asyncio import AsyncEngine
from sqlalchemy.engine.url import URL as SQL_ALCHEMY_URL


class BaseEngine(ABC):
    """Abstract base class for database engines"""

    def __init__(self, engine: Engine | AsyncEngine) -> None:
        self.engine: Engine | AsyncEngine = engine

    @abstractmethod
    def create_engine(self) -> Engine | AsyncEngine:
        """Create the database engine"""
        pass

    @abstractmethod
    def _make_url(self) -> SQL_ALCHEMY_URL | str:
        """Create the database connection URL"""
        pass
