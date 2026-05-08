"""
ChatService — Chatbot thông minh cho TechShop.

Kiến trúc:
    ┌─────────────┐
    │  User Input  │
    └──────┬──────┘
           ▼
    ┌─────────────────────┐
    │   Gemini LLM        │  ← System prompt + Conversation History (from DB)
    │   (Function Calling) │
    └──────┬──────────────┘
           │
     ┌─────┴─────┐
     ▼           ▼
  [search_products]   [General Answer]
     │                    │
     ▼                    │
  ┌──────────┐            │
  │ AI Search│            │
  │ Service  │            │
  └────┬─────┘            │
       ▼                  ▼
    Products + AI Message → Save to DB

Features:
    - Function Calling: Gemini tự quyết định khi nào gọi search_products
    - Context-aware: Load lịch sử từ DB, Gemini hiểu ngữ cảnh
    - Persistent: User đăng nhập → lưu DB, quay lại vẫn còn
    - Guest: Chưa đăng nhập → session chỉ tồn tại trên app
"""

import json
import uuid
import time
import logging
from typing import Optional, List
from uuid import UUID

import google.generativeai as genai
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import settings
from app.models.chat import ChatConversation, ChatMessage
from app.schemas.chat import ChatProductResult, ChatResponseData
from app.services.ai_search_service import ai_search_service

logger = logging.getLogger("chatbot")
logger.setLevel(logging.INFO)
if not logger.handlers:
    ch = logging.StreamHandler()
    ch.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    ch.setFormatter(formatter)
    logger.addHandler(ch)


# ── System Prompt ──
CHATBOT_SYSTEM_PROMPT = """Bạn là TechBot — trợ lý AI thông minh của cửa hàng công nghệ TechShop.

=== THÔNG TIN CỬA HÀNG ===
TechShop là cửa hàng trực tuyến chuyên bán các sản phẩm công nghệ:
- Điện thoại (smartphone)
- Laptop
- Máy tính bảng (tablet)
- Tai nghe (headphone)
- Đồng hồ thông minh (smartwatch)
- Phụ kiện (accessory)

=== VAI TRÒ CỦA BẠN ===
1. Tư vấn sản phẩm: Khi người dùng muốn tìm/mua sản phẩm, hãy dùng tool `search_products` để tìm trong kho hàng TechShop.
2. Kiến thức công nghệ: Trả lời các câu hỏi về công nghệ, so sánh, xu hướng, tips.
3. Hỗ trợ chung: Chào hỏi, giới thiệu cửa hàng, hướng dẫn mua hàng.

=== QUY TẮC QUAN TRỌNG ===
- Luôn thân thiện, nhiệt tình, dùng ngôn ngữ tiếng Việt tự nhiên.
- Khi người dùng hỏi về sản phẩm cụ thể, muốn tìm/mua/xem/gợi ý sản phẩm → BẮT BUỘC gọi tool `search_products`.
- Khi người dùng hỏi kiến thức chung (xu hướng, so sánh, tips) → Trả lời trực tiếp từ kiến thức của bạn.
- Khi gọi tool xong và có kết quả, hãy viết một câu giới thiệu ngắn gọn, thân thiện. KHÔNG liệt kê lại chi tiết sản phẩm (app sẽ hiển thị).
- Nếu không tìm thấy sản phẩm, hãy gợi ý người dùng thử tìm kiếm khác.
- Luôn nhớ ngữ cảnh cuộc trò chuyện để trả lời chính xác.
- KHÔNG bịa thông tin về giá, tồn kho, khuyến mãi nếu không có dữ liệu.
- Trả lời ngắn gọn, tối đa 2-3 câu cho mỗi tin nhắn (trừ khi giải thích kiến thức phức tạp).
"""


