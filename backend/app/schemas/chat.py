"""
Chat Schemas — Request/Response DTOs cho Chatbot API.

Hỗ trợ:
    - Context-aware conversation (lưu lịch sử theo session_id)
    - Smart routing: chatbot tự quyết định khi nào tìm sản phẩm, khi nào trả lời kiến thức
    - Trả về cả message text và optional product list
"""

from typing import Optional, List
from uuid import UUID
from pydantic import BaseModel, Field


# ─── Request DTOs ─────────────────────────────────────────

class ChatMessage(BaseModel):
    """Một tin nhắn trong cuộc trò chuyện."""
    role: str = Field(..., description="'user' hoặc 'assistant'")
    content: str = Field(..., description="Nội dung tin nhắn")


class ChatRequest(BaseModel):
    """Request body cho API chatbot."""
    message: str = Field(
        ...,
        min_length=1,
        max_length=1000,
        description="Tin nhắn từ người dùng",
        examples=["Cho tôi xem điện thoại iPhone pin trâu dưới 20 triệu"]
    )
    session_id: Optional[str] = Field(
        None,
        description="ID phiên trò chuyện. Nếu không truyền, server sẽ tạo mới."
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
    session_id: str = Field(..., description="ID phiên trò chuyện")
    message: str = Field(..., description="Câu trả lời của chatbot")
    products: Optional[List[ChatProductResult]] = Field(
        None,
        description="Danh sách sản phẩm (nếu chatbot quyết định tìm kiếm sản phẩm)"
    )
    intent_type: str = Field(
        ...,
        description="Loại ý định: 'product_search', 'general_knowledge', 'greeting', 'unclear'"
    )


class ChatResponse(BaseModel):
    """Response wrapper cho API chatbot."""
    success: bool = True
    message: str = "OK"
    data: Optional[ChatResponseData] = None
    error: Optional[str] = None
