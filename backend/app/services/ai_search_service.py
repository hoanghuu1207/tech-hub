"""
AISearchService — Xử lý logic tìm kiếm ngữ nghĩa cho TechShop.

Pipeline:
    1. Nhận câu truy vấn ngôn ngữ tự nhiên từ Client
    2. Trích xuất bộ lọc giá + specs từ câu query (nếu có)
    3. Gọi Gemini API để chuyển query thành vector embedding (3072 dims)
    4. Tìm kiếm Qdrant Cloud bằng cosine similarity + payload filters
    5. Post-filter bằng dữ liệu thực từ PostgreSQL
    6. Trả về danh sách sản phẩm kèm similarity score
"""

import re
import time
import logging
from typing import Optional, Tuple, Dict, Any
from uuid import UUID
from dataclasses import dataclass, field

import google.generativeai as genai
from qdrant_client.models import Filter, FieldCondition, MatchValue, Range
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import settings
from app.db.qdrant import qdrant_client
from app.models.product import Product, Category, Brand, ProductImage
from app.schemas.ai import (
    AISearchFilters,
    AIProductResult,
    AISearchData,
    AISuggestItem,
)

logger = logging.getLogger("ai_search")

COLLECTION_NAME = "products"
EMBEDDING_MODEL = "models/gemini-embedding-2"
EMBEDDING_DIM = 3072


@dataclass
class ExtractedConstraints:
    """Kết quả trích xuất tất cả constraints từ câu query NL."""
    price_min: Optional[float] = None
    price_max: Optional[float] = None
    ram_min: Optional[int] = None
    ram_max: Optional[int] = None
    storage_min: Optional[int] = None
    storage_max: Optional[int] = None
    screen_min: Optional[float] = None
    screen_max: Optional[float] = None

    @property
    def has_any(self) -> bool:
        return any(v is not None for v in [
            self.price_min, self.price_max,
            self.ram_min, self.ram_max,
            self.storage_min, self.storage_max,
            self.screen_min, self.screen_max,
        ])


