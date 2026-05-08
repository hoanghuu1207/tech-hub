"""
Chat Schemas — Request/Response DTOs cho Chatbot API.

Hỗ trợ:
    - Context-aware conversation (lưu lịch sử DB theo conversation_id)
    - Smart routing: chatbot tự quyết định khi nào tìm sản phẩm, khi nào trả lời kiến thức
    - Trả về cả message text và optional product list
    - Quản lý conversations (list, get messages, delete)
"""

from typing import Optional, List
from uuid import UUID
from pydantic import BaseModel, Field


# ─── Request DTOs ─────────────────────────────────────────

class ChatRequest(BaseModel):
    """Request body cho API chatbot."""
    message: str = Field(
        ...,
        min_length=1,
        max_length=1000,
        description="Tin nhắn từ người dùng",
        examples=["Cho tôi xem điện thoại iPhone pin trâu dưới 20 triệu"]
    )
    conversation_id: Optional[str] = Field(
        None,
        description="ID cuộc trò chuyện. Nếu không truyền, server sẽ tạo mới."
    )


# ─── Response DTOs ────────────────────────────────────────

class ChatProductResult(BaseModel):
    """Sản phẩm được trả về từ chatbot khi tìm kiếm."""
    id: UUID
    name: str
    slug: str
    category_name: Optional[str] = None
    category_slug: Optional[str] = None
    brand_name: Optional[str] = None
    brand_slug: Optional[str] = None
    base_price: float = 0
    sale_price: Optional[float] = None
    primary_image: Optional[str] = None
    rating_avg: float = 0
    sold_count: int = 0
    similarity_score: float = 0


class ChatResponseData(BaseModel):
    """Dữ liệu trả về từ chatbot."""
    session_id: str = Field(..., description="ID cuộc trò chuyện (conversation_id)")
    message: str = Field(..., description="Câu trả lời của chatbot")
    products: Optional[List[ChatProductResult]] = Field(
        None,
        description="Danh sách sản phẩm (nếu có)"
    )
    intent_type: str = Field(
        ...,
        description=(
            "Loại ý định: 'product_search', 'product_detail', 'product_compare', "
            "'add_to_cart', 'get_cart', 'checkout', 'order_status', 'promotions', "
            "'general_knowledge', 'greeting', 'unclear'"
        )
    )
    action_data: Optional[dict] = Field(
        None,
        description=(
            "Dữ liệu hành động cho Flutter. Chứa 'action' key để app biết chuyển màn hình. "
            "Ví dụ: {'action': 'navigate_product_detail', 'product_slug': '...'}"
        )
    )


class ChatResponse(BaseModel):
    """Response wrapper cho API chatbot."""
    success: bool = True
    message: str = "OK"
    data: Optional[ChatResponseData] = None
    error: Optional[str] = None


# ─── Conversation Management DTOs ─────────────────────────

class ConversationItem(BaseModel):
    """Một cuộc trò chuyện trong danh sách."""
    id: str
    title: str
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


class ConversationListResponse(BaseModel):
    """Response danh sách cuộc trò chuyện."""
    success: bool = True
    message: str = "OK"
    data: Optional[List[ConversationItem]] = None
    error: Optional[str] = None


class MessageItem(BaseModel):
    """Một tin nhắn trong lịch sử."""
    id: str
    role: str
    content: str
    intent_type: Optional[str] = None
    products_data: Optional[list] = None
    created_at: Optional[str] = None


class MessageListResponse(BaseModel):
    """Response lịch sử tin nhắn."""
    success: bool = True
    message: str = "OK"
    data: Optional[List[MessageItem]] = None
    error: Optional[str] = None