# ── Tool Definition cho Gemini Function Calling ──
search_products_func = genai.protos.FunctionDeclaration(
    name="search_products",
    description=(
        "Tìm kiếm sản phẩm trong kho hàng TechShop. "
        "BẮT BUỘC dùng khi người dùng muốn tìm, mua, xem, gợi ý, hoặc hỏi về sản phẩm cụ thể. "
        "Ví dụ: 'cho tôi xem iPhone', 'laptop gaming dưới 20 triệu', 'tai nghe chống ồn sony', "
        "'điện thoại pin trâu', 'có laptop nào tốt không', 'gợi ý đồng hồ cho nữ'."
    ),
    parameters=genai.protos.Schema(
        type=genai.protos.Type.OBJECT,
        properties={
            "query": genai.protos.Schema(
                type=genai.protos.Type.STRING,
                description=(
                    "Câu tìm kiếm sản phẩm bằng ngôn ngữ tự nhiên. "
                    "Giữ nguyên ý định của người dùng, bao gồm: tên sản phẩm, brand, "
                    "đặc điểm (pin trâu, chống ồn), giá, specs (RAM, ROM)."
                ),
            ),
            "limit": genai.protos.Schema(
                type=genai.protos.Type.INTEGER,
                description="Số lượng sản phẩm tối đa trả về (mặc định 10).",
            ),
        },
        required=["query"],
    ),
)

SEARCH_PRODUCTS_TOOL = genai.protos.Tool(
    function_declarations=[search_products_func],
)

# Số lượng tin nhắn gần nhất để gửi cho Gemini (context window)
MAX_HISTORY_MESSAGES = 30


