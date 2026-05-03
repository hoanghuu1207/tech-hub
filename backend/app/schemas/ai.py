"""
AI Search Module — Request/Response DTOs.

Định nghĩa cấu trúc dữ liệu cho các API endpoint liên quan đến
tìm kiếm ngữ nghĩa (semantic search) qua Qdrant.
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from uuid import UUID


# ─── Request DTOs ──────────────────────────────────────────

class AISearchFilters(BaseModel):
    """Bộ lọc tuỳ chọn để thu hẹp kết quả tìm kiếm từ Qdrant payload."""
    category_slug: Optional[str] = Field(None, description="Slug danh mục (vd: 'smartphone', 'laptop')")
    brand_slug: Optional[str] = Field(None, description="Slug thương hiệu (vd: 'apple', 'samsung')")
    price_min: Optional[float] = Field(None, ge=0, description="Giá tối thiểu (VNĐ)")
    price_max: Optional[float] = Field(None, ge=0, description="Giá tối đa (VNĐ)")
    # Spec filters (trích xuất tự động từ NLP hoặc client truyền)
    ram_min: Optional[int] = Field(None, description="RAM tối thiểu (GB)")
    ram_max: Optional[int] = Field(None, description="RAM tối đa (GB)")
    storage_min: Optional[int] = Field(None, description="Bộ nhớ tối thiểu (GB)")
    storage_max: Optional[int] = Field(None, description="Bộ nhớ tối đa (GB)")
    screen_min: Optional[float] = Field(None, description="Kích thước màn hình tối thiểu (inch)")
    screen_max: Optional[float] = Field(None, description="Kích thước màn hình tối đa (inch)")


class AISearchRequest(BaseModel):
    """Request body cho API tìm kiếm bằng ngôn ngữ tự nhiên."""
    query: str = Field(
        ...,
        min_length=2,
        max_length=500,
        description="Câu truy vấn bằng ngôn ngữ tự nhiên",
        examples=["laptop mỏng nhẹ dưới 20 triệu cho sinh viên"]
    )
    filters: Optional[AISearchFilters] = Field(None, description="Bộ lọc tuỳ chọn")
    limit: int = Field(10, ge=1, le=50, description="Số lượng kết quả tối đa trả về")


class AISuggestRequest(BaseModel):
    """Request body cho API gợi ý tìm kiếm."""
    query: str = Field(
        ...,
        min_length=1,
        max_length=200,
        description="Từ khoá để gợi ý",
        examples=["iphone"]
    )
    limit: int = Field(5, ge=1, le=20, description="Số gợi ý tối đa")


# ─── Response DTOs ─────────────────────────────────────────

class AIProductResult(BaseModel):
    """Kết quả 1 sản phẩm trả về từ AI Search."""
    id: UUID
    name: str
    slug: str
    category_name: Optional[str] = None
    category_slug: Optional[str] = None
    brand_name: Optional[str] = None
    brand_slug: Optional[str] = None
    base_price: float
    sale_price: Optional[float] = None
    primary_image: Optional[str] = None
    rating_avg: Optional[float] = 0
    sold_count: Optional[int] = 0
    highlight_features: Optional[list] = []
    similarity_score: float = Field(
        ...,
        description="Điểm tương đồng cosine (0-1, càng cao càng khớp)"
    )

    class Config:
        from_attributes = True


class AISearchData(BaseModel):
    """Dữ liệu kết quả tìm kiếm AI."""
    products: List[AIProductResult]
    total: int
    query: str
    search_time_ms: float


class AISearchResponse(BaseModel):
    """Response chuẩn cho API AI Search."""
    success: bool = True
    message: str
    data: Optional[AISearchData] = None
    error: Optional[str] = None


class AISuggestItem(BaseModel):
    """Một gợi ý tìm kiếm."""
    text: str
    category_slug: Optional[str] = None


class AISuggestResponse(BaseModel):
    """Response chuẩn cho API AI Suggest."""
    success: bool = True
    message: str
    data: Optional[List[AISuggestItem]] = None
    error: Optional[str] = None
