import {
  LayoutDashboard,
  Package,
  FolderTree,
  Tags,
  Layers,
  ShoppingCart,
  Users,
  Star,
  Search,
  type LucideIcon,
} from "lucide-react";

// ─── Sidebar Menu Items ──────────────────────────────────

export interface MenuItem {
  title: string;
  href: string;
  icon: LucideIcon;
  badge?: string;
}

export const MENU_ITEMS: MenuItem[] = [
  { title: "Dashboard", href: "/dashboard", icon: LayoutDashboard },
  { title: "Sản phẩm", href: "/products", icon: Package },
  { title: "Danh mục", href: "/categories", icon: FolderTree },
  { title: "Thương hiệu", href: "/brands", icon: Tags },
  { title: "Dòng sản phẩm", href: "/product-lines", icon: Layers },
  { title: "Đơn hàng", href: "/orders", icon: ShoppingCart },
  { title: "Người dùng", href: "/users", icon: Users },
  { title: "Đánh giá", href: "/reviews", icon: Star },
  { title: "Vector Index", href: "/vector-index", icon: Search },
];

// ─── Order Status ────────────────────────────────────────

export const ORDER_STATUS_MAP: Record<
  string,
  { label: string; variant: "default" | "secondary" | "destructive" | "outline" }
> = {
  pending: { label: "Chờ xử lý", variant: "secondary" },
  confirmed: { label: "Đã xác nhận", variant: "default" },
  shipping: { label: "Đang giao", variant: "outline" },
  delivered: { label: "Đã giao", variant: "default" },
  cancelled: { label: "Đã hủy", variant: "destructive" },
};

export const PAYMENT_STATUS_MAP: Record<
  string,
  { label: string; variant: "default" | "secondary" | "destructive" | "outline" }
> = {
  pending: { label: "Chưa thanh toán", variant: "secondary" },
  paid: { label: "Đã thanh toán", variant: "default" },
  refunded: { label: "Đã hoàn tiền", variant: "outline" },
  failed: { label: "Thất bại", variant: "destructive" },
};

// ─── Product Status ──────────────────────────────────────

export const PRODUCT_STATUS_MAP: Record<string, string> = {
  new: "Mới",
  active: "Đang bán",
  inactive: "Ngừng bán",
  out_of_stock: "Hết hàng",
};