# ── Main Chat Service ──
class ChatService:
    """Service xử lý chatbot với Gemini Function Calling + DB persistence."""

    def __init__(self):
        genai.configure(api_key=settings.GEMINI_API_KEY)
        self._model = genai.GenerativeModel(
            model_name="gemini-2.5-flash-lite",
            tools=[SEARCH_PRODUCTS_TOOL],
            system_instruction=CHATBOT_SYSTEM_PROMPT,
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
        """
        Xử lý tin nhắn từ người dùng.

        Flow:
            1. Lấy/tạo conversation
            2. Load history từ DB → build Gemini history
            3. Gọi Gemini + xử lý function calling nếu có
            4. Lưu user message + assistant response vào DB
            5. Trả về response
        """
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
                    f"\n   Message: {message}\n" +
                    "=" * 60)

        # ── 2. Load history từ DB → Gemini format ──
        gemini_history = await self._load_gemini_history(db, conversation.id)

        # ── 3. Gọi Gemini ──
        try:
            chat_session = self._model.start_chat(history=gemini_history)

            response = chat_session.send_message(
                message,
                generation_config=genai.GenerationConfig(
                    temperature=0.7,
                    max_output_tokens=1024,
                ),
            )

            # ── 4. Check function call ──
            products = None
            intent_type = "general_knowledge"
            products_snapshot = None

            candidate = response.candidates[0]
            parts = candidate.content.parts

            function_call_part = None
            for part in parts:
                if part.function_call and part.function_call.name == "search_products":
                    function_call_part = part
                    break

            if function_call_part:
                # ── 4a. Product search ──
                intent_type = "product_search"
                fc = function_call_part.function_call
                search_query = fc.args.get("query", message)
                search_limit = int(fc.args.get("limit", 10))

                logger.info(f"💬 [Chatbot] Function call: search_products(query='{search_query}', limit={search_limit})")

                search_result = await ai_search_service.search(
                    query=search_query,
                    db=db,
                    limit=search_limit,
                )

                products = [
                    ChatProductResult(
                        id=p.id,
                        name=p.name,
                        slug=p.slug,
                        category_name=p.category_name,
                        category_slug=p.category_slug,
                        brand_name=p.brand_name,
                        brand_slug=p.brand_slug,
                        base_price=p.base_price,
                        sale_price=p.sale_price,
                        primary_image=p.primary_image,
                        rating_avg=p.rating_avg,
                        sold_count=p.sold_count,
                        similarity_score=p.similarity_score,
                    )
                    for p in search_result.products
                ]

                # Snapshot sản phẩm để lưu DB (không lưu image/score)
                products_snapshot = [
                    {"id": str(p.id), "name": p.name, "slug": p.slug,
                     "base_price": p.base_price, "sale_price": p.sale_price}
                    for p in products
                ]

                # Function response
                if products:
                    product_summary = f"Tìm thấy {len(products)} sản phẩm phù hợp."
                    product_names = [p.name for p in products[:5]]
                    product_summary += f" Một số sản phẩm: {', '.join(product_names)}."
                else:
                    product_summary = "Không tìm thấy sản phẩm nào phù hợp với yêu cầu."

                fn_response = genai.protos.Part(
                    function_response=genai.protos.FunctionResponse(
                        name="search_products",
                        response={"result": product_summary},
                    )
                )

                response2 = chat_session.send_message(
                    fn_response,
                    generation_config=genai.GenerationConfig(
                        temperature=0.7,
                        max_output_tokens=512,
                    ),
                )

                assistant_message = self._safe_extract_text(response2)

            else:
                # ── 4b. Direct answer ──
                assistant_message = self._safe_extract_text(response)

                msg_lower = message.lower()
                greetings = ["xin chào", "hello", "hi", "chào", "hey", "alo"]
                if any(g in msg_lower for g in greetings):
                    intent_type = "greeting"

            # ── 5. Lưu vào DB ──
            await self._save_message(db, conversation.id, "user", message)
            await self._save_message(
                db, conversation.id, "assistant", assistant_message,
                intent_type=intent_type,
                products_data=products_snapshot,
            )

            # Cập nhật title nếu chưa có (lấy từ tin nhắn đầu tiên)
            if not conversation.title:
                title = message[:100] + ("..." if len(message) > 100 else "")
                await self._update_conversation_title(db, conversation.id, title)

            await db.commit()

            elapsed = (time.time() - start_time) * 1000
            logger.info(f"💬 [Chatbot] Response ({intent_type}) in {elapsed:.0f}ms: {assistant_message[:100]}...")

            return ChatResponseData(
                session_id=conv_id_str,
                message=assistant_message,
                products=products,
                intent_type=intent_type,
            )

        except Exception as e:
            logger.error(f"💬 [Chatbot] Error: {e}", exc_info=True)
            await db.rollback()

            fallback = (
                "Xin lỗi bạn, mình đang gặp chút trục trặc kỹ thuật. "
                "Bạn có thể thử lại sau hoặc mô tả yêu cầu cụ thể hơn nhé! 😊"
            )

            # Vẫn cố lưu vào DB
            try:
                await self._save_message(db, conversation.id, "user", message)
                await self._save_message(db, conversation.id, "assistant", fallback, intent_type="unclear")
                await db.commit()
            except Exception:
                pass

            return ChatResponseData(
                session_id=conv_id_str,
                message=fallback,
                products=None,
                intent_type="unclear",
            )

    # ────────────────────────────────────────────────────────
    # HELPER: Safe text extraction from Gemini response
    # ────────────────────────────────────────────────────────

    @staticmethod
    def _safe_extract_text(response) -> str:
        """
        Trích xuất text an toàn từ Gemini response.
        Xử lý trường hợp response chứa function_call thay vì text
        (khi Gemini muốn gọi function lần nữa sau function response).
        """
        try:
            return response.text.strip()
        except ValueError:
            # response.text raise ValueError khi có function_call parts
            # → duyệt qua tất cả parts, lấy text nếu có
            text_parts = []
            for candidate in response.candidates:
                for part in candidate.content.parts:
                    if hasattr(part, "text") and part.text:
                        text_parts.append(part.text)
            if text_parts:
                return " ".join(text_parts).strip()
            # Không có text nào → trả fallback
            return "Mình đã tìm được một số sản phẩm phù hợp cho bạn, hãy xem nhé! 😊"

    # ────────────────────────────────────────────────────────
    # PUBLIC: List conversations (cho user đã đăng nhập)
    # ────────────────────────────────────────────────────────

    async def list_conversations(
        self,
        db: AsyncSession,
        user_id: UUID,
        limit: int = 20,
    ) -> list:
        """Lấy danh sách cuộc trò chuyện của user."""
        stmt = (
            select(ChatConversation)
            .where(ChatConversation.user_id == user_id, ChatConversation.is_active == True)
            .order_by(ChatConversation.updated_at.desc())
            .limit(limit)
        )
        result = await db.execute(stmt)
        conversations = result.scalars().all()

        return [
            {
                "id": str(c.id),
                "title": c.title or "Cuộc trò chuyện mới",
                "created_at": c.created_at.isoformat() if c.created_at else None,
                "updated_at": c.updated_at.isoformat() if c.updated_at else None,
            }
            for c in conversations
        ]

    # ────────────────────────────────────────────────────────
    # PUBLIC: Get conversation messages
    # ────────────────────────────────────────────────────────

    async def get_messages(
        self,
        db: AsyncSession,
        conversation_id: str,
        user_id: Optional[UUID] = None,
        limit: int = 50,
    ) -> list:
        """Lấy lịch sử tin nhắn của một cuộc trò chuyện."""
        conv_uuid = UUID(conversation_id)

        # Verify ownership nếu có user_id
        if user_id:
            conv = await self._get_conversation(db, conversation_id)
            if not conv or (conv.user_id and conv.user_id != user_id):
                return []

        stmt = (
            select(ChatMessage)
            .where(ChatMessage.conversation_id == conv_uuid)
            .order_by(ChatMessage.created_at.asc())
            .limit(limit)
        )
        result = await db.execute(stmt)
        messages = result.scalars().all()

        return [
            {
                "id": str(m.id),
                "role": m.role,
                "content": m.content,
                "intent_type": m.intent_type,
                "products_data": m.products_data,
                "created_at": m.created_at.isoformat() if m.created_at else None,
            }
            for m in messages
        ]

    # ────────────────────────────────────────────────────────
    # PUBLIC: Delete conversation
    # ────────────────────────────────────────────────────────

    async def delete_conversation(
        self,
        db: AsyncSession,
        conversation_id: str,
        user_id: Optional[UUID] = None,
    ) -> bool:
        """Soft-delete cuộc trò chuyện."""
        conv = await self._get_conversation(db, conversation_id)
        if not conv:
            return False
        if user_id and conv.user_id and conv.user_id != user_id:
            return False

        conv.is_active = False
        await db.commit()
        return True

    # ────────────────────────────────────────────────────────
    # PRIVATE: DB operations
    # ────────────────────────────────────────────────────────

    async def _get_conversation(self, db: AsyncSession, conversation_id: str) -> Optional[ChatConversation]:
        """Lấy conversation từ DB."""
        try:
            conv_uuid = UUID(conversation_id)
        except ValueError:
            return None

        stmt = select(ChatConversation).where(
            ChatConversation.id == conv_uuid,
            ChatConversation.is_active == True,
        )
        result = await db.execute(stmt)
        return result.scalar_one_or_none()

    async def _create_conversation(
        self,
        db: AsyncSession,
        user_id: Optional[UUID],
        first_message: str,
    ) -> ChatConversation:
        """Tạo conversation mới."""
        title = first_message[:100] + ("..." if len(first_message) > 100 else "")
        conversation = ChatConversation(
            user_id=user_id,
            title=title,
        )
        db.add(conversation)
        await db.flush()  # Lấy ID mà chưa commit
        return conversation

    async def _save_message(
        self,
        db: AsyncSession,
        conversation_id: UUID,
        role: str,
        content: str,
        intent_type: Optional[str] = None,
        products_data: Optional[list] = None,
    ):
        """Lưu một tin nhắn vào DB."""
        msg = ChatMessage(
            conversation_id=conversation_id,
            role=role,
            content=content,
            intent_type=intent_type,
            products_data=products_data,
        )
        db.add(msg)

    async def _update_conversation_title(
        self,
        db: AsyncSession,
        conversation_id: UUID,
        title: str,
    ):
        """Cập nhật title cho conversation."""
        stmt = (
            update(ChatConversation)
            .where(ChatConversation.id == conversation_id)
            .values(title=title)
        )
        await db.execute(stmt)

    async def _load_gemini_history(
        self,
        db: AsyncSession,
        conversation_id: UUID,
    ) -> list:
        """
        Load tin nhắn từ DB → chuyển thành Gemini history format.

        Gemini cần format:
            [{"role": "user", "parts": ["..."]}, {"role": "model", "parts": ["..."]}]

        Chú ý: role "assistant" trong DB → "model" cho Gemini.
        """
        stmt = (
            select(ChatMessage)
            .where(ChatMessage.conversation_id == conversation_id)
            .order_by(ChatMessage.created_at.asc())
            .limit(MAX_HISTORY_MESSAGES)
        )
        result = await db.execute(stmt)
        messages = result.scalars().all()

        gemini_history = []
        for msg in messages:
            role = "model" if msg.role == "assistant" else msg.role
            gemini_history.append({
                "role": role,
                "parts": [msg.content],
            })

        return gemini_history


# Singleton
chat_service = ChatService()
