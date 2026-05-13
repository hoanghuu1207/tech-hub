"""
Chat Tool Handlers — Thực thi các function call từ Gemini.

Mỗi handler nhận args từ Gemini + db session + user_id,
trả về (intent_type, result_summary, action_data, products).
"""

import logging
from typing import Optional, Tuple
from uuid import UUID
from decimal import Decimal

from sqlalchemy import select, func as sql_func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.product import Product, ProductVariant, ProductImage, Category, Brand
from app.models.order import CartItem, Order, OrderItem
from app.schemas.chat import ChatProductResult
from app.services.ai_search_service import ai_search_service

logger = logging.getLogger("chatbot")


def _format_price(price) -> str:
    """Format giá VND."""
    if price is None:
        return "N/A"
    return f"{int(price):,}đ".replace(",", ".")


async def handle_search_products(args: dict, db, user_id) -> dict:
    """Tool: search_products"""
    query = args.get("query", "")
    limit = int(args.get("limit", 10))

    logger.info(f"🔧 [Tool] search_products(query='{query}', limit={limit})")

    search_result = await ai_search_service.search(query=query, db=db, limit=limit)

    products = [
        ChatProductResult(
            id=p.id, name=p.name, slug=p.slug,
            category_name=p.category_name, category_slug=p.category_slug,
            brand_name=p.brand_name, brand_slug=p.brand_slug,
            base_price=p.base_price, sale_price=p.sale_price,
            primary_image=p.primary_image, rating_avg=p.rating_avg,
            sold_count=p.sold_count, similarity_score=p.similarity_score,
        )
        for p in search_result.products
    ]

    # Summary kèm ID để Gemini dùng cho các tool tiếp theo
    if products:
        lines = [f"Tìm thấy {len(products)} sản phẩm phù hợp:"]
        for i, p in enumerate(products, 1):
            price = _format_price(p.sale_price or p.base_price)
            lines.append(f"{i}. {p.name} (id: {p.id}, slug: {p.slug}, giá: {price})")
        summary = "\n".join(lines)
    else:
        summary = "Không tìm thấy sản phẩm nào phù hợp."

    return {
        "intent_type": "product_search",
        "summary": summary,
        "products": products,
        "action_data": {"action": "show_product_list"} if products else None,
    }


async def handle_get_product_detail(args: dict, db, user_id) -> dict:
    """Tool: get_product_detail"""
    product_id = args.get("product_id")
    product_slug = args.get("product_slug")

    logger.info(f"🔧 [Tool] get_product_detail(id={product_id}, slug={product_slug})")

    stmt = select(Product).options(
        selectinload(Product.category),
        selectinload(Product.brand),
        selectinload(Product.variants),
        selectinload(Product.images),
    )

    if product_id:
        try:
            stmt = stmt.where(Product.id == UUID(product_id))
        except ValueError:
            return {"intent_type": "product_detail", "summary": "ID sản phẩm không hợp lệ.", "products": None, "action_data": None}
    elif product_slug:
        stmt = stmt.where(Product.slug == product_slug)
    else:
        return {"intent_type": "product_detail", "summary": "Cần cung cấp product_id hoặc product_slug.", "products": None, "action_data": None}

    result = await db.execute(stmt)
    product = result.scalar_one_or_none()

    if not product:
        return {"intent_type": "product_detail", "summary": "Không tìm thấy sản phẩm.", "products": None, "action_data": None}

    # Build specs text
    specs_text = ""
    if product.specs:
        specs_lines = []
        for key, val in product.specs.items():
            if isinstance(val, dict):
                for k2, v2 in val.items():
                    specs_lines.append(f"  - {k2}: {v2}")
            else:
                specs_lines.append(f"  - {key}: {val}")
        specs_text = "\n".join(specs_lines)

    # Variants
    variants_text = ""
    if product.variants:
        v_lines = [f"  - {v.color_name}: {_format_price(v.price_override or product.sale_price or product.base_price)} (tồn kho: {v.stock_quantity})"
                    for v in product.variants if v.is_active]
        variants_text = "\n".join(v_lines)

    # Highlight features
    features_text = ""
    if product.highlight_features:
        features_text = "\n".join(f"  ✦ {f}" for f in product.highlight_features)

    summary = (
        f"Chi tiết sản phẩm: {product.name}\n"
        f"- ID: {product.id}\n"
        f"- Slug: {product.slug}\n"
        f"- Thương hiệu: {product.brand.name if product.brand else 'N/A'}\n"
        f"- Danh mục: {product.category.name if product.category else 'N/A'}\n"
        f"- Giá gốc: {_format_price(product.base_price)}\n"
        f"- Giá bán: {_format_price(product.sale_price)}\n"
        f"- Đánh giá: {product.rating_avg}/5 ({product.rating_count} đánh giá)\n"
        f"- Đã bán: {product.sold_count}\n"
    )
    if features_text:
        summary += f"- Điểm nổi bật:\n{features_text}\n"
    if specs_text:
        summary += f"- Thông số kỹ thuật:\n{specs_text}\n"
    if variants_text:
        summary += f"- Phiên bản màu:\n{variants_text}\n"

    return {
        "intent_type": "product_detail",
        "summary": summary,
        "products": None,
        "action_data": {
            "action": "navigate_product_detail",
            "product_id": str(product.id),
            "product_slug": product.slug,
        },
    }


