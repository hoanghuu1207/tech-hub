"""
ProfileLearningService — Tự động học và cập nhật hồ sơ người dùng.

Phân tích hành vi từ 3 nguồn:
    1. Duyệt (xem chi tiết sản phẩm)
    2. Hỏi (chat với TechBot)
    3. Mua hàng (thanh toán thành công)

Sử dụng Gemini LLM để tóm tắt và cập nhật hồ sơ sở thích.
Hồ sơ này được nhúng vào System Prompt khi chatbot tư vấn,
giúp AI cá nhân hóa thay vì trả lời chung chung.
"""

import asyncio
import logging
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

import google.generativeai as genai
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import settings
from app.models.user import User
from app.models.product import Product

logger = logging.getLogger("profile_learning")
logger.setLevel(logging.INFO)
if not logger.handlers:
    ch = logging.StreamHandler()
    ch.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    ch.setFormatter(formatter)
    logger.addHandler(ch)

# Thread pool cho sync Gemini calls
_profile_executor = ThreadPoolExecutor(max_workers=2)

# ── Prompt để Gemini tóm tắt hồ sơ ──
PROFILE_SUMMARIZE_PROMPT = """Bạn là hệ thống phân tích hồ sơ khách hàng của cửa hàng công nghệ TechShop.

Nhiệm vụ: Dựa trên HỒ SƠ CŨ và HÀNH ĐỘNG MỚI, hãy viết lại MỘT đoạn tóm tắt ngắn gọn (tối đa 200 từ) về sở thích và lịch sử mua sắm hiện tại của khách hàng.

=== QUY TẮC ===
- Giữ lại thông tin quan trọng từ hồ sơ cũ, KHÔNG xóa sở thích cũ trừ khi mâu thuẫn.
- Tích hợp hành động mới vào hồ sơ một cách tự nhiên.
- Tóm tắt theo các khía cạnh: danh mục quan tâm, thương hiệu yêu thích, phân khúc giá, tính năng ưu tiên, lịch sử mua.
- Viết dạng gạch đầu dòng ngắn gọn, tiếng Việt.
- KHÔNG thêm suy đoán, chỉ dựa trên dữ liệu thực.
- Nếu hồ sơ cũ trống, tạo hồ sơ mới từ hành động.

=== VÍ DỤ OUTPUT ===
- Danh mục: Quan tâm chủ yếu đến smartphone và tai nghe
- Thương hiệu: Thích Samsung, Sony
- Phân khúc giá: Tầm trung (5-15 triệu)
- Tính năng: Ưu tiên pin trâu, chống ồn
- Lịch sử mua: Đã mua Samsung Galaxy S24 (màu đen), Sony WH-1000XM5
"""

# Giới hạn tần suất cập nhật (giây) — tránh gọi Gemini quá nhiều
MIN_UPDATE_INTERVAL_SECONDS = 30


