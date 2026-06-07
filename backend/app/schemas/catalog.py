"""
Catalog Schemas — Categories, Brands, ProductLines, Products browsing.

Dùng cho các API duyệt danh mục sản phẩm theo cấu trúc phân cấp:
  Category → Brand → ProductLine → Product
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from uuid import UUID


# ─── Base Items ──────────────────────────────────────────

class BrandOut(BaseModel):
    id: UUID
    name: str
    slug: str
    logo_url: Optional[str] = None

    class Config:
        from_attributes = True


class ProductLineOut(BaseModel):
    id: UUID
    name: str
    slug: str
    brand_id: UUID
    category_id: UUID

    class Config:
        from_attributes = True


class CategoryOut(BaseModel):
    id: UUID
    name: str
    slug: str
    icon_url: Optional[str] = None
    description: Optional[str] = None
    sort_order: int = 0

    class Config:
        from_attributes = True


class ProductCompact(BaseModel):
    """Thông tin sản phẩm gọn cho danh sách."""
    id: UUID
    name: str
    slug: str
    base_price: float
    sale_price: Optional[float] = None
    primary_image: Optional[str] = None
    rating_avg: Optional[float] = 0
    sold_count: Optional[int] = 0
    brand_name: Optional[str] = None
    category_name: Optional[str] = None
    line_name: Optional[str] = None

    class Config:
        from_attributes = True


# ─── Response DTOs ───────────────────────────────────────

class CategoryWithBrandsOut(CategoryOut):
    """Category kèm danh sách brands thuộc category đó."""
    brands: List[BrandOut] = []


class CategoriesListResponse(BaseModel):
    success: bool = True
    message: str = "OK"
    data: List[CategoryWithBrandsOut]


class CategoryProductsResponse(BaseModel):
    """Response cho API 2: products + brands của 1 category."""
    success: bool = True
    message: str = "OK"
    data: Optional["CategoryProductsData"] = None


class CategoryProductsData(BaseModel):
    category: CategoryOut
    brands: List[BrandOut]
    products: List[ProductCompact]
    total: int


class BrandProductsResponse(BaseModel):
    """Response cho API 3: products + product_lines của 1 brand trong 1 category."""
    success: bool = True
    message: str = "OK"
    data: Optional["BrandProductsData"] = None


class BrandProductsData(BaseModel):
    category: CategoryOut
    brand: BrandOut
    product_lines: List[ProductLineOut]
    products: List[ProductCompact]
    total: int


class LineProductsResponse(BaseModel):
    """Response cho API 4: products của 1 product_line."""
    success: bool = True
    message: str = "OK"
    data: Optional["LineProductsData"] = None


class LineProductsData(BaseModel):
    product_line: ProductLineOut
    brand: BrandOut
    products: List[ProductCompact]
    total: int


class AllProductsData(BaseModel):
    products: List[ProductCompact]
    total: int


class AllProductsResponse(BaseModel):
    """Response cho API lấy tất cả products (không filter)."""
    success: bool = True
    message: str = "OK"
    data: Optional[AllProductsData] = None



# ─── Product Detail ─────────────────────────────────────

class ProductVariantOut(BaseModel):
    """Variant detail for product detail page."""
    id: UUID
    color_name: str
    color_hex: Optional[str] = None
    price_override: Optional[float] = None
    sale_price_override: Optional[float] = None
    stock_quantity: int = 0

    class Config:
        from_attributes = True


class ProductImageOut(BaseModel):
    """Image detail for product detail page."""
    id: UUID
    image_url: str
    is_primary: bool = False
    sort_order: int = 0

    class Config:
        from_attributes = True


class ProductDetailOut(BaseModel):
    """Full product detail."""
    id: UUID
    name: str
    slug: str
    base_price: float
    sale_price: Optional[float] = None
    description: Optional[str] = None
    highlight_features: Optional[List[str]] = []
    rating_avg: Optional[float] = 0
    rating_count: Optional[int] = 0
    sold_count: Optional[int] = 0
    status: Optional[str] = "new"
    brand: Optional[BrandOut] = None
    category: Optional[CategoryOut] = None
    line: Optional[ProductLineOut] = None
    variants: List[ProductVariantOut] = []
    images: List[ProductImageOut] = []
    specs: Optional[dict] = {}

    class Config:
        from_attributes = True


class ProductDetailResponse(BaseModel):
    """Response for product detail API."""
    success: bool = True
    message: str = "OK"
    data: Optional[ProductDetailOut] = None


# Resolve forward references
CategoryProductsResponse.model_rebuild()
BrandProductsResponse.model_rebuild()
LineProductsResponse.model_rebuild()
ProductDetailResponse.model_rebuild()
