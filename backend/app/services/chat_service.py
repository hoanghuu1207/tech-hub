"""
ChatService — Chatbot thông minh cho TechShop (Multi-Tool Architecture).

Kiến trúc:
    User Input → Gemini LLM (8 tools) → Tool Handler → DB + Response

Tools:
    search_products, get_product_detail, compare_products,
    add_to_cart, get_cart, proceed_to_checkout,
    get_order_status, get_promotions
"""

import asyncio
import json
import uuid
import time
import logging
from concurrent.futures import ThreadPoolExecutor
from typing import Optional, List
from uuid import UUID

import google.generativeai as genai
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.chat import ChatConversation, ChatMessage
from app.schemas.chat import ChatResponseData
from app.services.chat_tools import ALL_TOOLS, AUTH_REQUIRED_TOOLS
from app.services.chat_tool_handlers import TOOL_HANDLERS
from app.services.profile_learning_service import profile_learning_service

logger = logging.getLogger("chatbot")
logger.setLevel(logging.INFO)
if not logger.handlers:
    ch = logging.StreamHandler()
    ch.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    ch.setFormatter(formatter)
    logger.addHandler(ch)

# Thread pool cho sync Gemini calls — tránh block event loop
_chat_executor = ThreadPoolExecutor(max_workers=4)

