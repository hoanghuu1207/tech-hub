import uuid
from sqlalchemy import Column, String, Boolean, DateTime, Integer, ForeignKey, Text, SmallInteger
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.db.base import Base

class Review(Base):
    __tablename__ = "reviews"

    id = Column("review_id", UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    product_id = Column(UUID(as_uuid=True), ForeignKey("products.product_id", ondelete="CASCADE"), nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    order_item_id = Column(UUID(as_uuid=True), ForeignKey("order_items.item_id", ondelete="SET NULL"), nullable=True)
    
    rating = Column(SmallInteger, nullable=False)
    comment = Column(Text, nullable=True)
    is_verified = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    product = relationship("Product", back_populates="reviews")
    user = relationship("User", back_populates="reviews")
    order_item = relationship("OrderItem")


class Notification(Base):
    __tablename__ = "notifications"

    id = Column("notification_id", UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    type = Column(String(50), nullable=True)
    title = Column(String(255), nullable=False)
    body = Column(Text, nullable=True)
    data = Column(JSONB, nullable=True)
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    user = relationship("User", back_populates="notifications")
