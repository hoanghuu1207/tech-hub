"""
AISearchService — Xử lý logic tìm kiếm ngữ nghĩa cho TechShop.

Pipeline:
    1. Nhận câu truy vấn ngôn ngữ tự nhiên từ Client
    2. Dùng Gemini LLM phân tích ý định → structured filters + refined keywords
    3. Gọi Gemini Embedding để chuyển refined keywords thành vector (3072 dims)
    4. Tìm kiếm Qdrant Cloud bằng cosine similarity + payload filters
    5. Post-filter bằng dữ liệu thực từ PostgreSQL JSONB
    6. Trả về danh sách sản phẩm kèm similarity score
"""

import json
import re
import time
import logging
from typing import Optional, Tuple, Dict, Any
from uuid import UUID
from dataclasses import dataclass

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
logger.setLevel(logging.INFO)
# Đảm bảo log được in ra console nếu chưa có handler
if not logger.handlers:
    ch = logging.StreamHandler()
    ch.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    ch.setFormatter(formatter)
    logger.addHandler(ch)

COLLECTION_NAME = "products"
EMBEDDING_MODEL = "models/gemini-embedding-2"
EMBEDDING_DIM = 3072

# ── Prompt hệ thống cho Gemini Intent Parser ──
INTENT_PARSER_PROMPT = """Bạn là bộ phân tích ý định tìm kiếm sản phẩm công nghệ cho cửa hàng TechShop.
Cửa hàng bán: smartphone, laptop, tablet, tai nghe (headphone), đồng hồ thông minh (smartwatch), phụ kiện (accessory).

Nhiệm vụ: Phân tích câu truy vấn của người dùng và trả về JSON duy nhất.

=== QUY TẮC GIÁ ===
- "củ", "triệu", "tr" = 1.000.000 VNĐ
- "k", "nghìn" = 1.000 VNĐ
- "đổ lại", "trở xuống", "dưới", "không quá" → price_max
- "đổ lên", "trở lên", "trên" → price_min  
- "tầm", "khoảng", "around" → ±30%

=== QUY TẮC CATEGORY ===
category_slug phải là 1 trong: smartphone, laptop, tablet, headphone, smartwatch, accessory
- "đồng hồ", "smartwatch", "vòng đeo tay", "watch" → smartwatch
- "tai nghe", "headphone", "earphone", "earbud" → headphone
- "điện thoại", "smartphone", "dt", "phone" → smartphone
- "máy tính bảng", "ipad", "tablet" → tablet
- "laptop", "máy tính xách tay", "notebook" → laptop
- "phụ kiện", "ốp lưng", "sạc", "cáp" → accessory

=== QUY TẮC BRAND ===
brand_slugs là MẢNG thương hiệu, viết thường không dấu.
Nếu user nói "hoặc"/"hay"/"và" nhiều brand → liệt kê hết: ["huawei", "xiaomi"]
Nếu chỉ 1 brand → ["apple"]. Không xác định → [].

=== QUY TẮC SEARCH_TEXT (RẤT QUAN TRỌNG) ===
search_text là câu TÌM KIẾM NGỮ NGHĨA, sẽ được dùng để so sánh vector similarity với dữ liệu sản phẩm.
- BỎ: giá cả, số tiền, tên brand, specs kỹ thuật (ram, gb, inch...)
- GIỮ LẠI BẮT BUỘC:
  + Đối tượng sử dụng: "trẻ em", "nam", "nữ", "sinh viên", "game thủ", "văn phòng"
  + Mục đích sử dụng: "chơi game", "học tập", "chạy bộ", "bơi lội", "nghe nhạc"
  + Đặc tính sản phẩm: "chống nước", "chống ồn", "mỏng nhẹ", "pin trâu", "chụp ảnh đẹp"
  + Loại sản phẩm cụ thể: "định vị trẻ em", "gaming", "ultrabook", "true wireless"

Trả về JSON thuần túy (KHÔNG markdown, KHÔNG ```):
{"search_text": "...", "category_slug": null, "brand_slugs": [], "price_min": null, "price_max": null, "ram_min": null, "ram_max": null, "storage_min": null, "storage_max": null, "screen_min": null, "screen_max": null}

Ví dụ:
- "đồng hồ huawei hoặc xiaomi dành cho trẻ em dưới 2 triệu" → {"search_text": "đồng hồ định vị trẻ em", "category_slug": "smartwatch", "brand_slugs": ["huawei", "xiaomi"], "price_max": 2000000, "ram_min": null, "ram_max": null, "storage_min": null, "storage_max": null, "screen_min": null, "screen_max": null}
- "tai nghe chống ồn sony tầm 3 củ" → {"search_text": "tai nghe chống ồn", "category_slug": "headphone", "brand_slugs": ["sony"], "price_min": 2100000, "price_max": 3900000, "ram_min": null, "ram_max": null, "storage_min": null, "storage_max": null, "screen_min": null, "screen_max": null}
- "laptop chơi game cho sinh viên dell hoặc hp ram 16gb" → {"search_text": "laptop chơi game sinh viên", "category_slug": "laptop", "brand_slugs": ["dell", "hp"], "price_min": null, "price_max": null, "ram_min": 16, "ram_max": 16, "storage_min": null, "storage_max": null, "screen_min": null, "screen_max": null}
- "điện thoại chụp ảnh đẹp pin trâu dưới 5tr" → {"search_text": "điện thoại chụp ảnh đẹp pin trâu", "category_slug": "smartphone", "brand_slugs": [], "price_min": null, "price_max": 5000000, "ram_min": null, "ram_max": null, "storage_min": null, "storage_max": null, "screen_min": null, "screen_max": null}
- "ip 15 pro max" → {"search_text": "iPhone 15 Pro Max", "category_slug": "smartphone", "brand_slugs": ["apple"], "price_min": null, "price_max": null, "ram_min": null, "ram_max": null, "storage_min": null, "storage_max": null, "screen_min": null, "screen_max": null}
- "smartwatch nữ nhỏ gọn dưới 5 triệu" → {"search_text": "đồng hồ thông minh nữ nhỏ gọn", "category_slug": "smartwatch", "brand_slugs": [], "price_min": null, "price_max": 5000000, "ram_min": null, "ram_max": null, "storage_min": null, "storage_max": null, "screen_min": null, "screen_max": null}
"""