# ── System Prompt ──
CHATBOT_SYSTEM_PROMPT = """Bạn là TechBot — trợ lý AI thông minh của cửa hàng công nghệ TechShop.

=== THÔNG TIN CỬA HÀNG ===
TechShop là cửa hàng trực tuyến chuyên bán các sản phẩm công nghệ:
- Điện thoại (smartphone), Laptop, Máy tính bảng (tablet)
- Tai nghe (headphone), Đồng hồ thông minh (smartwatch), Phụ kiện (accessory)

=== CÁC TOOL CỦA BẠN ===
1. search_products: Tìm sản phẩm trong kho TechShop.
2. get_product_detail: Xem chi tiết thông số kỹ thuật sản phẩm (cần product_id từ search).
3. compare_products: So sánh 2+ sản phẩm (cần product_ids từ search).
4. add_to_cart: Thêm sản phẩm vào giỏ hàng (cần đăng nhập, cần product_id, có thể cần variant_id).
5. get_cart: Xem giỏ hàng hiện tại (cần đăng nhập).
6. proceed_to_checkout: Chuyển sang thanh toán (cần đăng nhập).
7. get_order_status: Tra cứu đơn hàng (cần đăng nhập).
8. get_promotions: Xem sản phẩm đang giảm giá.
9. buy_product: Mua ngay sản phẩm, tạo đơn hàng + thanh toán PayOS (cần đăng nhập, cần product_id, có thể cần variant_id, có quantity).

=== QUY TẮC BẮT BUỘC ===
- QUAN TRỌNG NHẤT: Bạn KHÔNG ĐƯỢC TỰ Ý thực hiện bất kỳ hành động nào mà KHÔNG gọi tool tương ứng.
  + Khi user muốn tìm sản phẩm → BẮT BUỘC gọi search_products
  + Khi user muốn xem chi tiết → BẮT BUỘC gọi get_product_detail
  + Khi user muốn so sánh → BẮT BUỘC gọi compare_products
  + Khi user muốn thêm vào giỏ hàng (nói 'thêm vào giỏ', 'cho vào giỏ', 'bỏ vào giỏ hàng') → BẮT BUỘC gọi add_to_cart
  + Khi user muốn MUA sản phẩm (nói 'mua', 'tôi muốn mua', 'mua cái này', 'đặt mua', 'đặt hàng', 'mua cho tôi') → BẮT BUỘC gọi buy_product (kèm quantity)
- TUYỆT ĐỐI KHÔNG được nói "đã thêm vào giỏ hàng" hoặc "đã mua" hoặc "đã đặt hàng" mà không gọi tool. Đó là BỊA ĐẶT.
- Khi kết quả search trả về, KẾT QUẢ CÓ KÈM ID VÀ SLUG. Hãy nhớ để dùng cho các tool sau.
- Khi user nói "sản phẩm đầu tiên" / "cái thứ 2" / "2 cái cuối" → lấy đúng product_id từ danh sách trước đó.

=== QUY TẮC CHỌN MÀU (VARIANT) ===
- Khi gọi add_to_cart hoặc buy_product mà kết quả trả về action='select_variant' kèm danh sách màu/variant:
  + Hãy hiển thị các màu có sẵn cho người dùng (tên màu, giá, tồn kho).
  + Hỏi người dùng chọn màu nào.
  + Khi người dùng trả lời chọn màu, hãy gọi LẠI tool add_to_cart/buy_product với variant_id tương ứng.
- Nếu sản phẩm hết hàng (stock = 0) ở màu đó, thông báo cho người dùng.

=== QUY TẮC PHÂN BIỆT "MUA" vs "THÊM GIỎ HÀNG" ===
- Khi user nói 'mua', 'tôi muốn mua', 'mua cái này', 'đặt mua', 'đặt hàng', 'mua ngay', 'mua luôn', 'mua cho tôi' → LUÔN LUÔN gọi buy_product.
- Khi user nói 'thêm vào giỏ', 'cho vào giỏ', 'bỏ vào giỏ hàng', 'add to cart' → LUÔN LUÔN gọi add_to_cart.
- TUYỆT ĐỐI KHÔNG được gọi add_to_cart khi user nói 'mua' hoặc 'tôi muốn mua'. Đó là SAI.

=== QUY TẮC CHUNG ===
- Khi gọi tool xong, hãy viết câu trả lời tự nhiên dựa trên kết quả tool trả về. KHÔNG liệt kê lại toàn bộ (app sẽ hiển thị).
- QUAN TRỌNG: Khi nhắc đến số lượng sản phẩm trong câu trả lời, PHẢI đếm CHÍNH XÁC số lượng sản phẩm từ kết quả tool. Ví dụ: nếu tool trả về 5 sản phẩm, nói "5 sản phẩm", KHÔNG được nói "3 sản phẩm".
- QUAN TRỌNG: CHỈ được đề cập đến sản phẩm CÓ TRONG kết quả tool. KHÔNG được nhắc đến sản phẩm không có trong danh sách kết quả.
- Luôn thân thiện, nhiệt tình, dùng ngôn ngữ tiếng Việt tự nhiên.
- KHÔNG bịa thông tin về giá, tồn kho, khuyến mãi.
- Trả lời ngắn gọn 2-3 câu (trừ giải thích kiến thức phức tạp).

=== CÁ NHÂN HÓA ===
- Nếu có HỒ SƠ KHÁCH HÀNG bên dưới, hãy ưu tiên tư vấn sản phẩm, thương hiệu, tính năng phù hợp với sở thích trong hồ sơ.
- Khi khách hỏi chung chung ("gợi ý cho tôi", "có gì hay không"), hãy dùng hồ sơ để đề xuất cá nhân hóa.
- KHÔNG nhắc trực tiếp rằng bạn đang đọc hồ sơ. Hãy tư vấn tự nhiên như một người bán hàng hiểu khách.
{user_profile_section}
"""

MAX_HISTORY_MESSAGES = 30
MAX_TOOL_ROUNDS = 3  # Giới hạn vòng lặp function calling


