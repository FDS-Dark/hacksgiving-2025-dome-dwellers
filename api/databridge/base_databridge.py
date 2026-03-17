import asyncio
from concurrent.futures import ThreadPoolExecutor
from typing import Any, Sequence
from sqlalchemy import text
from sqlalchemy.engine import Engine, Row
from sqlalchemy.ext.asyncio import AsyncEngine
from engine.base_engine import BaseEngine
from structlog import get_logger

logger = get_logger()


class ThreadpoolAsyncDatabridge:
    def __init__(self, engine: BaseEngine) -> None:
        self.engine: BaseEngine = engine
        self._executor = ThreadPoolExecutor(max_workers=4)

    async def query_procedure_safe_async(
        self, query: str, params: dict[str, Any] | None = None
    ) -> tuple[Sequence[Row], list[str]]:
        """Execute a SQL query asynchronously and return data with column names"""
        # Check if we have an async engine
        if isinstance(self.engine.engine, AsyncEngine):
            return await self._execute_query_async(query, params or {})
        else:
            loop = asyncio.get_event_loop()
            return await loop.run_in_executor(
                self._executor, self._execute_query_sync, query, params or {}
            )

    async def _execute_query_async(
        self, query: str, params: dict[str, Any]
    ) -> tuple[Sequence[Row], list[str]]:
        """Execute a SQL query asynchronously for async engines"""
        try:
            async with self.engine.engine.begin() as conn:  # type: ignore
                result = await conn.execute(text(query), params)
                data = result.fetchall()
                columns = [str(key) for key in result.keys()]
                return data, columns
        except Exception as e:
            logger.info(f"Error executing async query: {str(e)}")
            raise

    def _execute_query_sync(
        self, query: str, params: dict[str, Any]
    ) -> tuple[Sequence[Row], list[str]]:
        """Execute a SQL query synchronously for sync engines"""
        try:
            if isinstance(self.engine.engine, Engine):
                conn = self.engine.engine.connect()
                result = conn.execute(text(query), params)
                data = result.fetchall()
                columns = [str(key) for key in result.keys()]
                conn.close()
                return data, columns
            else:
                raise ValueError("Engine is not a sync engine")
        except Exception as e:
            logger.info(f"Error executing sync query: {str(e)}")
            raise
