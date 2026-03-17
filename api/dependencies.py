import jwt
import httpx
import time
import logging
import threading
from datetime import datetime
from fastapi import Request, HTTPException, status, Depends
from typing import Dict, Any, Optional, List, Tuple, Iterable
from pydantic import BaseModel
from services.stripe import StripeService
from services.user import UserService
from services.dome import DomeService
from services.plants import PlantsService
from services.inventory import InventoryService
from services.scrapbook import ScrapbookService
from services.qr_admin import QRAdminService
from services.tasks import TasksService
from services.announcements import AnnouncementsService
from settings import config
from engine.postgres_engine import PostgresDBEngine
from engine.supabase_engine import SupabaseDBEngine
from databridge.postgres_databridge import PostgresDatabridge
from databridge.supabase_databridge import SupabaseDatabridge
from databridge.dome_databridge import DomeDatabridge
from databridge.user_databridge import UserDatabridge
from databridge.plants_databridge import PlantsDatabridge
from databridge.scrapbook_databridge import ScrapbookDatabridge
from databridge.tasks_databridge import TasksDatabridge
from databridge.announcements_databridge import AnnouncementsDatabridge
from collections import OrderedDict
import re
import csv
from rapidfuzz import fuzz

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class AuthUser(BaseModel):
    """Auth0 user model for authentication"""
    id: str
    email: Optional[str] = None
    name: Optional[str] = None
    nickname: Optional[str] = None
    picture: Optional[str] = None
    permissions: List[str] = []
    roles: List[str] = []


class LRUCache:
    """LRU Cache implementation with TTL (Time To Live) support"""

    def __init__(self, capacity: int = 128, ttl: int = 600):
        self.capacity = capacity
        self.ttl = ttl  # TTL in seconds
        self.cache = OrderedDict()  # Maintains insertion order
        self._lock = threading.RLock()  # Thread-safe operations
        self._cleanup_timer = None
        self._start_cleanup_timer()

    def get(self, key: str) -> Optional[Dict[str, Any]]:
        """Get item from cache, return None if not found or expired"""
        with self._lock:
            if key not in self.cache:
                return None

            # Check if expired
            entry = self.cache[key]
            current_time = time.time()
            if current_time - entry["timestamp"] > self.ttl:
                # Remove expired entry
                del self.cache[key]
                logger.info(f"Cache entry expired for key: {key[:10]}...")
                return None

            # Move to end (mark as recently used)
            self.cache.move_to_end(key)
            return entry["data"]

    def put(self, key: str, value: Dict[str, Any]) -> None:
        """Put item in cache, evict LRU item if at capacity"""
        with self._lock:
            current_time = time.time()

            if key in self.cache:
                # Update existing entry
                self.cache[key] = {"data": value, "timestamp": current_time}
                self.cache.move_to_end(key)
            else:
                # Add new entry
                if len(self.cache) >= self.capacity:
                    # Remove least recently used item (first item)
                    oldest_key = next(iter(self.cache))
                    del self.cache[oldest_key]
                    logger.info(f"Evicted LRU cache entry: {oldest_key[:10]}...")

                self.cache[key] = {"data": value, "timestamp": current_time}

            logger.info(
                f"Cached entry for key: {key[:10]}... (cache size: {len(self.cache)})"
            )

    def clear(self) -> None:
        """Clear all cache entries"""
        with self._lock:
            self.cache.clear()
        logger.info("Cache cleared")

    def size(self) -> int:
        """Get current cache size"""
        with self._lock:
            return len(self.cache)

    def cleanup_expired(self) -> None:
        """Remove all expired entries"""
        with self._lock:
            current_time = time.time()
            expired_keys = []

            for key, entry in self.cache.items():
                if current_time - entry["timestamp"] > self.ttl:
                    expired_keys.append(key)

            for key in expired_keys:
                del self.cache[key]

            if expired_keys:
                logger.info(f"Cleaned up {len(expired_keys)} expired cache entries")

    def _start_cleanup_timer(self) -> None:
        """Start the automatic cleanup timer"""
        self._cleanup_expired_entries()
        # Schedule next cleanup
        self._cleanup_timer = threading.Timer(self.ttl, self._start_cleanup_timer)
        self._cleanup_timer.daemon = True
        self._cleanup_timer.start()

    def _cleanup_expired_entries(self) -> None:
        """Internal method to cleanup expired entries (called by timer)"""
        try:
            self.cleanup_expired()
        except Exception as e:
            logger.error(f"Error during automatic cache cleanup: {e}")

    def __del__(self):
        """Cleanup timer on object destruction"""
        if hasattr(self, "_cleanup_timer") and self._cleanup_timer:
            self._cleanup_timer.cancel()


# Initialize LRU cache for userinfo
userinfo_cache = LRUCache(capacity=128, ttl=600)  # 10 minutes TTL

