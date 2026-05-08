"""
Chat Endpoints — Chatbot trợ lý AI cho TechShop.

Endpoints:
    POST /api/v1/chat          — Gửi tin nhắn cho chatbot
    DELETE /api/v1/chat/{id}   — Xoá lịch sử hội thoại
"""

import logging
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.chat import ChatRequest, ChatResponse
from app.services.chat_service import chat_service

logger = logging.getLogger("chatbot")

router = APIRouter()


@router.post(
    "",
    response_model=ChatResponse,
    summary="Trò chuyện với TechBot",
    description=(
        "Gửi tin nhắn cho chatbot TechBot. Bot sẽ tự động nhận biết khi nào "
        "cần tìm kiếm sản phẩm trong shop và khi nào trả lời kiến thức chung. "
        "Hỗ trợ ngữ cảnh hội thoại qua session_id."
    ),
)
async def chat(
    request: ChatRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Gửi tin nhắn cho TechBot.

    - **message**: Tin nhắn từ người dùng
    - **session_id**: ID phiên trò chuyện (tự tạo nếu không truyền)

    Response sẽ bao gồm:
    - **message**: Câu trả lời của bot
    - **products**: Danh sách sản phẩm (nếu bot tìm kiếm)
    - **intent_type**: Loại ý định ('product_search', 'general_knowledge', 'greeting')
    - **session_id**: Dùng lại cho tin nhắn tiếp theo để duy trì ngữ cảnh
    """
    try:
        result = await chat_service.chat(
            message=request.message,
            db=db,
            session_id=request.session_id,
        )

        return ChatResponse(
            success=True,
            message="OK",
            data=result,
        )

    except Exception as e:
        logger.error(f"[Chat API] Error: {e}")
        return ChatResponse(
            success=False,
            message="Lỗi xử lý tin nhắn",
            error=str(e),
        )


@router.delete(
    "/{session_id}",
    response_model=ChatResponse,
    summary="Xoá lịch sử hội thoại",
    description="Xoá toàn bộ lịch sử hội thoại của một session.",
)
async def clear_chat(session_id: str):
    """Xoá lịch sử hội thoại theo session_id."""
    chat_service._conversations.clear_session(session_id)
    return ChatResponse(
        success=True,
        message=f"Đã xoá lịch sử session {session_id}",
    )
