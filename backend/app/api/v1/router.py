from fastapi import APIRouter
from app.api.v1.endpoints import auth, ai

api_router = APIRouter()

# Mount auth sub-router vào hệ thống
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])

# Mount AI search sub-router vào hệ thống
api_router.include_router(ai.router, prefix="/ai", tags=["ai"])
