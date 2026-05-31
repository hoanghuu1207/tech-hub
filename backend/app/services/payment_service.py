"""
PaymentService — Tích hợp PayOS Gateway.

Flow:
    1. create_payment_link() → Gọi PayOS API tạo link thanh toán
    2. handle_webhook() → Xử lý callback từ PayOS, cập nhật trạng thái
    3. verify_webhook() → Xác thực chữ ký webhook
"""

import time
import hmac
import hashlib
import json
import logging
from decimal import Decimal
from typing import Optional
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import settings
from app.models.order import Order, OrderItem, Payment, CartItem, Address
from app.models.product import Product, ProductVariant, ProductImage
from app.models.user import User
from app.schemas.order import (
    CreateOrderRequest, CreateOrderResponse, OrderItemCreate,
)

logger = logging.getLogger("payment")
logger.setLevel(logging.INFO)
if not logger.handlers:
    ch = logging.StreamHandler()
    ch.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    ch.setFormatter(formatter)
    logger.addHandler(ch)

# PayOS config
PAYOS_CLIENT_ID = settings.PAYOS_CLIENT_ID
PAYOS_API_KEY = settings.PAYOS_API_KEY
PAYOS_CHECKSUM_KEY = settings.PAYOS_CHECKSUM_KEY

RETURN_URL = "techshop://payment/success"
CANCEL_URL = "techshop://payment/cancel"

def _build_return_url(order_id) -> str:
    base = settings.PAYMENT_REDIRECT_BASE_URL.rstrip("/")
    return f"{base}/api/v1/payment/result?status=success&orderId={order_id}"

def _build_cancel_url(order_id) -> str:
    base = settings.PAYMENT_REDIRECT_BASE_URL.rstrip("/")
    return f"{base}/api/v1/payment/result?status=cancelled&orderId={order_id}"


