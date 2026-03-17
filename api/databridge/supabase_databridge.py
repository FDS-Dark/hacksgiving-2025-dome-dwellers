from databridge.postgres_databridge import PostgresDatabridge
from engine.supabase_engine import SupabaseDBEngine
import pandas as pd
from typing import Any
from structlog import get_logger
import numpy as np

logger = get_logger()


class SupabaseDatabridge(PostgresDatabridge):
    """
    Supabase databridge for executing SQL queries against Supabase (PostgreSQL)

    Uses stored procedures for all database operations for better:
    - Performance (compiled procedures)
    - Security (parameterized queries)
    - Maintainability (logic in database)
    - Row-level security (RLS) support
    """

    def __init__(self, engine: SupabaseDBEngine) -> None:
        super().__init__(engine)
        logger.info("Initialized Supabase databridge")

    async def execute_query(
        self, query: str, params: dict[str, Any] | None = None
    ) -> pd.DataFrame:
        """
        Execute a SQL query with parameterized parameters

        Args:
            query: SQL query (e.g., 'SELECT * FROM dome.get_events(:p_limit)')
            params: Dictionary of parameter names and values

        Returns:
            DataFrame with query results
        """
        try:
            data, columns = await self.query_procedure_safe_async(query, params)
            df = pd.DataFrame(data, columns=columns)
            df = df.replace({np.nan: None})
            return df
        except Exception as e:
            logger.error(f"Error executing Supabase query: {str(e)}")
            raise

    async def execute_scalar(
        self, query: str, params: dict[str, Any] | None = None
    ) -> Any:
        """
        Execute a SQL query that returns a single scalar value

        Args:
            query: SQL query that returns a single value
            params: Dictionary of parameter names and values

        Returns:
            Scalar value from query result
        """
        try:
            data, columns = await self.query_procedure_safe_async(query, params)
            df = pd.DataFrame(data, columns=columns)

            if not df.empty and len(df.columns) > 0:
                return df.iloc[0, 0]
            return None
        except Exception as e:
            logger.error(f"Error executing scalar query: {str(e)}")
            raise

    # Health check methods
    
    async def check_connection(self) -> bool:
        """Check if Supabase connection is healthy"""
        try:
            result = await self.execute_query("SELECT 1 as test")
            return not result.empty
        except Exception as e:
            logger.error(f"Supabase connection check failed: {str(e)}")
            return False

    async def get_database_version(self) -> str:
        """Get PostgreSQL version from Supabase"""
        try:
            result = await self.execute_query("SELECT version() as version")
            if not result.empty:
                return result.iloc[0]["version"]
            return "Unknown"
        except Exception as e:
            logger.error(f"Error getting database version: {str(e)}")
            return "Error"

