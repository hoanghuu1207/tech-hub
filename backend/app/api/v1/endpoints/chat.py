"""
Chat Endpoints — Chatbot trợ lý AI cho TechShop.

Endpoints:
    POST   /api/v1/chat                           — Gửi tin nhắn cho chatbot
    GET    /api/v1/chat/conversations              — Danh sách cuộc trò chuyện (yêu cầu auth)
    GET    /api/v1/chat/conversations/{id}/messages — Lịch sử tin nhắn
    DELETE /api/v1/chat/conversations/{id}         — Xoá cuộc trò chuyện
"""

import logging
from typing import Optional
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models.user import User
from app.core.dependencies import get_current_user, get_optional_user
from app.schemas.chat import (
    ChatRequest,
    ChatResponse,
    ConversationListResponse,
    ConversationItem,
    MessageListResponse,
    MessageItem,
)
from app.services.chat_service import chat_service

logger = logging.getLogger("chatbot")

router = APIRouter()


# ─── 1. Chat (gửi tin nhắn) ──────────────────────────────

@router.post(
    "",
    response_model=ChatResponse,
    summary="Trò chuyện với TechBot",
    description=(
        "Gửi tin nhắn cho chatbot TechBot. Bot sẽ tự động nhận biết khi nào "
        "cần tìm kiếm sản phẩm trong shop và khi nào trả lời kiến thức chung. "
        "Hỗ trợ ngữ cảnh hội thoại qua conversation_id. "
        "Nếu đã đăng nhập (gửi Bearer token), lịch sử sẽ được lưu vĩnh viễn."
    ),
)
async def chat(
    request: ChatRequest,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """
    Gửi tin nhắn cho TechBot.

    - **message**: Tin nhắn từ người dùng
    - **conversation_id**: ID cuộc trò chuyện (tự tạo nếu không truyền)
    - **Authorization** (optional): Bearer token nếu đã đăng nhập

    Response:
    - **session_id**: conversation_id (dùng lại cho tin nhắn tiếp theo)
    - **message**: Câu trả lời của bot
    - **products**: Danh sách sản phẩm (nếu bot tìm kiếm)
    - **intent_type**: Loại ý định
    """
    try:
        user_id = current_user.id if current_user else None

        result = await chat_service.chat(
            message=request.message,
            db=db,
            conversation_id=request.conversation_id,
            user_id=user_id,
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


# ─── 2. List conversations (yêu cầu đăng nhập) ──────────

@router.get(
    "/conversations",
    response_model=ConversationListResponse,
    summary="Danh sách cuộc trò chuyện",
    description="Lấy danh sách cuộc trò chuyện của user đã đăng nhập.",
)
async def list_conversations(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
    limit: int = 20,
):
    """Lấy danh sách cuộc trò chuyện (yêu cầu đăng nhập)."""
    try:
        conversations = await chat_service.list_conversations(
            db=db,
            user_id=current_user.id,
            limit=limit,
        )

        items = [ConversationItem(**c) for c in conversations]

        return ConversationListResponse(
            success=True,
            message=f"Tìm thấy {len(items)} cuộc trò chuyện",
            data=items,
        )

    except Exception as e:
        logger.error(f"[Chat API] List error: {e}")
        return ConversationListResponse(
            success=False,
            message="Lỗi lấy danh sách",
            error=str(e),
        )


# ─── 3. Get messages of a conversation ───────────────────

@router.get(
    "/conversations/{conversation_id}/messages",
    response_model=MessageListResponse,
    summary="Lịch sử tin nhắn",
    description="Lấy lịch sử tin nhắn của một cuộc trò chuyện.",
)
async def get_messages(
    conversation_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
    limit: int = 50,
):
    """Lấy lịch sử tin nhắn của cuộc trò chuyện."""
    try:
        user_id = current_user.id if current_user else None

        messages = await chat_service.get_messages(
            db=db,
            conversation_id=conversation_id,
            user_id=user_id,
            limit=limit,
        )

        items = [MessageItem(**m) for m in messages]

        return MessageListResponse(
            success=True,
            message=f"Tìm thấy {len(items)} tin nhắn",
            data=items,
        )

    except Exception as e:
        logger.error(f"[Chat API] Messages error: {e}")
        return MessageListResponse(
            success=False,
            message="Lỗi lấy tin nhắn",
            error=str(e),
        )


# ─── 4. Delete conversation ──────────────────────────────

@router.delete(
    "/conversations/{conversation_id}",
    response_model=ChatResponse,
    summary="Xoá cuộc trò chuyện",
    description="Soft-delete cuộc trò chuyện.",
)
async def delete_conversation(
    conversation_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """Xoá cuộc trò chuyện."""
    try:
        user_id = current_user.id if current_user else None

        deleted = await chat_service.delete_conversation(
            db=db,
            conversation_id=conversation_id,
            user_id=user_id,
        )

        if deleted:
            return ChatResponse(success=True, message="Đã xoá cuộc trò chuyện")
        else:
            return ChatResponse(success=False, message="Không tìm thấy cuộc trò chuyện")

    except Exception as e:
        logger.error(f"[Chat API] Delete error: {e}")
        return ChatResponse(
            success=False,
            message="Lỗi xoá cuộc trò chuyện",
            error=str(e),
        )
