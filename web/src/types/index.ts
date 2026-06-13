// ─── Auth Types ──────────────────────────────────────────

export interface User {
  id: string;
  email: string;
  full_name: string;
  phone: string | null;
  role: "buyer" | "seller" | "admin";
  is_active: boolean;
  is_verified: boolean;
  avatar_url: string | null;
}

export interface TokenResponse {
  access_token: string;
  refresh_token: string;
  token_type: string;
  user: User;
}

export interface LoginCredentials {
  email: string;
  password: string;
}

// ─── API Response ────────────────────────────────────────

export interface ApiResponse<T = unknown> {
  success: boolean;
  message: string;
  data: T | null;
  error?: string | null;
}

// ─── Catalog Types ───────────────────────────────────────

export interface Category {
  id: string;
  name: string;
  slug: string;
  icon_url: string | null;
  description: string | null;
  is_active: boolean;
  sort_order: number;
  parent_id: string | null;
}

export interface Brand {
  id: string;
  name: string;
  slug: string;
  logo_url: string | null;
  country: string | null;
  is_active: boolean;
}

export interface ProductLine {
  id: string;
  name: string;
  slug: string;
  brand_id: string;
  category_id: string;
  description: string | null;
  is_active: boolean;
  sort_order: number;
}

// ─── Product Types ───────────────────────────────────────

export interface Product {
  id: string;
  name: string;
  slug: string;
  category_id: string;
  brand_id: string;
  line_id: string | null;
  description: string | null;
  highlight_features: string[];
  base_price: number;
  sale_price: number | null;
  status: string;
  specs: Record<string, unknown>;
  qdrant_vector_id: string | null;
  rating_avg: number;
  rating_count: number;
  sold_count: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  // Joined fields
  category_name?: string;
  brand_name?: string;
  line_name?: string;
  primary_image?: string | null;
  stock_total?: number;
  variants?: ProductVariant[];
  images?: ProductImage[];
}

export interface ProductVariant {
  id: string;
  product_id: string;
  color_name: string;
  color_hex: string | null;
  price_override: number | null;
  sale_price_override: number | null;
  stock_quantity: number;
  sku: string | null;
  is_active: boolean;
  sort_order: number;
}

export interface ProductImage {
  id: string;
  product_id: string;
  variant_id: string | null;
  image_url: string;
  alt_text: string | null;
  is_primary: boolean;
  sort_order: number;
}

// ─── Order Types ─────────────────────────────────────────

export interface Order {
  id: string;
  order_code: number | null;
  user_id: string;
  status: string;
  total_amount: number;
  discount_amount: number;
  shipping_fee: number;
  payment_method: string | null;
  payment_status: string;
  note: string | null;
  created_at: string;
  updated_at: string;
  items: OrderItem[];
  address: Address | null;
  user_name?: string;
  user_email?: string;
}

export interface OrderItem {
  id: string;
  product_id: string;
  variant_id: string | null;
  quantity: number;
  unit_price: number;
  subtotal: number;
  product_name: string | null;
  product_image: string | null;
}

export interface Address {
  id: string;
  recipient_name: string;
  phone: string;
  province: string | null;
  district: string | null;
  ward: string | null;
  street: string | null;
}

// ─── Review Types ────────────────────────────────────────

export interface Review {
  id: string;
  product_id: string;
  user_id: string;
  rating: number;
  comment: string | null;
  is_verified: boolean;
  created_at: string;
  product_name?: string;
  user_name?: string;
}

// ─── Dashboard Types ─────────────────────────────────────

export interface DashboardStats {
  total_revenue: number;
  total_orders: number;
  new_customers: number;
  active_products: number;
  revenue_change: number; // % change vs last month
  orders_change: number;
  customers_change: number;
}

export interface RevenueDataPoint {
  date: string;
  revenue: number;
  orders: number;
}

export interface OrderStatusCount {
  status: string;
  count: number;
}

export interface TopProduct {
  id: string;
  name: string;
  sold_count: number;
  revenue: number;
}

// ─── Qdrant Indexing Types ───────────────────────────────

export interface IndexingStatus {
  collection_name: string;
  total_vectors: number;
  indexed_products: number;
  unindexed_products: number;
}

// ─── Pagination ──────────────────────────────────────────

export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  limit: number;
  offset: number;
}
