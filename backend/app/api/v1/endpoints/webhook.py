"""
Webhook endpoints — Nhận callback từ PayOS.

QUAN TRỌNG: Endpoint webhook KHÔNG cần authentication.
PayOS gửi POST request kèm signature để xác thực.
"""

import logging
from fastapi import APIRouter, Request, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.services.payment_service import payment_service

logger = logging.getLogger("webhook")
router = APIRouter()


@router.post("/payos", summary="PayOS Webhook Callback")
async def payos_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """
    Endpoint nhận webhook callback từ PayOS sau khi thanh toán.

    Xử lý 2 loại request:
    1. **Verification request**: PayOS gửi khi đăng ký webhook URL
       - data.description chứa "success" và code = "00"
       - orderCode = 0 (hoặc giá trị test)
    2. **Payment callback**: Sau khi user thanh toán thành công/thất bại

    PayOS gửi body dạng:
    ```json
    {
        "code": "00",
        "desc": "success",
        "data": {
            "orderCode": 123456789,
            "amount": 10000,
            "description": "...",
            "accountNumber": "...",
            "reference": "...",
            "transactionDateTime": "...",
            "paymentLinkId": "...",
            "code": "00",
            "desc": "success"
        },
        "signature": "..."
    }
    ```

    - code "00" = thanh toán thành công
    - Các code khác = thất bại
    """
    try:
        body = await request.json()
    except Exception:
        return {"success": False, "message": "Invalid JSON body"}

    logger.info(f"🔔 [Webhook] Received POST: {str(body)[:500]}")

    # ── Kiểm tra PayOS verification/confirm request ──
    # Khi đăng ký webhook URL, PayOS gửi request test với:
    #   code = "00", data.description = "success", data.orderCode = 0
    data = body.get("data", {})
    code = body.get("code", "")

    # PayOS confirm webhook URL: trả 200 OK ngay lập tức
    if (code == "00"
        and data.get("orderCode") == 0
        and data.get("description") == "success"):
        logger.info("🔔 [Webhook] PayOS webhook URL verification → OK")
        return {"success": True, "message": "Webhook verified"}

    # ── Xử lý payment callback thực tế ──
    result = await payment_service.handle_webhook(body, db)

    # PayOS yêu cầu trả 200 OK
    return result
