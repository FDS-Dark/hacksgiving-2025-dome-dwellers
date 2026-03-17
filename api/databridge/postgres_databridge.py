from databridge.base_databridge import ThreadpoolAsyncDatabridge
from engine.postgres_engine import PostgresDBEngine
import pandas as pd
from typing import Any
from structlog import get_logger

logger = get_logger()


class PostgresDatabridge(ThreadpoolAsyncDatabridge):
    """Postgres databridge for executing SQL queries against Postgres"""

    def __init__(self, engine: PostgresDBEngine) -> None:
        super().__init__(engine)

    async def execute_query(
        self, query: str, params: dict[str, Any] | None = None
    ) -> pd.DataFrame:
        """Execute a custom SQL query with optional parameters"""
        try:
            data, columns = await self.query_procedure_safe_async(query, params)
            return pd.DataFrame(data, columns=columns)
        except Exception as e:
            logger.error(f"Error executing custom query: {str(e)}")
            raise