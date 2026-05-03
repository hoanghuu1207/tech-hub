"""
ProductIndexer — Quản lý vector data trong Qdrant Cloud.

Cung cấp các methods:
  - index_product(product_data)    : Upsert 1 product vào Qdrant
  - build_embed_text(product)      : Tạo text để generate embedding
  - extract_flat_specs(product)    : Trích xuất specs phẳng cho payload filter
  - delete_product(product_id)     : Xoá 1 product khỏi Qdrant
  - reindex_all(products)          : Upsert hàng loạt
"""

import uuid
import logging
from typing import Optional

import google.generativeai as genai
from qdrant_client.models import PointStruct, FilterSelector, Filter, FieldCondition, MatchValue

from app.db.qdrant import qdrant_client
from app.core.config import settings

logger = logging.getLogger(__name__)

COLLECTION_NAME = "products"
EMBEDDING_MODEL = "models/gemini-embedding-2"
EMBEDDING_DIM = 3072


class ProductIndexer:
    """
    Lớp quản lý việc đồng bộ dữ liệu sản phẩm từ PostgreSQL lên Qdrant Cloud.
    Mỗi product = 1 vector point trong Qdrant.
    """

    def __init__(self):
        # Cấu hình Gemini API
        self.current_key_is_primary = True
        genai.configure(api_key=settings.GEMINI_API_KEY)

    def switch_api_key(self) -> bool:
        """Chuyển đổi sang backup API key nếu có. Trả về True nếu thành công."""
        if not settings.GEMINI_BACKUP_API_KEY:
            return False
            
        if self.current_key_is_primary:
            logger.info("🔄 Đang cấu hình Gemini sang GEMINI_BACKUP_API_KEY...")
            genai.configure(api_key=settings.GEMINI_BACKUP_API_KEY)
            self.current_key_is_primary = False
            return True
        else:
            logger.info("🔄 Đang cấu hình Gemini về GEMINI_API_KEY chính...")
            genai.configure(api_key=settings.GEMINI_API_KEY)
            self.current_key_is_primary = True
            return True

    # ────────────────────────────────────────────────────────
    # PUBLIC METHODS
    # ────────────────────────────────────────────────────────

    async def index_product(self, product_data: dict) -> str:
        """
        Upsert 1 product vào Qdrant.

        Args:
            product_data: Dict chứa thông tin product (bao gồm cả specs, category, brand...).

        Returns:
            qdrant_vector_id (str) — ID point trong Qdrant, cần lưu lại vào PostgreSQL.
        """
        # 1. Build text dùng để tạo embedding
        embed_text = self.build_embed_text(product_data)

        # 2. Gọi OpenAI để tạo embedding vector
        vector = await self._create_embedding(embed_text)

        # 3. Trích xuất payload flat cho filter
        payload = self._build_payload(product_data, embed_text)

        # 4. Tạo hoặc sử dụng vector_id hiện có
        vector_id = product_data.get("qdrant_vector_id") or str(uuid.uuid4())

        # 5. Upsert vào Qdrant
        qdrant_client.upsert(
            collection_name=COLLECTION_NAME,
            points=[
                PointStruct(
                    id=vector_id,
                    vector=vector,
                    payload=payload,
                )
            ]
        )

        logger.info(f"[Qdrant] Indexed product '{product_data.get('name')}' → {vector_id}")
        return vector_id

    async def delete_product(self, product_id: str) -> None:
        """
        Xoá 1 product khỏi Qdrant theo product_id (UUID từ PostgreSQL).

        Args:
            product_id: UUID string của product trong bảng products.
        """
        qdrant_client.delete(
            collection_name=COLLECTION_NAME,
            points_selector=FilterSelector(
                filter=Filter(
                    must=[
                        FieldCondition(
                            key="product_id",
                            match=MatchValue(value=product_id),
                        )
                    ]
                )
            ),
        )
        logger.info(f"[Qdrant] Deleted product {product_id}")

    async def reindex_all(self, products: list[dict]) -> list[str]:
        """
        Upsert hàng loạt products vào Qdrant.
        Gọi embedding theo batch để tối ưu API calls.

        Args:
            products: Danh sách dict product_data.

        Returns:
            Danh sách qdrant_vector_id đã được upsert.
        """
        if not products:
            logger.warning("[Qdrant] reindex_all called with empty list")
            return []

        # 1. Build text cho tất cả products
        texts = [self.build_embed_text(p) for p in products]

        # 2. Gọi OpenAI batch embedding
        vectors = await self._create_embeddings_batch(texts)

        # 3. Tạo points
        points = []
        vector_ids = []
        for i, product_data in enumerate(products):
            vector_id = product_data.get("qdrant_vector_id") or str(uuid.uuid4())
            vector_ids.append(vector_id)

            payload = self._build_payload(product_data, texts[i])

            points.append(
                PointStruct(
                    id=vector_id,
                    vector=vectors[i],
                    payload=payload,
                )
            )

        # 4. Upsert batch (Qdrant hỗ trợ upsert list)
        qdrant_client.upsert(
            collection_name=COLLECTION_NAME,
            points=points,
        )

        logger.info(f"[Qdrant] Reindexed {len(points)} products")
        return vector_ids

    # ────────────────────────────────────────────────────────
    # TEXT BUILDING
    # ────────────────────────────────────────────────────────

    @staticmethod
    def build_embed_text(product: dict) -> str:
        """
        Chuyển product data thành text tự nhiên để tạo embedding.
        Flatten specs lồng nhau, xử lý None/null gracefully.

        Args:
            product: Dict chứa thông tin product.

        Returns:
            Chuỗi text tổng hợp, dùng dấu " | " phân cách.
        """
        specs = product.get("specs") or {}
        parts: list[str] = []

        # ── Thông tin cơ bản ──
        _append(parts, product.get("name"))
        _append(parts, product.get("brand_name"))
        _append(parts, product.get("line_name"))
        _append(parts, product.get("category_name"))

        desc = product.get("description") or ""
        if desc:
            parts.append(desc[:300])

        base_price = product.get("base_price")
        if base_price:
            parts.append(f"Giá {base_price:,.0f}đ")

        status = product.get("status")
        if status:
            parts.append(f"Tình trạng: {status}")

        # ── Performance ──
        perf = specs.get("performance") or {}
        if perf.get("ram_gb"):
            parts.append(f"RAM {perf['ram_gb']}GB")
        if perf.get("storage_gb"):
            parts.append(f"ROM {perf['storage_gb']}GB")
        if perf.get("chipset"):
            parts.append(f"Chip {perf['chipset']}")
        if perf.get("os"):
            parts.append(perf["os"])

        # ── Screen ──
        screen = specs.get("screen") or {}
        if screen.get("size_inch"):
            parts.append(f"Màn hình {screen['size_inch']} inch")
        elif screen.get("size_mm"):  # smartwatch
            parts.append(f"Mặt {screen['size_mm']}mm")
        if screen.get("refresh_rate_hz"):
            parts.append(f"{screen['refresh_rate_hz']}Hz")
        if screen.get("technology"):
            parts.append(screen["technology"])

        # ── Camera (smartphone/tablet) ──
        cam = specs.get("camera_rear") or {}
        if cam.get("main_mp"):
            parts.append(f"Camera {cam['main_mp']}MP")

        # ── Battery ──
        battery = specs.get("battery") or {}
        if battery.get("capacity_mah"):
            parts.append(f"Pin {battery['capacity_mah']}mAh")
        if battery.get("total_hours"):      # tai nghe
            parts.append(f"Pin {battery['total_hours']} giờ")
        if battery.get("usage_hours"):      # smartwatch / laptop
            parts.append(f"Dùng {battery['usage_hours']} giờ")
        if battery.get("fast_charge_w"):
            parts.append(f"Sạc nhanh {battery['fast_charge_w']}W")

        # ── Headphone-specific ──
        headphone_type = specs.get("type")
        if headphone_type:
            parts.append(headphone_type)

        # ── Accessory-specific ──
        acc_type = specs.get("accessory_type")
        if acc_type:
            parts.append(acc_type)
        compat = specs.get("compatible_model")
        if compat:
            parts.append(f"Tương thích {compat}")

        # ── Special features & Sensors ──
        features = specs.get("special_features")
        if features and isinstance(features, list):
            parts.append(" ".join(features))

        sensors = specs.get("sensors")
        if sensors and isinstance(sensors, list):
            parts.append(" ".join(sensors))

        return " | ".join(filter(None, parts))

    # ────────────────────────────────────────────────────────
    # FLAT SPECS EXTRACTION (cho Qdrant payload filter)
    # ────────────────────────────────────────────────────────

    @staticmethod
    def extract_flat_specs(product: dict) -> dict:
        """
        Trích xuất specs phẳng từ JSONB lồng nhau để dùng làm payload filter.
        Chỉ lấy các field thường xuyên dùng để lọc.

        Args:
            product: Dict chứa thông tin product (bao gồm specs JSONB).

        Returns:
            Dict phẳng với các key filter-friendly.
        """
        specs = product.get("specs") or {}
        perf = specs.get("performance") or {}
        screen = specs.get("screen") or {}
        battery = specs.get("battery") or {}

        return {
            "ram_gb":       perf.get("ram_gb"),
            "storage_gb":   perf.get("storage_gb"),
            "screen_size":  screen.get("size_inch") or screen.get("size_mm"),
            "battery_mah":  battery.get("capacity_mah"),
            "os":           perf.get("os"),
        }

    # ────────────────────────────────────────────────────────
    # PRIVATE HELPERS
    # ────────────────────────────────────────────────────────

    def _build_payload(self, product_data: dict, embed_text: str) -> dict:
        """Xây dựng payload object cho Qdrant point."""
        flat_specs = self.extract_flat_specs(product_data)

        # Colors — lấy từ product_data nếu đã join sẵn
        colors = product_data.get("colors") or []

        return {
            # FK về PostgreSQL
            "product_id":    str(product_data.get("product_id", "")),
            "category_slug": product_data.get("category_slug", ""),
            "brand_slug":    product_data.get("brand_slug", ""),
            "line_slug":     product_data.get("line_slug"),

            # Thông tin hiển thị
            "name":          product_data.get("name", ""),
            "original_url":  product_data.get("original_url", ""),
            "highlight_features": product_data.get("highlight_features", []),
            "base_price":    product_data.get("base_price"),
            "sale_price":    product_data.get("sale_price"),
            "status":        product_data.get("status", "new"),
            "rating_avg":    product_data.get("rating_avg", 0),
            "sold_count":    product_data.get("sold_count", 0),
            "is_active":     product_data.get("is_active", True),
            "primary_image": product_data.get("primary_image"),

            # Màu có sẵn
            "colors":        colors,

            # Specs flat cho filter
            **flat_specs,

            # Text đã embed (debug/audit)
            "embedded_text": embed_text,
        }

    async def _create_embedding(self, text: str) -> list[float]:
        """Tạo embedding vector cho 1 đoạn text qua Gemini."""
        result = genai.embed_content(
            model=EMBEDDING_MODEL,
            content=text
        )
        return result['embedding']

    async def _create_embeddings_batch(self, texts: list[str]) -> list[list[float]]:
        """
        Tạo embedding vectors cho nhiều đoạn text cùng lúc qua Gemini.
        Gemini hỗ trợ tốt việc pass list các chuỗi.
        """
        all_vectors = []
        batch_size = 100 # Chia batch nhỏ để an toàn

        for i in range(0, len(texts), batch_size):
            batch = texts[i:i + batch_size]
            result = genai.embed_content(
                model=EMBEDDING_MODEL,
                content=batch
            )
            all_vectors.extend(result['embedding'])

        return all_vectors

def _append(parts: list[str], value: Optional[str]) -> None:
    """Helper: append non-None, non-empty value to parts list."""
    if value:
        parts.append(str(value))
