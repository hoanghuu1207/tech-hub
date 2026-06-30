"""
CacheService — Quản lý cache strategy cho TechShop.

Cache Strategy:
    ┌─────────────────────────┬────────┬───────────────────────────────────────┐
    │ Dữ liệu                │ TTL    │ Cache Key                             │
    ├─────────────────────────┼────────┼───────────────────────────────────────┤
    │ Categories + Brands     │ 10 min │ catalog:categories                    │
    │ Category Products       │ 5 min  │ catalog:cat:{id}:p:{limit}:{offset}  │
    │ Brand Products          │ 5 min  │ catalog:cat:{cid}:b:{bid}:...        │
    │ Line Products           │ 5 min  │ catalog:line:{id}:p:{limit}:{offset} │
    │ All Products (list)     │ 3 min  │ catalog:products:{limit}:{offset}    │
    │ Product Detail          │ 5 min  │ product:{id}                         │
    │ Gemini Embedding        │ 1 hour │ embed:{hash(text)}                   │
    └─────────────────────────┴────────┴───────────────────────────────────────┘

Personalization:
    - Catalog list APIs cache DỮ LIỆU GỐC (không có personalization)
    - Khi user đã login, personalization (re-rank) được tính trên dữ liệu cached
    - Product detail không cần personalization → cache trực tiếp

Invalidation:
    - Admin tạo/sửa/xóa product → invalidate "catalog:*" + "product:{id}"
    - Admin tạo/sửa/xóa category → invalidate "catalog:*"
    - Webhook thanh toán (stock change) → invalidate "product:{id}" + "catalog:*"
"""

import hashlib
import logging

from typing import Optional, Any

from app.db.redis import cache_get, cache_set, cache_delete, cache_delete_pattern

logger = logging.getLogger("cache_service")


# ── TTL Constants (seconds) ──
class CacheTTL:
    CATEGORIES = 600          # 10 phút — dữ liệu ít thay đổi
    PRODUCT_LIST = 300        # 5 phút — danh sách sản phẩm
    PRODUCT_DETAIL = 300      # 5 phút — chi tiết sản phẩm
    ALL_PRODUCTS = 180        # 3 phút — trang sản phẩm chung
    EMBEDDING = 3600          # 1 giờ — embedding vectors


# ── Cache Key Builders ──
class CacheKeys:
    """Tạo cache keys chuẩn hóa."""

    @staticmethod
    def categories() -> str:
        return "catalog:categories"

    @staticmethod
    def all_products(limit: int, offset: int) -> str:
        return f"catalog:products:{limit}:{offset}"

    @staticmethod
    def category_products(category_id, limit: int, offset: int) -> str:
        return f"catalog:cat:{category_id}:p:{limit}:{offset}"

    @staticmethod
    def brand_products(category_id, brand_id, limit: int, offset: int) -> str:
        return f"catalog:cat:{category_id}:b:{brand_id}:{limit}:{offset}"

    @staticmethod
    def line_products(line_id, limit: int, offset: int) -> str:
        return f"catalog:line:{line_id}:p:{limit}:{offset}"

    @staticmethod
    def product_detail(product_id) -> str:
        return f"product:{product_id}"

    @staticmethod
    def embedding(text: str) -> str:
        """Hash text để tạo key cho embedding cache."""
        text_hash = hashlib.md5(text.encode()).hexdigest()
        return f"embed:{text_hash}"


# ── Cache Invalidation ──
class CacheInvalidator:
    """Xóa cache khi dữ liệu thay đổi."""

    @staticmethod
    async def invalidate_catalog():
        """Xóa toàn bộ cache catalog (khi admin CRUD product/category/brand)."""
        await cache_delete_pattern("catalog:*")
        logger.info("[Cache] Invalidated all catalog cache")

    @staticmethod
    async def invalidate_product(product_id):
        """Xóa cache chi tiết 1 sản phẩm."""
        await cache_delete(CacheKeys.product_detail(product_id))
        logger.info(f"[Cache] Invalidated product:{product_id}")

    @staticmethod
    async def invalidate_product_and_catalog(product_id):
        """Xóa cache sản phẩm + catalog (khi update/delete product)."""
        await cache_delete(CacheKeys.product_detail(product_id))
        await cache_delete_pattern("catalog:*")
        logger.info(f"[Cache] Invalidated product:{product_id} + catalog")

    @staticmethod
    async def invalidate_all():
        """Xóa toàn bộ cache (nuclear option)."""
        await cache_delete_pattern("catalog:*")
        await cache_delete_pattern("product:*")
        await cache_delete_pattern("embed:*")
        logger.info("[Cache] Invalidated ALL cache")
