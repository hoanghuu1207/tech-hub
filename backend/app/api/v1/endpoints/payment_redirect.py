"""
Payment Redirect — Trung gian giữa PayOS và Flutter app.

PayOS redirect browser tới đây → Backend cập nhật DB → trả HTML chứa deep link →
Flutter WebView bắt deep link và navigate sang PaymentResultScreen.
"""

import logging
from uuid import UUID

from fastapi import APIRouter, Query, Depends
from fastapi.responses import HTMLResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models.order import Order, Payment

logger = logging.getLogger("payment_redirect")
router = APIRouter()

DEEP_LINK_SCHEME = "techhub"


@router.get("/result", response_class=HTMLResponse, summary="Payment redirect page")
async def payment_result(
    status: str = Query("success", description="success hoặc cancelled"),
    orderId: str = Query("", description="Order ID"),
    db: AsyncSession = Depends(get_db),
):
    """
    Trang trung gian sau khi PayOS thanh toán xong.

    - Nếu status=cancelled → cập nhật payment_status='failed', status='cancelled'
    - Sau đó redirect Flutter app qua deep link.
    """

    # ── Cập nhật DB khi thanh toán bị hủy/thất bại ──
    if status == "cancelled" and orderId:
        try:
            order_uuid = UUID(orderId)
            stmt = select(Order).where(Order.id == order_uuid)
            result = await db.execute(stmt)
            order = result.scalar_one_or_none()

            if order and order.payment_status == "pending":
                order.payment_status = "failed"
                order.status = "cancelled"

                # Cập nhật payment record
                stmt_payment = select(Payment).where(Payment.order_id == order.id)
                result_payment = await db.execute(stmt_payment)
                payment = result_payment.scalar_one_or_none()
                if payment and payment.status == "pending":
                    payment.status = "failed"
                    payment.gateway_response = {
                        **(payment.gateway_response or {}),
                        "cancel_reason": "user_cancelled_on_payos",
                    }

                await db.commit()
                logger.info(f"💳 [Redirect] Order {orderId} → payment_status=failed, status=cancelled")
            else:
                logger.info(f"💳 [Redirect] Order {orderId} already processed (status={order.status if order else 'not_found'})")

        except Exception as e:
            logger.error(f"💳 [Redirect] Error updating order {orderId}: {e}")
            # Không rollback — vẫn redirect user về app

    deep_link = f"{DEEP_LINK_SCHEME}://payment/result?status={status}&orderId={orderId}"
    
    status_text = "Thanh toán thành công!" if status == "success" else "Thanh toán đã bị hủy"
    status_color = "#10B981" if status == "success" else "#EF4444"
    status_icon = "✅" if status == "success" else "❌"
    
    html = f"""
    <!DOCTYPE html>
    <html lang="vi">
    <head>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
        <title>TechHub - {status_text}</title>
        <style>
            body {{
                font-family: 'Segoe UI', sans-serif;
                background: #0F172A;
                color: white;
                display: flex;
                justify-content: center;
                align-items: center;
                min-height: 100vh;
                margin: 0;
            }}
            .card {{
                text-align: center;
                padding: 48px 32px;
                background: rgba(30, 41, 59, 0.8);
                border-radius: 24px;
                max-width: 400px;
                margin: 16px;
            }}
            .icon {{ font-size: 64px; margin-bottom: 16px; }}
            h1 {{ color: {status_color}; font-size: 24px; margin: 0 0 8px; }}
            p {{ color: #94A3B8; font-size: 14px; margin: 16px 0; }}
            .btn {{
                display: inline-block;
                padding: 14px 32px;
                background: #6366F1;
                color: white;
                border-radius: 12px;
                text-decoration: none;
                font-weight: 600;
                margin-top: 16px;
            }}
        </style>
    </head>
    <body>
        <div class="card">
            <div class="icon">{status_icon}</div>
            <h1>{status_text}</h1>
            <p>Đang chuyển về ứng dụng TechHub...</p>
            <a class="btn" href="{deep_link}">Mở ứng dụng TechHub</a>
        </div>
        <script>
            // Tự động redirect sau 1 giây
            setTimeout(function() {{
                window.location.href = "{deep_link}";
            }}, 1000);
        </script>
    </body>
    </html>
    """
    return HTMLResponse(content=html)