async def handle_compare_products(args: dict, db, user_id) -> dict:
    """Tool: compare_products"""
    product_ids = args.get("product_ids", [])

    logger.info(f"🔧 [Tool] compare_products(ids={product_ids})")

    if len(product_ids) < 2:
        return {"intent_type": "product_compare", "summary": "Cần ít nhất 2 sản phẩm để so sánh.", "products": None, "action_data": None}

    try:
        uuids = [UUID(pid) for pid in product_ids]
    except ValueError:
        return {"intent_type": "product_compare", "summary": "ID sản phẩm không hợp lệ.", "products": None, "action_data": None}

    stmt = select(Product).options(
        selectinload(Product.brand),
        selectinload(Product.category),
    ).where(Product.id.in_(uuids))

    result = await db.execute(stmt)
    products = result.scalars().all()

    if len(products) < 2:
        return {"intent_type": "product_compare", "summary": "Không tìm đủ sản phẩm để so sánh.", "products": None, "action_data": None}

    # Build comparison table
    lines = ["Bảng so sánh sản phẩm:\n"]
    lines.append(f"{'Tiêu chí':<20} | " + " | ".join(p.name[:25] for p in products))
    lines.append("-" * 80)
    lines.append(f"{'Thương hiệu':<20} | " + " | ".join((p.brand.name if p.brand else "N/A")[:25] for p in products))
    lines.append(f"{'Giá bán':<20} | " + " | ".join(_format_price(p.sale_price or p.base_price)[:25] for p in products))
    lines.append(f"{'Đánh giá':<20} | " + " | ".join(f"{p.rating_avg}/5"[:25] for p in products))

    # Compare specs
    all_spec_keys = set()
    for p in products:
        if p.specs:
            for key, val in p.specs.items():
                if isinstance(val, dict):
                    all_spec_keys.update(val.keys())
                else:
                    all_spec_keys.add(key)

    for key in sorted(all_spec_keys)[:15]:  # Giới hạn 15 specs
        vals = []
        for p in products:
            v = "N/A"
            if p.specs:
                if key in p.specs:
                    v = str(p.specs[key])
                else:
                    for group in p.specs.values():
                        if isinstance(group, dict) and key in group:
                            v = str(group[key])
                            break
            vals.append(v[:25])
        lines.append(f"{key:<20} | " + " | ".join(vals))

    compare_products_result = [
        ChatProductResult(
            id=p.id, name=p.name, slug=p.slug,
            category_name=p.category.name if p.category else None,
            brand_name=p.brand.name if p.brand else None,
            base_price=float(p.base_price), sale_price=float(p.sale_price) if p.sale_price else None,
        )
        for p in products
    ]

    return {
        "intent_type": "product_compare",
        "summary": "\n".join(lines),
        "products": compare_products_result,
        "action_data": {
            "action": "show_compare_table",
            "product_ids": [str(p.id) for p in products],
        },
    }


