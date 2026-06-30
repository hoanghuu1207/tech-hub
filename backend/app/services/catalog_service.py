"""
CatalogService — Duyệt danh mục / thương hiệu / dòng sản phẩm.

Cung cấp 4 API chính:
  1. GET /categories           → Danh sách category gốc + brands
  2. GET /categories/{id}      → Products + brands của 1 category
  3. GET /categories/{id}/brands/{id} → Products + lines của 1 brand/category
  4. GET /product-lines/{id}   → Products của 1 line

Cá nhân hóa (thứ tự ưu tiên):
  1. Sản phẩm vừa xem gần đây + sản phẩm liên quan (cùng brand/category/line)
  2. Profile summary: thương hiệu, danh mục, phân khúc giá, lịch sử mua, tính năng
  3. Trong cùng mức boost: ưu tiên sold_count cao hơn
"""

import logging
import json
from uuid import UUID
from typing import Optional, List, Set

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.product import (
    Category, Brand, ProductLine, Product, ProductImage, ProductVariant,
)
from app.models.interaction import ProductView
from app.schemas.catalog import (
    CategoryOut, BrandOut, ProductLineOut, ProductCompact,
    CategoryWithBrandsOut,
    ProductDetailOut, ProductVariantOut, ProductImageOut,
)

logger = logging.getLogger("catalog")
logger.setLevel(logging.INFO)
if not logger.handlers:
    ch = logging.StreamHandler()
    ch.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    ch.setFormatter(formatter)
    logger.addHandler(ch)


