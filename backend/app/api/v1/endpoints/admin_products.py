"""
Admin Product CRUD Endpoints.

Quản lý sản phẩm: List, Create, Update, Delete, kèm Variants và Images.
Tất cả endpoints yêu cầu role=admin.
"""

import logging
from uuid import UUID
from typing import Optional, List
from datetime import datetime, timezone, UTC

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from sqlalchemy import select, func, or_, and_, case

from app.db.session import get_db
from app.models.user import User
from app.models.product import Product, ProductVariant, ProductImage, Category, Brand, ProductLine
from app.api.v1.endpoints.admin import require_admin

logger = logging.getLogger("admin_products")

router = APIRouter()


# ─── Pydantic Schemas ────────────────────────────────────

class ProductListItem(BaseModel):
    id: str
    name: str
    slug: str
    category_id: str
    category_name: str | None = None
    brand_id: str
    brand_name: str | None = None
    line_id: str | None = None
    line_name: str | None = None
    base_price: float
    sale_price: float | None = None
    status: str
    is_active: bool
    qdrant_vector_id: str | None = None
    rating_avg: float = 0
    sold_count: int = 0
    stock_total: int = 0
    primary_image: str | None = None
    created_at: str | None = None

class ProductListResponse(BaseModel):
    success: bool = True
    data: dict  # items + total + limit + offset

class VariantInput(BaseModel):
    id: str | None = None  # None = create new, existing = update
    color_name: str
    color_hex: str | None = None
    price_override: float | None = None
    sale_price_override: float | None = None
    stock_quantity: int = 0
    sku: str | None = None
    is_active: bool = True
    sort_order: int = 0

class ImageInput(BaseModel):
    id: str | None = None
    image_url: str
    alt_text: str | None = None
    is_primary: bool = False
    variant_id: str | None = None
    sort_order: int = 0

class ProductCreate(BaseModel):
    name: str
    slug: str
    category_id: str
    brand_id: str
    line_id: str | None = None
    description: str | None = None
    highlight_features: list[str] = []
    base_price: float
    sale_price: float | None = None
    status: str = "new"
    specs: dict = {}
    is_active: bool = True
    variants: list[VariantInput] = []
    images: list[ImageInput] = []

class ProductUpdate(BaseModel):
    name: str | None = None
    slug: str | None = None
    category_id: str | None = None
    brand_id: str | None = None
    line_id: str | None = None
    description: str | None = None
    highlight_features: list[str] | None = None
    base_price: float | None = None
    sale_price: float | None = None
    status: str | None = None
    specs: dict | None = None
    is_active: bool | None = None
    variants: list[VariantInput] | None = None
    images: list[ImageInput] | None = None

class StatusUpdate(BaseModel):
    is_active: bool


# ─── Helpers ─────────────────────────────────────────────

def _serialize_product(p: Product, stock_total: int = 0) -> dict:
    primary_img = None
    if p.images:
        primary = next((img for img in p.images if img.is_primary), None)
        if primary:
            primary_img = primary.image_url
        elif p.images:
            primary_img = p.images[0].image_url

    return {
        "id": str(p.id),
        "name": p.name,
        "slug": p.slug,
        "category_id": str(p.category_id),
        "category_name": p.category.name if p.category else None,
        "brand_id": str(p.brand_id),
        "brand_name": p.brand.name if p.brand else None,
        "line_id": str(p.line_id) if p.line_id else None,
        "line_name": p.line.name if p.line else None,
        "description": p.description,
        "highlight_features": p.highlight_features or [],
        "base_price": float(p.base_price),
        "sale_price": float(p.sale_price) if p.sale_price else None,
        "status": p.status,
        "specs": p.specs or {},
        "is_active": p.is_active,
        "qdrant_vector_id": p.qdrant_vector_id,
        "rating_avg": float(p.rating_avg) if p.rating_avg else 0,
        "rating_count": p.rating_count or 0,
        "sold_count": p.sold_count or 0,
        "stock_total": stock_total,
        "primary_image": primary_img,
        "created_at": p.created_at.isoformat() if p.created_at else None,
        "updated_at": p.updated_at.isoformat() if p.updated_at else None,
        "variants": [
            {
                "id": str(v.id),
                "color_name": v.color_name,
                "color_hex": v.color_hex,
                "price_override": float(v.price_override) if v.price_override else None,
                "sale_price_override": float(v.sale_price_override) if v.sale_price_override else None,
                "stock_quantity": v.stock_quantity,
                "sku": v.sku,
                "is_active": v.is_active,
                "sort_order": v.sort_order,
            }
            for v in sorted(p.variants, key=lambda x: x.sort_order)
        ] if p.variants else [],
        "images": [
            {
                "id": str(img.id),
                "image_url": img.image_url,
                "alt_text": img.alt_text,
                "is_primary": img.is_primary,
                "variant_id": str(img.variant_id) if img.variant_id else None,
                "sort_order": img.sort_order,
            }
            for img in sorted(p.images, key=lambda x: x.sort_order)
        ] if p.images else [],
    }


