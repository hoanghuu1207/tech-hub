"""
Order & Payment schemas.
"""

from decimal import Decimal
from typing import Optional, List
from uuid import UUID
from datetime import datetime
from pydantic import BaseModel, Field


# ─── Address ──────────────────────────────────────────────

class AddressCreate(BaseModel):
    recipient_name: str = Field(..., min_length=1, max_length=255)
    phone: str = Field(..., min_length=8, max_length=20)
    province: Optional[str] = None
    district: Optional[str] = None
    ward: Optional[str] = None
    street: Optional[str] = None


class AddressOut(AddressCreate):
    id: UUID

    class Config:
        from_attributes = True


# ─── Order Item ───────────────────────────────────────────

class OrderItemCreate(BaseModel):
    product_id: UUID
    variant_id: Optional[UUID] = None
    quantity: int = Field(1, ge=1)


class OrderItemOut(BaseModel):
    id: UUID
    product_id: UUID
    variant_id: Optional[UUID] = None
    quantity: int
    unit_price: float
    subtotal: float
    product_name: Optional[str] = None
    product_image: Optional[str] = None

    class Config:
        from_attributes = True


# ─── Create Order (Checkout) ─────────────────────────────

class CreateOrderRequest(BaseModel):
    """Request tạo đơn hàng + thanh toán PayOS."""
    items: List[OrderItemCreate] = Field(..., min_length=1, description="Danh sách sản phẩm")
    address_id: Optional[UUID] = Field(None, description="ID địa chỉ đã lưu. Nếu null thì dùng shipping_address mới.")
    shipping_address: Optional[AddressCreate] = Field(None, description="Địa chỉ mới (nếu không dùng address_id)")
    note: Optional[str] = Field(None, max_length=500)
    payment_method: str = Field("payos", description="Phương thức thanh toán: 'payos', 'cod'")


class CreateOrderResponse(BaseModel):
    """Response sau khi tạo đơn hàng."""
    order_id: UUID
    order_code: int
    status: str
    payment_status: str
    total_amount: float
    checkout_url: Optional[str] = None  # PayOS checkout URL
    qr_code: Optional[str] = None  # PayOS QR code URL


# ─── Order Detail ─────────────────────────────────────────

class OrderOut(BaseModel):
    id: UUID
    order_code: Optional[int] = None
    status: str
    total_amount: float
    discount_amount: float = 0
    shipping_fee: float = 0
    payment_method: Optional[str] = None
    payment_status: str
    payment_expires_at: Optional[datetime] = None
    note: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    items: List[OrderItemOut] = []
    address: Optional[AddressOut] = None

    class Config:
        from_attributes = True


class OrderListResponse(BaseModel):
    success: bool = True
    message: str = "OK"
    data: List[OrderOut]


class OrderDetailResponse(BaseModel):
    success: bool = True
    message: str = "OK"
    data: Optional[OrderOut] = None
    error: Optional[str] = None


class CheckoutResponse(BaseModel):
    success: bool = True
    message: str = "OK"
    data: Optional[CreateOrderResponse] = None
    error: Optional[str] = None