class CatalogService:
    """Service duyệt catalog theo cấu trúc Category → Brand → Line → Product."""

    # ──────────────────────────────────────────────────────
    # Helpers (shared logic)
    # ──────────────────────────────────────────────────────

    @staticmethod
    def _product_to_compact(product: Product) -> ProductCompact:
        """Chuyển Product ORM → schema gọn cho danh sách."""
        primary_image = None
        if product.images:
            for img in product.images:
                if img.is_primary:
                    primary_image = img.image_url
                    break
            if not primary_image:
                primary_image = product.images[0].image_url

        return ProductCompact(
            id=product.id,
            name=product.name,
            slug=product.slug,
            base_price=float(product.base_price),
            sale_price=float(product.sale_price) if product.sale_price else None,
            primary_image=primary_image,
            rating_avg=float(product.rating_avg or 0),
            sold_count=product.sold_count or 0,
            brand_name=product.brand.name if product.brand else None,
            category_name=product.category.name if product.category else None,
            line_name=product.line.name if product.line else None,
        )

    @staticmethod
    def _parse_profile_preferences(profile_summary: str) -> dict:
        """
        Trích xuất thông tin sở thích có cấu trúc từ profile_summary.
        Returns dict với keys: brands, categories, price_range, purchased_products, features.
        """
        profile_lower = profile_summary.lower()
        prefs = {
            "brands": [],
            "categories": [],
            "price_min": None,
            "price_max": None,
            "purchased_keywords": [],
            "features": [],
        }

        # ── Trích xuất thương hiệu ──
        known_brands = [
            "apple", "samsung", "xiaomi", "huawei", "oppo", "vivo",
            "realme", "sony", "jbl", "marshall", "bose", "garmin",
            "dell", "hp", "asus", "acer", "lenovo", "msi",
            "amazfit", "honor",
        ]
        for brand in known_brands:
            if brand in profile_lower:
                prefs["brands"].append(brand)

        # ── Trích xuất danh mục ──
        category_map = {
            "smartphone": ["smartphone", "điện thoại", "phone"],
            "laptop": ["laptop", "máy tính xách tay"],
            "tablet": ["tablet", "máy tính bảng", "ipad"],
            "headphone": ["tai nghe", "headphone", "earphone", "earbud"],
            "smartwatch": ["đồng hồ thông minh", "smartwatch", "đồng hồ"],
            "accessory": ["phụ kiện", "accessory"],
        }
        for cat_key, aliases in category_map.items():
            for alias in aliases:
                if alias in profile_lower:
                    prefs["categories"].append(cat_key)
                    break

        # ── Trích xuất phân khúc giá ──
        import re
        # "giá rẻ", "dưới X triệu"
        if any(kw in profile_lower for kw in ["giá rẻ", "bình dân", "budget"]):
            prefs["price_max"] = 5_000_000
        elif any(kw in profile_lower for kw in ["tầm trung", "mid-range"]):
            prefs["price_min"] = 5_000_000
            prefs["price_max"] = 20_000_000
        elif any(kw in profile_lower for kw in ["cao cấp", "premium", "flagship"]):
            prefs["price_min"] = 20_000_000

        # "dưới X triệu"
        price_match = re.search(r"dưới\s+([\d,.]+)\s*(?:triệu|tr|củ)", profile_lower)
        if price_match:
            prefs["price_max"] = float(price_match.group(1).replace(",", ".")) * 1_000_000
        price_match = re.search(r"trên\s+([\d,.]+)\s*(?:triệu|tr|củ)", profile_lower)
        if price_match:
            prefs["price_min"] = float(price_match.group(1).replace(",", ".")) * 1_000_000
        # "tầm X-Y triệu"
        range_match = re.search(r"(\d+)\s*[-–]\s*(\d+)\s*(?:triệu|tr)", profile_lower)
        if range_match:
            prefs["price_min"] = float(range_match.group(1)) * 1_000_000
            prefs["price_max"] = float(range_match.group(2)) * 1_000_000

        # ── Trích xuất lịch sử mua ──
        purchase_section = ""
        for line in profile_summary.split("\n"):
            if "lịch sử mua" in line.lower() or "đã mua" in line.lower():
                purchase_section = line.lower()
                break
        if purchase_section and "chưa có" not in purchase_section:
            # Trích từ khóa sản phẩm đã mua
            for brand in known_brands:
                if brand in purchase_section:
                    prefs["purchased_keywords"].append(brand)

        # ── Trích xuất tính năng ──
        feature_keywords = [
            "chống ồn", "pin trâu", "gaming", "mỏng nhẹ", "chụp ảnh",
            "chống nước", "true wireless", "5g", "sạc nhanh",
            "định vị", "trẻ em", "thể thao", "văn phòng",
        ]
        for kw in feature_keywords:
            if kw in profile_lower:
                prefs["features"].append(kw)

        return prefs

    @staticmethod
    def _personalize_products(
        products: List[Product],
        profile_summary: Optional[str],
        recent_view_ids: Optional[dict] = None,
        related_brand_ids: Optional[Set[str]] = None,
        related_category_ids: Optional[Set[str]] = None,
        related_line_ids: Optional[Set[str]] = None,
    ) -> List[Product]:
        """
        Re-rank danh sách sản phẩm. Thứ tự ưu tiên:
          0. Sản phẩm vừa xem gần đây       → 20.0 ~ 12.0 (giảm dần theo thứ tự)
          0b. SP liên quan (cùng brand/cat/line với SP đã xem) → 8.0
          1. Thương hiệu yêu thích (profile) → 5.0
          2. Danh mục quan tâm (profile)      → 3.0
          3. Phân khúc giá phù hợp (profile)  → 2.0
          4. Lịch sử mua (profile)            → 1.5
          5. Tính năng ưu tiên (profile)      → 1.0
        Tie-breaker: sold_count (cao → thấp).
        """
        if not products:
            return products

        prefs = CatalogService._parse_profile_preferences(profile_summary) if profile_summary else None
        rv_ids = recent_view_ids or {}   # dict {pid: position}
        rb_ids = related_brand_ids or set()
        rc_ids = related_category_ids or set()
        rl_ids = related_line_ids or set()

        def _calc_boost(product: Product) -> float:
            boost = 0.0
            pid = str(product.id)

            # ⓪ Sản phẩm vừa xem gần đây (20.0 → 12.0 giảm dần)
            #    position 0 = gần nhất → boost cao nhất
            if pid in rv_ids:
                position = rv_ids[pid]
                boost += max(20.0 - position * 1.0, 12.0)

            # ⓪b Sản phẩm liên quan (cùng brand/category/line) (8.0)
            if pid not in rv_ids:
                related = False
                if product.brand_id and str(product.brand_id) in rb_ids:
                    related = True
                if product.category_id and str(product.category_id) in rc_ids:
                    related = True
                if product.line_id and str(product.line_id) in rl_ids:
                    related = True
                if related:
                    boost += 8.0

            if not prefs:
                return boost

            # ① Thương hiệu yêu thích (5.0)
            if product.brand and product.brand.name:
                if product.brand.name.lower() in prefs["brands"]:
                    boost += 5.0

            # ② Danh mục quan tâm (3.0)
            if product.category and product.category.slug:
                cat_slug = product.category.slug.lower()
                if cat_slug in prefs["categories"]:
                    boost += 3.0
                elif product.category.name and product.category.name.lower() in profile_summary.lower():
                    boost += 3.0

            # ③ Phân khúc giá (2.0)
            dp = float(product.sale_price) if product.sale_price else (float(product.base_price) if product.base_price else 0)
            if dp > 0:
                in_range = True
                if prefs["price_min"] is not None and dp < prefs["price_min"]:
                    in_range = False
                if prefs["price_max"] is not None and dp > prefs["price_max"]:
                    in_range = False
                if in_range and (prefs["price_min"] is not None or prefs["price_max"] is not None):
                    boost += 2.0

            # ④ Lịch sử mua (1.5)
            if product.brand and product.brand.name and prefs["purchased_keywords"]:
                if product.brand.name.lower() in prefs["purchased_keywords"]:
                    boost += 1.5

            # ⑤ Tính năng (1.0)
            if product.name and prefs["features"]:
                combined = product.name.lower() + " " + " ".join(product.highlight_features or []).lower()
                for kw in prefs["features"]:
                    if kw in combined:
                        boost += 1.0
                        break

            return boost

        # Sort: boost cao trước, tie-break bằng sold_count
        products_with_score = [
            (p, _calc_boost(p), p.sold_count or 0) for p in products
        ]
        products_with_score.sort(key=lambda x: (x[1], x[2]), reverse=True)

        if any(b > 0 for _, b, _ in products_with_score):
            return [p for p, _, _ in products_with_score]

        return products

    @staticmethod
    async def _query_products(
        db: AsyncSession,
        *,
        category_id: Optional[UUID] = None,
        brand_id: Optional[UUID] = None,
        line_id: Optional[UUID] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> List[Product]:
        """Query products với các filter tùy chọn, eager-load quan hệ cần thiết."""
        stmt = (
            select(Product)
            .options(
                selectinload(Product.images),
                selectinload(Product.brand),
                selectinload(Product.category),
                selectinload(Product.line),
            )
            .where(Product.is_active == True, Product.deleted_at.is_(None))
            .order_by(Product.sold_count.desc(), Product.created_at.desc())
        )

        if category_id:
            stmt = stmt.where(Product.category_id == category_id)
        if brand_id:
            stmt = stmt.where(Product.brand_id == brand_id)
        if line_id:
            stmt = stmt.where(Product.line_id == line_id)

        stmt = stmt.limit(limit).offset(offset)
        result = await db.execute(stmt)
        return list(result.scalars().unique().all())

    @staticmethod
    async def _count_products(
        db: AsyncSession,
        *,
        category_id: Optional[UUID] = None,
        brand_id: Optional[UUID] = None,
        line_id: Optional[UUID] = None,
    ) -> int:
        """Đếm tổng sản phẩm theo filter."""
        stmt = select(func.count(Product.id)).where(Product.is_active == True, Product.deleted_at.is_(None))
        if category_id:
            stmt = stmt.where(Product.category_id == category_id)
        if brand_id:
            stmt = stmt.where(Product.brand_id == brand_id)
        if line_id:
            stmt = stmt.where(Product.line_id == line_id)
        result = await db.execute(stmt)
        return result.scalar() or 0

    @staticmethod
    async def _get_brands_of_category(db: AsyncSession, category_id: UUID) -> List[Brand]:
        """Lấy danh sách brands (distinct) có trong category thông qua product_lines."""
        stmt = (
            select(Brand)
            .join(ProductLine, ProductLine.brand_id == Brand.id)
            .where(
                ProductLine.category_id == category_id,
                ProductLine.is_active == True,
                Brand.is_active == True,
            )
            .distinct()
            .order_by(Brand.name)
        )
        result = await db.execute(stmt)
        return list(result.scalars().unique().all())

    # ──────────────────────────────────────────────────────
    # API 1: Danh sách categories gốc + brands
    # ──────────────────────────────────────────────────────

    async def get_root_categories_with_brands(
        self, db: AsyncSession
    ) -> List[CategoryWithBrandsOut]:
        """
        Lấy categories có parent_id = NULL (gốc).
        Mỗi category kèm danh sách brands (distinct từ product_lines).
        """
        # Lấy categories gốc
        stmt = (
            select(Category)
            .where(Category.parent_id == None, Category.is_active == True)
            .order_by(Category.sort_order, Category.name)
        )
        result = await db.execute(stmt)
        categories = result.scalars().all()

        output = []
        for cat in categories:
            brands = await self._get_brands_of_category(db, cat.id)
            output.append(CategoryWithBrandsOut(
                id=cat.id,
                name=cat.name,
                slug=cat.slug,
                icon_url=cat.icon_url,
                description=cat.description,
                sort_order=cat.sort_order or 0,
                brands=[BrandOut.model_validate(b) for b in brands],
            ))

        return output

    # ──────────────────────────────────────────────────────
    # API 1b: Tất cả sản phẩm (có cache)
    # ──────────────────────────────────────────────────────

    async def get_all_products_cached(
        self, db: AsyncSession, limit: int = 50, offset: int = 0,
        user_profile: Optional[str] = None,
        user_id: Optional[UUID] = None,
    ) -> dict:
        """Lấy tất cả products, cache base data, personalize trên cached data."""
        from app.services.cache_service import CacheKeys, CacheTTL
        from app.db.redis import cache_get, cache_set

        # Lấy lịch sử xem gần đây (nếu đã login)
        rv = await self._get_recent_views(db, user_id) if user_id else {}

        logger.info(
            f"🔍 [AllProducts] user_id={str(user_id)[:8] if user_id else None}, "
            f"has_profile={bool(user_profile)}, "
            f"rv={rv}, "
            f"rv_truthy={bool(rv)}"
        )

        cache_key = CacheKeys.all_products(limit, offset)

        # Thử lấy từ cache
        cached = await cache_get(cache_key)
        if cached is not None:
            should_personalize = (user_profile or rv) and cached.get("products")
            logger.info(
                f"🔍 [AllProducts] Cache HIT, should_personalize={bool(should_personalize)}, "
                f"products_count={len(cached.get('products', []))}"
            )
            if should_personalize:
                cached["products"] = self._personalize_compact_products(
                    cached["products"], user_profile,
                    recent_view_ids=rv.get("product_ids"),
                    related_brand_ids=rv.get("brand_ids"),
                    related_category_ids=rv.get("category_ids"),
                    related_line_ids=rv.get("line_ids"),
                )
            return cached

        # Cache miss → query DB
        products = await self._query_products(db, limit=limit, offset=offset)
        total = await self._count_products(db)

        data = {
            "products": [self._product_to_compact(p).model_dump() for p in products],
            "total": total,
        }

        # Cache base data (không personalization)
        await cache_set(cache_key, data, CacheTTL.ALL_PRODUCTS)

        # Personalize cho request hiện tại
        if (user_profile or rv) and data["products"]:
            data["products"] = self._personalize_compact_products(
                data["products"], user_profile,
                recent_view_ids=rv.get("product_ids"),
                related_brand_ids=rv.get("brand_ids"),
                related_category_ids=rv.get("category_ids"),
                related_line_ids=rv.get("line_ids"),
            )

        return data

    # ──────────────────────────────────────────────────────
    # API 2: Products + brands của 1 category
    # ──────────────────────────────────────────────────────

    async def get_category_products(
        self, category_id: UUID, db: AsyncSession,
        limit: int = 50, offset: int = 0,
        user_profile: Optional[str] = None,
    ) -> dict:
        """
        Lấy tất cả products thuộc category_id,
        kèm danh sách brands của category đó.
        """
        # Category info
        category = await db.get(Category, category_id)
        if not category:
            return None

        # Brands + Products (song song)
        brands = await self._get_brands_of_category(db, category_id)
        products = await self._query_products(
            db, category_id=category_id, limit=limit, offset=offset
        )
        total = await self._count_products(db, category_id=category_id)

        result = {
            "category": CategoryOut.model_validate(category),
            "brands": [BrandOut.model_validate(b) for b in brands],
            "products": [self._product_to_compact(p) for p in products],
            "total": total,
        }

        # Cá nhân hóa thứ tự sản phẩm
        if user_profile and result["products"]:
            products = self._personalize_products(products, user_profile)
            result["products"] = [self._product_to_compact(p) for p in products]

        return result

    async def get_category_products_cached(
        self, category_id: UUID, db: AsyncSession,
        limit: int = 50, offset: int = 0,
        user_profile: Optional[str] = None,
        user_id: Optional[UUID] = None,
    ) -> dict:
        """get_category_products với Redis cache."""
        from app.services.cache_service import CacheKeys, CacheTTL
        from app.db.redis import cache_get, cache_set

        rv = await self._get_recent_views(db, user_id) if user_id else {}

        cache_key = CacheKeys.category_products(category_id, limit, offset)
        cached = await cache_get(cache_key)
        if cached is not None:
            if (user_profile or rv) and cached.get("products"):
                cached["products"] = self._personalize_compact_products(
                    cached["products"], user_profile,
                    recent_view_ids=rv.get("product_ids"),
                    related_brand_ids=rv.get("brand_ids"),
                    related_category_ids=rv.get("category_ids"),
                    related_line_ids=rv.get("line_ids"),
                )
            return cached

        result = await self.get_category_products(
            category_id, db, limit=limit, offset=offset, user_profile=None
        )
        if result is None:
            return None

        cache_data = {
            "category": result["category"].model_dump() if hasattr(result["category"], 'model_dump') else result["category"],
            "brands": [b.model_dump() if hasattr(b, 'model_dump') else b for b in result["brands"]],
            "products": [p.model_dump() if hasattr(p, 'model_dump') else p for p in result["products"]],
            "total": result["total"],
        }
        await cache_set(cache_key, cache_data, CacheTTL.PRODUCT_LIST)

        if (user_profile or rv) and cache_data["products"]:
            cache_data["products"] = self._personalize_compact_products(
                cache_data["products"], user_profile,
                recent_view_ids=rv.get("product_ids"),
                related_brand_ids=rv.get("brand_ids"),
                related_category_ids=rv.get("category_ids"),
                related_line_ids=rv.get("line_ids"),
            )

        return cache_data

    # ──────────────────────────────────────────────────────
    # API 3: Products + lines của 1 brand trong 1 category
    # ──────────────────────────────────────────────────────

    async def get_brand_products(
        self, category_id: UUID, brand_id: UUID, db: AsyncSession,
        limit: int = 50, offset: int = 0,
        user_profile: Optional[str] = None,
    ) -> dict:
        """
        Lấy tất cả products thuộc category_id + brand_id,
        kèm danh sách product_lines của brand trong category đó.
        """
        category = await db.get(Category, category_id)
        brand = await db.get(Brand, brand_id)
        if not category or not brand:
            return None

        # Product lines của brand trong category
        stmt = (
            select(ProductLine)
            .where(
                ProductLine.category_id == category_id,
                ProductLine.brand_id == brand_id,
                ProductLine.is_active == True,
            )
            .order_by(ProductLine.sort_order, ProductLine.name)
        )
        result = await db.execute(stmt)
        lines = list(result.scalars().all())

        # Products
        products = await self._query_products(
            db, category_id=category_id, brand_id=brand_id,
            limit=limit, offset=offset,
        )
        total = await self._count_products(
            db, category_id=category_id, brand_id=brand_id,
        )

        # Cá nhân hóa thứ tự sản phẩm
        if user_profile:
            products = self._personalize_products(products, user_profile)

        return {
            "category": CategoryOut.model_validate(category),
            "brand": BrandOut.model_validate(brand),
            "product_lines": [ProductLineOut.model_validate(ln) for ln in lines],
            "products": [self._product_to_compact(p) for p in products],
            "total": total,
        }

    async def get_brand_products_cached(
        self, category_id: UUID, brand_id: UUID, db: AsyncSession,
        limit: int = 50, offset: int = 0,
        user_profile: Optional[str] = None,
        user_id: Optional[UUID] = None,
    ) -> dict:
        """get_brand_products với Redis cache."""
        from app.services.cache_service import CacheKeys, CacheTTL
        from app.db.redis import cache_get, cache_set

        rv = await self._get_recent_views(db, user_id) if user_id else {}

        cache_key = CacheKeys.brand_products(category_id, brand_id, limit, offset)
        cached = await cache_get(cache_key)
        if cached is not None:
            if (user_profile or rv) and cached.get("products"):
                cached["products"] = self._personalize_compact_products(
                    cached["products"], user_profile,
                    recent_view_ids=rv.get("product_ids"),
                    related_brand_ids=rv.get("brand_ids"),
                    related_category_ids=rv.get("category_ids"),
                    related_line_ids=rv.get("line_ids"),
                )
            return cached

        result = await self.get_brand_products(
            category_id, brand_id, db, limit=limit, offset=offset, user_profile=None
        )
        if result is None:
            return None

        cache_data = {
            "category": result["category"].model_dump() if hasattr(result["category"], 'model_dump') else result["category"],
            "brand": result["brand"].model_dump() if hasattr(result["brand"], 'model_dump') else result["brand"],
            "product_lines": [pl.model_dump() if hasattr(pl, 'model_dump') else pl for pl in result["product_lines"]],
            "products": [p.model_dump() if hasattr(p, 'model_dump') else p for p in result["products"]],
            "total": result["total"],
        }
        await cache_set(cache_key, cache_data, CacheTTL.PRODUCT_LIST)

        if (user_profile or rv) and cache_data["products"]:
            cache_data["products"] = self._personalize_compact_products(
                cache_data["products"], user_profile,
                recent_view_ids=rv.get("product_ids"),
                related_brand_ids=rv.get("brand_ids"),
                related_category_ids=rv.get("category_ids"),
                related_line_ids=rv.get("line_ids"),
            )

        return cache_data

    # ──────────────────────────────────────────────────────
    # API 4: Products của 1 product_line
    # ──────────────────────────────────────────────────────

    async def get_line_products(
        self, line_id: UUID, db: AsyncSession,
        limit: int = 50, offset: int = 0,
        user_profile: Optional[str] = None,
    ) -> dict:
        """
        Lấy products có line_id = line_id (chỉ lấy đúng line đó).
        """
        stmt = (
            select(ProductLine)
            .options(selectinload(ProductLine.brand))
            .where(ProductLine.id == line_id)
        )
        result = await db.execute(stmt)
        line = result.scalar_one_or_none()
        if not line:
            return None

        products = await self._query_products(
            db, line_id=line_id, limit=limit, offset=offset
        )
        total = await self._count_products(db, line_id=line_id)

        # Cá nhân hóa thứ tự sản phẩm
        if user_profile:
            products = self._personalize_products(products, user_profile)

        return {
            "product_line": ProductLineOut.model_validate(line),
            "brand": BrandOut.model_validate(line.brand),
            "products": [self._product_to_compact(p) for p in products],
            "total": total,
        }

    async def get_line_products_cached(
        self, line_id: UUID, db: AsyncSession,
        limit: int = 50, offset: int = 0,
        user_profile: Optional[str] = None,
        user_id: Optional[UUID] = None,
    ) -> dict:
        """get_line_products với Redis cache."""
        from app.services.cache_service import CacheKeys, CacheTTL
        from app.db.redis import cache_get, cache_set

        rv = await self._get_recent_views(db, user_id) if user_id else {}

        cache_key = CacheKeys.line_products(line_id, limit, offset)
        cached = await cache_get(cache_key)
        if cached is not None:
            if (user_profile or rv) and cached.get("products"):
                cached["products"] = self._personalize_compact_products(
                    cached["products"], user_profile,
                    recent_view_ids=rv.get("product_ids"),
                    related_brand_ids=rv.get("brand_ids"),
                    related_category_ids=rv.get("category_ids"),
                    related_line_ids=rv.get("line_ids"),
                )
            return cached

        result = await self.get_line_products(
            line_id, db, limit=limit, offset=offset, user_profile=None
        )
        if result is None:
            return None

        cache_data = {
            "product_line": result["product_line"].model_dump() if hasattr(result["product_line"], 'model_dump') else result["product_line"],
            "brand": result["brand"].model_dump() if hasattr(result["brand"], 'model_dump') else result["brand"],
            "products": [p.model_dump() if hasattr(p, 'model_dump') else p for p in result["products"]],
            "total": result["total"],
        }
        await cache_set(cache_key, cache_data, CacheTTL.PRODUCT_LIST)

        if (user_profile or rv) and cache_data["products"]:
            cache_data["products"] = self._personalize_compact_products(
                cache_data["products"], user_profile,
                recent_view_ids=rv.get("product_ids"),
                related_brand_ids=rv.get("brand_ids"),
                related_category_ids=rv.get("category_ids"),
                related_line_ids=rv.get("line_ids"),
            )

        return cache_data


    # ──────────────────────────────────────────────────────
    # API 5: Product Detail
    # ──────────────────────────────────────────────────────

    async def get_product_detail(
        self, product_id: UUID, db: AsyncSession,
    ) -> Optional[ProductDetailOut]:
        """
        Lấy chi tiết đầy đủ của 1 product: variants, images, brand, category, line, specs.
        Chỉ trả về product active. Variants chỉ lấy is_active. Images sort theo sort_order.
        """
        stmt = (
            select(Product)
            .options(
                selectinload(Product.variants),
                selectinload(Product.images),
                selectinload(Product.brand),
                selectinload(Product.category),
                selectinload(Product.line),
            )
            .where(Product.id == product_id, Product.is_active == True)
        )
        result = await db.execute(stmt)
        product = result.scalar_one_or_none()

        if not product:
            return None

        # Filter active variants, sort images by sort_order
        active_variants = [
            v for v in product.variants if v.is_active
        ]
        sorted_images = sorted(
            product.images, key=lambda img: img.sort_order
        )

        return ProductDetailOut(
            id=product.id,
            name=product.name,
            slug=product.slug,
            base_price=float(product.base_price),
            sale_price=float(product.sale_price) if product.sale_price else None,
            description=product.description,
            highlight_features=product.highlight_features or [],
            rating_avg=float(product.rating_avg or 0),
            rating_count=product.rating_count or 0,
            sold_count=product.sold_count or 0,
            status=product.status or "new",
            brand=BrandOut.model_validate(product.brand) if product.brand else None,
            category=CategoryOut.model_validate(product.category) if product.category else None,
            line=ProductLineOut.model_validate(product.line) if product.line else None,
            variants=[ProductVariantOut(
                id=v.id,
                color_name=v.color_name,
                color_hex=v.color_hex,
                price_override=float(v.price_override) if v.price_override else None,
                sale_price_override=float(v.sale_price_override) if v.sale_price_override else None,
                stock_quantity=v.stock_quantity or 0,
            ) for v in active_variants],
            images=[ProductImageOut(
                id=img.id,
                image_url=img.image_url,
                is_primary=img.is_primary,
                sort_order=img.sort_order,
            ) for img in sorted_images],
            specs=product.specs or {},
        )

    async def get_product_detail_cached(
        self, product_id: UUID, db: AsyncSession,
    ) -> Optional[ProductDetailOut]:
        """get_product_detail với Redis cache."""
        from app.services.cache_service import CacheKeys, CacheTTL
        from app.db.redis import cache_get, cache_set

        cache_key = CacheKeys.product_detail(product_id)
        cached = await cache_get(cache_key)
        if cached is not None:
            return ProductDetailOut(**cached)

        detail = await self.get_product_detail(product_id, db)
        if detail is None:
            return None

        # Cache serialized detail
        await cache_set(cache_key, detail.model_dump(), CacheTTL.PRODUCT_DETAIL)
        return detail

    # ──────────────────────────────────────────────────────
    # Helpers: Lấy lịch sử xem gần đây
    # ──────────────────────────────────────────────────────

    @staticmethod
    async def _get_recent_views(
        db: AsyncSession, user_id: UUID, limit: int = 15,
    ) -> dict:
        """
        Lấy N sản phẩm xem gần nhất của user.
        Returns dict với keys:
          - product_ids: dict {product_id_str: position} (0 = gần nhất)
          - brand_ids: set tên brand (lowercase)
          - category_ids: set tên category (lowercase)
          - line_ids: set line_id (str)
        """
        stmt = (
            select(ProductView)
            .where(ProductView.user_id == user_id)
            .order_by(ProductView.viewed_at.desc())
            .limit(limit)
        )
        result = await db.execute(stmt)
        views = list(result.scalars().all())

        if not views:
            return {}

        # product_ids: dict {pid: position} — position 0 = xem gần nhất
        product_ids_with_pos = {
            str(v.product_id): idx for idx, v in enumerate(views)
        }

        # Collect unique brand/category IDs từ views
        brand_uuid_set = {v.brand_id for v in views if v.brand_id}
        cat_uuid_set = {v.category_id for v in views if v.category_id}

        # Resolve brand names
        brand_names: Set[str] = set()
        if brand_uuid_set:
            res = await db.execute(
                select(Brand.name).where(Brand.id.in_(brand_uuid_set))
            )
            brand_names = {row[0].lower() for row in res.all()}

        # Resolve category names
        cat_names: Set[str] = set()
        if cat_uuid_set:
            res = await db.execute(
                select(Category.name).where(Category.id.in_(cat_uuid_set))
            )
            cat_names = {row[0].lower() for row in res.all()}

        return {
            "product_ids": product_ids_with_pos,  # dict {pid: position}
            "brand_ids": brand_names,
            "category_ids": cat_names,
            "line_ids": {str(v.line_id) for v in views if v.line_id},
        }

    # ──────────────────────────────────────────────────────
    # Helpers: Personalize trên dữ liệu đã serialize (dict)
    # ──────────────────────────────────────────────────────

    @staticmethod
    def _personalize_compact_products(
        products_data: list[dict],
        profile_summary: Optional[str],
        recent_view_ids: Optional[dict] = None,
        related_brand_ids: Optional[Set[str]] = None,
        related_category_ids: Optional[Set[str]] = None,
        related_line_ids: Optional[Set[str]] = None,
    ) -> list[dict]:
        """
        Re-rank danh sách sản phẩm (dạng dict/serialized).
        Dùng cho cached data — không cần ORM objects.
        Thứ tự: recently viewed (giảm dần) → related → profile boost → sold_count.
        """
        if not products_data:
            return products_data

        prefs = CatalogService._parse_profile_preferences(profile_summary) if profile_summary else None
        rv_ids = recent_view_ids or {}   # dict {pid: position}
        rb_ids = related_brand_ids or set()
        rc_ids = related_category_ids or set()
        rl_ids = related_line_ids or set()

        # Debug log
        if rv_ids or prefs:
            logger.info(
                f"🔍 [Personalize] rv_ids={rv_ids}, "
                f"rb_ids={rb_ids}, rc_ids={rc_ids}, "
                f"has_prefs={prefs is not None}, "
                f"total_products={len(products_data)}"
            )
            if products_data:
                sample = products_data[0]
                logger.info(
                    f"🔍 [Personalize] Sample product id={sample.get('id')} "
                    f"type={type(sample.get('id'))}"
                )

        def _calc_boost(p: dict) -> float:
            boost = 0.0
            pid = str(p.get("id", ""))
            brand_name = (p.get("brand_name") or "").lower()
            category_name = (p.get("category_name") or "").lower()

            # ⓪ Sản phẩm vừa xem (20.0 → 12.0 giảm dần)
            if pid in rv_ids:
                position = rv_ids[pid]
                boost += max(20.0 - position * 1.0, 12.0)

            # ⓪b Sản phẩm liên quan (8.0)
            if pid not in rv_ids:
                related = False
                # rb_ids / rc_ids đã là lowercase names (từ _get_recent_views)
                if brand_name and brand_name in rb_ids:
                    related = True
                if category_name and category_name in rc_ids:
                    related = True
                if related:
                    boost += 8.0

            if not prefs:
                return boost

            # ① Thương hiệu (5.0)
            if brand_name in prefs["brands"]:
                boost += 5.0
            # ② Danh mục (3.0)
            if category_name in [c.lower() for c in prefs["categories"]]:
                boost += 3.0
            # ③ Phân khúc giá (2.0)
            dp = p.get("sale_price") or p.get("base_price") or 0
            if dp > 0:
                in_range = True
                if prefs["price_min"] is not None and dp < prefs["price_min"]:
                    in_range = False
                if prefs["price_max"] is not None and dp > prefs["price_max"]:
                    in_range = False
                if in_range and (prefs["price_min"] is not None or prefs["price_max"] is not None):
                    boost += 2.0
            # ④ Lịch sử mua (1.5)
            if brand_name and brand_name in prefs.get("purchased_keywords", []):
                boost += 1.5
            # ⑤ Tính năng (1.0)
            for kw in prefs.get("features", []):
                if kw in (p.get("name") or "").lower():
                    boost += 1.0
                    break

            return boost

        products_with_score = [
            (p, _calc_boost(p), p.get("sold_count") or 0) for p in products_data
        ]
        products_with_score.sort(key=lambda x: (x[1], x[2]), reverse=True)

        if any(b > 0 for _, b, _ in products_with_score):
            # Debug: log top 3 boosted products
            top3 = products_with_score[:3]
            logger.info(
                f"🔍 [Personalize] Top 3 after sort: "
                + ", ".join(
                    f"{p.get('name','?')}(boost={b:.1f}, sold={s})"
                    for p, b, s in top3
                )
            )
            return [p for p, _, _ in products_with_score]

        return products_data


# Singleton
catalog_service = CatalogService()

