"""
Order endpoints — Quản lý đơn hàng + Checkout.
"""

from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.core.dependencies import get_current_user
from app.models.user import User
from app.schemas.order import (
    CreateOrderRequest, CheckoutResponse, OrderListResponse,
    OrderDetailResponse, OrderOut, OrderItemOut, AddressOut,
)
from app.services.payment_service import payment_service

router = APIRouter()


def _get_product_image(product) -> str | None:
    """Lấy ảnh chính của sản phẩm từ relationship images."""
    if not product or not hasattr(product, 'images') or not product.images:
        return None
    # Ưu tiên ảnh is_primary, fallback ảnh đầu tiên
    for img in product.images:
        if img.is_primary:
            return img.image_url
    return product.images[0].image_url if product.images else None


@router.post("", response_model=CheckoutResponse, summary="Tạo đơn hàng + Payment Link")
async def create_order(
    request: CreateOrderRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Tạo đơn hàng mới.

    - **items**: Danh sách sản phẩm (product_id, quantity)
    - **address_id**: ID địa chỉ đã lưu (hoặc dùng shipping_address)
    - **payment_method**: `payos` (QR/chuyển khoản) hoặc `cod` (thanh toán khi nhận hàng)

    Response chứa `checkout_url` để mở trang thanh toán PayOS.
    """
    try:
        result = await payment_service.create_order(request, user, db)
        return CheckoutResponse(
            success=True,
            message="Đơn hàng đã được tạo thành công",
            data=result,
        )
    except ValueError as e:
        return CheckoutResponse(success=False, message=str(e), error=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("", response_model=OrderListResponse, summary="Danh sách đơn hàng")
async def list_orders(
    limit: int = 20,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Lấy danh sách đơn hàng của user hiện tại."""
    orders = await payment_service.get_user_orders(user.id, db, limit)

    data = []
    for order in orders:
        items_out = []
        for item in order.items:
            items_out.append(OrderItemOut(
                id=item.id,
                product_id=item.product_id,
                variant_id=item.variant_id,
                quantity=item.quantity,
                unit_price=float(item.unit_price),
                subtotal=float(item.subtotal),
                product_name=item.product.name if item.product else None,
                product_image=_get_product_image(item.product),
            ))

        address_out = None
        if order.address:
            address_out = AddressOut(
                id=order.address.id,
                recipient_name=order.address.recipient_name,
                phone=order.address.phone,
                province=order.address.province,
                district=order.address.district,
                ward=order.address.ward,
                street=order.address.street,
            )

        data.append(OrderOut(
            id=order.id,
            order_code=order.order_code,
            status=order.status,
            total_amount=float(order.total_amount),
            discount_amount=float(order.discount_amount or 0),
            shipping_fee=float(order.shipping_fee or 0),
            payment_method=order.payment_method,
            payment_status=order.payment_status,
            note=order.note,
            created_at=order.created_at,
            updated_at=order.updated_at,
            items=items_out,
            address=address_out,
        ))

    return OrderListResponse(data=data)


@router.get("/{order_id}", response_model=OrderDetailResponse, summary="Chi tiết đơn hàng")
async def get_order(
    order_id: UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Xem chi tiết một đơn hàng."""
    order = await payment_service.get_order_detail(order_id, user.id, db)

    if not order:
        return OrderDetailResponse(success=False, message="Đơn hàng không tồn tại", error="not_found")

    items_out = [
        OrderItemOut(
            id=item.id,
            product_id=item.product_id,
            variant_id=item.variant_id,
            quantity=item.quantity,
            unit_price=float(item.unit_price),
            subtotal=float(item.subtotal),
            product_name=item.product.name if item.product else None,
            product_image=_get_product_image(item.product),
        )
        for item in order.items
    ]

    address_out = None
    if order.address:
        address_out = AddressOut(
            id=order.address.id,
            recipient_name=order.address.recipient_name,
            phone=order.address.phone,
            province=order.address.province,
            district=order.address.district,
            ward=order.address.ward,
            street=order.address.street,
        )

    return OrderDetailResponse(
        data=OrderOut(
            id=order.id,
            order_code=order.order_code,
            status=order.status,
            total_amount=float(order.total_amount),
            discount_amount=float(order.discount_amount or 0),
            shipping_fee=float(order.shipping_fee or 0),
            payment_method=order.payment_method,
            payment_status=order.payment_status,
            note=order.note,
            created_at=order.created_at,
            updated_at=order.updated_at,
            items=items_out,
            address=address_out,
        )
    )


@router.post("/{order_id}/cancel", summary="Hủy đơn hàng")
async def cancel_order(
    order_id: UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Hủy đơn hàng (chỉ khi chưa thanh toán)."""
    result = await payment_service.cancel_order(order_id, user.id, db)
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["message"])
    return result