# ─── LIST Products (Paginated, Search, Filter) ──────────

@router.get("/products", summary="List products (admin)")
async def list_products(
    search: Optional[str] = Query(None),
    category_id: Optional[str] = Query(None),
    brand_id: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    is_active: Optional[bool] = Query(None),
    indexed: Optional[bool] = Query(None),  # True = has qdrant_vector_id
    sort_by: str = Query("created_at"),
    sort_order: str = Query("desc"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    query = select(Product).options(
        selectinload(Product.category),
        selectinload(Product.brand),
        selectinload(Product.line),
        selectinload(Product.variants),
        selectinload(Product.images),
    )

    # Filters — always exclude soft-deleted products unless explicitly requested
    filters = [Product.deleted_at.is_(None)]
    if search:
        filters.append(
            or_(
                Product.name.ilike(f"%{search}%"),
                Product.slug.ilike(f"%{search}%"),
            )
        )
    if category_id:
        filters.append(Product.category_id == UUID(category_id))
    if brand_id:
        filters.append(Product.brand_id == UUID(brand_id))
    if status:
        filters.append(Product.status == status)
    if is_active is not None:
        filters.append(Product.is_active == is_active)
    if indexed is not None:
        if indexed:
            filters.append(Product.qdrant_vector_id.isnot(None))
        else:
            filters.append(Product.qdrant_vector_id.is_(None))

    if filters:
        query = query.where(and_(*filters))

    # Count
    count_query = select(func.count(Product.id))
    if filters:
        count_query = count_query.where(and_(*filters))
    total_result = await db.execute(count_query)
    total = total_result.scalar_one()

    # Sort
    sort_col = getattr(Product, sort_by, Product.created_at)
    if sort_order == "asc":
        query = query.order_by(sort_col.asc())
    else:
        query = query.order_by(sort_col.desc())

    # Paginate
    query = query.offset(offset).limit(limit)
    result = await db.execute(query)
    products = result.unique().scalars().all()

    items = []
    for p in products:
        stock = sum(v.stock_quantity for v in p.variants) if p.variants else 0
        items.append(_serialize_product(p, stock))

    return {
        "success": True,
        "data": {
            "items": items,
            "total": total,
            "limit": limit,
            "offset": offset,
        },
    }


# ─── GET Single Product ─────────────────────────────────

@router.get("/products/{product_id}", summary="Get product detail (admin)")
async def get_product(
    product_id: UUID,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Product)
        .where(Product.id == product_id)
        .options(
            selectinload(Product.category),
            selectinload(Product.brand),
            selectinload(Product.line),
            selectinload(Product.variants),
            selectinload(Product.images),
        )
    )
    product = result.unique().scalar_one_or_none()
    if not product:
        raise HTTPException(404, "Product not found")

    stock = sum(v.stock_quantity for v in product.variants) if product.variants else 0
    return {"success": True, "data": _serialize_product(product, stock)}


# ─── CREATE Product ──────────────────────────────────────

@router.post("/products", summary="Create product")
async def create_product(
    body: ProductCreate,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    # Check slug uniqueness
    existing = await db.execute(select(Product).where(Product.slug == body.slug))
    if existing.scalar_one_or_none():
        raise HTTPException(400, f"Slug '{body.slug}' already exists")

    product = Product(
        name=body.name,
        slug=body.slug,
        category_id=UUID(body.category_id),
        brand_id=UUID(body.brand_id),
        line_id=UUID(body.line_id) if body.line_id else None,
        description=body.description,
        highlight_features=body.highlight_features,
        base_price=body.base_price,
        sale_price=body.sale_price,
        status=body.status,
        specs=body.specs,
        is_active=body.is_active,
    )
    db.add(product)
    await db.flush()

    # Add variants
    for v_data in body.variants:
        variant = ProductVariant(
            product_id=product.id,
            color_name=v_data.color_name,
            color_hex=v_data.color_hex,
            price_override=v_data.price_override,
            sale_price_override=v_data.sale_price_override,
            stock_quantity=v_data.stock_quantity,
            sku=v_data.sku,
            is_active=v_data.is_active,
            sort_order=v_data.sort_order,
        )
        db.add(variant)

    # Add images
    for img_data in body.images:
        image = ProductImage(
            product_id=product.id,
            image_url=img_data.image_url,
            alt_text=img_data.alt_text,
            is_primary=img_data.is_primary,
            sort_order=img_data.sort_order,
        )
        db.add(image)

    await db.commit()

    # Re-fetch with relationships
    result = await db.execute(
        select(Product).where(Product.id == product.id).options(
            selectinload(Product.category),
            selectinload(Product.brand),
            selectinload(Product.line),
            selectinload(Product.variants),
            selectinload(Product.images),
        )
    )
    product = result.unique().scalar_one()
    stock = sum(v.stock_quantity for v in product.variants) if product.variants else 0

    return {"success": True, "message": "Product created", "data": _serialize_product(product, stock)}


# ─── UPDATE Product ──────────────────────────────────────

@router.put("/products/{product_id}", summary="Update product")
async def update_product(
    product_id: UUID,
    body: ProductUpdate,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Product).where(Product.id == product_id).options(
            selectinload(Product.variants),
            selectinload(Product.images),
        )
    )
    product = result.unique().scalar_one_or_none()
    if not product:
        raise HTTPException(404, "Product not found")

    # Update scalar fields
    update_fields = body.model_dump(exclude_unset=True, exclude={"variants", "images"})
    for field, value in update_fields.items():
        if field in ("category_id", "brand_id", "line_id") and value:
            value = UUID(value)
        setattr(product, field, value)

    # Update variants if provided
    if body.variants is not None:
        existing_variant_ids = {str(v.id) for v in product.variants}
        incoming_ids = {v.id for v in body.variants if v.id}

        # Delete removed variants
        for v in product.variants:
            if str(v.id) not in incoming_ids:
                await db.delete(v)

        # Update or create
        for v_data in body.variants:
            if v_data.id and v_data.id in existing_variant_ids:
                # Update existing
                vr = await db.execute(
                    select(ProductVariant).where(ProductVariant.id == UUID(v_data.id))
                )
                variant = vr.scalar_one_or_none()
                if variant:
                    variant.color_name = v_data.color_name
                    variant.color_hex = v_data.color_hex
                    variant.price_override = v_data.price_override
                    variant.sale_price_override = v_data.sale_price_override
                    variant.stock_quantity = v_data.stock_quantity
                    variant.sku = v_data.sku
                    variant.is_active = v_data.is_active
                    variant.sort_order = v_data.sort_order
            else:
                # Create new
                new_v = ProductVariant(
                    product_id=product.id,
                    color_name=v_data.color_name,
                    color_hex=v_data.color_hex,
                    price_override=v_data.price_override,
                    sale_price_override=v_data.sale_price_override,
                    stock_quantity=v_data.stock_quantity,
                    sku=v_data.sku,
                    is_active=v_data.is_active,
                    sort_order=v_data.sort_order,
                )
                db.add(new_v)

    # Update images if provided
    if body.images is not None:
        existing_img_ids = {str(img.id) for img in product.images}
        incoming_img_ids = {img.id for img in body.images if img.id}

        for img in product.images:
            if str(img.id) not in incoming_img_ids:
                await db.delete(img)

        for img_data in body.images:
            if img_data.id and img_data.id in existing_img_ids:
                ir = await db.execute(
                    select(ProductImage).where(ProductImage.id == UUID(img_data.id))
                )
                image = ir.scalar_one_or_none()
                if image:
                    image.image_url = img_data.image_url
                    image.alt_text = img_data.alt_text
                    image.is_primary = img_data.is_primary
                    image.variant_id = UUID(img_data.variant_id) if img_data.variant_id else None
                    image.sort_order = img_data.sort_order
            else:
                new_img = ProductImage(
                    product_id=product.id,
                    image_url=img_data.image_url,
                    alt_text=img_data.alt_text,
                    is_primary=img_data.is_primary,
                    variant_id=UUID(img_data.variant_id) if img_data.variant_id else None,
                    sort_order=img_data.sort_order,
                )
                db.add(new_img)

    await db.commit()

    # Re-fetch
    result = await db.execute(
        select(Product).where(Product.id == product.id).options(
            selectinload(Product.category),
            selectinload(Product.brand),
            selectinload(Product.line),
            selectinload(Product.variants),
            selectinload(Product.images),
        )
    )
    product = result.unique().scalar_one()
    stock = sum(v.stock_quantity for v in product.variants) if product.variants else 0

    # Auto re-index if product was already indexed in Qdrant
    reindexed = False
    if product.qdrant_vector_id:
        try:
            from app.api.v1.endpoints.admin_indexing import indexer, _product_to_indexer_data
            product_data = _product_to_indexer_data(product)
            vector_id = await indexer.index_product(product_data)
            product.qdrant_vector_id = vector_id
            await db.commit()
            reindexed = True
            logger.info(f"Auto re-indexed product '{product.name}' after update")
        except Exception as e:
            logger.warning(f"Auto re-index failed for '{product.name}': {e}")

    msg = "Product updated" + (" & re-indexed" if reindexed else "")
    return {"success": True, "message": msg, "data": _serialize_product(product, stock)}


# ─── DELETE Product ──────────────────────────────────────

@router.delete("/products/{product_id}", summary="Soft-delete product")
async def delete_product(
    product_id: UUID,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Soft-delete: set deleted_at timestamp, remove from Qdrant, deactivate."""
    result = await db.execute(
        select(Product).where(Product.id == product_id, Product.deleted_at.is_(None))
    )
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(404, "Product not found")

    # Remove from Qdrant if indexed
    if product.qdrant_vector_id:
        try:
            from app.api.v1.endpoints.admin_indexing import indexer
            await indexer.delete_product(str(product_id))
            logger.info(f"Removed product '{product.name}' from Qdrant")
        except Exception as e:
            logger.warning(f"Failed to remove from Qdrant: {e}")

    # Soft delete
    product.deleted_at = datetime.now(UTC)
    product.is_active = False
    product.qdrant_vector_id = None
    await db.commit()

    return {"success": True, "message": f"Product '{product.name}' moved to trash"}


@router.post("/products/{product_id}/restore", summary="Restore soft-deleted product")
async def restore_product(
    product_id: UUID,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Restore a soft-deleted product."""
    result = await db.execute(
        select(Product).where(Product.id == product_id, Product.deleted_at.isnot(None))
    )
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(404, "Product not found or not deleted")

    product.deleted_at = None
    product.is_active = True
    await db.commit()

    return {"success": True, "message": f"Product '{product.name}' restored"}


# ─── TOGGLE Active Status ───────────────────────────────

@router.patch("/products/{product_id}/status", summary="Toggle product active status")
async def toggle_product_status(
    product_id: UUID,
    body: StatusUpdate,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Product).where(Product.id == product_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(404, "Product not found")

    product.is_active = body.is_active
    await db.commit()

    # Update Qdrant payload is_active if indexed
    if product.qdrant_vector_id:
        try:
            from app.db.qdrant import qdrant_client
            from database.indexer import COLLECTION_NAME
            from qdrant_client.models import SetPayload
            qdrant_client.set_payload(
                collection_name=COLLECTION_NAME,
                payload={"is_active": body.is_active},
                points=[product.qdrant_vector_id],
            )
            logger.info(f"Updated Qdrant is_active={body.is_active} for '{product.name}'")
        except Exception as e:
            logger.warning(f"Failed to update Qdrant payload: {e}")

    return {"success": True, "message": f"Product {'activated' if body.is_active else 'deactivated'}"}


# ─── List Root Categories (parent_id = null) ────────────

@router.get("/categories", summary="List root categories (admin)")
async def list_root_categories(
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Only returns categories with parent_id = NULL (root categories)."""
    result = await db.execute(
        select(Category)
        .where(Category.parent_id == None)
        .order_by(Category.sort_order, Category.name)
    )
    categories = result.scalars().all()
    return {
        "success": True,
        "data": [
            {
                "id": str(c.id),
                "name": c.name,
                "slug": c.slug,
                "parent_id": None,
                "icon_url": c.icon_url,
                "description": c.description,
                "is_active": c.is_active,
                "sort_order": c.sort_order,
            }
            for c in categories
        ],
    }


# ─── List All Categories (flat, for reference) ──────────

@router.get("/categories/all", summary="List all categories (admin)")
async def list_all_categories(
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Returns ALL categories (both root and sub) for reference."""
    result = await db.execute(select(Category).order_by(Category.sort_order, Category.name))
    categories = result.scalars().all()
    return {
        "success": True,
        "data": [
            {
                "id": str(c.id),
                "name": c.name,
                "slug": c.slug,
                "parent_id": str(c.parent_id) if c.parent_id else None,
                "icon_url": c.icon_url,
                "description": c.description,
                "is_active": c.is_active,
                "sort_order": c.sort_order,
            }
            for c in categories
        ],
    }


# ─── Create Category ─────────────────────────────────────

class CategoryCreate(BaseModel):
    name: str
    slug: str
    parent_id: str | None = None
    icon_url: str | None = None
    description: str | None = None
    is_active: bool = True
    sort_order: int = 0


class CategoryUpdate(BaseModel):
    name: str | None = None
    slug: str | None = None
    parent_id: str | None = None
    icon_url: str | None = None
    description: str | None = None
    is_active: bool | None = None
    sort_order: int | None = None


@router.post("/categories", summary="Create category (admin)")
async def create_category(
    body: CategoryCreate,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Create a new category."""
    # Check slug uniqueness
    existing = await db.execute(select(Category).where(Category.slug == body.slug))
    if existing.scalar_one_or_none():
        raise HTTPException(400, f"Slug '{body.slug}' already exists")

    category = Category(
        name=body.name,
        slug=body.slug,
        parent_id=UUID(body.parent_id) if body.parent_id else None,
        icon_url=body.icon_url,
        description=body.description,
        is_active=body.is_active,
        sort_order=body.sort_order,
    )
    db.add(category)
    await db.commit()
    await db.refresh(category)

    return {
        "success": True,
        "message": "Category created",
        "data": {
            "id": str(category.id),
            "name": category.name,
            "slug": category.slug,
            "parent_id": str(category.parent_id) if category.parent_id else None,
            "icon_url": category.icon_url,
            "description": category.description,
            "is_active": category.is_active,
            "sort_order": category.sort_order,
        },
    }


@router.put("/categories/{category_id}", summary="Update category (admin)")
async def update_category(
    category_id: UUID,
    body: CategoryUpdate,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Update an existing category."""
    result = await db.execute(select(Category).where(Category.id == category_id))
    category = result.scalar_one_or_none()
    if not category:
        raise HTTPException(404, "Category not found")

    update_fields = body.model_dump(exclude_unset=True)
    for field, value in update_fields.items():
        if field == "parent_id" and value is not None:
            value = UUID(value)
        elif field == "parent_id" and value is None:
            pass  # Allow setting parent_id to None
        setattr(category, field, value)

    await db.commit()
    await db.refresh(category)

    return {
        "success": True,
        "message": "Category updated",
        "data": {
            "id": str(category.id),
            "name": category.name,
            "slug": category.slug,
            "parent_id": str(category.parent_id) if category.parent_id else None,
            "icon_url": category.icon_url,
            "description": category.description,
            "is_active": category.is_active,
            "sort_order": category.sort_order,
        },
    }


@router.delete("/categories/{category_id}", summary="Delete category (admin)")
async def delete_category(
    category_id: UUID,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Delete a category. Will fail if products are attached."""
    result = await db.execute(select(Category).where(Category.id == category_id))
    category = result.scalar_one_or_none()
    if not category:
        raise HTTPException(404, "Category not found")

    # Check if category has products
    from sqlalchemy import exists
    has_products = await db.execute(
        select(exists().where(Product.category_id == category_id))
    )
    if has_products.scalar():
        raise HTTPException(
            400,
            f"Cannot delete category '{category.name}': it has products attached. "
            "Move or delete the products first."
        )

    # Check if category has subcategories
    has_children = await db.execute(
        select(exists().where(Category.parent_id == category_id))
    )
    if has_children.scalar():
        raise HTTPException(
            400,
            f"Cannot delete category '{category.name}': it has subcategories. "
            "Delete the subcategories first."
        )

    await db.delete(category)
    await db.commit()

    return {"success": True, "message": f"Category '{category.name}' deleted"}


# ─── Brands by Category (via product_lines) ─────────────

@router.get("/categories/{category_id}/brands", summary="Brands of a category")
async def list_brands_by_category(
    category_id: UUID,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Returns distinct brands that have product_lines in this category."""
    stmt = (
        select(Brand)
        .join(ProductLine, ProductLine.brand_id == Brand.id)
        .where(
            ProductLine.category_id == category_id,
            ProductLine.is_active == True,
            Brand.is_active == True,
        )
        .distinct()
        .order_by(Brand.name)
    )
    result = await db.execute(stmt)
    brands = result.scalars().unique().all()
    return {
        "success": True,
        "data": [
            {
                "id": str(b.id),
                "name": b.name,
                "slug": b.slug,
                "logo_url": b.logo_url,
                "country": b.country,
                "is_active": b.is_active,
            }
            for b in brands
        ],
    }


# ─── All Brands (fallback) ──────────────────────────────

@router.get("/brands", summary="List all brands (admin)")
async def list_brands(
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Brand).order_by(Brand.name))
    brands = result.scalars().all()
    return {
        "success": True,
        "data": [
            {
                "id": str(b.id),
                "name": b.name,
                "slug": b.slug,
                "logo_url": b.logo_url,
                "country": b.country,
                "is_active": b.is_active,
            }
            for b in brands
        ],
    }


# ─── Brand CRUD ──────────────────────────────────────────

class BrandCreate(BaseModel):
    name: str
    slug: str
    logo_url: str | None = None
    country: str | None = None
    is_active: bool = True


class BrandUpdate(BaseModel):
    name: str | None = None
    slug: str | None = None
    logo_url: str | None = None
    country: str | None = None
    is_active: bool | None = None


@router.post("/brands", summary="Create brand (admin)")
async def create_brand(
    body: BrandCreate,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Create a new brand."""
    existing = await db.execute(select(Brand).where(Brand.slug == body.slug))
    if existing.scalar_one_or_none():
        raise HTTPException(400, f"Slug '{body.slug}' already exists")

    brand = Brand(
        name=body.name,
        slug=body.slug,
        logo_url=body.logo_url,
        country=body.country,
        is_active=body.is_active,
    )
    db.add(brand)
    await db.commit()
    await db.refresh(brand)

    return {
        "success": True,
        "message": "Brand created",
        "data": {
            "id": str(brand.id),
            "name": brand.name,
            "slug": brand.slug,
            "logo_url": brand.logo_url,
            "country": brand.country,
            "is_active": brand.is_active,
        },
    }


@router.put("/brands/{brand_id}", summary="Update brand (admin)")
async def update_brand(
    brand_id: UUID,
    body: BrandUpdate,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Update an existing brand."""
    result = await db.execute(select(Brand).where(Brand.id == brand_id))
    brand = result.scalar_one_or_none()
    if not brand:
        raise HTTPException(404, "Brand not found")

    update_fields = body.model_dump(exclude_unset=True)
    for field, value in update_fields.items():
        setattr(brand, field, value)

    await db.commit()
    await db.refresh(brand)

    return {
        "success": True,
        "message": "Brand updated",
        "data": {
            "id": str(brand.id),
            "name": brand.name,
            "slug": brand.slug,
            "logo_url": brand.logo_url,
            "country": brand.country,
            "is_active": brand.is_active,
        },
    }


@router.delete("/brands/{brand_id}", summary="Delete brand (admin)")
async def delete_brand(
    brand_id: UUID,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Delete a brand. Will fail if products are attached."""
    result = await db.execute(select(Brand).where(Brand.id == brand_id))
    brand = result.scalar_one_or_none()
    if not brand:
        raise HTTPException(404, "Brand not found")

    from sqlalchemy import exists
    has_products = await db.execute(
        select(exists().where(Product.brand_id == brand_id))
    )
    if has_products.scalar():
        raise HTTPException(
            400,
            f"Cannot delete brand '{brand.name}': it has products attached. "
            "Move or delete the products first."
        )

    await db.delete(brand)
    await db.commit()

    return {"success": True, "message": f"Brand '{brand.name}' deleted"}


# ─── Product Lines by Category + Brand ──────────────────

@router.get("/product-lines", summary="List product lines (admin)")
async def list_product_lines(
    brand_id: Optional[str] = Query(None),
    category_id: Optional[str] = Query(None),
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    query = select(ProductLine).options(
        selectinload(ProductLine.brand),
        selectinload(ProductLine.category),
    )
    if brand_id:
        query = query.where(ProductLine.brand_id == UUID(brand_id))
    if category_id:
        query = query.where(ProductLine.category_id == UUID(category_id))
    query = query.order_by(ProductLine.sort_order, ProductLine.name)

    result = await db.execute(query)
    lines = result.unique().scalars().all()
    return {
        "success": True,
        "data": [
            {
                "id": str(l.id),
                "name": l.name,
                "slug": l.slug,
                "brand_id": str(l.brand_id),
                "brand_name": l.brand.name if l.brand else None,
                "category_id": str(l.category_id),
                "category_name": l.category.name if l.category else None,
                "description": l.description,
                "is_active": l.is_active,
                "sort_order": l.sort_order,
            }
            for l in lines
        ],
    }


# ─── Product Line CRUD ───────────────────────────────────

class ProductLineCreate(BaseModel):
    name: str
    slug: str
    brand_id: str
    category_id: str
    description: str | None = None
    is_active: bool = True
    sort_order: int = 0


class ProductLineUpdate(BaseModel):
    name: str | None = None
    slug: str | None = None
    brand_id: str | None = None
    category_id: str | None = None
    description: str | None = None
    is_active: bool | None = None
    sort_order: int | None = None


def _serialize_line(l: ProductLine) -> dict:
    return {
        "id": str(l.id),
        "name": l.name,
        "slug": l.slug,
        "brand_id": str(l.brand_id),
        "brand_name": l.brand.name if l.brand else None,
        "category_id": str(l.category_id),
        "category_name": l.category.name if l.category else None,
        "description": l.description,
        "is_active": l.is_active,
        "sort_order": l.sort_order,
    }


@router.post("/product-lines", summary="Create product line (admin)")
async def create_product_line(
    body: ProductLineCreate,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Create a new product line."""
    existing = await db.execute(select(ProductLine).where(ProductLine.slug == body.slug))
    if existing.scalar_one_or_none():
        raise HTTPException(400, f"Slug '{body.slug}' already exists")

    line = ProductLine(
        name=body.name,
        slug=body.slug,
        brand_id=UUID(body.brand_id),
        category_id=UUID(body.category_id),
        description=body.description,
        is_active=body.is_active,
        sort_order=body.sort_order,
    )
    db.add(line)
    await db.commit()

    # Re-fetch with relationships
    result = await db.execute(
        select(ProductLine).where(ProductLine.id == line.id).options(
            selectinload(ProductLine.brand),
            selectinload(ProductLine.category),
        )
    )
    line = result.unique().scalar_one()

    return {"success": True, "message": "Product line created", "data": _serialize_line(line)}


@router.put("/product-lines/{line_id}", summary="Update product line (admin)")
async def update_product_line(
    line_id: UUID,
    body: ProductLineUpdate,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Update an existing product line."""
    result = await db.execute(select(ProductLine).where(ProductLine.id == line_id))
    line = result.scalar_one_or_none()
    if not line:
        raise HTTPException(404, "Product line not found")

    update_fields = body.model_dump(exclude_unset=True)
    for field, value in update_fields.items():
        if field in ("brand_id", "category_id") and value:
            value = UUID(value)
        setattr(line, field, value)

    await db.commit()

    # Re-fetch with relationships
    result = await db.execute(
        select(ProductLine).where(ProductLine.id == line_id).options(
            selectinload(ProductLine.brand),
            selectinload(ProductLine.category),
        )
    )
    line = result.unique().scalar_one()

    return {"success": True, "message": "Product line updated", "data": _serialize_line(line)}


@router.delete("/product-lines/{line_id}", summary="Delete product line (admin)")
async def delete_product_line(
    line_id: UUID,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Delete a product line. Will fail if products are attached."""
    result = await db.execute(select(ProductLine).where(ProductLine.id == line_id))
    line = result.scalar_one_or_none()
    if not line:
        raise HTTPException(404, "Product line not found")

    from sqlalchemy import exists
    has_products = await db.execute(
        select(exists().where(Product.line_id == line_id))
    )
    if has_products.scalar():
        raise HTTPException(
            400,
            f"Cannot delete product line '{line.name}': it has products attached. "
            "Move or delete the products first."
        )

    await db.delete(line)
    await db.commit()

    return {"success": True, "message": f"Product line '{line.name}' deleted"}


# ─── Spec Templates by Category ─────────────────────────

from app.models.product import SpecTemplate

@router.get("/spec-templates", summary="Spec templates by category (admin)")
async def list_spec_templates(
    category_id: str = Query(..., description="Category ID to get spec templates for"),
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Returns spec_templates for a category, grouped by spec_group."""
    result = await db.execute(
        select(SpecTemplate)
        .where(SpecTemplate.category_id == UUID(category_id))
        .order_by(SpecTemplate.spec_group, SpecTemplate.sort_order, SpecTemplate.display_name)
    )
    templates = result.scalars().all()
    return {
        "success": True,
        "data": [
            {
                "id": str(t.id),
                "spec_key": t.spec_key,
                "display_name": t.display_name,
                "data_type": t.data_type,
                "unit": t.unit,
                "spec_group": t.spec_group,
                "is_filterable": t.is_filterable,
                "sort_order": t.sort_order,
            }
            for t in templates
        ],
    }

