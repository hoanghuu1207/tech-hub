from fastapi import APIRouter
from app.api.v1.endpoints import auth, ai, chat

api_router = APIRouter()

# Mount auth sub-router vào hệ thống
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])

# Mount AI search sub-router vào hệ thống
api_router.include_router(ai.router, prefix="/ai", tags=["ai"])

# Mount Chat sub-router vào hệ thống
api_router.include_router(chat.router, prefix="/chat", tags=["chat"])