class AISearchService:
    """
    Service class quản lý toàn bộ luồng tìm kiếm ngữ nghĩa.
    Sử dụng Gemini embedding + Qdrant vector search + PostgreSQL hydration.
    """

    def __init__(self):
        genai.configure(api_key=settings.GEMINI_API_KEY)

    # ────────────────────────────────────────────────────────
    # PUBLIC: Tìm kiếm ngữ nghĩa
    # ────────────────────────────────────────────────────────

    async def search(
        self,
        query: str,
        db: AsyncSession,
        filters: Optional[AISearchFilters] = None,
        limit: int = 10,
    ) -> AISearchData:
        start_time = time.time()

        # ── Bước 1: Trích xuất constraints từ câu query ──
        constraints = self._extract_all_constraints(query)

        if constraints.has_any:
            if filters is None:
                filters = AISearchFilters()
            # Merge constraints vào filters (chỉ khi client chưa truyền)
            if filters.price_min is None and constraints.price_min is not None:
                filters.price_min = constraints.price_min
            if filters.price_max is None and constraints.price_max is not None:
                filters.price_max = constraints.price_max
            if filters.ram_min is None and constraints.ram_min is not None:
                filters.ram_min = constraints.ram_min
            if filters.ram_max is None and constraints.ram_max is not None:
                filters.ram_max = constraints.ram_max
            if filters.storage_min is None and constraints.storage_min is not None:
                filters.storage_min = constraints.storage_min
            if filters.storage_max is None and constraints.storage_max is not None:
                filters.storage_max = constraints.storage_max
            if filters.screen_min is None and constraints.screen_min is not None:
                filters.screen_min = constraints.screen_min
            if filters.screen_max is None and constraints.screen_max is not None:
                filters.screen_max = constraints.screen_max
            logger.info(f"[AI Search] Extracted constraints: {constraints}")

        # ── Bước 2: Chuyển query thành vector ──
        logger.info(f"[AI Search] Query: '{query}'")
        query_vector = await self._embed_query(query)

        # ── Bước 3: Tìm kiếm trên Qdrant ──
        search_limit = limit * 4 if constraints.has_any else limit
        qdrant_filter = self._build_qdrant_filters(filters)
        scored_points = self._search_qdrant(query_vector, qdrant_filter, search_limit)

        if not scored_points:
            elapsed = (time.time() - start_time) * 1000
            return AISearchData(
                products=[], total=0, query=query, search_time_ms=round(elapsed, 2)
            )

        # ── Bước 4: Lấy dữ liệu đầy đủ từ PostgreSQL ──
        score_map = {}
        product_ids = []
        for point in scored_points:
            pid = point.payload.get("product_id")
            if pid:
                product_ids.append(UUID(pid))
                score_map[pid] = point.score

        products = await self._hydrate_products(product_ids, db)

        # ── Bước 5: Post-filter từ PostgreSQL (chính xác nhất) ──
        results = []
        for product in products:
            pid_str = str(product.id)
            score = score_map.get(pid_str, 0.0)

            # Post-filter giá
            display_price = float(product.sale_price) if product.sale_price else (
                float(product.base_price) if product.base_price else 0
            )
            if constraints.price_min is not None and display_price > 0 and display_price < constraints.price_min:
                continue
            if constraints.price_max is not None and display_price > 0 and display_price > constraints.price_max:
                continue

            # Post-filter specs từ PostgreSQL JSONB (nguồn chính xác nhất)
            specs = product.specs or {}
            perf = specs.get("performance") or {}
            screen = specs.get("screen") or {}

            ram_gb = perf.get("ram_gb")
            storage_gb = perf.get("storage_gb")
            screen_size = screen.get("size_inch")

            if ram_gb is not None:
                if constraints.ram_min is not None and ram_gb < constraints.ram_min:
                    continue
                if constraints.ram_max is not None and ram_gb > constraints.ram_max:
                    continue

            if storage_gb is not None:
                if constraints.storage_min is not None and storage_gb < constraints.storage_min:
                    continue
                if constraints.storage_max is not None and storage_gb > constraints.storage_max:
                    continue

            if screen_size is not None:
                if constraints.screen_min is not None and screen_size < constraints.screen_min:
                    continue
                if constraints.screen_max is not None and screen_size > constraints.screen_max:
                    continue

            # Lấy ảnh chính
            primary_img = None
            if product.images:
                primary = next((img for img in product.images if img.is_primary), None)
                primary_img = primary.image_url if primary else product.images[0].image_url

            results.append(AIProductResult(
                id=product.id,
                name=product.name,
                slug=product.slug,
                category_name=product.category.name if product.category else None,
                category_slug=product.category.slug if product.category else None,
                brand_name=product.brand.name if product.brand else None,
                brand_slug=product.brand.slug if product.brand else None,
                base_price=float(product.base_price) if product.base_price else 0,
                sale_price=float(product.sale_price) if product.sale_price else None,
                primary_image=primary_img,
                rating_avg=float(product.rating_avg) if product.rating_avg else 0,
                sold_count=product.sold_count or 0,
                highlight_features=product.highlight_features or [],
                similarity_score=round(score, 4),
            ))

        results.sort(key=lambda x: x.similarity_score, reverse=True)
        results = results[:limit]

        elapsed = (time.time() - start_time) * 1000
        logger.info(f"[AI Search] Found {len(results)} results in {elapsed:.0f}ms")

        return AISearchData(
            products=results,
            total=len(results),
            query=query,
            search_time_ms=round(elapsed, 2),
        )

    # ────────────────────────────────────────────────────────
    # PUBLIC: Gợi ý tìm kiếm
    # ────────────────────────────────────────────────────────

    async def suggest(
        self,
        query: str,
        limit: int = 5,
    ) -> list[AISuggestItem]:
        """Gợi ý tìm kiếm dựa trên vector similarity."""
        query_vector = await self._embed_query(query)
        scored_points = self._search_qdrant(query_vector, qdrant_filter=None, limit=limit)

        suggestions = []
        seen_texts = set()
        for point in scored_points:
            payload = point.payload or {}
            name = payload.get("name", "")
            category_slug = payload.get("category_slug")
            if name and name not in seen_texts:
                seen_texts.add(name)
                suggestions.append(AISuggestItem(text=name, category_slug=category_slug))

        return suggestions

    # ────────────────────────────────────────────────────────
    # PRIVATE: Trích xuất TẤT CẢ constraints từ câu query
    # ────────────────────────────────────────────────────────

    @classmethod
    def _extract_all_constraints(cls, query: str) -> ExtractedConstraints:
        """Trích xuất giá + specs (RAM, storage, screen) từ câu query NL."""
        c = ExtractedConstraints()

        price_min, price_max = cls._extract_price_from_query(query)
        c.price_min = price_min
        c.price_max = price_max

        specs = cls._extract_specs_from_query(query)
        c.ram_min = specs.get("ram_min")
        c.ram_max = specs.get("ram_max")
        c.storage_min = specs.get("storage_min")
        c.storage_max = specs.get("storage_max")
        c.screen_min = specs.get("screen_min")
        c.screen_max = specs.get("screen_max")

        return c

    # ────────────────────────────────────────────────────────
    # PRIVATE: Trích xuất specs từ câu truy vấn tự nhiên
    # ────────────────────────────────────────────────────────

    @staticmethod
    def _extract_specs_from_query(query: str) -> Dict[str, Any]:
        """
        Trích xuất bộ lọc specs kỹ thuật từ câu query tiếng Việt.

        Hỗ trợ:
            - RAM:     "ram dưới 16gb", "ram 8gb", "ram từ 8 đến 16gb"
            - Storage: "bộ nhớ 256gb", "rom 512gb", "ssd 1tb"
            - Screen:  "màn hình 15 inch", "màn dưới 14 inch"
        """
        q = query.lower().strip()
        result = {}

        # ── RAM patterns ──
        # "ram dưới/under X gb"
        m = re.search(r"ram\s*(?:dưới|duoi|under|<|nhỏ hơn)\s*(\d+)\s*(?:gb|g)", q)
        if m:
            result["ram_max"] = int(m.group(1))
        else:
            # "ram trên/over X gb"
            m = re.search(r"ram\s*(?:trên|tren|over|>|hơn|lớn hơn|từ)\s*(\d+)\s*(?:gb|g)", q)
            if m:
                result["ram_min"] = int(m.group(1))
            else:
                # "ram từ X đến Y gb"
                m = re.search(r"ram\s*(?:từ\s*)?(\d+)\s*(?:gb|g)?\s*(?:đến|den|tới|-)\s*(\d+)\s*(?:gb|g)", q)
                if m:
                    result["ram_min"] = int(m.group(1))
                    result["ram_max"] = int(m.group(2))
                else:
                    # "ram X gb" (exact match → ±tolerance: ram 8gb = 8gb exactly)
                    m = re.search(r"ram\s*(\d+)\s*(?:gb|g)\b", q)
                    if m:
                        val = int(m.group(1))
                        result["ram_min"] = val
                        result["ram_max"] = val

        # ── Storage patterns ──
        storage_prefix = r"(?:bộ nhớ|bo nho|rom|ssd|ổ cứng|o cung|dung lượng|storage|lưu trữ)"

        def parse_storage(num_str: str, unit: str) -> int:
            val = int(num_str)
            if unit in ("tb", "t"):
                return val * 1024
            return val  # GB

        m = re.search(storage_prefix + r"\s*(?:dưới|duoi|under|<)\s*(\d+)\s*(gb|g|tb|t)\b", q)
        if m:
            result["storage_max"] = parse_storage(m.group(1), m.group(2))
        else:
            m = re.search(storage_prefix + r"\s*(?:trên|tren|over|>|hơn|từ)\s*(\d+)\s*(gb|g|tb|t)\b", q)
            if m:
                result["storage_min"] = parse_storage(m.group(1), m.group(2))
            else:
                m = re.search(storage_prefix + r"\s*(?:từ\s*)?(\d+)\s*(?:gb|g|tb|t)?\s*(?:đến|den|tới|-)\s*(\d+)\s*(gb|g|tb|t)", q)
                if m:
                    result["storage_min"] = parse_storage(m.group(1), m.group(3))
                    result["storage_max"] = parse_storage(m.group(2), m.group(3))
                else:
                    m = re.search(storage_prefix + r"\s*(\d+)\s*(gb|g|tb|t)\b", q)
                    if m:
                        val = parse_storage(m.group(1), m.group(2))
                        result["storage_min"] = val
                        result["storage_max"] = val

        # ── Screen size patterns ──
        screen_prefix = r"(?:màn hình|man hinh|màn|man|screen|display)"

        m = re.search(screen_prefix + r"\s*(?:dưới|duoi|under|<|nhỏ hơn)\s*([\d.]+)\s*(?:inch|\")", q)
        if m:
            result["screen_max"] = float(m.group(1))
        else:
            m = re.search(screen_prefix + r"\s*(?:trên|tren|over|>|hơn|lớn hơn|từ)\s*([\d.]+)\s*(?:inch|\")", q)
            if m:
                result["screen_min"] = float(m.group(1))
            else:
                m = re.search(screen_prefix + r"\s*(?:từ\s*)?([\d.]+)\s*(?:inch|\")?\s*(?:đến|den|tới|-)\s*([\d.]+)\s*(?:inch|\")", q)
                if m:
                    result["screen_min"] = float(m.group(1))
                    result["screen_max"] = float(m.group(2))
                else:
                    m = re.search(screen_prefix + r"\s*([\d.]+)\s*(?:inch|\")", q)
                    if m:
                        val = float(m.group(1))
                        result["screen_min"] = val - 0.5
                        result["screen_max"] = val + 0.5

        # ── Fallback: "dưới Xgb" (without prefix) ──
        if "ram_max" not in result and "ram_min" not in result:
            m = re.search(r"(?:dưới|duoi|under|<)\s*(\d+)\s*(?:gb|g)\s*(?:ram)", q)
            if m:
                result["ram_max"] = int(m.group(1))

        return result

    # ────────────────────────────────────────────────────────
    # PRIVATE: Trích xuất giá từ câu truy vấn tự nhiên
    # ────────────────────────────────────────────────────────

    @staticmethod
    def _extract_price_from_query(query: str) -> Tuple[Optional[float], Optional[float]]:
        """Trích xuất khoảng giá từ câu query tiếng Việt."""
        q = query.lower().strip()

        def parse_price(num_str: str, unit: str) -> float:
            num = float(num_str.replace(",", "."))
            unit = unit.lower().strip()
            if unit in ("triệu", "trieu", "tr"):
                return num * 1_000_000
            elif unit in ("nghìn", "nghin", "k"):
                return num * 1_000
            elif unit in ("tỷ", "ty"):
                return num * 1_000_000_000
            return num if num > 10000 else num * 1_000_000

        # "từ X đến Y triệu"
        m = re.search(r"từ\s+([\d,.]+)\s*(?:triệu|trieu|tr|nghìn|nghin|k)?\s*(?:đến|den|tới|toi|-)\s*([\d,.]+)\s*(triệu|trieu|tr|nghìn|nghin|k)", q)
        if m:
            return (parse_price(m.group(1), m.group(3)), parse_price(m.group(2), m.group(3)))

        # "dưới X triệu"
        m = re.search(r"(?:dưới|duoi|under|không quá|khong qua|rẻ hơn|re hon|<)\s*([\d,.]+)\s*(triệu|trieu|tr|nghìn|nghin|k)", q)
        if m:
            return (None, parse_price(m.group(1), m.group(2)))

        # "trên X triệu"
        m = re.search(r"(?:trên|tren|over|hơn|hon|>)\s*([\d,.]+)\s*(triệu|trieu|tr|nghìn|nghin|k)", q)
        if m:
            return (parse_price(m.group(1), m.group(2)), None)

        # "tầm/khoảng X triệu" → ±30%
        m = re.search(r"(?:tầm|tam|khoảng|khoang|cỡ|co|chừng|around|~)\s*([\d,.]+)\s*(triệu|trieu|tr|nghìn|nghin|k)", q)
        if m:
            target = parse_price(m.group(1), m.group(2))
            return (target * 0.7, target * 1.3)

        return (None, None)

    # ────────────────────────────────────────────────────────
    # PRIVATE: Tạo embedding cho query
    # ────────────────────────────────────────────────────────

    async def _embed_query(self, text: str) -> list[float]:
        try:
            result = genai.embed_content(model=EMBEDDING_MODEL, content=text)
            return result["embedding"]
        except Exception as e:
            logger.error(f"[AI Search] Gemini embedding failed: {e}")
            raise ValueError(f"Không thể tạo embedding cho query: {e}")

    # ────────────────────────────────────────────────────────
    # PRIVATE: Tìm kiếm trên Qdrant
    # ────────────────────────────────────────────────────────

    def _search_qdrant(self, query_vector: list[float], qdrant_filter: Optional[Filter], limit: int):
        try:
            response = qdrant_client.query_points(
                collection_name=COLLECTION_NAME,
                query=query_vector,
                query_filter=qdrant_filter,
                limit=limit,
                with_payload=True,
                score_threshold=0.3,
            )
            return response.points
        except Exception as e:
            logger.error(f"[AI Search] Qdrant search failed: {e}")
            raise ValueError(f"Lỗi tìm kiếm Qdrant: {e}")

    # ────────────────────────────────────────────────────────
    # PRIVATE: Build Qdrant filter
    # ────────────────────────────────────────────────────────

    @staticmethod
    def _build_qdrant_filters(filters: Optional[AISearchFilters]) -> Optional[Filter]:
        if not filters:
            return None

        conditions = []
        conditions.append(FieldCondition(key="is_active", match=MatchValue(value=True)))

        if filters.category_slug:
            conditions.append(FieldCondition(key="category_slug", match=MatchValue(value=filters.category_slug)))

        if filters.brand_slug:
            conditions.append(FieldCondition(key="brand_slug", match=MatchValue(value=filters.brand_slug)))

        # Price filter
        if filters.price_min is not None or filters.price_max is not None:
            pr = {}
            if filters.price_min is not None: pr["gte"] = filters.price_min
            if filters.price_max is not None: pr["lte"] = filters.price_max
            conditions.append(FieldCondition(key="base_price", range=Range(**pr)))

        # RAM filter (Qdrant payload: ram_gb)
        if filters.ram_min is not None or filters.ram_max is not None:
            rr = {}
            if filters.ram_min is not None: rr["gte"] = filters.ram_min
            if filters.ram_max is not None: rr["lte"] = filters.ram_max
            conditions.append(FieldCondition(key="ram_gb", range=Range(**rr)))

        # Storage filter (Qdrant payload: storage_gb)
        if filters.storage_min is not None or filters.storage_max is not None:
            sr = {}
            if filters.storage_min is not None: sr["gte"] = filters.storage_min
            if filters.storage_max is not None: sr["lte"] = filters.storage_max
            conditions.append(FieldCondition(key="storage_gb", range=Range(**sr)))

        # Screen size filter (Qdrant payload: screen_size)
        if filters.screen_min is not None or filters.screen_max is not None:
            scr = {}
            if filters.screen_min is not None: scr["gte"] = filters.screen_min
            if filters.screen_max is not None: scr["lte"] = filters.screen_max
            conditions.append(FieldCondition(key="screen_size", range=Range(**scr)))

        if not conditions:
            return None

        return Filter(must=conditions)

    # ────────────────────────────────────────────────────────
    # PRIVATE: Hydrate từ PostgreSQL
    # ────────────────────────────────────────────────────────

    @staticmethod
    async def _hydrate_products(product_ids: list[UUID], db: AsyncSession) -> list[Product]:
        if not product_ids:
            return []

        result = await db.execute(
            select(Product)
            .where(Product.id.in_(product_ids))
            .options(
                selectinload(Product.category),
                selectinload(Product.brand),
                selectinload(Product.images),
            )
        )
        products = result.scalars().all()
        id_order = {pid: idx for idx, pid in enumerate(product_ids)}
        return sorted(products, key=lambda p: id_order.get(p.id, 999))


# Singleton instance
ai_search_service = AISearchService()
