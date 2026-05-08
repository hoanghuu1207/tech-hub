"""
Chat Models — Lưu trữ lịch sử hội thoại chatbot.

Tables:
    - chat_conversations: Mỗi cuộc trò chuyện (1 user có nhiều conversations)
    - chat_messages: Mỗi tin nhắn trong cuộc trò chuyện
"""

import uuid
from sqlalchemy import Column, String, Boolean, DateTime, Integer, ForeignKey, Text, Enum
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.db.base import Base


class ChatConversation(Base):
    """Một cuộc trò chuyện chatbot."""
    __tablename__ = "chat_conversations"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=True,  # NULL = khách chưa đăng nhập (chỉ tồn tại trong session app)
        index=True,
    )
    title = Column(String(255), nullable=True)  # Auto-generated từ tin nhắn đầu tiên
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Relationships
    user = relationship("User", backref="chat_conversations")
    messages = relationship(
        "ChatMessage",
        back_populates="conversation",
        cascade="all, delete-orphan",
        order_by="ChatMessage.created_at",
    )


class ChatMessage(Base):
    """Một tin nhắn trong cuộc trò chuyện."""
    __tablename__ = "chat_messages"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    conversation_id = Column(
        UUID(as_uuid=True),
        ForeignKey("chat_conversations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    role = Column(String(20), nullable=False)  # 'user' | 'assistant'
    content = Column(Text, nullable=False)
    intent_type = Column(String(50), nullable=True)  # 'product_search', 'general_knowledge', etc.
    products_data = Column(JSONB, nullable=True)  # Snapshot sản phẩm trả về (nếu có)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    conversation = relationship("ChatConversation", back_populates="messages")