async def handle_add_to_cart(args: dict, db, user_id) -> dict:
    """Tool: add_to_cart (YÊU CẦU AUTH)"""
    if not user_id:
        return {
            "intent_type": "add_to_cart",
            "summary": "Người dùng chưa đăng nhập. Vui lòng yêu cầu đăng nhập trước khi thêm giỏ hàng.",
            "products": None,
            "action_data": {"action": "require_login"},
        }

    product_id = args.get("product_id")
    quantity = int(args.get("quantity", 1))

    logger.info(f"🔧 [Tool] add_to_cart(product_id={product_id}, qty={quantity})")

    try:
        product_uuid = UUID(product_id)
    except (ValueError, TypeError):
        return {"intent_type": "add_to_cart", "summary": "ID sản phẩm không hợp lệ.", "products": None, "action_data": None}

    # Kiểm tra sản phẩm tồn tại
    product = await db.get(Product, product_uuid)
    if not product or not product.is_active:
        return {"intent_type": "add_to_cart", "summary": "Sản phẩm không tồn tại hoặc đã ngừng bán.", "products": None, "action_data": None}

    # Kiểm tra đã có trong giỏ chưa
    stmt = select(CartItem).where(
        CartItem.user_id == user_id,
        CartItem.product_id == product_uuid,
    )
    result = await db.execute(stmt)
    existing = result.scalar_one_or_none()

    if existing:
        existing.quantity += quantity
        action_text = f"Đã cập nhật số lượng {product.name} trong giỏ hàng (tổng: {existing.quantity})."
    else:
        cart_item = CartItem(
            user_id=user_id,
            product_id=product_uuid,
            quantity=quantity,
        )
        db.add(cart_item)
        action_text = f"Đã thêm {quantity}x {product.name} vào giỏ hàng. Giá: {_format_price(product.sale_price or product.base_price)}."

    return {
        "intent_type": "add_to_cart",
        "summary": action_text,
        "products": None,
        "action_data": {
            "action": "cart_updated",
            "product_id": str(product.id),
            "product_name": product.name,
            "quantity": quantity,
        },
    }


async def handle_get_cart(args: dict, db, user_id) -> dict:
    """Tool: get_cart (YÊU CẦU AUTH)"""
    if not user_id:
        return {
            "intent_type": "get_cart",
            "summary": "Người dùng chưa đăng nhập. Vui lòng yêu cầu đăng nhập để xem giỏ hàng.",
            "products": None,
            "action_data": {"action": "require_login"},
        }

    logger.info(f"🔧 [Tool] get_cart(user_id={user_id})")

    stmt = select(CartItem).options(
        selectinload(CartItem.product),
    ).where(CartItem.user_id == user_id)

    result = await db.execute(stmt)
    cart_items = result.scalars().all()

    if not cart_items:
        return {
            "intent_type": "get_cart",
            "summary": "Giỏ hàng trống.",
            "products": None,
            "action_data": {"action": "show_cart", "total_items": 0},
        }

    total = 0
    lines = [f"Giỏ hàng ({len(cart_items)} sản phẩm):"]
    for i, item in enumerate(cart_items, 1):
        p = item.product
        price = float(p.sale_price or p.base_price)
        subtotal = price * item.quantity
        total += subtotal
        lines.append(
            f"{i}. {p.name} (id: {p.id}) - SL: {item.quantity} - "
            f"Đơn giá: {_format_price(price)} - Thành tiền: {_format_price(subtotal)}"
        )
    lines.append(f"\nTổng cộng: {_format_price(total)}")

    return {
        "intent_type": "get_cart",
        "summary": "\n".join(lines),
        "products": None,
        "action_data": {
            "action": "show_cart",
            "total_items": len(cart_items),
            "total_amount": total,
        },
    }


