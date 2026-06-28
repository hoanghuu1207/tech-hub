"""
Admin API endpoints — Dashboard stats, CRUD sản phẩm, quản lý hệ thống.

Tất cả endpoints đều yêu cầu role = admin.
"""

from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, case, and_

from app.db.session import get_db
from app.core.dependencies import get_current_user
from app.models.user import User, UserRole
from app.models.product import Product, Category, Brand, ProductLine, ProductVariant, ProductImage
from app.models.order import Order, OrderItem
from app.models.interaction import Review

router = APIRouter()


# ─── Admin Dependency ────────────────────────────────────

async def require_admin(user: User = Depends(get_current_user)) -> User:
    """Dependency: chỉ cho phép user có role admin."""
    if user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="Admin access required")
    return user


# ─── Dashboard Stats ─────────────────────────────────────

@router.get("/dashboard/stats", summary="Thống kê tổng quan dashboard")
async def get_dashboard_stats(
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Trả về các chỉ số KPI cho dashboard."""
    now = datetime.now(timezone.utc)
    first_this_month = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    first_last_month = (first_this_month - timedelta(days=1)).replace(day=1)

    # Total revenue this month (from paid orders)
    rev_this = await db.execute(
        select(func.coalesce(func.sum(Order.total_amount), 0))
        .where(
            and_(
                Order.payment_status == "paid",
                Order.created_at >= first_this_month,
            )
        )
    )
    revenue_this_month = float(rev_this.scalar_one())

    rev_last = await db.execute(
        select(func.coalesce(func.sum(Order.total_amount), 0))
        .where(
            and_(
                Order.payment_status == "paid",
                Order.created_at >= first_last_month,
                Order.created_at < first_this_month,
            )
        )
    )
    revenue_last_month = float(rev_last.scalar_one())

    # Orders this month
    orders_this = await db.execute(
        select(func.count(Order.id)).where(Order.created_at >= first_this_month)
    )
    orders_count = orders_this.scalar_one()

    orders_last = await db.execute(
        select(func.count(Order.id)).where(
            and_(
                Order.created_at >= first_last_month,
                Order.created_at < first_this_month,
            )
        )
    )
    orders_last_count = orders_last.scalar_one()

    # New customers this month
    new_cust = await db.execute(
        select(func.count(User.id)).where(
            and_(
                User.role == UserRole.buyer,
                User.created_at >= first_this_month,
            )
        )
    )
    new_customers = new_cust.scalar_one()

    new_cust_last = await db.execute(
        select(func.count(User.id)).where(
            and_(
                User.role == UserRole.buyer,
                User.created_at >= first_last_month,
                User.created_at < first_this_month,
            )
        )
    )
    new_customers_last = new_cust_last.scalar_one()

    # Active products
    active_prod = await db.execute(
        select(func.count(Product.id)).where(Product.is_active == True)
    )
    active_products = active_prod.scalar_one()

    def pct_change(current: float, previous: float) -> float:
        if previous == 0:
            return 100.0 if current > 0 else 0.0
        return round(((current - previous) / previous) * 100, 1)

    return {
        "success": True,
        "data": {
            "total_revenue": revenue_this_month,
            "total_orders": orders_count,
            "new_customers": new_customers,
            "active_products": active_products,
            "revenue_change": pct_change(revenue_this_month, revenue_last_month),
            "orders_change": pct_change(orders_count, orders_last_count),
            "customers_change": pct_change(new_customers, new_customers_last),
        },
    }


@router.get("/dashboard/chart", summary="Dữ liệu chart doanh thu")
async def get_dashboard_chart(
    days: int = Query(30, ge=7, le=90),
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Doanh thu và số đơn theo ngày cho chart."""
    now = datetime.now(timezone.utc)
    start_date = now - timedelta(days=days)

    result = await db.execute(
        select(
            func.date(Order.created_at).label("date"),
            func.coalesce(func.sum(
                case(
                    (Order.payment_status == "paid", Order.total_amount),
                    else_=0,
                )
            ), 0).label("revenue"),
            func.count(Order.id).label("orders"),
        )
        .where(Order.created_at >= start_date)
        .group_by(func.date(Order.created_at))
        .order_by(func.date(Order.created_at))
    )

    data = [
        {"date": str(row.date), "revenue": float(row.revenue), "orders": row.orders}
        for row in result.all()
    ]

    return {"success": True, "data": data}


@router.get("/dashboard/order-status", summary="Thống kê trạng thái đơn hàng")
async def get_order_status_stats(
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Đếm đơn hàng theo status."""
    result = await db.execute(
        select(Order.status, func.count(Order.id).label("count"))
        .group_by(Order.status)
    )
    data = [{"status": row.status, "count": row.count} for row in result.all()]
    return {"success": True, "data": data}


@router.get("/dashboard/top-products", summary="Top sản phẩm bán chạy")
async def get_top_products(
    limit: int = Query(5, ge=1, le=20),
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Top N sản phẩm bán chạy nhất."""
    result = await db.execute(
        select(Product.id, Product.name, Product.sold_count)
        .where(Product.is_active == True)
        .order_by(Product.sold_count.desc())
        .limit(limit)
    )
    data = [
        {"id": str(row.id), "name": row.name, "sold_count": row.sold_count}
        for row in result.all()
    ]
    return {"success": True, "data": data}


@router.get("/dashboard/recent-orders", summary="Đơn hàng gần đây")
async def get_recent_orders(
    limit: int = Query(10, ge=1, le=50),
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Danh sách đơn hàng mới nhất."""
    from sqlalchemy.orm import selectinload

    result = await db.execute(
        select(Order)
        .options(selectinload(Order.user))
        .order_by(Order.created_at.desc())
        .limit(limit)
    )
    orders = result.scalars().all()

    data = [
        {
            "id": str(o.id),
            "order_code": o.order_code,
            "status": o.status,
            "total_amount": float(o.total_amount),
            "payment_status": o.payment_status,
            "payment_method": o.payment_method,
            "created_at": o.created_at.isoformat() if o.created_at else None,
            "user_name": o.user.full_name if o.user else None,
            "user_email": o.user.email if o.user else None,
        }
        for o in orders
    ]
    return {"success": True, "data": data}


# ─── Admin Order Management ─────────────────────────────

@router.get("/orders", summary="List all orders (admin)")
async def list_admin_orders(
    status: str | None = Query(None),
    payment_status: str | None = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """List all orders with optional filtering and pagination."""
    from sqlalchemy.orm import selectinload

    query = (
        select(Order)
        .options(
            selectinload(Order.user),
            selectinload(Order.address),
            selectinload(Order.items).selectinload(OrderItem.product).selectinload(Product.images),
        )
    )

    if status:
        query = query.where(Order.status == status)
    if payment_status:
        query = query.where(Order.payment_status == payment_status)

    # Count total
    from sqlalchemy import func as sa_func
    count_query = select(sa_func.count(Order.id))
    if status:
        count_query = count_query.where(Order.status == status)
    if payment_status:
        count_query = count_query.where(Order.payment_status == payment_status)
    total_result = await db.execute(count_query)
    total = total_result.scalar_one()

    # Paginate
    query = query.order_by(Order.created_at.desc()).offset((page - 1) * limit).limit(limit)
    result = await db.execute(query)
    orders = result.unique().scalars().all()

    def _get_product_image(product):
        if not product or not hasattr(product, 'images') or not product.images:
            return None
        for img in product.images:
            if img.is_primary:
                return img.image_url
        return product.images[0].image_url if product.images else None

    data = []
    for o in orders:
        items = [
            {
                "id": str(item.id),
                "product_id": str(item.product_id),
                "variant_id": str(item.variant_id) if item.variant_id else None,
                "quantity": item.quantity,
                "unit_price": float(item.unit_price),
                "subtotal": float(item.subtotal),
                "product_name": item.product.name if item.product else None,
                "product_image": _get_product_image(item.product),
            }
            for item in o.items
        ]

        address = None
        if o.address:
            address = {
                "recipient_name": o.address.recipient_name,
                "phone": o.address.phone,
                "province": o.address.province,
                "district": o.address.district,
                "ward": o.address.ward,
                "street": o.address.street,
            }

        data.append({
            "id": str(o.id),
            "order_code": o.order_code,
            "status": o.status,
            "total_amount": float(o.total_amount),
            "discount_amount": float(o.discount_amount or 0),
            "shipping_fee": float(o.shipping_fee or 0),
            "payment_method": o.payment_method,
            "payment_status": o.payment_status,
            "note": o.note,
            "created_at": o.created_at.isoformat() if o.created_at else None,
            "updated_at": o.updated_at.isoformat() if o.updated_at else None,
            "user_name": o.user.full_name if o.user else None,
            "user_email": o.user.email if o.user else None,
            "items": items,
            "address": address,
            "item_count": len(o.items),
        })

    return {
        "success": True,
        "data": data,
        "pagination": {
            "total": total,
            "page": page,
            "limit": limit,
            "total_pages": (total + limit - 1) // limit,
        },
    }


@router.put("/orders/{order_id}/status", summary="Update order status (admin)")
async def update_order_status(
    order_id: UUID,
    status: str = Query(...),
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Update order status. Valid statuses: pending, confirmed, shipping, delivered, cancelled."""
    valid_statuses = ["pending", "confirmed", "shipping", "delivered", "cancelled"]
    if status not in valid_statuses:
        raise HTTPException(400, f"Invalid status. Must be one of: {valid_statuses}")

    result = await db.execute(select(Order).where(Order.id == order_id))
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(404, "Order not found")

    order.status = status
    await db.commit()

    return {"success": True, "message": f"Order status updated to '{status}'"}


@router.put("/orders/{order_id}/payment-status", summary="Update payment status (admin)")
async def update_payment_status(
    order_id: UUID,
    payment_status: str = Query(...),
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Update payment status. Valid: pending, paid, failed, refunded."""
    valid = ["pending", "paid", "failed", "refunded"]
    if payment_status not in valid:
        raise HTTPException(400, f"Invalid payment status. Must be one of: {valid}")

    result = await db.execute(select(Order).where(Order.id == order_id))
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(404, "Order not found")

    order.payment_status = payment_status
    await db.commit()

    return {"success": True, "message": f"Payment status updated to '{payment_status}'"}
