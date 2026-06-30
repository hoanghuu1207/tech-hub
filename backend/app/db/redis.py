"""
Redis Cache Client — Async Redis connection cho TechShop.

Cung cấp:
    - get/set/delete cache operations (JSON serialized)
    - Pattern-based cache invalidation
    - Connection health check
"""

import json
import logging
from typing import Optional, Any

import redis.asyncio as aioredis

from app.core.config import settings

logger = logging.getLogger("redis_cache")

# Khởi tạo Redis async client
redis_client: aioredis.Redis = aioredis.from_url(
    settings.REDIS_URL,
    encoding="utf-8",
    decode_responses=True,
    max_connections=50,
)


async def cache_get(key: str) -> Optional[Any]:
    """Lấy giá trị từ cache. Trả về None nếu key không tồn tại hoặc lỗi."""
    try:
        data = await redis_client.get(key)
        if data is not None:
            return json.loads(data)
        return None
    except Exception as e:
        logger.warning(f"[Redis] GET failed for '{key}': {e}")
        return None


async def cache_set(key: str, value: Any, ttl: int = 300) -> bool:
    """
    Lưu giá trị vào cache với TTL (giây).
    
    Args:
        key: Cache key
        value: Dữ liệu (sẽ được JSON serialize)
        ttl: Time-to-live (giây), mặc định 5 phút
    """
    try:
        serialized = json.dumps(value, default=str, ensure_ascii=False)
        await redis_client.set(key, serialized, ex=ttl)
        return True
    except Exception as e:
        logger.warning(f"[Redis] SET failed for '{key}': {e}")
        return False


async def cache_delete(key: str) -> bool:
    """Xóa 1 key khỏi cache."""
    try:
        await redis_client.delete(key)
        return True
    except Exception as e:
        logger.warning(f"[Redis] DELETE failed for '{key}': {e}")
        return False


async def cache_delete_pattern(pattern: str) -> int:
    """
    Xóa tất cả keys khớp pattern (dùng SCAN để tránh block Redis).
    
    Ví dụ: cache_delete_pattern("catalog:*") → xóa tất cả cache catalog.
    """
    try:
        deleted = 0
        async for key in redis_client.scan_iter(match=pattern, count=100):
            await redis_client.delete(key)
            deleted += 1
        if deleted > 0:
            logger.info(f"[Redis] Invalidated {deleted} keys matching '{pattern}'")
        return deleted
    except Exception as e:
        logger.warning(f"[Redis] DELETE pattern '{pattern}' failed: {e}")
        return 0


async def check_redis_connection() -> bool:
    """Kiểm tra kết nối Redis."""
    try:
        await redis_client.ping()
        logger.info("✅ [Redis] Connected successfully")
        return True
    except Exception as e:
        logger.warning(f"❌ [Redis] Connection failed: {e}")
        return False