@dataclass
class ParsedIntent:
    """Kết quả phân tích ý định từ Gemini LLM."""
    search_text: str  # Từ khóa refined cho embedding
    category_slug: Optional[str] = None
    brand_slugs: Optional[list[str]] = None  # Hỗ trợ nhiều brand (OR)
    price_min: Optional[float] = None
    price_max: Optional[float] = None
    ram_min: Optional[int] = None
    ram_max: Optional[int] = None
    storage_min: Optional[int] = None
    storage_max: Optional[int] = None
    screen_min: Optional[float] = None
    screen_max: Optional[float] = None

    @property
    def has_filters(self) -> bool:
        return any([
            self.category_slug,
            self.brand_slugs,
            self.price_min is not None, self.price_max is not None,
            self.ram_min is not None, self.ram_max is not None,
            self.storage_min is not None, self.storage_max is not None,
            self.screen_min is not None, self.screen_max is not None,
        ])


class AISearchService:
    """
    Service class quản lý toàn bộ luồng tìm kiếm ngữ nghĩa.
    Dùng Gemini LLM phân tích ý định + Gemini Embedding + Qdrant + PostgreSQL.
    """

    def __init__(self):
        genai.configure(api_key=settings.GEMINI_API_KEY)
        self._llm_model = genai.GenerativeModel("gemini-2.5-flash-lite")

    # ────────────────────────────────────────────────────────
    # PUBLIC: Tìm kiếm ngữ nghĩa
    # ────────────────────────────────────────────────────────

    async def search(
        self,
        query: str,
        db: AsyncSession,
        filters: Optional[AISearchFilters] = None,
        limit: int = 10,
        user_profile: Optional[str] = None,
    ) -> AISearchData:
        start_time = time.time()

        # ── Bước 1: Dùng Gemini LLM phân tích ý định ──
        intent = await self._parse_intent(query)
        logger.info(f"[AI Search] Query: '{query}' → Intent: search='{intent.search_text}', "
                     f"cat={intent.category_slug}, brands={intent.brand_slugs}, "
                     f"price=[{intent.price_min}, {intent.price_max}], "
                     f"ram=[{intent.ram_min}, {intent.ram_max}]")

        # ── Bước 2: Merge intent vào filters ──
        if filters is None:
            filters = AISearchFilters()
        self._merge_intent_to_filters(intent, filters)

        # ── Bước 3: Chuyển refined keywords thành vector ──
        query_vector = await self._embed_query(intent.search_text)

        # ── Bước 4: Tìm kiếm trên Qdrant ──
        # Brand KHÔNG được dùng làm hard filter (để giữ kết quả ngữ nghĩa tốt nhất)
        # Brand sẽ được xử lý bằng boost scoring ở bước post-processing
        saved_brand_slugs = filters.brand_slugs
        filters.brand_slugs = None  # Tạm bỏ brand khỏi Qdrant filter
        
        # Tăng mạnh limit vì brand/specs sẽ được filter cứng ở post-processing
        search_limit = limit * 20 if intent.has_filters else limit
        qdrant_filter = self._build_qdrant_filters(filters)
        scored_points = self._search_qdrant(query_vector, qdrant_filter, search_limit)

        # Restore brand slugs cho post-processing
        filters.brand_slugs = saved_brand_slugs

        if not scored_points:
            elapsed = (time.time() - start_time) * 1000
            return AISearchData(products=[], total=0, query=query, search_time_ms=round(elapsed, 2))

        # ── Bước 5: Hydrate từ PostgreSQL ──
        score_map = {}
        product_ids = []
        for point in scored_points:
            pid = point.payload.get("product_id")
            if pid:
                product_ids.append(UUID(pid))
                score_map[pid] = point.score

        products = await self._hydrate_products(product_ids, db)

        # ── Bước 6: Post-filter + Brand boost scoring ──
        BRAND_BOOST = 0.15  # Boost cho sản phẩm khớp brand yêu cầu
        
        results = []
        for product in products:
            pid_str = str(product.id)
            raw_score = score_map.get(pid_str, 0.0)

            # Post-filter giá
            display_price = float(product.sale_price) if product.sale_price else (
                float(product.base_price) if product.base_price else 0
            )
            if intent.price_min is not None and display_price > 0 and display_price < intent.price_min:
                continue
            if intent.price_max is not None and display_price > 0 and display_price > intent.price_max:
                continue

            # Post-filter specs từ PostgreSQL JSONB
            specs = product.specs or {}
            perf = specs.get("performance") or {}
            screen = specs.get("screen") or {}

            ram_gb = perf.get("ram_gb")
            storage_gb = perf.get("storage_gb")
            screen_size = screen.get("size_inch")

            if ram_gb is not None:
                if intent.ram_min is not None and ram_gb < intent.ram_min:
                    continue
                if intent.ram_max is not None and ram_gb > intent.ram_max:
                    continue
            if storage_gb is not None:
                if intent.storage_min is not None and storage_gb < intent.storage_min:
                    continue
                if intent.storage_max is not None and storage_gb > intent.storage_max:
                    continue
            if screen_size is not None:
                if intent.screen_min is not None and screen_size < intent.screen_min:
                    continue
                if intent.screen_max is not None and screen_size > intent.screen_max:
                    continue

            # Post-filter Brand (Hard filter với substring matching để xử lý 'dien-thoai-samsung' vs 'samsung')
            if saved_brand_slugs:
                if not product.brand:
                    continue
                brand_match = any(
                    bs in product.brand.slug or product.brand.slug in bs 
                    for bs in saved_brand_slugs
                )
                if not brand_match:
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
                similarity_score=round(raw_score, 4),
            ))

        # Sắp xếp theo score (semantic similarity)
        results.sort(key=lambda x: x.similarity_score, reverse=True)

        # ── Profile Boost: ưu tiên sản phẩm khớp sở thích cá nhân ──
        # Thứ tự ưu tiên: Brand(0.15) > Category(0.10) > Price(0.06) > Purchase(0.04) > Features(0.03)
        if user_profile:
            import re as _re
            profile_lower = user_profile.lower()

            # Parse structured preferences
            known_brands = [
                "apple", "samsung", "xiaomi", "huawei", "oppo", "vivo",
                "realme", "sony", "jbl", "marshall", "bose", "garmin",
                "dell", "hp", "asus", "acer", "lenovo", "msi",
                "amazfit", "honor",
            ]
            pref_brands = [b for b in known_brands if b in profile_lower]

            category_map = {
                "smartphone": ["smartphone", "điện thoại", "phone"],
                "laptop": ["laptop", "máy tính xách tay"],
                "tablet": ["tablet", "máy tính bảng", "ipad"],
                "headphone": ["tai nghe", "headphone", "earphone", "earbud"],
                "smartwatch": ["đồng hồ thông minh", "smartwatch", "đồng hồ"],
                "accessory": ["phụ kiện", "accessory"],
            }
            pref_categories = []
            for cat_key, aliases in category_map.items():
                if any(alias in profile_lower for alias in aliases):
                    pref_categories.append(cat_key)

            # Price range
            pref_price_min, pref_price_max = None, None
            if any(kw in profile_lower for kw in ["giá rẻ", "bình dân", "budget"]):
                pref_price_max = 5_000_000
            elif any(kw in profile_lower for kw in ["tầm trung", "mid-range"]):
                pref_price_min, pref_price_max = 5_000_000, 20_000_000
            elif any(kw in profile_lower for kw in ["cao cấp", "premium", "flagship"]):
                pref_price_min = 20_000_000

            pm = _re.search(r"dưới\s+([\d,.]+)\s*(?:triệu|tr|củ)", profile_lower)
            if pm:
                pref_price_max = float(pm.group(1).replace(",", ".")) * 1_000_000
            pm = _re.search(r"trên\s+([\d,.]+)\s*(?:triệu|tr|củ)", profile_lower)
            if pm:
                pref_price_min = float(pm.group(1).replace(",", ".")) * 1_000_000
            rm = _re.search(r"(\d+)\s*[-–]\s*(\d+)\s*(?:triệu|tr)", profile_lower)
            if rm:
                pref_price_min = float(rm.group(1)) * 1_000_000
                pref_price_max = float(rm.group(2)) * 1_000_000

            # Features
            feature_keywords = [
                "chống ồn", "pin trâu", "gaming", "mỏng nhẹ", "chụp ảnh",
                "chống nước", "true wireless", "5g", "sạc nhanh",
                "định vị", "trẻ em", "thể thao", "văn phòng",
            ]
            pref_features = [kw for kw in feature_keywords if kw in profile_lower]

            for r in results:
                boost = 0.0

                # ① Brand — cao nhất
                if r.brand_name and r.brand_name.lower() in pref_brands:
                    boost += 0.15

                # ② Category
                if r.category_slug and r.category_slug.lower() in pref_categories:
                    boost += 0.10

                # ③ Price range
                if pref_price_min is not None or pref_price_max is not None:
                    dp = r.sale_price if r.sale_price else r.base_price
                    if dp and dp > 0:
                        in_range = True
                        if pref_price_min is not None and dp < pref_price_min:
                            in_range = False
                        if pref_price_max is not None and dp > pref_price_max:
                            in_range = False
                        if in_range:
                            boost += 0.06

                # ④ Features
                if pref_features and r.highlight_features:
                    combined = " ".join(r.highlight_features).lower()
                    if any(kw in combined for kw in pref_features):
                        boost += 0.03

                r.similarity_score = round(r.similarity_score + boost, 4)

            results.sort(key=lambda x: x.similarity_score, reverse=True)

        results = results[:limit]

        elapsed = (time.time() - start_time) * 1000
        logger.info(f"[AI Search] Found {len(results)} results in {elapsed:.0f}ms")

        return AISearchData(
            products=results, total=len(results), query=query, search_time_ms=round(elapsed, 2)
        )

    # ────────────────────────────────────────────────────────
    # PUBLIC: Gợi ý tìm kiếm
    # ────────────────────────────────────────────────────────

    async def suggest(self, query: str, limit: int = 5) -> list[AISuggestItem]:
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
    # PRIVATE: Gemini LLM Intent Parser
    # ────────────────────────────────────────────────────────

    async def _parse_intent(self, query: str) -> ParsedIntent:
        """
        Dùng Gemini LLM để phân tích câu query ngôn ngữ tự nhiên
        thành structured filters. Xử lý được tiếng lóng, viết tắt,
        ngôn ngữ nói ("3 củ đổ lại", "ip 15", "laptop ngon bổ rẻ").

        Nếu key chính bị limit, tự động thử backup key.
        Fallback về regex nếu cả 2 key đều thất bại.
        """
        # Thử gọi LLM, nếu thất bại thử backup key
        keys_to_try = [settings.GEMINI_API_KEY]
        if settings.GEMINI_BACKUP_API_KEY:
            keys_to_try.append(settings.GEMINI_BACKUP_API_KEY)

        last_error = None
        for api_key in keys_to_try:
            try:
                genai.configure(api_key=api_key)
                response = self._llm_model.generate_content(
                    [INTENT_PARSER_PROMPT, f"Câu truy vấn: \"{query}\""],
                    generation_config=genai.GenerationConfig(
                        temperature=0.1,
                        max_output_tokens=300,
                    ),
                )

                raw_text = response.text.strip()
                # Loại bỏ markdown code block
                raw_text = re.sub(r"^```(?:json)?\s*", "", raw_text)
                raw_text = re.sub(r"\s*```$", "", raw_text)

                # Trích xuất JSON object từ response (robust parsing)
                json_match = re.search(r"\{[^{}]*\}", raw_text, re.DOTALL)
                if json_match:
                    raw_text = json_match.group(0)

                data = json.loads(raw_text)
                formatted_json = json.dumps(data, indent=2, ensure_ascii=False)
                logger.info("\n" + "="*60 +
                            f"\n🤖 [AI Search] GEMINI 2.5 FLASH-LITE PARSED INTENT:\n{formatted_json}\n" +
                            "="*60)

                # Restore key chính cho embedding
                genai.configure(api_key=settings.GEMINI_API_KEY)

                # Xử lý brand_slugs — hỗ trợ cả cũ (brand_slug) lẫn mới (brand_slugs)
                brand_slugs = data.get("brand_slugs") or []
                if not brand_slugs and data.get("brand_slug"):
                    brand_slugs = [data["brand_slug"]]

                return ParsedIntent(
                    search_text=data.get("search_text") or query,
                    category_slug=data.get("category_slug"),
                    brand_slugs=brand_slugs or None,
                    price_min=data.get("price_min"),
                    price_max=data.get("price_max"),
                    ram_min=data.get("ram_min"),
                    ram_max=data.get("ram_max"),
                    storage_min=data.get("storage_min"),
                    storage_max=data.get("storage_max"),
                    screen_min=data.get("screen_min"),
                    screen_max=data.get("screen_max"),
                )

            except Exception as e:
                last_error = e
                logger.warning(f"[AI Search] LLM failed with key ...{api_key[-6:]}: {e}")
                continue

        # Restore key chính
        genai.configure(api_key=settings.GEMINI_API_KEY)
        logger.warning(f"[AI Search] All LLM keys failed. Falling back to regex.")
        return self._parse_intent_regex_fallback(query)

    def _parse_intent_regex_fallback(self, query: str) -> ParsedIntent:
        """Regex fallback khi Gemini LLM không khả dụng."""
        price_min, price_max = self._extract_price_regex(query)
        specs = self._extract_specs_regex(query)
        return ParsedIntent(
            search_text=query,
            price_min=price_min,
            price_max=price_max,
            ram_min=specs.get("ram_min"),
            ram_max=specs.get("ram_max"),
            storage_min=specs.get("storage_min"),
            storage_max=specs.get("storage_max"),
            screen_min=specs.get("screen_min"),
            screen_max=specs.get("screen_max"),
        )

    # ────────────────────────────────────────────────────────
    # PRIVATE: Merge intent → filters
    # ────────────────────────────────────────────────────────

    @staticmethod
    def _merge_intent_to_filters(intent: ParsedIntent, filters: AISearchFilters):
        """Merge LLM intent vào filters (chỉ khi client chưa truyền)."""
        if filters.category_slug is None and intent.category_slug:
            filters.category_slug = intent.category_slug
        if filters.brand_slugs is None and intent.brand_slugs:
            filters.brand_slugs = intent.brand_slugs
        if filters.price_min is None and intent.price_min is not None:
            filters.price_min = intent.price_min
        if filters.price_max is None and intent.price_max is not None:
            filters.price_max = intent.price_max
        if filters.ram_min is None and intent.ram_min is not None:
            filters.ram_min = intent.ram_min
        if filters.ram_max is None and intent.ram_max is not None:
            filters.ram_max = intent.ram_max
        if filters.storage_min is None and intent.storage_min is not None:
            filters.storage_min = intent.storage_min
        if filters.storage_max is None and intent.storage_max is not None:
            filters.storage_max = intent.storage_max
        if filters.screen_min is None and intent.screen_min is not None:
            filters.screen_min = intent.screen_min
        if filters.screen_max is None and intent.screen_max is not None:
            filters.screen_max = intent.screen_max

    # ────────────────────────────────────────────────────────
    # PRIVATE: Embedding + Qdrant search
    # ────────────────────────────────────────────────────────

    async def _embed_query(self, text: str) -> list[float]:
        try:
            result = genai.embed_content(model=EMBEDDING_MODEL, content=text)
            return result["embedding"]
        except Exception as e:
            logger.error(f"[AI Search] Gemini embedding failed: {e}")
            raise ValueError(f"Không thể tạo embedding cho query: {e}")

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
        if filters.brand_slugs:
            if len(filters.brand_slugs) == 1:
                conditions.append(FieldCondition(key="brand_slug", match=MatchValue(value=filters.brand_slugs[0])))
            else:
                from qdrant_client.models import MatchAny
                conditions.append(FieldCondition(key="brand_slug", match=MatchAny(any=filters.brand_slugs)))

        # Price
        if filters.price_min is not None or filters.price_max is not None:
            pr = {}
            if filters.price_min is not None: pr["gte"] = filters.price_min
            if filters.price_max is not None: pr["lte"] = filters.price_max
            conditions.append(FieldCondition(key="base_price", range=Range(**pr)))

        # RAM
        if filters.ram_min is not None or filters.ram_max is not None:
            rr = {}
            if filters.ram_min is not None: rr["gte"] = filters.ram_min
            if filters.ram_max is not None: rr["lte"] = filters.ram_max
            conditions.append(FieldCondition(key="ram_gb", range=Range(**rr)))

        # Storage
        if filters.storage_min is not None or filters.storage_max is not None:
            sr = {}
            if filters.storage_min is not None: sr["gte"] = filters.storage_min
            if filters.storage_max is not None: sr["lte"] = filters.storage_max
            conditions.append(FieldCondition(key="storage_gb", range=Range(**sr)))

        # Screen
        if filters.screen_min is not None or filters.screen_max is not None:
            scr = {}
            if filters.screen_min is not None: scr["gte"] = filters.screen_min
            if filters.screen_max is not None: scr["lte"] = filters.screen_max
            conditions.append(FieldCondition(key="screen_size", range=Range(**scr)))

        return Filter(must=conditions) if conditions else None

    # ────────────────────────────────────────────────────────
    # PRIVATE: Hydrate từ PostgreSQL
    # ────────────────────────────────────────────────────────

    @staticmethod
    async def _hydrate_products(product_ids: list[UUID], db: AsyncSession) -> list[Product]:
        if not product_ids:
            return []
        result = await db.execute(
            select(Product).where(Product.id.in_(product_ids))
            .options(selectinload(Product.category), selectinload(Product.brand), selectinload(Product.images))
        )
        products = result.scalars().all()
        id_order = {pid: idx for idx, pid in enumerate(product_ids)}
        return sorted(products, key=lambda p: id_order.get(p.id, 999))

    # ────────────────────────────────────────────────────────
    # REGEX FALLBACK (khi LLM không khả dụng)
    # ────────────────────────────────────────────────────────

    @staticmethod
    def _extract_price_regex(query: str) -> Tuple[Optional[float], Optional[float]]:
        q = query.lower().strip()
        # Non-capturing for optional middle position
        PRICE_UNITS_NC = r"(?:triệu|trieu|tr|củ|cu|nghìn|nghin|k)"
        # Capturing for positions where we need the unit value
        PRICE_UNITS_C = r"(triệu|trieu|tr|củ|cu|nghìn|nghin|k)"

        def parse_price(num_str: str, unit: str) -> float:
            num = float(num_str.replace(",", "."))
            if unit in ("triệu", "trieu", "tr", "củ", "cu"):
                return num * 1_000_000
            elif unit in ("nghìn", "nghin", "k"):
                return num * 1_000
            return num if num > 10000 else num * 1_000_000

        # "từ X đến Y triệu"
        m = re.search(r"từ\s+([\d,.]+)\s*" + PRICE_UNITS_NC + r"?\s*(?:đến|den|tới|-)\s*([\d,.]+)\s*" + PRICE_UNITS_C, q)
        if m:
            return (parse_price(m.group(1), m.group(3)), parse_price(m.group(2), m.group(3)))

        # "X củ/triệu đổ lại/trở xuống" (số đứng TRƯỚC từ chỉ giới hạn)
        m = re.search(r"([\d,.]+)\s*" + PRICE_UNITS_C + r"\s*(?:đổ lại|do lai|trở xuống|tro xuong)", q)
        if m:
            return (None, parse_price(m.group(1), m.group(2)))

        # "dưới X triệu"
        m = re.search(r"(?:dưới|duoi|under|<)\s*([\d,.]+)\s*" + PRICE_UNITS_C, q)
        if m:
            return (None, parse_price(m.group(1), m.group(2)))

        # "tầm giá X củ đổ lại"
        m = re.search(r"(?:tầm giá|tam gia|giá|gia)\s*([\d,.]+)\s*" + PRICE_UNITS_C + r"\s*(?:đổ lại|do lai|trở xuống|tro xuong)", q)
        if m:
            return (None, parse_price(m.group(1), m.group(2)))

        # "trên X triệu"
        m = re.search(r"(?:trên|tren|over|>)\s*([\d,.]+)\s*" + PRICE_UNITS_C, q)
        if m:
            return (parse_price(m.group(1), m.group(2)), None)

        # "X củ đổ lên"
        m = re.search(r"([\d,.]+)\s*" + PRICE_UNITS_C + r"\s*(?:đổ lên|do len|trở lên|tro len)", q)
        if m:
            return (parse_price(m.group(1), m.group(2)), None)

        # "tầm/khoảng X triệu" → ±30%
        m = re.search(r"(?:tầm|tam|khoảng|khoang|cỡ|co|~)\s*([\d,.]+)\s*" + PRICE_UNITS_C, q)
        if m:
            t = parse_price(m.group(1), m.group(2))
            return (t * 0.7, t * 1.3)

        return (None, None)

    @staticmethod
    def _extract_specs_regex(query: str) -> Dict[str, Any]:
        q = query.lower().strip()
        result = {}

        m = re.search(r"ram\s*(?:dưới|duoi|<)\s*(\d+)\s*(?:gb|g)", q)
        if m:
            result["ram_max"] = int(m.group(1))
        else:
            m = re.search(r"ram\s*(?:trên|tren|>|từ)\s*(\d+)\s*(?:gb|g)", q)
            if m:
                result["ram_min"] = int(m.group(1))
            else:
                m = re.search(r"ram\s*(\d+)\s*(?:gb|g)\b", q)
                if m:
                    v = int(m.group(1))
                    result["ram_min"] = v
                    result["ram_max"] = v

        return result


# Singleton instance
ai_search_service = AISearchService()