# _auth_service = None  # Not needed for Stripe
_postgres_engine = None
_postgres_databridge = None
_supabase_engine = None
_supabase_databridge = None
_dome_databridge = None
_user_databridge = None
_plants_databridge = None
_scrapbook_databridge = None
_tasks_databridge = None
_announcements_databridge = None
_user_service = None
_stripe_service = None
_dome_service = None
_plants_service = None
_inventory_service = None
_scrapbook_service = None
_qr_admin_service = None
_tasks_service = None
_announcements_service = None
# _item_service = None  # Not needed for Stripe
# _processing_server_service = None  # Not needed for Stripe
# _item_prediction_service = None  # Not needed for Stripe
# _chat_service = None  # Not needed for Stripe
# _admin_service = None  # Not needed for Stripe

def get_postgres_engine():
    global _postgres_engine
    if _postgres_engine is None:
        _postgres_engine = PostgresDBEngine()
    return _postgres_engine


def get_postgres_databridge():
    global _postgres_databridge
    if _postgres_databridge is None:
        _postgres_databridge = PostgresDatabridge(get_postgres_engine())
    return _postgres_databridge


def get_supabase_engine():
    global _supabase_engine
    if _supabase_engine is None:
        _supabase_engine = SupabaseDBEngine()
    return _supabase_engine


def get_supabase_databridge():
    global _supabase_databridge
    if _supabase_databridge is None:
        _supabase_databridge = SupabaseDatabridge(get_supabase_engine())
    return _supabase_databridge


def get_dome_databridge():
    global _dome_databridge
    if _dome_databridge is None:
        _dome_databridge = DomeDatabridge(get_supabase_engine())
    return _dome_databridge


def get_user_databridge():
    global _user_databridge
    if _user_databridge is None:
        _user_databridge = UserDatabridge(get_supabase_engine())
    return _user_databridge


def get_plants_databridge():
    global _plants_databridge
    if _plants_databridge is None:
        _plants_databridge = PlantsDatabridge(get_supabase_engine())
    return _plants_databridge


def get_scrapbook_databridge():
    global _scrapbook_databridge
    if _scrapbook_databridge is None:
        _scrapbook_databridge = ScrapbookDatabridge(get_supabase_engine())
    return _scrapbook_databridge


def get_tasks_databridge():
    global _tasks_databridge
    if _tasks_databridge is None:
        _tasks_databridge = TasksDatabridge(get_supabase_engine())
    return _tasks_databridge


def get_announcements_databridge():
    global _announcements_databridge
    if _announcements_databridge is None:
        _announcements_databridge = AnnouncementsDatabridge(get_supabase_engine())
    return _announcements_databridge


def get_user_service() -> UserService:
    global _user_service
    if _user_service is None:
        _user_service = UserService(get_user_databridge())
    return _user_service


def get_stripe_service() -> StripeService:
    global _stripe_service
    if _stripe_service is None:
        _stripe_service = StripeService(get_postgres_databridge())
    return _stripe_service


def get_dome_service() -> DomeService:
    global _dome_service
    if _dome_service is None:
        _dome_service = DomeService(get_dome_databridge())
    return _dome_service


def get_plants_service() -> PlantsService:
    global _plants_service
    if _plants_service is None:
        _plants_service = PlantsService(get_plants_databridge())
    return _plants_service


def get_inventory_service() -> InventoryService:
    global _inventory_service
    if _inventory_service is None:
        _inventory_service = InventoryService(get_supabase_databridge())
    return _inventory_service


def get_scrapbook_service() -> ScrapbookService:
    global _scrapbook_service
    if _scrapbook_service is None:
        _scrapbook_service = ScrapbookService(get_scrapbook_databridge())
    return _scrapbook_service


def get_qr_admin_service() -> QRAdminService:
    global _qr_admin_service
    if _qr_admin_service is None:
        _qr_admin_service = QRAdminService(get_scrapbook_databridge())
    return _qr_admin_service


def get_tasks_service() -> TasksService:
    global _tasks_service
    if _tasks_service is None:
        _tasks_service = TasksService(get_tasks_databridge())
    return _tasks_service


def get_announcements_service() -> AnnouncementsService:
    global _announcements_service
    if _announcements_service is None:
        _announcements_service = AnnouncementsService(get_announcements_databridge())
    return _announcements_service

# def get_item_service() -> ItemService:
#     global _item_service
#     if _item_service is None:
#         _item_service = ItemService(get_postgres_databridge())
#     return _item_service

# def get_processing_server_service() -> ProcessingServerService:
#     global _processing_server_service
#     if _processing_server_service is None:
#         _processing_server_service = ProcessingServerService()
#     return _processing_server_service


# def get_chat_service() -> ChatService:
#     global _chat_service
#     if _chat_service is None:
#         _chat_service = ChatService(get_postgres_databridge())
#     return _chat_service

# def get_admin_service() -> AdminService:
#     global _admin_service
#     if _admin_service is None:
#         _admin_service = AdminService(get_postgres_databridge())
#     return _admin_service

