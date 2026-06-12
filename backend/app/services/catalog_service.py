"""
CatalogService — Duyệt danh mục / thương hiệu / dòng sản phẩm.

Cung cấp 4 API chính:
  1. GET /categories           → Danh sách category gốc + brands
  2. GET /categories/{id}      → Products + brands của 1 category
  3. GET /categories/{id}/brands/{id} → Products + lines của 1 brand/category
  4. GET /product-lines/{id}   → Products của 1 line

Cá nhân hóa:
  - Khi user đã login và có profile_summary, danh sách sản phẩm sẽ được
    re-rank (boost) theo sở thích cá nhân (thương hiệu, danh mục, tầm giá).
"""

import logging
from uuid import UUID
from typing import Optional, List

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.product import (
    Category, Brand, ProductLine, Product, ProductImage, ProductVariant,
)
from app.schemas.catalog import (
    CategoryOut, BrandOut, ProductLineOut, ProductCompact,
    CategoryWithBrandsOut,
    ProductDetailOut, ProductVariantOut, ProductImageOut,
)

logger = logging.getLogger("catalog")


class CatalogService:
    """Service duyệt catalog theo cấu trúc Category → Brand → Line → Product."""

    # ──────────────────────────────────────────────────────
    # Helpers (shared logic)
    # ──────────────────────────────────────────────────────

    @staticmethod
    def _product_to_compact(product: Product) -> ProductCompact:
        """Chuyển Product ORM → schema gọn cho danh sách."""
        primary_image = None
        if product.images:
            for img in product.images:
                if img.is_primary:
                    primary_image = img.image_url
                    break
            if not primary_image:
                primary_image = product.images[0].image_url

        return ProductCompact(
            id=product.id,
            name=product.name,
            slug=product.slug,
            base_price=float(product.base_price),
            sale_price=float(product.sale_price) if product.sale_price else None,
            primary_image=primary_image,
            rating_avg=float(product.rating_avg or 0),
            sold_count=product.sold_count or 0,
            brand_name=product.brand.name if product.brand else None,
            category_name=product.category.name if product.category else None,
            line_name=product.line.name if product.line else None,
        )

    @staticmethod
    def _personalize_products(
        products: List[Product],
        profile_summary: Optional[str],
    ) -> List[Product]:
        """
        Re-rank danh sách sản phẩm dựa trên hồ sơ người dùng.
        Boost các sản phẩm khớp thương hiệu/danh mục yêu thích lên đầu.
        Không thay đổi tập kết quả, chỉ thay đổi thứ tự.
        """
        if not profile_summary or not products:
            return products

        profile_lower = profile_summary.lower()

        def _calc_boost(product: Product) -> float:
            """Tính điểm boost cho 1 sản phẩm dựa trên profile."""
            boost = 0.0

            # Boost nếu thương hiệu khớp
            if product.brand and product.brand.name:
                brand_name = product.brand.name.lower()
                if brand_name in profile_lower:
                    boost += 3.0

            # Boost nếu danh mục khớp
            if product.category and product.category.name:
                cat_name = product.category.name.lower()
                if cat_name in profile_lower:
                    boost += 2.0

            # Boost nếu tên sản phẩm chứa từ khóa trong profile
            if product.name:
                name_lower = product.name.lower()
                # Tìm các từ khóa đặc trưng trong profile
                keywords = ["chống ồn", "pin trâu", "gaming", "mỏng nhẹ",
                            "chụp ảnh", "chống nước", "true wireless"]
                for kw in keywords:
                    if kw in profile_lower and kw in name_lower:
                        boost += 1.5

            return boost

        # Sắp xếp: sản phẩm có boost cao lên trước, giữ thứ tự cũ nếu boost bằng nhau
        products_with_boost = [(p, _calc_boost(p)) for p in products]
        products_with_boost.sort(key=lambda x: x[1], reverse=True)

        # Chỉ re-rank nếu ít nhất 1 sản phẩm có boost > 0
        if any(b > 0 for _, b in products_with_boost):
            return [p for p, _ in products_with_boost]

        return products

    @staticmethod
    async def _query_products(
        db: AsyncSession,
        *,
        category_id: Optional[UUID] = None,
        brand_id: Optional[UUID] = None,
        line_id: Optional[UUID] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> List[Product]:
        """Query products với các filter tùy chọn, eager-load quan hệ cần thiết."""
        stmt = (
            select(Product)
            .options(
                selectinload(Product.images),
                selectinload(Product.brand),
                selectinload(Product.category),
                selectinload(Product.line),
            )
            .where(Product.is_active == True, Product.deleted_at.is_(None))
            .order_by(Product.sold_count.desc(), Product.created_at.desc())
        )

        if category_id:
            stmt = stmt.where(Product.category_id == category_id)
        if brand_id:
            stmt = stmt.where(Product.brand_id == brand_id)
        if line_id:
            stmt = stmt.where(Product.line_id == line_id)

        stmt = stmt.limit(limit).offset(offset)
        result = await db.execute(stmt)
        return list(result.scalars().unique().all())

    @staticmethod
    async def _count_products(
        db: AsyncSession,
        *,
        category_id: Optional[UUID] = None,
        brand_id: Optional[UUID] = None,
        line_id: Optional[UUID] = None,
    ) -> int:
        """Đếm tổng sản phẩm theo filter."""
        stmt = select(func.count(Product.id)).where(Product.is_active == True, Product.deleted_at.is_(None))
        if category_id:
            stmt = stmt.where(Product.category_id == category_id)
        if brand_id:
            stmt = stmt.where(Product.brand_id == brand_id)
        if line_id:
            stmt = stmt.where(Product.line_id == line_id)
        result = await db.execute(stmt)
        return result.scalar() or 0

    @staticmethod
    async def _get_brands_of_category(db: AsyncSession, category_id: UUID) -> List[Brand]:
        """Lấy danh sách brands (distinct) có trong category thông qua product_lines."""
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
        return list(result.scalars().unique().all())

    # ──────────────────────────────────────────────────────
    # API 1: Danh sách categories gốc + brands
    # ──────────────────────────────────────────────────────

    async def get_root_categories_with_brands(
        self, db: AsyncSession
    ) -> List[CategoryWithBrandsOut]:
        """
        Lấy categories có parent_id = NULL (gốc).
        Mỗi category kèm danh sách brands (distinct từ product_lines).
        """
        # Lấy categories gốc
        stmt = (
            select(Category)
            .where(Category.parent_id == None, Category.is_active == True)
            .order_by(Category.sort_order, Category.name)
        )
        result = await db.execute(stmt)
        categories = result.scalars().all()

        output = []
        for cat in categories:
            brands = await self._get_brands_of_category(db, cat.id)
            output.append(CategoryWithBrandsOut(
                id=cat.id,
                name=cat.name,
                slug=cat.slug,
                icon_url=cat.icon_url,
                description=cat.description,
                sort_order=cat.sort_order or 0,
                brands=[BrandOut.model_validate(b) for b in brands],
            ))

        return output

    # ──────────────────────────────────────────────────────
    # API 2: Products + brands của 1 category
    # ──────────────────────────────────────────────────────

    async def get_category_products(
        self, category_id: UUID, db: AsyncSession,
        limit: int = 50, offset: int = 0,
        user_profile: Optional[str] = None,
    ) -> dict:
        """
        Lấy tất cả products thuộc category_id,
        kèm danh sách brands của category đó.
        """
        # Category info
        category = await db.get(Category, category_id)
        if not category:
            return None

        # Brands + Products (song song)
        brands = await self._get_brands_of_category(db, category_id)
        products = await self._query_products(
            db, category_id=category_id, limit=limit, offset=offset
        )
        total = await self._count_products(db, category_id=category_id)

        # Cá nhân hóa thứ tự sản phẩm
        products = self._personalize_products(products, user_profile)

        return {
            "category": CategoryOut.model_validate(category),
            "brands": [BrandOut.model_validate(b) for b in brands],
            "products": [self._product_to_compact(p) for p in products],
            "total": total,
        }

    # ──────────────────────────────────────────────────────
    # API 3: Products + lines của 1 brand trong 1 category
    # ──────────────────────────────────────────────────────

    async def get_brand_products(
        self, category_id: UUID, brand_id: UUID, db: AsyncSession,
        limit: int = 50, offset: int = 0,
        user_profile: Optional[str] = None,
    ) -> dict:
        """
        Lấy tất cả products thuộc category_id + brand_id,
        kèm danh sách product_lines của brand trong category đó.
        """
        category = await db.get(Category, category_id)
        brand = await db.get(Brand, brand_id)
        if not category or not brand:
            return None

        # Product lines của brand trong category
        stmt = (
            select(ProductLine)
            .where(
                ProductLine.category_id == category_id,
                ProductLine.brand_id == brand_id,
                ProductLine.is_active == True,
            )
            .order_by(ProductLine.sort_order, ProductLine.name)
        )
        result = await db.execute(stmt)
        lines = list(result.scalars().all())

        # Products
        products = await self._query_products(
            db, category_id=category_id, brand_id=brand_id,
            limit=limit, offset=offset,
        )
        total = await self._count_products(
            db, category_id=category_id, brand_id=brand_id,
        )

        # Cá nhân hóa thứ tự sản phẩm
        products = self._personalize_products(products, user_profile)

        return {
            "category": CategoryOut.model_validate(category),
            "brand": BrandOut.model_validate(brand),
            "product_lines": [ProductLineOut.model_validate(ln) for ln in lines],
            "products": [self._product_to_compact(p) for p in products],
            "total": total,
        }

    # ──────────────────────────────────────────────────────
    # API 4: Products của 1 product_line
    # ──────────────────────────────────────────────────────

    async def get_line_products(
        self, line_id: UUID, db: AsyncSession,
        limit: int = 50, offset: int = 0,
        user_profile: Optional[str] = None,
    ) -> dict:
        """
        Lấy products có line_id = line_id (chỉ lấy đúng line đó).
        """
        stmt = (
            select(ProductLine)
            .options(selectinload(ProductLine.brand))
            .where(ProductLine.id == line_id)
        )
        result = await db.execute(stmt)
        line = result.scalar_one_or_none()
        if not line:
            return None

        products = await self._query_products(
            db, line_id=line_id, limit=limit, offset=offset
        )
        total = await self._count_products(db, line_id=line_id)

        # Cá nhân hóa thứ tự sản phẩm
        products = self._personalize_products(products, user_profile)

        return {
            "product_line": ProductLineOut.model_validate(line),
            "brand": BrandOut.model_validate(line.brand),
            "products": [self._product_to_compact(p) for p in products],
            "total": total,
        }


    # ──────────────────────────────────────────────────────
    # API 5: Product Detail
    # ──────────────────────────────────────────────────────

    async def get_product_detail(
        self, product_id: UUID, db: AsyncSession,
    ) -> Optional[ProductDetailOut]:
        """
        Lấy chi tiết đầy đủ của 1 product: variants, images, brand, category, line, specs.
        Chỉ trả về product active. Variants chỉ lấy is_active. Images sort theo sort_order.
        """
        stmt = (
            select(Product)
            .options(
                selectinload(Product.variants),
                selectinload(Product.images),
                selectinload(Product.brand),
                selectinload(Product.category),
                selectinload(Product.line),
            )
            .where(Product.id == product_id, Product.is_active == True)
        )
        result = await db.execute(stmt)
        product = result.scalar_one_or_none()

        if not product:
            return None

        # Filter active variants, sort images by sort_order
        active_variants = [
            v for v in product.variants if v.is_active
        ]
        sorted_images = sorted(
            product.images, key=lambda img: img.sort_order
        )

        return ProductDetailOut(
            id=product.id,
            name=product.name,
            slug=product.slug,
            base_price=float(product.base_price),
            sale_price=float(product.sale_price) if product.sale_price else None,
            description=product.description,
            highlight_features=product.highlight_features or [],
            rating_avg=float(product.rating_avg or 0),
            rating_count=product.rating_count or 0,
            sold_count=product.sold_count or 0,
            status=product.status or "new",
            brand=BrandOut.model_validate(product.brand) if product.brand else None,
            category=CategoryOut.model_validate(product.category) if product.category else None,
            line=ProductLineOut.model_validate(product.line) if product.line else None,
            variants=[ProductVariantOut(
                id=v.id,
                color_name=v.color_name,
                color_hex=v.color_hex,
                price_override=float(v.price_override) if v.price_override else None,
                sale_price_override=float(v.sale_price_override) if v.sale_price_override else None,
                stock_quantity=v.stock_quantity or 0,
            ) for v in active_variants],
            images=[ProductImageOut(
                id=img.id,
                image_url=img.image_url,
                is_primary=img.is_primary,
                sort_order=img.sort_order,
            ) for img in sorted_images],
            specs=product.specs or {},
        )


# Singleton
catalog_service = CatalogService()
