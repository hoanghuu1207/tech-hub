from uuid import UUID
from typing import List, Optional
from pydantic import BaseModel
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db.session import get_db
from app.core.dependencies import get_current_user
from app.models.user import User
from app.models.order import CartItem
from app.models.product import Product, ProductVariant

router = APIRouter()

# ── Schemas ──
class AddToCartRequest(BaseModel):
    product_id: UUID
    variant_id: Optional[UUID] = None
    quantity: int = 1

class UpdateCartItemRequest(BaseModel):
    quantity: int

class CartItemOut(BaseModel):
    id: UUID
    product_id: UUID
    product_name: str
    variant_id: Optional[UUID]
    color_name: Optional[str]
    color_hex: Optional[str]
    quantity: int
    unit_price: float
    image_url: Optional[str]

    class Config:
        from_attributes = True

class CartResponse(BaseModel):
    success: bool
    data: List[CartItemOut]

# Helper
def _get_product_image(product) -> str | None:
    if not product or not hasattr(product, 'images') or not product.images:
        return None
    for img in product.images:
        if img.is_primary:
            return img.image_url
    return product.images[0].image_url if product.images else None

class VariantOut(BaseModel):
    id: UUID
    color_name: str
    color_hex: Optional[str]
    price: float
    stock_quantity: int

    class Config:
        from_attributes = True

# ── Endpoints ──

@router.get("/variants/{product_id}", summary="Lấy danh sách biến thể màu sắc của sản phẩm")
async def get_product_variants(
    product_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    product = await db.get(Product, product_id)
    if not product or not product.is_active:
        raise HTTPException(status_code=404, detail="Sản phẩm không tồn tại")

    stmt = (
        select(ProductVariant)
        .where(ProductVariant.product_id == product_id, ProductVariant.is_active == True)
        .order_by(ProductVariant.sort_order)
    )
    result = await db.execute(stmt)
    variants = result.scalars().all()

    return {
        "success": True,
        "data": [
            VariantOut(
                id=v.id,
                color_name=v.color_name,
                color_hex=v.color_hex,
                price=float(v.sale_price_override or v.price_override or product.sale_price or product.base_price),
                stock_quantity=v.stock_quantity,
            )
            for v in variants
        ],
    }

@router.get("", response_model=CartResponse, summary="Lấy danh sách giỏ hàng")
async def get_cart(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(CartItem)
        .options(
            selectinload(CartItem.product).selectinload(Product.images),
            selectinload(CartItem.variant),
        )
        .where(CartItem.user_id == user.id)
        .order_by(CartItem.added_at.desc())
    )
    result = await db.execute(stmt)
    cart_items = result.scalars().all()

    out_items = []
    for item in cart_items:
        p = item.product
        v = item.variant
        price = float(v.sale_price_override or v.price_override or p.sale_price or p.base_price) if v else float(p.sale_price or p.base_price)
        
        out_items.append(CartItemOut(
            id=item.id,
            product_id=item.product_id,
            product_name=p.name,
            variant_id=item.variant_id,
            color_name=v.color_name if v else None,
            color_hex=v.color_hex if v else None,
            quantity=item.quantity,
            unit_price=price,
            image_url=_get_product_image(p),
        ))

    return CartResponse(success=True, data=out_items)

@router.post("", response_model=CartResponse, summary="Thêm sản phẩm vào giỏ")
async def add_to_cart(
    req: AddToCartRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Check product exists
    product = await db.get(Product, req.product_id)
    if not product or not product.is_active:
        raise HTTPException(status_code=404, detail="Sản phẩm không tồn tại hoặc đã ngừng bán")

    # Check variant exists
    if req.variant_id:
        variant = await db.get(ProductVariant, req.variant_id)
        if not variant or not variant.is_active or variant.product_id != req.product_id:
            raise HTTPException(status_code=404, detail="Phiên bản màu của sản phẩm không hợp lệ")

    # Check existing item
    stmt = select(CartItem).where(
        CartItem.user_id == user.id,
        CartItem.product_id == req.product_id,
        CartItem.variant_id == req.variant_id,
    )
    res = await db.execute(stmt)
    existing = res.scalar_one_or_none()

    if existing:
        existing.quantity += req.quantity
    else:
        new_item = CartItem(
            user_id=user.id,
            product_id=req.product_id,
            variant_id=req.variant_id,
            quantity=req.quantity,
        )
        db.add(new_item)

    await db.commit()
    return await get_cart(user, db)

@router.put("/{cart_item_id}", response_model=CartResponse, summary="Cập nhật số lượng sản phẩm")
async def update_cart_quantity(
    cart_item_id: UUID,
    req: UpdateCartItemRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(CartItem).where(CartItem.id == cart_item_id, CartItem.user_id == user.id)
    res = await db.execute(stmt)
    item = res.scalar_one_or_none()

    if not item:
        raise HTTPException(status_code=404, detail="Sản phẩm không có trong giỏ hàng")

    if req.quantity <= 0:
        await db.delete(item)
    else:
        item.quantity = req.quantity

    await db.commit()
    return await get_cart(user, db)

@router.delete("/{cart_item_id}", response_model=CartResponse, summary="Xoá sản phẩm khỏi giỏ")
async def delete_cart_item(
    cart_item_id: UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(CartItem).where(CartItem.id == cart_item_id, CartItem.user_id == user.id)
    res = await db.execute(stmt)
    item = res.scalar_one_or_none()

    if not item:
        raise HTTPException(status_code=404, detail="Sản phẩm không có trong giỏ hàng")

    await db.delete(item)
    await db.commit()
    return await get_cart(user, db)

@router.delete("", response_model=CartResponse, summary="Xoá toàn bộ giỏ hàng")
async def clear_cart(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    q = delete(CartItem).where(CartItem.user_id == user.id)
    await db.execute(q)
    await db.commit()
    return CartResponse(success=True, data=[])
