import uuid
from sqlalchemy import Column, String, Boolean, DateTime, Integer, ForeignKey, Text, Numeric
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.db.base import Base

class Category(Base):
    __tablename__ = "categories"

    id = Column("category_id", UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), nullable=False)
    slug = Column(String(100), nullable=False, unique=True)
    parent_id = Column(UUID(as_uuid=True), ForeignKey("categories.category_id", ondelete="SET NULL"), nullable=True)
    icon_url = Column(Text, nullable=True)
    description = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True)
    sort_order = Column(Integer, default=0)

    # Relationships
    parent = relationship("Category", remote_side=[id], backref="subcategories")
    products = relationship("Product", back_populates="category")
    product_lines = relationship("ProductLine", back_populates="category")
    spec_templates = relationship("SpecTemplate", back_populates="category", cascade="all, delete-orphan")


class Brand(Base):
    __tablename__ = "brands"

    id = Column("brand_id", UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(100), nullable=False)
    slug = Column(String(100), nullable=False, unique=True)
    logo_url = Column(Text, nullable=True)
    country = Column(String(100), nullable=True)
    is_active = Column(Boolean, default=True)

    # Relationships
    products = relationship("Product", back_populates="brand")
    product_lines = relationship("ProductLine", back_populates="brand")


class ProductLine(Base):
    __tablename__ = "product_lines"

    id = Column("line_id", UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    brand_id = Column(UUID(as_uuid=True), ForeignKey("brands.brand_id", ondelete="CASCADE"), nullable=False)
    category_id = Column(UUID(as_uuid=True), ForeignKey("categories.category_id", ondelete="CASCADE"), nullable=False)
    name = Column(String(150), nullable=False)
    slug = Column(String(150), nullable=False, unique=True)
    description = Column(Text, nullable=True)
    banner_url = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True)
    sort_order = Column(Integer, default=0)

    # Relationships
    brand = relationship("Brand", back_populates="product_lines")
    category = relationship("Category", back_populates="product_lines")
    products = relationship("Product", back_populates="line")


class Product(Base):
    __tablename__ = "products"

    id = Column("product_id", UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    category_id = Column(UUID(as_uuid=True), ForeignKey("categories.category_id"), nullable=False)
    brand_id = Column(UUID(as_uuid=True), ForeignKey("brands.brand_id"), nullable=False)
    line_id = Column(UUID(as_uuid=True), ForeignKey("product_lines.line_id", ondelete="SET NULL"), nullable=True)
    
    name = Column(String(255), nullable=False)
    slug = Column(String(255), nullable=False, unique=True)
    original_url = Column(Text, nullable=True)
    description = Column(Text, nullable=True)
    highlight_features = Column(JSONB, default=[])
    
    base_price = Column(Numeric(15, 2), nullable=False)
    sale_price = Column(Numeric(15, 2), nullable=True)
    status = Column(String(20), default="new")
    
    specs = Column(JSONB, default={})
    qdrant_vector_id = Column(String(100), nullable=True)
    
    rating_avg = Column(Numeric(3, 2), default=0)
    rating_count = Column(Integer, default=0)
    sold_count = Column(Integer, default=0)
    
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # Relationships
    category = relationship("Category", back_populates="products")
    brand = relationship("Brand", back_populates="products")
    line = relationship("ProductLine", back_populates="products")
    variants = relationship("ProductVariant", back_populates="product", cascade="all, delete-orphan")
    images = relationship("ProductImage", back_populates="product", cascade="all, delete-orphan")
    reviews = relationship("Review", back_populates="product")


class ProductVariant(Base):
    __tablename__ = "product_variants"

    id = Column("variant_id", UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    product_id = Column(UUID(as_uuid=True), ForeignKey("products.product_id", ondelete="CASCADE"), nullable=False)
    
    color_name = Column(String(100), nullable=False)
    color_hex = Column(String(7), nullable=True)
    price_override = Column(Numeric(15, 2), nullable=True)
    sale_price_override = Column(Numeric(15, 2), nullable=True)
    stock_quantity = Column(Integer, nullable=False, default=0)
    sku = Column(String(100), unique=True, nullable=True)
    
    is_active = Column(Boolean, default=True)
    sort_order = Column(Integer, default=0)

    # Relationships
    product = relationship("Product", back_populates="variants")
    images = relationship("ProductImage", back_populates="variant")


class ProductImage(Base):
    __tablename__ = "product_images"

    id = Column("image_id", UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    product_id = Column(UUID(as_uuid=True), ForeignKey("products.product_id", ondelete="CASCADE"), nullable=False)
    variant_id = Column(UUID(as_uuid=True), ForeignKey("product_variants.variant_id", ondelete="SET NULL"), nullable=True)
    
    image_url = Column(Text, nullable=False)
    alt_text = Column(String(255), nullable=True)
    is_primary = Column(Boolean, default=False)
    sort_order = Column(Integer, default=0)

    # Relationships
    product = relationship("Product", back_populates="images")
    variant = relationship("ProductVariant", back_populates="images")


class SpecTemplate(Base):
    __tablename__ = "spec_templates"

    id = Column("template_id", UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    category_id = Column(UUID(as_uuid=True), ForeignKey("categories.category_id", ondelete="CASCADE"), nullable=False)
    
    spec_key = Column(String(100), nullable=False)
    display_name = Column(String(100), nullable=False)
    data_type = Column(String(20), nullable=False)
    unit = Column(String(30), nullable=True)
    spec_group = Column(String(50), nullable=True)
    is_filterable = Column(Boolean, default=False)
    sort_order = Column(Integer, default=0)

    # Relationships
    category = relationship("Category", back_populates="spec_templates")
