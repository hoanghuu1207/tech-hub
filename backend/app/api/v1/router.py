from fastapi import APIRouter
from app.api.v1.endpoints import auth, ai, chat, orders, webhook

api_router = APIRouter()

# Mount auth sub-router vào hệ thống
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])

# Mount AI search sub-router vào hệ thống
api_router.include_router(ai.router, prefix="/ai", tags=["ai"])

# Mount Chat sub-router vào hệ thống
api_router.include_router(chat.router, prefix="/chat", tags=["chat"])

# Mount Order sub-router vào hệ thống
api_router.include_router(orders.router, prefix="/orders", tags=["orders"])

# Mount Webhook sub-router (PayOS callback — NO AUTH)
api_router.include_router(webhook.router, prefix="/webhook", tags=["webhook"])