async def get_auth0_userinfo(token: str, user_id: str = None) -> Dict[str, Any]:
    """
    Fetch user information from Auth0's userinfo endpoint with LRU caching.

    Args:
        token: The Auth0 access token
        user_id: The Auth0 user ID (for caching by user instead of token)

    Returns:
        User information dictionary or None if the request fails
    """
    # Use user_id for caching if provided, otherwise fall back to token
    cache_key = user_id if user_id else token

    # Check cache first
    cached_userinfo = userinfo_cache.get(cache_key)
    if cached_userinfo is not None:
        return cached_userinfo

    # Fetch user info from Auth0
    try:
        async with httpx.AsyncClient() as client:
            userinfo_url = f"https://{config.auth0.domain}/userinfo"
            headers = {"Authorization": f"Bearer {token}"}
            response = await client.get(userinfo_url, headers=headers)

            if response.status_code == 200:
                userinfo = response.json()
                logger.info("Successfully fetched user info from Auth0")

                # Cache the result using cache_key
                userinfo_cache.put(cache_key, userinfo)

                return userinfo
            else:
                logger.error(
                    f"Failed to fetch user info: {response.status_code} - {response.text}"
                )
                # if ratelimited
                if response.status_code == 429:
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail="Failed to authenticate user. Please try again later.",
                    )
                else:
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail=f"Failed to fetch user info: {response.status_code} - {response.text}",
                    )
    except HTTPException:
        # Re-raise HTTPException as-is
        raise
    except Exception as e:
        logger.error(f"Error fetching user info: {str(e)}")
        return None


async def get_optional_current_user(request: Request) -> Optional[Dict[str, Any]]:
    """
    Dependency function that optionally extracts and validates the JWT token.
    Accepts token from Authorization header OR ?token= query parameter.
    Returns None if no valid token is found (does not raise exception).
    
    Args:
        request: FastAPI Request object
        
    Returns:
        Dict containing user information from the database or None
    """
    # Try to get token from header first
    auth_header = request.headers.get("Authorization")
    token = None
    
    if auth_header and auth_header.startswith("Bearer "):
        token = auth_header.replace("Bearer ", "")
    else:
        # Try to get from query parameter
        token = request.query_params.get("token")
    
    if not token:
        logger.warning("No authentication token found in header or query")
        return None
    
    try:
        # Decode the token and extract user info
        payload = jwt.decode(
            token,
            algorithms=["RS256"],
            options={"verify_signature": False},
            audience=config.auth0.audience,
            issuer=f"https://{config.auth0.domain}/",
        )
        
        auth0_user_id = payload.get("sub")
        logger.info(f"Authenticated user: {auth0_user_id}")
        
        # Fetch detailed user info from Auth0's userinfo endpoint
        try:
            userinfo = await get_auth0_userinfo(token, auth0_user_id)
        except Exception as e:
            logger.error(f"Failed to get Auth0 userinfo: {str(e)}")
            return None
        
        # Get user from database
        user_databridge = UserDatabridge(get_supabase_engine())
        db_user = await user_databridge.get_user_by_auth0_id(auth0_user_id)
        
        if db_user.empty:
            logger.error(f"User not found in database: {auth0_user_id}")
            return None
        
        logger.info(f"User DB record: {db_user['id']}")
        return db_user
        
    except Exception as e:
        logger.error(f"Error in get_optional_current_user: {str(e)}")
        return None


async def get_current_user(request: Request) -> Dict[str, Any]:
    """
    Dependency function that extracts and validates the JWT token from the Authorization header
    and returns the current authenticated user information from the database.
    
    Args:
        request: FastAPI Request object
        
    Returns:
        Dict containing user information from the database
        
    Raises:
        HTTPException: If token is invalid or user is not authenticated
    """
    # Get the authorization header
    auth_header = request.headers.get("Authorization")
    
    if not auth_header or not auth_header.startswith("Bearer "):
        logger.warning(f"Missing or invalid auth header: {auth_header}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Extract the token
    token = auth_header.replace("Bearer ", "")
    
    try:
        # Decode the token and extract user info
        payload = jwt.decode(
            token,
            algorithms=["RS256"],
            options={"verify_signature": False},
            audience=config.auth0.audience,
            issuer=f"https://{config.auth0.domain}/",
        )
        
        auth0_user_id = payload.get("sub")
        logger.info(f"Authenticated user: {auth0_user_id}")
        
        # Fetch detailed user info from Auth0's userinfo endpoint
        try:
            userinfo = await get_auth0_userinfo(token, auth0_user_id)
        except Exception as e:
            logger.error(f"Failed to get Auth0 userinfo: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Failed to authenticate user. Please try again later.",
            )
        
        # Get user from database
        user_databridge = UserDatabridge(get_supabase_engine())
        db_user = await user_databridge.get_user_by_auth0_id(auth0_user_id)
        
        if db_user.empty:
            logger.error(f"User not found in database: {auth0_user_id}")
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found. Please complete registration first.",
            )
        
        logger.info(f"User DB record: {db_user['id']}")
        return db_user
        
    except jwt.PyJWTError as e:
        logger.error(f"JWT token error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid authentication credentials: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except Exception as e:
        logger.error(f"Unexpected error in get_current_user: {str(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Internal server error during authentication",
        )