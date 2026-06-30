"""
Catalog Endpoints — Duyệt danh mục sản phẩm theo cấu trúc phân cấp.

Endpoints:
    GET  /api/v1/catalog/categories                              — Danh sách category gốc + brands
    GET  /api/v1/catalog/categories/{category_id}                — Products + brands của 1 category
    GET  /api/v1/catalog/categories/{category_id}/brands/{brand_id}  — Products + lines của 1 brand
    GET  /api/v1/catalog/product-lines/{line_id}                 — Products của 1 product_line
"""

from typing import Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.models.user import User
from app.core.dependencies import get_optional_user
from app.services.catalog_service import catalog_service
from app.schemas.catalog import (
    CategoriesListResponse,
    CategoryProductsResponse, CategoryProductsData,
    BrandProductsResponse, BrandProductsData,
    LineProductsResponse, LineProductsData,
    AllProductsResponse, AllProductsData,
    ProductDetailResponse,
    ProductCompact,
)

router = APIRouter()


# ─── 0. Tất cả sản phẩm (không filter) ───────────────────

@router.get(
    "/products",
    response_model=AllProductsResponse,
    summary="Tất cả sản phẩm",
    description="Lấy tất cả products không phân biệt category/brand. Dùng khi chưa chọn filter nào.",
)
async def list_all_products(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):

    # Cá nhân hóa thứ tự sản phẩm nếu đã login
    user_profile = current_user.profile_summary if current_user else None
    user_id = current_user.id if current_user else None
    result = await catalog_service.get_all_products_cached(
        db, limit=limit, offset=offset,
        user_profile=user_profile, user_id=user_id,
    )

    data = AllProductsData(
        products=[ProductCompact(**p) if isinstance(p, dict) else p for p in result["products"]],
        total=result["total"],
    )
    return AllProductsResponse(data=data)


# ─── 0b. Chi tiết 1 sản phẩm ─────────────────────────────

