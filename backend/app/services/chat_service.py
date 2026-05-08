"""
ChatService — Chatbot thông minh cho TechShop.

Kiến trúc:
    ┌─────────────┐
    │  User Input  │
    └──────┬──────┘
           ▼
    ┌─────────────────────┐
    │   Gemini LLM        │  ← System prompt + Conversation History
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
    Products + AI Message

Features:
    - Function Calling: Gemini tự quyết định khi nào gọi search_products
    - Context-aware: Lưu lịch sử hội thoại theo session_id
    - Hybrid response: Trả về cả text + optional products
"""

import json
import uuid
import time
import logging
from typing import Optional
from collections import OrderedDict

import google.generativeai as genai
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
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
SEARCH_PRODUCTS_TOOL = genai.protos.Tool(
    function_declarations=[
        genai.protos.FunctionDeclaration(
            name="search_products",
            description=(
                "Tìm kiếm sản phẩm trong kho hàng TechShop. "
                "Dùng khi người dùng muốn tìm, mua, xem, hoặc được gợi ý sản phẩm cụ thể. "
                "Ví dụ: 'cho tôi xem iPhone', 'laptop gaming dưới 20 triệu', 'tai nghe chống ồn sony'."
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
    ]
)


# ── Conversation Store (In-memory, LRU) ──
class ConversationStore:
    """Lưu trữ lịch sử hội thoại theo session_id (in-memory LRU)."""

    def __init__(self, max_sessions: int = 500, max_turns_per_session: int = 20):
        self._store: OrderedDict[str, list] = OrderedDict()
        self._max_sessions = max_sessions
        self._max_turns = max_turns_per_session

    def get_history(self, session_id: str) -> list:
        """Lấy lịch sử hội thoại của session."""
        if session_id in self._store:
            self._store.move_to_end(session_id)
        return self._store.get(session_id, [])

    def add_turn(self, session_id: str, role: str, content: str):
        """Thêm một lượt trò chuyện vào session."""
        if session_id not in self._store:
            self._store[session_id] = []
            # Evict oldest session if over capacity
            while len(self._store) > self._max_sessions:
                self._store.popitem(last=False)

        self._store[session_id].append({"role": role, "parts": [content]})
        self._store.move_to_end(session_id)

        # Trim old turns (keep only recent)
        if len(self._store[session_id]) > self._max_turns * 2:
            self._store[session_id] = self._store[session_id][-self._max_turns * 2:]

    def add_function_call(self, session_id: str, function_call, function_response):
        """Thêm function call + response vào history."""
        if session_id not in self._store:
            self._store[session_id] = []

        # Model's function call
        self._store[session_id].append({
            "role": "model",
            "parts": [function_call]
        })
        # Function response
        self._store[session_id].append({
            "role": "function",
            "parts": [function_response]
        })
        self._store.move_to_end(session_id)

    def clear_session(self, session_id: str):
        """Xoá lịch sử của một session."""
        self._store.pop(session_id, None)


# ── Main Chat Service ──
class ChatService:
    """Service xử lý chatbot với Gemini Function Calling."""

    def __init__(self):
        genai.configure(api_key=settings.GEMINI_API_KEY)
        self._model = genai.GenerativeModel(
            model_name="gemini-2.5-flash-lite",
            tools=[SEARCH_PRODUCTS_TOOL],
            system_instruction=CHATBOT_SYSTEM_PROMPT,
        )
        self._conversations = ConversationStore()

    async def chat(
        self,
        message: str,
        db: AsyncSession,
        session_id: Optional[str] = None,
    ) -> ChatResponseData:
        """
        Xử lý tin nhắn từ người dùng.

        Flow:
            1. Lấy/tạo session
            2. Gửi message + history cho Gemini
            3. Nếu Gemini gọi function → thực thi search → gửi lại kết quả
            4. Trả về response text + optional products
        """
        start_time = time.time()

        # ── 1. Session Management ──
        if not session_id:
            session_id = str(uuid.uuid4())

        history = self._conversations.get_history(session_id)

        logger.info("\n" + "=" * 60 +
                    f"\n💬 [Chatbot] New message in session {session_id[:8]}..." +
                    f"\n   User: {message}\n" +
                    "=" * 60)

        # ── 2. Gọi Gemini với history + message ──
        try:
            chat_session = self._model.start_chat(history=history)

            response = chat_session.send_message(
                message,
                generation_config=genai.GenerationConfig(
                    temperature=0.7,
                    max_output_tokens=1024,
                ),
            )

            # ── 3. Check nếu Gemini muốn gọi function ──
            products = None
            intent_type = "general_knowledge"

            # Kiểm tra function call
            candidate = response.candidates[0]
            parts = candidate.content.parts

            function_call_part = None
            for part in parts:
                if part.function_call and part.function_call.name == "search_products":
                    function_call_part = part
                    break

            if function_call_part:
                # ── 3a. Thực thi product search ──
                intent_type = "product_search"
                fc = function_call_part.function_call
                search_query = fc.args.get("query", message)
                search_limit = int(fc.args.get("limit", 10))

                logger.info(f"💬 [Chatbot] Function call: search_products(query='{search_query}', limit={search_limit})")

                # Gọi AI Search Service có sẵn
                search_result = await ai_search_service.search(
                    query=search_query,
                    db=db,
                    limit=search_limit,
                )

                # Chuyển thành ChatProductResult
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

                # Tạo function response summary
                if products:
                    product_summary = f"Tìm thấy {len(products)} sản phẩm phù hợp."
                    product_names = [p.name for p in products[:5]]
                    product_summary += f" Một số sản phẩm: {', '.join(product_names)}."
                else:
                    product_summary = "Không tìm thấy sản phẩm nào phù hợp với yêu cầu."

                # Gửi function response lại cho Gemini để nó tạo câu trả lời tự nhiên
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

                assistant_message = response2.text.strip()

                # Lưu history (user + function call + function response + model answer)
                self._conversations.add_turn(session_id, "user", message)
                self._conversations.add_function_call(
                    session_id,
                    function_call_part,
                    fn_response,
                )
                self._conversations.add_turn(session_id, "model", assistant_message)

            else:
                # ── 3b. Trả lời trực tiếp (kiến thức chung, chào hỏi) ──
                assistant_message = response.text.strip()

                # Phân loại intent
                msg_lower = message.lower()
                greetings = ["xin chào", "hello", "hi", "chào", "hey", "alo"]
                if any(g in msg_lower for g in greetings):
                    intent_type = "greeting"

                # Lưu history
                self._conversations.add_turn(session_id, "user", message)
                self._conversations.add_turn(session_id, "model", assistant_message)

            elapsed = (time.time() - start_time) * 1000
            logger.info(f"💬 [Chatbot] Response ({intent_type}) in {elapsed:.0f}ms: {assistant_message[:100]}...")

            return ChatResponseData(
                session_id=session_id,
                message=assistant_message,
                products=products,
                intent_type=intent_type,
            )

        except Exception as e:
            logger.error(f"💬 [Chatbot] Error: {e}", exc_info=True)

            # Lưu user message vào history dù lỗi
            self._conversations.add_turn(session_id, "user", message)

            # Fallback response
            fallback = (
                "Xin lỗi bạn, mình đang gặp chút trục trặc kỹ thuật. "
                "Bạn có thể thử lại sau hoặc mô tả yêu cầu cụ thể hơn nhé! 😊"
            )
            self._conversations.add_turn(session_id, "model", fallback)

            return ChatResponseData(
                session_id=session_id,
                message=fallback,
                products=None,
                intent_type="unclear",
            )


# Singleton
chat_service = ChatService()