class ProfileLearningService:
    """Service tự động học hồ sơ người dùng từ hành vi."""

    def __init__(self):
        genai.configure(api_key=settings.GEMINI_API_KEY)
        self._model = genai.GenerativeModel("gemini-2.5-flash-lite")

    # ────────────────────────────────────────────────────────
    # PUBLIC: Học từ hành vi duyệt sản phẩm
    # ────────────────────────────────────────────────────────

    async def learn_from_view(
        self,
        user_id: UUID,
        product: Product,
        db: AsyncSession,
    ) -> None:
        """Cập nhật hồ sơ khi user xem chi tiết sản phẩm."""
        action_desc = (
            f"Xem sản phẩm: {product.name}"
        )
        if hasattr(product, 'category') and product.category:
            action_desc += f" (danh mục: {product.category.name})"
        if hasattr(product, 'brand') and product.brand:
            action_desc += f" (thương hiệu: {product.brand.name})"
        if product.sale_price:
            action_desc += f" (giá: {int(product.sale_price):,}đ)"
        elif product.base_price:
            action_desc += f" (giá: {int(product.base_price):,}đ)"

        await self._update_profile(user_id, action_desc, db)

    # ────────────────────────────────────────────────────────
    # PUBLIC: Học từ hành vi chat (hỏi)
    # ────────────────────────────────────────────────────────

    async def learn_from_chat(
        self,
        user_id: UUID,
        user_message: str,
        intent_type: str,
        db: AsyncSession,
    ) -> None:
        """Cập nhật hồ sơ khi user chat với chatbot."""
        # Chỉ học từ các intent có giá trị (search, detail, compare, promotions)
        LEARNABLE_INTENTS = {
            "product_search", "product_detail", "product_compare",
            "promotions", "add_to_cart", "buy_product",
        }
        if intent_type not in LEARNABLE_INTENTS:
            return

        action_desc = f"Hỏi chatbot ({intent_type}): \"{user_message}\""
        await self._update_profile(user_id, action_desc, db)

    # ────────────────────────────────────────────────────────
    # PUBLIC: Học từ hành vi mua hàng
    # ────────────────────────────────────────────────────────

    async def learn_from_purchase(
        self,
        user_id: UUID,
        order_items: list,
        db: AsyncSession,
    ) -> None:
        """Cập nhật hồ sơ khi user mua hàng thành công."""
        purchased_items = []
        for item in order_items:
            name = item.product.name if item.product else "Sản phẩm"
            color = ""
            if item.variant and item.variant.color_name:
                color = f" (màu {item.variant.color_name})"
            price = f" - giá {int(item.unit_price):,}đ" if item.unit_price else ""
            qty = f" x{item.quantity}" if item.quantity > 1 else ""
            purchased_items.append(f"{name}{color}{qty}{price}")

        action_desc = "Đã mua hàng thành công: " + "; ".join(purchased_items)
        await self._update_profile(user_id, action_desc, db)

    # ────────────────────────────────────────────────────────
    # PRIVATE: Core — Cập nhật hồ sơ bằng Gemini
    # ────────────────────────────────────────────────────────

    async def _update_profile(
        self,
        user_id: UUID,
        action_description: str,
        db: AsyncSession,
    ) -> None:
        """
        Core logic: Lấy hồ sơ cũ → Gọi Gemini tóm tắt lại → Lưu hồ sơ mới.
        Chạy fire-and-forget, không block luồng chính.
        """
        try:
            # Lấy user hiện tại
            result = await db.execute(select(User).where(User.id == user_id))
            user = result.scalar_one_or_none()
            if not user:
                return

            # Rate limiting: không cập nhật quá thường xuyên
            if user.profile_updated_at:
                elapsed = (datetime.now(timezone.utc) - user.profile_updated_at).total_seconds()
                if elapsed < MIN_UPDATE_INTERVAL_SECONDS:
                    logger.debug(
                        f"📝 [Profile] Skipping update for user {user_id} "
                        f"(last update {elapsed:.0f}s ago)"
                    )
                    return

            old_profile = user.profile_summary or "Chưa có thông tin."

            # Gọi Gemini để tóm tắt hồ sơ mới
            prompt = (
                f"{PROFILE_SUMMARIZE_PROMPT}\n\n"
                f"=== HỒ SƠ CŨ ===\n{old_profile}\n\n"
                f"=== HÀNH ĐỘNG MỚI ===\n{action_description}\n\n"
                f"Hãy viết lại hồ sơ tóm tắt (tiếng Việt, tối đa 200 từ):"
            )

            loop = asyncio.get_event_loop()
            response = await loop.run_in_executor(
                _profile_executor,
                lambda: self._model.generate_content(
                    prompt,
                    generation_config=genai.GenerationConfig(
                        temperature=0.3,
                        max_output_tokens=400,
                    ),
                )
            )

            new_profile = response.text.strip()

            # Validate output không rỗng
            if not new_profile or len(new_profile) < 10:
                logger.warning(f"📝 [Profile] Gemini returned empty/short profile, skipping")
                return

            # Lưu hồ sơ mới
            await db.execute(
                update(User)
                .where(User.id == user_id)
                .values(
                    profile_summary=new_profile,
                    profile_updated_at=datetime.now(timezone.utc),
                )
            )
            # Không commit ở đây — caller sẽ commit

            logger.info(
                f"📝 [Profile] Updated profile for user {str(user_id)[:8]}...\n"
                f"   Action: {action_description[:80]}...\n"
                f"   Profile: {new_profile[:120]}..."
            )

        except Exception as e:
            logger.error(f"📝 [Profile] Error updating profile for {user_id}: {e}", exc_info=True)
            # Không raise — profile learning là tính năng phụ, không block luồng chính

    # ────────────────────────────────────────────────────────
    # PUBLIC: Lấy hồ sơ để nhúng vào prompt
    # ────────────────────────────────────────────────────────

    async def get_profile_for_prompt(
        self,
        user_id: UUID,
        db: AsyncSession,
    ) -> Optional[str]:
        """Lấy profile_summary để nhúng vào chatbot system prompt."""
        result = await db.execute(
            select(User.profile_summary).where(User.id == user_id)
        )
        profile = result.scalar_one_or_none()
        if profile and profile.strip():
            return profile.strip()
        return None


# Singleton
profile_learning_service = ProfileLearningService()