@router.get(
    "/products/{product_id}",
    response_model=ProductDetailResponse,
    summary="Chi tiết sản phẩm",
    description="Lấy toàn bộ thông tin chi tiết của 1 sản phẩm: variants, images, specs, brand, category, line.",
)
async def get_product_detail(
    product_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    detail = await catalog_service.get_product_detail_cached(product_id, db)
    if detail is None:
        raise HTTPException(status_code=404, detail="Sản phẩm không tồn tại")

    # ── Tracking: cập nhật hồ sơ cá nhân + ghi lịch sử xem (fire-and-forget) ──
    if current_user:
        import asyncio
        _user_id = current_user.id

        async def _background_learn_view():
            from app.models.product import Product
            from app.models.interaction import ProductView
            from sqlalchemy.orm import selectinload
            from sqlalchemy import select, delete
            from app.db.session import SessionLocal
            import logging
            _logger = logging.getLogger("catalog")

            # ── Bước 1: Ghi lịch sử xem vào product_views (LUÔN chạy) ──
            try:
                async with SessionLocal() as view_db:
                    # Xóa bản ghi cũ nếu đã xem sản phẩm này (upsert logic)
                    await view_db.execute(
                        delete(ProductView).where(
                            ProductView.user_id == _user_id,
                            ProductView.product_id == product_id,
                        )
                    )

                    # Query product để lấy brand_id, category_id, line_id
                    stmt = select(Product).where(Product.id == product_id)
                    result = await view_db.execute(stmt)
                    product = result.scalar_one_or_none()

                    if product:
                        view = ProductView(
                            user_id=_user_id,
                            product_id=product.id,
                            brand_id=product.brand_id,
                            category_id=product.category_id,
                            line_id=product.line_id,
                        )
                        view_db.add(view)

                        # Giữ tối đa 30 bản ghi gần nhất
                        subq = (
                            select(ProductView.id)
                            .where(ProductView.user_id == _user_id)
                            .order_by(ProductView.viewed_at.desc())
                            .offset(30)
                        )
                        await view_db.execute(
                            delete(ProductView).where(ProductView.id.in_(subq))
                        )

                    await view_db.commit()
                    _logger.info(
                        f"👁️ [ProductView] Saved — user={str(_user_id)[:8]}... "
                        f"product={str(product_id)[:8]}... "
                        f"name={product.name if product else 'N/A'}"
                    )
            except Exception as e:
                _logger.error(
                    f"❌ [ProductView] FAILED — user={str(_user_id)[:8]}... "
                    f"product={str(product_id)[:8]}... error={e}", exc_info=True
                )

            # ── Bước 2: Cập nhật profile summary (Gemini — có thể fail) ──
            try:
                from app.services.profile_learning_service import profile_learning_service

                _logger.info(
                    f"🧠 [ProfileLearn] Starting — "
                    f"user={str(_user_id)[:8]}... product={str(product_id)[:8]}..."
                )

                async with SessionLocal() as profile_db:
                    stmt = (
                        select(Product)
                        .options(selectinload(Product.category), selectinload(Product.brand))
                        .where(Product.id == product_id)
                    )
                    result = await profile_db.execute(stmt)
                    product = result.scalar_one_or_none()
                    if product:
                        await profile_learning_service.learn_from_view(
                            user_id=_user_id,
                            product=product,
                            db=profile_db,
                        )
                        await profile_db.commit()
                        _logger.info(
                            f"✅ [ProfileLearn] Done — "
                            f"user={str(_user_id)[:8]}... product={product.name}"
                        )
                    else:
                        _logger.warning(
                            f"⚠️ [ProfileLearn] Product not found — "
                            f"product={str(product_id)[:8]}..."
                        )
            except Exception as e:
                _logger.error(
                    f"❌ [ProfileLearn] FAILED — "
                    f"user={str(_user_id)[:8]}... product={str(product_id)[:8]}... "
                    f"error={e}", exc_info=True
                )

        asyncio.create_task(_background_learn_view())

    return ProductDetailResponse(data=detail)


# ─── 1. Danh sách categories gốc + brands ────────────────

@router.get(
    "/categories",
    response_model=CategoriesListResponse,
    summary="Danh sách danh mục gốc + thương hiệu",
    description=(
        "Lấy tất cả categories có parent_id = NULL (danh mục gốc: Điện thoại, Laptop, Tai nghe...). "
        "Mỗi category kèm danh sách brands (distinct từ product_lines) thuộc category đó."
    ),
)
async def list_categories(db: AsyncSession = Depends(get_db)):
    categories = await catalog_service.get_root_categories_with_brands(db)
    return CategoriesListResponse(data=categories)


# ─── 2. Products + brands của 1 category ─────────────────

@router.get(
    "/categories/{category_id}",
    response_model=CategoryProductsResponse,
    summary="Sản phẩm theo danh mục",
    description=(
        "Lấy tất cả products thuộc category_id. "
        "Kèm danh sách brands (để hiển thị thanh filter brand phía trên). "
        "Dùng khi user ấn chọn 1 category (VD: Điện thoại)."
    ),
)
async def get_category_products(
    category_id: UUID,
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    user_profile = current_user.profile_summary if current_user else None
    user_id = current_user.id if current_user else None
    result = await catalog_service.get_category_products_cached(
        category_id, db, limit=limit, offset=offset,
        user_profile=user_profile, user_id=user_id,
    )
    if result is None:
        raise HTTPException(status_code=404, detail="Category không tồn tại")

    return CategoryProductsResponse(data=CategoryProductsData(**result))


# ─── 3. Products + lines của 1 brand trong 1 category ────

@router.get(
    "/categories/{category_id}/brands/{brand_id}",
    response_model=BrandProductsResponse,
    summary="Sản phẩm theo thương hiệu trong danh mục",
    description=(
        "Lấy tất cả products thuộc category_id + brand_id. "
        "Kèm danh sách product_lines của brand trong category đó "
        "(VD: iPhone 13 Series, iPhone 14 Series...). "
        "Dùng khi user ấn chọn 1 brand sau khi đã chọn category."
    ),
)
async def get_brand_products(
    category_id: UUID,
    brand_id: UUID,
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    user_profile = current_user.profile_summary if current_user else None
    user_id = current_user.id if current_user else None
    result = await catalog_service.get_brand_products_cached(
        category_id, brand_id, db, limit=limit, offset=offset,
        user_profile=user_profile, user_id=user_id,
    )
    if result is None:
        raise HTTPException(status_code=404, detail="Category hoặc Brand không tồn tại")

    return BrandProductsResponse(data=BrandProductsData(**result))


# ─── 4. Products của 1 product_line ──────────────────────

@router.get(
    "/product-lines/{line_id}",
    response_model=LineProductsResponse,
    summary="Sản phẩm theo dòng sản phẩm",
    description=(
        "Lấy products có line_id chính xác bằng line_id truyền vào. "
        "VD: iPhone 16 Series → hiển thị iPhone 16, iPhone 16 Plus, iPhone 16 Pro, iPhone 16 Pro Max."
    ),
)
async def get_line_products(
    line_id: UUID,
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: AsyncSession = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    user_profile = current_user.profile_summary if current_user else None
    user_id = current_user.id if current_user else None
    result = await catalog_service.get_line_products_cached(
        line_id, db, limit=limit, offset=offset,
        user_profile=user_profile, user_id=user_id,
    )
    if result is None:
        raise HTTPException(status_code=404, detail="Product Line không tồn tại")

    return LineProductsResponse(data=LineProductsData(**result))