async def handle_proceed_to_checkout(args: dict, db, user_id) -> dict:
    """Tool: proceed_to_checkout (YÊU CẦU AUTH)"""
    if not user_id:
        return {
            "intent_type": "checkout",
            "summary": "Người dùng chưa đăng nhập. Vui lòng đăng nhập để thanh toán.",
            "products": None,
            "action_data": {"action": "require_login"},
        }

    logger.info(f"🔧 [Tool] proceed_to_checkout(user_id={user_id})")

    # Kiểm tra giỏ hàng có items không
    stmt = select(sql_func.count()).select_from(CartItem).where(CartItem.user_id == user_id)
    result = await db.execute(stmt)
    count = result.scalar()

    if not count:
        return {
            "intent_type": "checkout",
            "summary": "Giỏ hàng trống, không thể thanh toán.",
            "products": None,
            "action_data": None,
        }

    return {
        "intent_type": "checkout",
        "summary": f"Giỏ hàng có {count} sản phẩm. Sẵn sàng chuyển sang thanh toán.",
        "products": None,
        "action_data": {
            "action": "navigate_checkout",
            "cart_items_count": count,
        },
    }


async def handle_get_order_status(args: dict, db, user_id) -> dict:
    """Tool: get_order_status (YÊU CẦU AUTH)"""
    if not user_id:
        return {
            "intent_type": "order_status",
            "summary": "Người dùng chưa đăng nhập. Vui lòng đăng nhập để xem đơn hàng.",
            "products": None,
            "action_data": {"action": "require_login"},
        }

    order_id = args.get("order_id")
    logger.info(f"🔧 [Tool] get_order_status(order_id={order_id})")

    if order_id:
        try:
            stmt = select(Order).options(
                selectinload(Order.items).selectinload(OrderItem.product),
            ).where(Order.id == UUID(order_id), Order.user_id == user_id)
        except ValueError:
            return {"intent_type": "order_status", "summary": "Mã đơn hàng không hợp lệ.", "products": None, "action_data": None}
    else:
        stmt = select(Order).options(
            selectinload(Order.items).selectinload(OrderItem.product),
        ).where(Order.user_id == user_id).order_by(Order.created_at.desc()).limit(3)

    result = await db.execute(stmt)
    orders = result.scalars().all() if not order_id else [result.scalar_one_or_none()]
    orders = [o for o in orders if o]

    if not orders:
        return {
            "intent_type": "order_status",
            "summary": "Không tìm thấy đơn hàng nào.",
            "products": None,
            "action_data": None,
        }

    STATUS_MAP = {
        "pending": "Chờ xác nhận",
        "confirmed": "Đã xác nhận",
        "shipping": "Đang giao hàng",
        "delivered": "Đã giao",
        "cancelled": "Đã hủy",
    }

    lines = []
    for order in orders:
        status_text = STATUS_MAP.get(order.status, order.status)
        lines.append(
            f"Đơn #{str(order.id)[:8]}... | Trạng thái: {status_text} | "
            f"Tổng: {_format_price(order.total_amount)} | "
            f"Ngày đặt: {order.created_at.strftime('%d/%m/%Y') if order.created_at else 'N/A'}"
        )
        for item in order.items[:3]:
            lines.append(f"  - {item.product.name if item.product else 'N/A'} x{item.quantity}")

    return {
        "intent_type": "order_status",
        "summary": "\n".join(lines),
        "products": None,
        "action_data": {
            "action": "show_order_detail",
            "order_ids": [str(o.id) for o in orders],
        },
    }


async def handle_get_promotions(args: dict, db, user_id) -> dict:
    """Tool: get_promotions — Sản phẩm đang giảm giá."""
    category = args.get("category")
    limit = int(args.get("limit", 10))

    logger.info(f"🔧 [Tool] get_promotions(category={category}, limit={limit})")

    stmt = (
        select(Product)
        .options(selectinload(Product.category), selectinload(Product.brand))
        .where(
            Product.is_active == True,
            Product.sale_price.isnot(None),
            Product.sale_price < Product.base_price,
        )
        .order_by((Product.base_price - Product.sale_price).desc())
        .limit(limit)
    )

    if category:
        stmt = stmt.join(Category).where(
            (Category.slug == category) | (Category.name.ilike(f"%{category}%"))
        )

    result = await db.execute(stmt)
    promo_products = result.scalars().all()

    if not promo_products:
        return {
            "intent_type": "promotions",
            "summary": "Hiện tại không có sản phẩm khuyến mãi nào.",
            "products": None,
            "action_data": None,
        }

    products = [
        ChatProductResult(
            id=p.id, name=p.name, slug=p.slug,
            category_name=p.category.name if p.category else None,
            brand_name=p.brand.name if p.brand else None,
            base_price=float(p.base_price), sale_price=float(p.sale_price),
        )
        for p in promo_products
    ]

    lines = [f"Tìm thấy {len(products)} sản phẩm đang khuyến mãi:"]
    for i, p in enumerate(promo_products, 1):
        discount = int(((p.base_price - p.sale_price) / p.base_price) * 100)
        lines.append(
            f"{i}. {p.name} (id: {p.id}) - "
            f"Giá gốc: {_format_price(p.base_price)} → {_format_price(p.sale_price)} (giảm {discount}%)"
        )

    return {
        "intent_type": "promotions",
        "summary": "\n".join(lines),
        "products": products,
        "action_data": {"action": "show_promotions"},
    }