class PaymentService:
    """Service tích hợp PayOS cho thanh toán đơn hàng."""

    def __init__(self):
        try:
            from payos import PayOS
            self._payos = PayOS(
                client_id=PAYOS_CLIENT_ID,
                api_key=PAYOS_API_KEY,
                checksum_key=PAYOS_CHECKSUM_KEY,
            )
            logger.info("💳 [PayOS] Initialized successfully")
        except Exception as e:
            logger.error(f"💳 [PayOS] Init failed: {e}")
            self._payos = None

    # ────────────────────────────────────────────────────────
    # PUBLIC: Create Order + Payment Link
    # ────────────────────────────────────────────────────────

    async def create_order(
        self,
        request: CreateOrderRequest,
        user: User,
        db: AsyncSession,
    ) -> CreateOrderResponse:
        """Tạo đơn hàng + PayOS payment link."""

        logger.info(f"💳 [Order] Creating order for user {user.id} | {len(request.items)} items")

        # ── 1. Resolve shipping address ──
        address_id = None
        if request.address_id:
            address_id = request.address_id
        elif request.shipping_address:
            # Tạo address mới
            addr = Address(
                user_id=user.id,
                recipient_name=request.shipping_address.recipient_name,
                phone=request.shipping_address.phone,
                province=request.shipping_address.province,
                district=request.shipping_address.district,
                ward=request.shipping_address.ward,
                street=request.shipping_address.street,
            )
            db.add(addr)
            await db.flush()
            address_id = addr.id
        else:
            # Dùng default address
            stmt = select(Address).where(
                Address.user_id == user.id,
                Address.is_default == True,
            )
            result = await db.execute(stmt)
            default_addr = result.scalar_one_or_none()
            if default_addr:
                address_id = default_addr.id

        # ── 2. Validate items + Tính giá ──
        total_amount = Decimal("0")
        order_items = []
        payos_items = []  # Items cho PayOS

        for item_req in request.items:
            product = await db.get(Product, item_req.product_id)
            if not product or not product.is_active:
                raise ValueError(f"Sản phẩm {item_req.product_id} không tồn tại hoặc đã ngừng bán.")

            # Lấy giá (variant hoặc base)
            unit_price = product.sale_price if product.sale_price else product.base_price
            variant = None
            if item_req.variant_id:
                variant = await db.get(ProductVariant, item_req.variant_id)
                if not variant or not variant.is_active:
                    raise ValueError(f"Variant {item_req.variant_id} không tồn tại hoặc đã ngừng bán.")
                # Giá variant: ưu tiên sale_price_override > price_override > base
                if variant.sale_price_override:
                    unit_price = variant.sale_price_override
                elif variant.price_override:
                    unit_price = variant.price_override
                # Check stock
                if variant.stock_quantity < item_req.quantity:
                    if variant.stock_quantity == 0:
                        raise ValueError(f"Sản phẩm \"{product.name}\" (màu {variant.color_name}) đã hết hàng.")
                    else:
                        raise ValueError(
                            f"Sản phẩm \"{product.name}\" (màu {variant.color_name}) "
                            f"chỉ còn {variant.stock_quantity}, bạn yêu cầu {item_req.quantity}."
                        )

            subtotal = unit_price * item_req.quantity
            total_amount += subtotal

            order_items.append({
                "product_id": item_req.product_id,
                "variant_id": item_req.variant_id,
                "quantity": item_req.quantity,
                "unit_price": unit_price,
                "subtotal": subtotal,
            })

            payos_items.append({
                "name": product.name[:256],  # PayOS giới hạn 256 ký tự
                "quantity": item_req.quantity,
                "price": int(unit_price),
            })

        # ── 3. Tạo Order ──
        order_code = int(time.time() * 1000) % 2147483647  # PayOS yêu cầu int32 max

        order = Order(
            user_id=user.id,
            address_id=address_id,
            order_code=order_code,
            status="pending",
            total_amount=total_amount,
            discount_amount=Decimal("0"),
            shipping_fee=Decimal("0"),
            payment_method=request.payment_method,
            payment_status="pending",
            note=request.note,
        )
        db.add(order)
        await db.flush()

        # Tạo order items
        for item_data in order_items:
            db.add(OrderItem(
                order_id=order.id,
                product_id=item_data["product_id"],
                variant_id=item_data["variant_id"],
                quantity=item_data["quantity"],
                unit_price=item_data["unit_price"],
                subtotal=item_data["subtotal"],
            ))

        # ── 4. Tạo PayOS payment link ──
        checkout_url = None
        qr_code = None

        if request.payment_method == "payos" and self._payos:
            try:
                from payos.types import CreatePaymentLinkRequest, ItemData

                payos_item_list = [
                    ItemData(name=it["name"], quantity=it["quantity"], price=it["price"])
                    for it in payos_items
                ]

                payment_data = CreatePaymentLinkRequest(
                    orderCode=order_code,
                    amount=int(total_amount),
                    description=f"TechShop #{order_code}",
                    items=payos_item_list,
                    returnUrl=_build_return_url(str(order.id)),
                    cancelUrl=_build_cancel_url(str(order.id)),
                    expiredAt=int(time.time()) + 15 * 60,  # 15 phút
                )

                payos_response = self._payos.payment_requests.create(payment_data)
                checkout_url = payos_response.checkout_url
                qr_code = payos_response.qr_code


                # Lưu payment record
                db.add(Payment(
                    order_id=order.id,
                    gateway="payos",
                    amount=total_amount,
                    currency="VND",
                    status="pending",
                    transaction_id=str(order_code),
                    gateway_response={
                        "checkout_url": checkout_url,
                        "qr_code": qr_code,
                        "order_code": order_code,
                    },
                ))

                logger.info(f"💳 [PayOS] Payment link created: {checkout_url}")

            except Exception as e:
                logger.error(f"💳 [PayOS] Error creating payment: {e}", exc_info=True)
                # Vẫn tạo đơn, chỉ không có payment link
                order.payment_status = "failed"
        elif request.payment_method == "cod":
            # COD — không cần payment link
            order.payment_status = "cod_pending"
            db.add(Payment(
                order_id=order.id,
                gateway="cod",
                amount=total_amount,
                currency="VND",
                status="cod_pending",
            ))

        # ── 5. Xóa cart items đã mua ──
        # Chỉ xóa ngay cho COD; PayOS sẽ xóa trong webhook khi thanh toán thành công
        if request.payment_method == "cod":
            product_ids = [item.product_id for item in request.items]
            stmt = select(CartItem).where(
                CartItem.user_id == user.id,
                CartItem.product_id.in_(product_ids),
            )
            result = await db.execute(stmt)
            for cart_item in result.scalars().all():
                await db.delete(cart_item)

        await db.commit()

        logger.info(f"💳 [Order] Created #{order_code} | Total: {total_amount} | Method: {request.payment_method}")

        return CreateOrderResponse(
            order_id=order.id,
            order_code=order_code,
            status=order.status,
            payment_status=order.payment_status,
            total_amount=float(total_amount),
            checkout_url=checkout_url,
            qr_code=qr_code,
        )

    # ────────────────────────────────────────────────────────
    # PUBLIC: PayOS Webhook
    # ────────────────────────────────────────────────────────

    async def handle_webhook(self, webhook_body: dict, db: AsyncSession) -> dict:
        """Xử lý webhook callback từ PayOS."""

        logger.info(f"💳 [Webhook] Received: {json.dumps(webhook_body, default=str)[:500]}")

        try:
            data = webhook_body.get("data", {})
            order_code = data.get("orderCode")
            code = data.get("code")  # "00" = success
            desc = data.get("desc", "")
            transaction_reference = data.get("reference", "")

            if not order_code:
                logger.warning("💳 [Webhook] Missing orderCode")
                return {"success": False, "message": "Missing orderCode"}

            # Verify webhook signature
            if not self._verify_webhook_signature(webhook_body):
                logger.warning("💳 [Webhook] Invalid signature!")
                return {"success": False, "message": "Invalid signature"}

            # Tìm order kèm items
            stmt = (
                select(Order)
                .options(
                    selectinload(Order.items).selectinload(OrderItem.variant),
                    selectinload(Order.items).selectinload(OrderItem.product),
                )
                .where(Order.order_code == order_code)
            )
            result = await db.execute(stmt)
            order = result.scalar_one_or_none()

            if not order:
                logger.warning(f"💳 [Webhook] Order not found: {order_code}")
                return {"success": False, "message": "Order not found"}

            # Cập nhật trạng thái
            if code == "00":
                order.payment_status = "paid"
                order.status = "confirmed"

                # ── Trừ tồn kho (stock deduction) ──
                for item in order.items:
                    if item.variant_id and item.variant:
                        item.variant.stock_quantity = max(0, item.variant.stock_quantity - item.quantity)
                        logger.info(
                            f"💳 [Stock] {item.product.name if item.product else 'N/A'} "
                            f"({item.variant.color_name}) -{item.quantity} → còn {item.variant.stock_quantity}"
                        )
                    # Cập nhật sold_count trên Product
                    if item.product:
                        item.product.sold_count = (item.product.sold_count or 0) + item.quantity

                # ── Xóa cart items sau khi thanh toán thành công ──
                product_ids = [item.product_id for item in order.items]
                cart_stmt = select(CartItem).where(
                    CartItem.user_id == order.user_id,
                    CartItem.product_id.in_(product_ids),
                )
                cart_result = await db.execute(cart_stmt)
                for cart_item in cart_result.scalars().all():
                    await db.delete(cart_item)
                logger.info(f"💳 [Cart] Cleared {len(product_ids)} cart items after payment")

                logger.info(f"💳 [Webhook] ✅ Order #{order_code} PAID + Stock deducted")
            else:
                order.payment_status = "failed"
                order.status = "cancelled"
                logger.info(f"💳 [Webhook] ❌ Order #{order_code} FAILED: {desc}")

            # Cập nhật payment record
            stmt_payment = select(Payment).where(Payment.order_id == order.id)
            result_payment = await db.execute(stmt_payment)
            payment = result_payment.scalar_one_or_none()

            if payment:
                payment.status = "paid" if code == "00" else "failed"
                payment.transaction_id = str(transaction_reference or order_code)
                if code == "00":
                    from datetime import datetime, timezone
                    payment.paid_at = datetime.now(timezone.utc)
                payment.gateway_response = {
                    **(payment.gateway_response or {}),
                    "webhook_code": code,
                    "webhook_desc": desc,
                    "webhook_reference": transaction_reference,
                }

            await db.commit()
            return {"success": True, "message": f"Order #{order_code} updated"}

        except Exception as e:
            logger.error(f"💳 [Webhook] Error: {e}", exc_info=True)
            await db.rollback()
            return {"success": False, "message": str(e)}

    def _verify_webhook_signature(self, webhook_body: dict) -> bool:
        """Xác thực chữ ký webhook PayOS bằng HMAC-SHA256."""
        try:
            if self._payos:
                # Dùng SDK verify nếu có
                self._payos.verifyPaymentWebhookData(webhook_body)
                return True
        except Exception:
            pass

        # Fallback: manual verify
        try:
            data = webhook_body.get("data", {})
            signature = webhook_body.get("signature", "")

            if not signature:
                return False

            # PayOS tạo signature từ sorted data string
            sorted_data = "&".join(
                f"{k}={data[k]}" for k in sorted(data.keys())
            )
            computed = hmac.new(
                PAYOS_CHECKSUM_KEY.encode("utf-8"),
                sorted_data.encode("utf-8"),
                hashlib.sha256,
            ).hexdigest()

            return hmac.compare_digest(computed, signature)
        except Exception:
            return False

    # ────────────────────────────────────────────────────────
    # PUBLIC: Order Management
    # ────────────────────────────────────────────────────────

    async def get_user_orders(self, user_id: UUID, db: AsyncSession, limit: int = 20):
        """Lấy danh sách đơn hàng của user."""
        stmt = (
            select(Order)
            .options(
                selectinload(Order.items).selectinload(OrderItem.product).selectinload(Product.images),
                selectinload(Order.address),
            )
            .where(Order.user_id == user_id)
            .order_by(Order.created_at.desc())
            .limit(limit)
        )
        result = await db.execute(stmt)
        return result.scalars().all()

    async def get_order_detail(self, order_id: UUID, user_id: UUID, db: AsyncSession):
        """Lấy chi tiết đơn hàng."""
        stmt = (
            select(Order)
            .options(
                selectinload(Order.items).selectinload(OrderItem.product).selectinload(Product.images),
                selectinload(Order.items).selectinload(OrderItem.variant),
                selectinload(Order.address),
                selectinload(Order.payment_details),
            )
            .where(Order.id == order_id, Order.user_id == user_id)
        )
        result = await db.execute(stmt)
        return result.scalar_one_or_none()

    async def cancel_order(self, order_id: UUID, user_id: UUID, db: AsyncSession) -> dict:
        """Hủy đơn hàng (chỉ khi chưa thanh toán)."""
        order = await self.get_order_detail(order_id, user_id, db)

        if not order:
            return {"success": False, "message": "Đơn hàng không tồn tại."}

        if order.payment_status == "paid":
            return {"success": False, "message": "Không thể hủy đơn hàng đã thanh toán."}

        if order.status in ("cancelled", "delivered"):
            return {"success": False, "message": f"Đơn hàng đã ở trạng thái: {order.status}"}

        # Hủy trên PayOS nếu có
        if order.order_code and self._payos:
            try:
                self._payos.cancelPaymentLink(order.order_code)
                logger.info(f"💳 [PayOS] Cancelled payment link #{order.order_code}")
            except Exception as e:
                logger.warning(f"💳 [PayOS] Cancel failed (may already be cancelled): {e}")

        order.status = "cancelled"
        order.payment_status = "cancelled"

        # Cập nhật payment record
        if order.payment_details:
            order.payment_details.status = "cancelled"

        await db.commit()
        logger.info(f"💳 [Order] Cancelled #{order.order_code}")
        return {"success": True, "message": "Đơn hàng đã được hủy."}

    async def create_order_from_cart(self, user: User, db: AsyncSession,
                                      note: Optional[str] = None,
                                      address_id: Optional[UUID] = None) -> CreateOrderResponse:
        """Tạo đơn hàng từ toàn bộ giỏ hàng hiện tại."""
        stmt = select(CartItem).options(
            selectinload(CartItem.product),
        ).where(CartItem.user_id == user.id)
        result = await db.execute(stmt)
        cart_items = result.scalars().all()

        if not cart_items:
            raise ValueError("Giỏ hàng trống.")

        items = [
            OrderItemCreate(
                product_id=ci.product_id,
                variant_id=ci.variant_id,
                quantity=ci.quantity,
            )
            for ci in cart_items
        ]

        request = CreateOrderRequest(
            items=items,
            address_id=address_id,
            note=note or "Đặt hàng từ giỏ hàng",
            payment_method="payos",
        )

        return await self.create_order(request, user, db)


# Singleton
payment_service = PaymentService()
