"""
Notifications API — Quản lý thông báo cho user.
"""

from uuid import UUID
from typing import Optional, List
from datetime import datetime

from pydantic import BaseModel
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, update, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.core.dependencies import get_current_user
from app.models.user import User
from app.models.interaction import Notification

router = APIRouter()


# ── Schemas ──

class NotificationOut(BaseModel):
    id: UUID
    type: Optional[str]
    title: str
    body: Optional[str]
    data: Optional[dict]
    is_read: bool
    created_at: datetime

    class Config:
        from_attributes = True


class NotificationListResponse(BaseModel):
    success: bool
    data: List[NotificationOut]
    unread_count: int


class UnreadCountResponse(BaseModel):
    success: bool
    unread_count: int


# ── Endpoints ──

@router.get("", response_model=NotificationListResponse, summary="Lấy danh sách thông báo")
async def get_notifications(
    limit: int = 50,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(Notification)
        .where(Notification.user_id == user.id)
        .order_by(Notification.created_at.desc())
        .limit(limit)
    )
    result = await db.execute(stmt)
    notifications = result.scalars().all()

    # Unread count
    count_stmt = (
        select(func.count())
        .select_from(Notification)
        .where(Notification.user_id == user.id, Notification.is_read == False)
    )
    count_result = await db.execute(count_stmt)
    unread_count = count_result.scalar() or 0

    return NotificationListResponse(
        success=True,
        data=[
            NotificationOut(
                id=n.id,
                type=n.type,
                title=n.title,
                body=n.body,
                data=n.data,
                is_read=n.is_read,
                created_at=n.created_at,
            )
            for n in notifications
        ],
        unread_count=unread_count,
    )


@router.get("/unread-count", response_model=UnreadCountResponse, summary="Đếm thông báo chưa đọc")
async def get_unread_count(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(func.count())
        .select_from(Notification)
        .where(Notification.user_id == user.id, Notification.is_read == False)
    )
    result = await db.execute(stmt)
    count = result.scalar() or 0
    return UnreadCountResponse(success=True, unread_count=count)


@router.put("/{notification_id}/read", summary="Đánh dấu đã đọc")
async def mark_as_read(
    notification_id: UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Notification).where(
        Notification.id == notification_id,
        Notification.user_id == user.id,
    )
    result = await db.execute(stmt)
    notif = result.scalar_one_or_none()

    if not notif:
        raise HTTPException(status_code=404, detail="Thông báo không tồn tại")

    notif.is_read = True
    await db.commit()
    return {"success": True, "message": "Đã đánh dấu đọc"}


@router.put("/read-all", summary="Đánh dấu tất cả đã đọc")
async def mark_all_as_read(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        update(Notification)
        .where(Notification.user_id == user.id, Notification.is_read == False)
        .values(is_read=True)
    )
    await db.execute(stmt)
    await db.commit()
    return {"success": True, "message": "Đã đánh dấu tất cả đã đọc"}


class RegisterTokenRequest(BaseModel):
    fcm_token: str


@router.post("/register-token", summary="Đăng ký FCM device token")
async def register_fcm_token(
    body: RegisterTokenRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Lưu FCM token để backend có thể gửi push notification khi app không mở."""
    user.fcm_token = body.fcm_token
    await db.commit()
    return {"success": True, "message": "FCM token registered"}