async def handle_buy_product(args: dict, db, user_id) -> dict:
    """Tool: buy_product — Mua ngay sản phẩm, tạo đơn hàng trực tiếp (không qua giỏ hàng)."""
    if not user_id:
        return {
            "intent_type": "buy_product",
            "summary": "Người dùng chưa đăng nhập. Vui lòng yêu cầu đăng nhập trước khi mua hàng.",
            "products": None,
            "action_data": {"action": "require_login"},
        }

    product_id = args.get("product_id")
    quantity = int(args.get("quantity", 1))

    logger.info(f"🔧 [Tool] buy_product(product_id={product_id}, qty={quantity})")

    # Validate product_id
    try:
        product_uuid = UUID(product_id)
    except (ValueError, TypeError):
        return {
            "intent_type": "buy_product",
            "summary": "ID sản phẩm không hợp lệ.",
            "products": None,
            "action_data": None,
        }

    # Kiểm tra sản phẩm tồn tại
    product = await db.get(Product, product_uuid)
    if not product or not product.is_active:
        return {
            "intent_type": "buy_product",
            "summary": "Sản phẩm không tồn tại hoặc đã ngừng bán.",
            "products": None,
            "action_data": None,
        }

    # Tính giá
    from decimal import Decimal
    unit_price = product.sale_price if product.sale_price else product.base_price
    subtotal = unit_price * quantity
    shipping_fee = Decimal("0")
    total_amount = subtotal + shipping_fee

    # Tạo đơn hàng
    order = Order(
        user_id=user_id,
        status="pending",
        total_amount=total_amount,
        discount_amount=Decimal("0"),
        shipping_fee=shipping_fee,
        payment_method=None,
        payment_status="pending",
        note=f"Đặt hàng nhanh qua TechBot",
    )
    db.add(order)
    await db.flush()  # Lấy order.id

    # Tạo order item
    order_item = OrderItem(
        order_id=order.id,
        product_id=product_uuid,
        quantity=quantity,
        unit_price=unit_price,
        subtotal=subtotal,
    )
    db.add(order_item)

    summary = (
        f"Đã tạo đơn hàng thành công!\n"
        f"- Mã đơn: #{str(order.id)[:8]}...\n"
        f"- Sản phẩm: {product.name}\n"
        f"- Số lượng: {quantity}\n"
        f"- Đơn giá: {_format_price(unit_price)}\n"
        f"- Tổng tiền: {_format_price(total_amount)}\n"
        f"- Trạng thái: Chờ xác nhận"
    )

    return {
        "intent_type": "buy_product",
        "summary": summary,
        "products": None,
        "action_data": {
            "action": "order_created",
            "order_id": str(order.id),
            "product_id": str(product.id),
            "product_name": product.name,
            "quantity": quantity,
            "total_amount": float(total_amount),
        },
    }


# ── Registry: map tool name → handler ──
TOOL_HANDLERS = {
    "search_products": handle_search_products,
    "get_product_detail": handle_get_product_detail,
    "compare_products": handle_compare_products,
    "add_to_cart": handle_add_to_cart,
    "get_cart": handle_get_cart,
    "proceed_to_checkout": handle_proceed_to_checkout,
    "get_order_status": handle_get_order_status,
    "get_promotions": handle_get_promotions,
    "buy_product": handle_buy_product,
}
