-- ============================================================
-- TechShop E-Commerce — Initial Database Schema
-- PostgreSQL 16+
-- ============================================================

-- 0. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "pgcrypto";  -- gen_random_uuid()

-- ============================================================
-- 1. CATEGORIES (self-referencing for subcategories)
-- ============================================================
CREATE TABLE IF NOT EXISTS categories (
    category_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(100) NOT NULL,
    slug        VARCHAR(100) NOT NULL UNIQUE,
    parent_id   UUID REFERENCES categories(category_id) ON DELETE SET NULL,
    icon_url    TEXT,
    description TEXT,
    is_active   BOOLEAN DEFAULT TRUE,
    sort_order  INT DEFAULT 0
);

-- ============================================================
-- 2. BRANDS
-- ============================================================
CREATE TABLE IF NOT EXISTS brands (
    brand_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name     VARCHAR(100) NOT NULL,
    slug     VARCHAR(100) NOT NULL UNIQUE,
    logo_url TEXT,
    country  VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE
);

-- ============================================================
-- 3. PRODUCT LINES (Dòng sản phẩm)
--    VD: Apple > iPhone 17 Series, Samsung > Galaxy S25 Series
-- ============================================================
CREATE TABLE IF NOT EXISTS product_lines (
    line_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    brand_id    UUID NOT NULL REFERENCES brands(brand_id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES categories(category_id) ON DELETE CASCADE,
    name        VARCHAR(150) NOT NULL,
    slug        VARCHAR(150) NOT NULL UNIQUE,
    description TEXT,
    banner_url  TEXT,
    is_active   BOOLEAN DEFAULT TRUE,
    sort_order  INT DEFAULT 0,
    UNIQUE(brand_id, name)
);

-- ============================================================
-- 4. PRODUCTS (model sản phẩm, chưa phân màu)
--    VD: "iPhone 17 Pro 256GB" = 1 product
-- ============================================================
CREATE TABLE IF NOT EXISTS products (
    product_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id      UUID NOT NULL REFERENCES categories(category_id),
    brand_id         UUID NOT NULL REFERENCES brands(brand_id),
    line_id          UUID REFERENCES product_lines(line_id) ON DELETE SET NULL,
    name             VARCHAR(255) NOT NULL,
    slug             VARCHAR(255) NOT NULL UNIQUE,
    original_url     TEXT,
    description      TEXT,
    highlight_features JSONB DEFAULT '[]',
    base_price       DECIMAL(15,2) NOT NULL,
    sale_price       DECIMAL(15,2),
    status           VARCHAR(20) DEFAULT 'new'
                     CHECK (status IN ('new','like_new','good','98_percent','97_percent','used')),
    specs            JSONB DEFAULT '{}',
    qdrant_vector_id VARCHAR(100),
    rating_avg       DECIMAL(3,2) DEFAULT 0,
    rating_count     INT DEFAULT 0,
    sold_count       INT DEFAULT 0,
    is_active        BOOLEAN DEFAULT TRUE,
    created_at       TIMESTAMP DEFAULT NOW(),
    updated_at       TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- 5. PRODUCT VARIANTS (màu sắc + tồn kho riêng)
--    VD: iPhone 17 Pro có 3 màu → 3 variants
-- ============================================================
CREATE TABLE IF NOT EXISTS product_variants (
    variant_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id          UUID NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    color_name          VARCHAR(100) NOT NULL,
    color_hex           VARCHAR(7),
    price_override      DECIMAL(15,2),
    sale_price_override DECIMAL(15,2),
    stock_quantity      INT NOT NULL DEFAULT 0,
    sku                 VARCHAR(100) UNIQUE,
    is_active           BOOLEAN DEFAULT TRUE,
    sort_order          INT DEFAULT 0
);

-- ============================================================
-- 6. PRODUCT IMAGES (gắn với variant hoặc product)
-- ============================================================
CREATE TABLE IF NOT EXISTS product_images (
    image_id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    variant_id UUID REFERENCES product_variants(variant_id) ON DELETE SET NULL,
    image_url  TEXT NOT NULL,
    alt_text   VARCHAR(255),
    is_primary BOOLEAN DEFAULT FALSE,
    sort_order INT DEFAULT 0
);

-- ============================================================
-- 7. SPEC TEMPLATES (định nghĩa spec keys của từng category)
--    Dùng để validate input và render UI filter trên mobile
-- ============================================================
CREATE TABLE IF NOT EXISTS spec_templates (
    template_id  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_id  UUID NOT NULL REFERENCES categories(category_id) ON DELETE CASCADE,
    spec_key     VARCHAR(100) NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    data_type    VARCHAR(20) NOT NULL CHECK (data_type IN ('text','number','boolean','json','array')),
    unit         VARCHAR(30),
    spec_group   VARCHAR(50),
    is_filterable BOOLEAN DEFAULT FALSE,
    sort_order   INT DEFAULT 0,
    UNIQUE(category_id, spec_key)
);

-- ============================================================
-- 8. USERS
--    NOTE: Project hiện tại đã có bảng `users` qua ORM.
--    File SQL này dành cho FRESH database install.
--    Nếu chạy trên DB đang có data, hãy dùng Alembic migration.
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
    user_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email         VARCHAR(255) UNIQUE,
    phone         VARCHAR(20) UNIQUE,
    full_name     VARCHAR(255),
    password_hash VARCHAR(255),
    avatar_url    TEXT,
    role          VARCHAR(20) DEFAULT 'buyer' CHECK (role IN ('buyer', 'seller', 'admin')),
    is_active     BOOLEAN DEFAULT TRUE,
    is_verified   BOOLEAN DEFAULT FALSE,
    google_id     VARCHAR(100),
    created_at    TIMESTAMP DEFAULT NOW(),
    updated_at    TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- 9. ADDRESSES
-- ============================================================
CREATE TABLE IF NOT EXISTS addresses (
    address_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    recipient_name VARCHAR(255) NOT NULL,
    phone          VARCHAR(20) NOT NULL,
    province       VARCHAR(100),
    district       VARCHAR(100),
    ward           VARCHAR(100),
    street         TEXT,
    is_default     BOOLEAN DEFAULT FALSE
);

-- ============================================================
-- 10. ORDERS
-- ============================================================
CREATE TABLE IF NOT EXISTS orders (
    order_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(user_id),
    address_id      UUID REFERENCES addresses(address_id) ON DELETE SET NULL,
    status          VARCHAR(30) DEFAULT 'pending'
                    CHECK (status IN ('pending','confirmed','shipping','delivered','cancelled','refunded')),
    total_amount    DECIMAL(15,2) NOT NULL,
    discount_amount DECIMAL(15,2) DEFAULT 0,
    shipping_fee    DECIMAL(15,2) DEFAULT 0,
    payment_method  VARCHAR(30),
    payment_status  VARCHAR(20) DEFAULT 'pending'
                    CHECK (payment_status IN ('pending','paid','failed','refunded')),
    note            TEXT,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- 11. ORDER ITEMS
-- ============================================================
CREATE TABLE IF NOT EXISTS order_items (
    item_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id   UUID NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(product_id),
    variant_id UUID REFERENCES product_variants(variant_id),
    quantity   INT NOT NULL,
    unit_price DECIMAL(15,2) NOT NULL,
    subtotal   DECIMAL(15,2) NOT NULL
);

-- ============================================================
-- 12. PAYMENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS payments (
    payment_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id         UUID NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    gateway          VARCHAR(30),
    amount           DECIMAL(15,2) NOT NULL,
    currency         CHAR(3) DEFAULT 'VND',
    status           VARCHAR(20) CHECK (status IN ('pending','success','failed','refunded')),
    transaction_id   VARCHAR(200),
    gateway_response JSONB,
    paid_at          TIMESTAMP
);

-- ============================================================
-- 13. REVIEWS
-- ============================================================
CREATE TABLE IF NOT EXISTS reviews (
    review_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id    UUID NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    user_id       UUID NOT NULL REFERENCES users(user_id),
    order_item_id UUID REFERENCES order_items(item_id) ON DELETE SET NULL,
    rating        SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment       TEXT,
    is_verified   BOOLEAN DEFAULT FALSE,
    created_at    TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- 14. CART ITEMS
-- ============================================================
CREATE TABLE IF NOT EXISTS cart_items (
    cart_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    product_id   UUID NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    variant_id   UUID REFERENCES product_variants(variant_id) ON DELETE SET NULL,
    quantity     INT NOT NULL DEFAULT 1,
    added_at     TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, product_id, variant_id)
);

-- ============================================================
-- 15. NOTIFICATIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS notifications (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    type            VARCHAR(50),
    title           VARCHAR(255) NOT NULL,
    body            TEXT,
    data            JSONB,
    is_read         BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMP DEFAULT NOW()
);


-- ============================================================
-- INDEXES
-- ============================================================

-- products
CREATE INDEX IF NOT EXISTS idx_products_category   ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_brand      ON products(brand_id);
CREATE INDEX IF NOT EXISTS idx_products_line       ON products(line_id);
CREATE INDEX IF NOT EXISTS idx_products_status     ON products(status);
CREATE INDEX IF NOT EXISTS idx_products_price      ON products(base_price, sale_price);
CREATE INDEX IF NOT EXISTS idx_products_active     ON products(is_active);
CREATE INDEX IF NOT EXISTS idx_products_specs      ON products USING GIN(specs);
CREATE INDEX IF NOT EXISTS idx_products_search     ON products USING GIN(
    to_tsvector('simple', name || ' ' || COALESCE(description, ''))
);

-- variants
CREATE INDEX IF NOT EXISTS idx_variants_product ON product_variants(product_id);

-- images
CREATE INDEX IF NOT EXISTS idx_images_product ON product_images(product_id);
CREATE INDEX IF NOT EXISTS idx_images_variant  ON product_images(variant_id);

-- orders
CREATE INDEX IF NOT EXISTS idx_orders_user   ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);

-- order_items
CREATE INDEX IF NOT EXISTS idx_order_items_order   ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product ON order_items(product_id);

-- cart
CREATE INDEX IF NOT EXISTS idx_cart_user ON cart_items(user_id);

-- reviews
CREATE INDEX IF NOT EXISTS idx_reviews_product ON reviews(product_id);

-- notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, is_read);


-- ============================================================
-- TRIGGERS: auto-update updated_at
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- products
DROP TRIGGER IF EXISTS trigger_products_updated_at ON products;
CREATE TRIGGER trigger_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- orders
DROP TRIGGER IF EXISTS trigger_orders_updated_at ON orders;
CREATE TRIGGER trigger_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- users
DROP TRIGGER IF EXISTS trigger_users_updated_at ON users;
CREATE TRIGGER trigger_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
