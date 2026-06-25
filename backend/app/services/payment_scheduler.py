"""
PaymentScheduler — Background task kiểm tra & hủy đơn hàng PayOS hết hạn.

Chạy định kỳ mỗi 60 giây, quét các đơn có:
  - payment_method = "payos"
  - payment_status = "pending"
  - payment_expires_at <= now()

→ Set status = "cancelled", payment_status = "failed"
"""

import asyncio
import logging
from datetime import datetime, timezone

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import SessionLocal
from app.models.order import Order, Payment

logger = logging.getLogger("payment_scheduler")
logger.setLevel(logging.INFO)
if not logger.handlers:
    ch = logging.StreamHandler()
    ch.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    ch.setFormatter(formatter)
    logger.addHandler(ch)

# Interval giữa các lần quét (seconds)
SCAN_INTERVAL = 60


async def _expire_pending_orders():
    """Quét và hủy các đơn PayOS pending đã hết hạn thanh toán."""
    async with SessionLocal() as db:
        try:
            now = datetime.now(timezone.utc)

            # Tìm các đơn PayOS pending đã quá hạn
            stmt = (
                select(Order)
                .where(
                    Order.payment_method == "payos",
                    Order.payment_status == "pending",
                    Order.payment_expires_at.isnot(None),
                    Order.payment_expires_at <= now,
                )
            )
            result = await db.execute(stmt)
            expired_orders = result.scalars().all()

            if not expired_orders:
                return

            logger.info(f"⏰ [Scheduler] Found {len(expired_orders)} expired PayOS orders")

            for order in expired_orders:
                order.status = "cancelled"
                order.payment_status = "failed"

                # Cập nhật payment record
                payment_stmt = select(Payment).where(Payment.order_id == order.id)
                payment_result = await db.execute(payment_stmt)
                payment = payment_result.scalar_one_or_none()
                if payment:
                    payment.status = "failed"
                    payment.gateway_response = {
                        **(payment.gateway_response or {}),
                        "expired_reason": "Payment link expired (auto-cancelled by scheduler)",
                        "expired_at": now.isoformat(),
                    }

                logger.info(
                    f"⏰ [Scheduler] Expired order #{order.order_code} "
                    f"(created: {order.created_at}, expires: {order.payment_expires_at})"
                )

            await db.commit()
            logger.info(f"⏰ [Scheduler] ✅ Cancelled {len(expired_orders)} expired orders")

        except Exception as e:
            logger.error(f"⏰ [Scheduler] Error: {e}", exc_info=True)
            await db.rollback()


async def run_payment_expiry_scheduler():
    """
    Background loop — chạy vĩnh viễn, quét mỗi SCAN_INTERVAL giây.
    Được khởi động khi FastAPI startup và cancel khi shutdown.
    """
    logger.info(f"⏰ [Scheduler] Started — scanning every {SCAN_INTERVAL}s for expired PayOS orders")
    while True:
        await _expire_pending_orders()
        await asyncio.sleep(SCAN_INTERVAL)