class ChatService:
    """Service xử lý chatbot với Gemini Multi-Tool Function Calling."""

    def __init__(self):
        genai.configure(api_key=settings.GEMINI_API_KEY)
        # Model mặc định (không có hồ sơ cá nhân)
        self._base_model = genai.GenerativeModel(
            model_name="gemini-2.5-flash-lite",
            tools=[ALL_TOOLS],
            system_instruction=CHATBOT_SYSTEM_PROMPT.format(user_profile_section=""),
            tool_config={"function_calling_config": {"mode": "AUTO"}},
        )

    def _get_model(self, user_profile: str = None):
        """Tạo model với hồ sơ cá nhân nếu có."""
        if not user_profile:
            return self._base_model

        profile_section = (
            f"\n=== HỒ SƠ KHÁCH HÀNG ===\n{user_profile}"
        )
        return genai.GenerativeModel(
            model_name="gemini-2.5-flash-lite",
            tools=[ALL_TOOLS],
            system_instruction=CHATBOT_SYSTEM_PROMPT.format(
                user_profile_section=profile_section
            ),
            tool_config={"function_calling_config": {"mode": "AUTO"}},
        )

    # ────────────────────────────────────────────────────────
    # PUBLIC: Chat
    # ────────────────────────────────────────────────────────

    async def chat(
        self,
        message: str,
        db: AsyncSession,
        conversation_id: Optional[str] = None,
        user_id: Optional[UUID] = None,
    ) -> ChatResponseData:
        start_time = time.time()

        # ── 1. Get or Create Conversation ──
        conversation = None
        if conversation_id:
            conversation = await self._get_conversation(db, conversation_id)
        if not conversation:
            conversation = await self._create_conversation(db, user_id, message)

        conv_id_str = str(conversation.id)

        logger.info("\n" + "=" * 60 +
                    f"\n💬 [Chatbot] Session: {conv_id_str[:8]}... | User: {user_id or 'guest'}" +
                    f"\n   Message: {message}\n" + "=" * 60)

        # ── 2. Load user profile cho cá nhân hóa ──
        user_profile = None
        if user_id:
            try:
                user_profile = await profile_learning_service.get_profile_for_prompt(user_id, db)
                if user_profile:
                    logger.info(f"💬 [Chatbot] Loaded profile for user {str(user_id)[:8]}...")
            except Exception as e:
                logger.warning(f"💬 [Chatbot] Failed to load profile: {e}")

        # ── 3. Load history từ DB ──
        gemini_history = await self._load_gemini_history(db, conversation.id)

        # ── 4. Multi-tool conversation loop ──
        try:
            model = self._get_model(user_profile)
            chat_session = model.start_chat(history=gemini_history)
            loop = asyncio.get_event_loop()
            response = await loop.run_in_executor(
                _chat_executor,
                lambda: chat_session.send_message(
                    message,
                    generation_config=genai.GenerationConfig(temperature=0.7, max_output_tokens=1024),
                )
            )

            # Track results across tool rounds
            intent_type = "general_knowledge"
            products = None
            action_data = None
            products_snapshot = None
            last_tool_summary = None  # Lưu summary cuối cùng để persist vào DB
            assistant_message = None  # Sẽ được set trong loop hoặc sau loop

            # Loop: xử lý function calls (tối đa MAX_TOOL_ROUNDS vòng)
            for round_num in range(MAX_TOOL_ROUNDS):
                fc_part = self._extract_function_call(response)

                if not fc_part:
                    break  # Không có function call → lấy text answer

                fc = fc_part.function_call
                tool_name = fc.name
                tool_args = dict(fc.args) if fc.args else {}

                logger.info(f"💬 [Chatbot] Round {round_num+1}: {tool_name}({tool_args})")

                # Gọi handler
                handler = TOOL_HANDLERS.get(tool_name)
                if not handler:
                    logger.warning(f"💬 [Chatbot] Unknown tool: {tool_name}")
                    break

                tool_result = await handler(tool_args, db, user_id)

                # Cập nhật kết quả
                intent_type = tool_result["intent_type"]
                last_tool_summary = tool_result["summary"]
                if tool_result.get("products"):
                    products = tool_result["products"]
                    products_snapshot = [
                        {"id": str(p.id), "name": p.name, "slug": p.slug,
                         "base_price": p.base_price, "sale_price": p.sale_price}
                        for p in products
                    ]
                if tool_result.get("action_data"):
                    action_data = tool_result["action_data"]

                # Gửi function response lại cho Gemini
                # Ngoại trừ: require_login / select_variant → dùng summary trực tiếp, không cần Gemini rephrase
                if action_data and action_data.get("action") in ("require_login", "select_variant"):
                    assistant_message = tool_result["summary"]
                    break

                fn_response = genai.protos.Part(
                    function_response=genai.protos.FunctionResponse(
                        name=tool_name,
                        response={"result": tool_result["summary"]},
                    )
                )
                response = await loop.run_in_executor(
                    _chat_executor,
                    lambda fn_resp=fn_response: chat_session.send_message(
                        fn_resp,
                        generation_config=genai.GenerationConfig(temperature=0.7, max_output_tokens=512),
                    )
                )

            # Extract final text (nếu chưa set từ early-break ở trên)
            if not assistant_message:
                assistant_message = self._safe_extract_text(response)

            # Fallback intent detection
            if intent_type == "general_knowledge":
                msg_lower = message.lower()
                greetings = ["xin chào", "hello", "hi", "chào", "hey", "alo"]
                if any(g in msg_lower for g in greetings):
                    intent_type = "greeting"

            # ── 4. Save to DB ──
            await self._save_message(db, conversation.id, "user", message)

            # Chỉ nhúng product IDs vào history cho search/promotions
            # (Gemini cần IDs để gọi compare/add_to_cart/detail follow-up)
            # Với các intent khác (cart, checkout, order) → chỉ lưu text
            EMBED_SUMMARY_INTENTS = {"product_search", "promotions", "product_compare"}
            db_content = assistant_message
            if last_tool_summary and intent_type in EMBED_SUMMARY_INTENTS:
                db_content = f"{assistant_message}\n\n[Danh sách sản phẩm: {last_tool_summary}]"

            save_data = products_snapshot
            if last_tool_summary and not save_data:
                save_data = [{"_tool_summary": last_tool_summary[:500]}]

            await self._save_message(
                db, conversation.id, "assistant", db_content,
                intent_type=intent_type, products_data=save_data,
            )

            if not conversation.title:
                title = message[:100] + ("..." if len(message) > 100 else "")
                await self._update_conversation_title(db, conversation.id, title)

            await db.commit()

            # ── 6. Trigger profile learning (fire-and-forget — không block response) ──
            if user_id and intent_type != "general_knowledge":
                async def _background_learn():
                    try:
                        from app.db.session import SessionLocal
                        async with SessionLocal() as bg_db:
                            await profile_learning_service.learn_from_chat(
                                user_id=user_id,
                                user_message=message,
                                intent_type=intent_type,
                                db=bg_db,
                            )
                            await bg_db.commit()
                    except Exception as profile_err:
                        logger.warning(f"💬 [Chatbot] Profile learning failed: {profile_err}")
                asyncio.create_task(_background_learn())

            elapsed = (time.time() - start_time) * 1000
            logger.info(f"💬 [Chatbot] Response ({intent_type}) in {elapsed:.0f}ms: {assistant_message[:100]}...")

            return ChatResponseData(
                session_id=conv_id_str,
                message=assistant_message,
                products=products,
                intent_type=intent_type,
                action_data=action_data,
            )

        except Exception as e:
            logger.error(f"💬 [Chatbot] Error: {e}", exc_info=True)
            await db.rollback()

            fallback = "Xin lỗi bạn, mình đang gặp chút trục trặc. Bạn thử lại sau nhé! 😊"
            try:
                await self._save_message(db, conversation.id, "user", message)
                await self._save_message(db, conversation.id, "assistant", fallback, intent_type="unclear")
                await db.commit()
            except Exception:
                pass

            return ChatResponseData(
                session_id=conv_id_str, message=fallback,
                products=None, intent_type="unclear", action_data=None,
            )

    # ────────────────────────────────────────────────────────
    # HELPERS
    # ────────────────────────────────────────────────────────

    @staticmethod
    def _extract_function_call(response):
        """Trích xuất function_call part từ response (nếu có)."""
        try:
            for part in response.candidates[0].content.parts:
                if part.function_call and part.function_call.name:
                    return part
        except (IndexError, AttributeError):
            pass
        return None

    @staticmethod
    def _safe_extract_text(response) -> str:
        """Trích xuất text an toàn, xử lý khi response chứa function_call."""
        try:
            return response.text.strip()
        except ValueError:
            text_parts = []
            for candidate in response.candidates:
                for part in candidate.content.parts:
                    if hasattr(part, "text") and part.text:
                        text_parts.append(part.text)
            if text_parts:
                return " ".join(text_parts).strip()
            return "Mình đã xử lý xong yêu cầu của bạn rồi nhé! 😊"

    # ────────────────────────────────────────────────────────
    # PUBLIC: Conversation Management
    # ────────────────────────────────────────────────────────

    async def list_conversations(self, db: AsyncSession, user_id: UUID, limit: int = 20) -> list:
        stmt = (
            select(ChatConversation)
            .where(ChatConversation.user_id == user_id, ChatConversation.is_active == True)
            .order_by(ChatConversation.updated_at.desc())
            .limit(limit)
        )
        result = await db.execute(stmt)
        return [
            {"id": str(c.id), "title": c.title or "Cuộc trò chuyện mới",
             "created_at": c.created_at.isoformat() if c.created_at else None,
             "updated_at": c.updated_at.isoformat() if c.updated_at else None}
            for c in result.scalars().all()
        ]

    async def get_messages(self, db: AsyncSession, conversation_id: str,
                           user_id: Optional[UUID] = None, limit: int = 50) -> list:
        conv_uuid = UUID(conversation_id)
        if user_id:
            conv = await self._get_conversation(db, conversation_id)
            if not conv or (conv.user_id and conv.user_id != user_id):
                return []
        stmt = (
            select(ChatMessage).where(ChatMessage.conversation_id == conv_uuid)
            .order_by(ChatMessage.created_at.asc()).limit(limit)
        )
        result = await db.execute(stmt)
        return [
            {"id": str(m.id), "role": m.role, "content": m.content,
             "intent_type": m.intent_type, "products_data": m.products_data,
             "created_at": m.created_at.isoformat() if m.created_at else None}
            for m in result.scalars().all()
        ]

    async def delete_conversation(self, db: AsyncSession, conversation_id: str,
                                   user_id: Optional[UUID] = None) -> bool:
        conv = await self._get_conversation(db, conversation_id)
        if not conv:
            return False
        if user_id and conv.user_id and conv.user_id != user_id:
            return False
        conv.is_active = False
        await db.commit()
        return True

    # ────────────────────────────────────────────────────────
    # PRIVATE: DB Operations
    # ────────────────────────────────────────────────────────

    async def _get_conversation(self, db, conversation_id: str):
        try:
            conv_uuid = UUID(conversation_id)
        except ValueError:
            return None
        stmt = select(ChatConversation).where(
            ChatConversation.id == conv_uuid, ChatConversation.is_active == True)
        result = await db.execute(stmt)
        return result.scalar_one_or_none()

    async def _create_conversation(self, db, user_id, first_message: str):
        title = first_message[:100] + ("..." if len(first_message) > 100 else "")
        conv = ChatConversation(user_id=user_id, title=title)
        db.add(conv)
        await db.flush()
        return conv

    async def _save_message(self, db, conversation_id, role, content,
                             intent_type=None, products_data=None):
        db.add(ChatMessage(
            conversation_id=conversation_id, role=role, content=content,
            intent_type=intent_type, products_data=products_data,
        ))

    async def _update_conversation_title(self, db, conversation_id, title):
        await db.execute(
            update(ChatConversation).where(ChatConversation.id == conversation_id).values(title=title)
        )

    async def _load_gemini_history(self, db, conversation_id) -> list:
        stmt = (
            select(ChatMessage).where(ChatMessage.conversation_id == conversation_id)
            .order_by(ChatMessage.created_at.asc()).limit(MAX_HISTORY_MESSAGES)
        )
        result = await db.execute(stmt)
        return [
            {"role": "model" if m.role == "assistant" else m.role, "parts": [m.content]}
            for m in result.scalars().all()
        ]


# Singleton
chat_service = ChatService()
