from fastapi import APIRouter
from app.api.v1.endpoints import auth, ai, chat, orders, webhook, cart, payment_redirect, catalog

api_router = APIRouter()

# Mount Catalog sub-router (Categories, Brands, ProductLines)
api_router.include_router(catalog.router, prefix="/catalog", tags=["catalog"])

# Mount auth sub-router vào hệ thống
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])

# Mount AI search sub-router vào hệ thống
api_router.include_router(ai.router, prefix="/ai", tags=["ai"])

# Mount Chat sub-router vào hệ thống
api_router.include_router(chat.router, prefix="/chat", tags=["chat"])

# Mount Cart sub-router vào hệ thống
api_router.include_router(cart.router, prefix="/cart", tags=["cart"])

# Mount Order sub-router vào hệ thống
api_router.include_router(orders.router, prefix="/orders", tags=["orders"])

# Mount Webhook sub-router (PayOS callback — NO AUTH)
api_router.include_router(webhook.router, prefix="/webhook", tags=["webhook"])

# Mount Payment Redirect sub-router (PayOS → deep link)
api_router.include_router(payment_redirect.router, prefix="/payment", tags=["Payment Redirect"])

