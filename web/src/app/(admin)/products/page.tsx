"use client";

import { useState, useMemo } from "react";
import Link from "next/link";
import { useProducts, useDeleteProduct, useToggleProductStatus, useAdminCategories, useAdminBrandsByCategory, useAdminProductLines } from "@/hooks/use-products";
import { Button, buttonVariants } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import {
  Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle,
} from "@/components/ui/dialog";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Plus, Search, Trash2, Eye, EyeOff, Pencil, ChevronLeft, ChevronRight,
  Database, X,
} from "lucide-react";
import { formatCurrency } from "@/lib/format";
import { toast } from "sonner";

const PAGE_SIZE = 15;

export default function ProductsPage() {
  // ─── Cascading Filter State ────────────────────────────
  const [search, setSearch] = useState("");
  const [searchInput, setSearchInput] = useState("");
  const [categoryFilter, setCategoryFilter] = useState<string>("all");
  const [brandFilter, setBrandFilter] = useState<string>("all");
  const [lineFilter, setLineFilter] = useState<string>("all");
  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [indexedFilter, setIndexedFilter] = useState<string>("all");
  const [page, setPage] = useState(0);

  // ─── Cascading Data Hooks ──────────────────────────────
  const { data: categories } = useAdminCategories();
  // Brands chỉ load khi đã chọn category
  const { data: brandsByCategory } = useAdminBrandsByCategory(
    categoryFilter !== "all" ? categoryFilter : undefined
  );
  // Product lines chỉ load khi đã chọn cả category VÀ brand
  const { data: productLines } = useAdminProductLines(
    brandFilter !== "all" ? brandFilter : undefined,
    categoryFilter !== "all" ? categoryFilter : undefined
  );

  // ─── Cascading reset logic ─────────────────────────────
  const handleCategoryChange = (value: string | null) => {
    setCategoryFilter(value ?? "all");
    setBrandFilter("all");    // reset brand khi đổi category
    setLineFilter("all");     // reset line khi đổi category
    setPage(0);
  };

  const handleBrandChange = (value: string | null) => {
    setBrandFilter(value ?? "all");
    setLineFilter("all");     // reset line khi đổi brand
    setPage(0);
  };

  const handleLineChange = (value: string | null) => {
    setLineFilter(value ?? "all");
    setPage(0);
  };

  // ─── Product Query ─────────────────────────────────────
  const filters = useMemo(() => ({
    search: search || undefined,
    category_id: categoryFilter !== "all" ? categoryFilter : undefined,
    brand_id: brandFilter !== "all" ? brandFilter : undefined,
    // line_id filter - cần thêm vào backend nếu cần, tạm thời dùng brand+category
    is_active: statusFilter === "active" ? true : statusFilter === "inactive" ? false : undefined,
    indexed: indexedFilter === "indexed" ? true : indexedFilter === "unindexed" ? false : undefined,
    sort_by: "created_at",
    sort_order: "desc",
    limit: PAGE_SIZE,
    offset: page * PAGE_SIZE,
  }), [search, categoryFilter, brandFilter, statusFilter, indexedFilter, page]);

  const { data, isLoading } = useProducts(filters);
  const deleteMutation = useDeleteProduct();
  const toggleMutation = useToggleProductStatus();

  // ─── Delete Dialog ─────────────────────────────────────
  const [deleteTarget, setDeleteTarget] = useState<{ id: string; name: string } | null>(null);

  const handleDelete = async () => {
    if (!deleteTarget) return;
    try {
      await deleteMutation.mutateAsync(deleteTarget.id);
      toast.success(`Đã xóa "${deleteTarget.name}"`);
      setDeleteTarget(null);
    } catch {
      toast.error("Xóa sản phẩm thất bại");
    }
  };

  const handleToggle = async (id: string, currentActive: boolean, name: string) => {
    try {
      await toggleMutation.mutateAsync({ id, is_active: !currentActive });
      toast.success(`${!currentActive ? "Kích hoạt" : "Ẩn"} "${name}" thành công`);
    } catch {
      toast.error("Thay đổi trạng thái thất bại");
    }
  };

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    setSearch(searchInput);
    setPage(0);
  };

  const totalPages = data ? Math.ceil(data.total / PAGE_SIZE) : 0;

  // Derived: is brand/line selectable?
  const isCategorySelected = categoryFilter !== "all";
  const isBrandSelected = brandFilter !== "all";

  return (
    <div className="space-y-4">
      {/* ─── Header ────────────────────────────────────── */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">Sản phẩm</h2>
          <p className="text-muted-foreground text-sm">
            {data ? `${data.total} sản phẩm` : "Đang tải..."}
          </p>
        </div>
        <Link href="/products/new" className={cn(buttonVariants(), "bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white")}>
            <Plus className="mr-2 h-4 w-4" />
            Thêm sản phẩm
        </Link>
      </div>

      {/* ─── Filters ───────────────────────────────────── */}
      <Card>
        <CardContent className="pt-4 pb-3">
          <div className="flex flex-wrap gap-3 items-end">
            {/* Search */}
            <form onSubmit={handleSearch} className="flex gap-2 flex-1 min-w-[250px]">
              <div className="relative flex-1">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                <Input
                  placeholder="Tìm theo tên sản phẩm..."
                  value={searchInput}
                  onChange={(e) => setSearchInput(e.target.value)}
                  className="pl-9 h-9"
                />
              </div>
              <Button type="submit" size="sm" variant="secondary" className="h-9">
                Tìm
              </Button>
              {search && (
                <Button
                  type="button" size="sm" variant="ghost" className="h-9"
                  onClick={() => { setSearch(""); setSearchInput(""); setPage(0); }}
                >
                  <X className="h-4 w-4" />
                </Button>
              )}
            </form>

            {/* Category filter (root only) */}
            <div className="space-y-1">
              <span className="text-xs text-muted-foreground">Danh mục</span>
              <Select value={categoryFilter} onValueChange={handleCategoryChange}>
                <SelectTrigger className="w-[160px] h-9">
                  <SelectValue placeholder="Danh mục" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Tất cả danh mục</SelectItem>
                  {categories?.map((c) => (
                    <SelectItem key={c.id} value={c.id}>{c.name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {/* Brand filter (cascading — only when category selected) */}
            <div className="space-y-1">
              <span className="text-xs text-muted-foreground">Thương hiệu</span>
              <Select
                value={brandFilter}
                onValueChange={handleBrandChange}
                disabled={!isCategorySelected}
              >
                <SelectTrigger className="w-[160px] h-9">
                  <SelectValue placeholder={!isCategorySelected ? "Chọn danh mục trước" : "Thương hiệu"} />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Tất cả thương hiệu</SelectItem>
                  {brandsByCategory?.map((b) => (
                    <SelectItem key={b.id} value={b.id}>{b.name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {/* Product Line filter (cascading — only when brand selected) */}
            <div className="space-y-1">
              <span className="text-xs text-muted-foreground">Dòng SP</span>
              <Select
                value={lineFilter}
                onValueChange={handleLineChange}
                disabled={!isBrandSelected}
              >
                <SelectTrigger className="w-[160px] h-9">
                  <SelectValue placeholder={!isBrandSelected ? "Chọn thương hiệu trước" : "Dòng SP"} />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Tất cả</SelectItem>
                  {productLines?.map((l) => (
                    <SelectItem key={l.id} value={l.id}>{l.name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {/* Status filter */}
            <div className="space-y-1">
              <span className="text-xs text-muted-foreground">Trạng thái</span>
              <Select value={statusFilter} onValueChange={(v) => { setStatusFilter(v ?? "all"); setPage(0); }}>
                <SelectTrigger className="w-[130px] h-9">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Tất cả</SelectItem>
                  <SelectItem value="active">Đang bán</SelectItem>
                  <SelectItem value="inactive">Đã ẩn</SelectItem>
                </SelectContent>
              </Select>
            </div>

            {/* Indexed filter */}
            <div className="space-y-1">
              <span className="text-xs text-muted-foreground">Qdrant</span>
              <Select value={indexedFilter} onValueChange={(v) => { setIndexedFilter(v ?? "all"); setPage(0); }}>
                <SelectTrigger className="w-[130px] h-9">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Tất cả</SelectItem>
                  <SelectItem value="indexed">Đã index</SelectItem>
                  <SelectItem value="unindexed">Chưa index</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* ─── Data Table ────────────────────────────────── */}
      <Card>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead className="w-[60px]">Ảnh</TableHead>
                <TableHead>Tên sản phẩm</TableHead>
                <TableHead>Danh mục</TableHead>
                <TableHead>Thương hiệu</TableHead>
                <TableHead className="text-right">Giá</TableHead>
                <TableHead className="text-center">Tồn kho</TableHead>
                <TableHead className="text-center">Trạng thái</TableHead>
                <TableHead className="text-center">Qdrant</TableHead>
                <TableHead className="text-right w-[140px]">Thao tác</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading ? (
                Array.from({ length: 5 }).map((_, i) => (
                  <TableRow key={i}>
                    {Array.from({ length: 9 }).map((_, j) => (
                      <TableCell key={j}><Skeleton className="h-5 w-full" /></TableCell>
                    ))}
                  </TableRow>
                ))
              ) : data?.items.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={9} className="text-center py-12 text-muted-foreground">
                    Không tìm thấy sản phẩm nào
                  </TableCell>
                </TableRow>
              ) : (
                data?.items.map((product) => (
                  <TableRow key={product.id} className="group">
                    <TableCell>
                      {product.primary_image ? (
                        <img src={product.primary_image} alt={product.name} className="h-10 w-10 rounded-md object-cover bg-muted" />
                      ) : (
                        <div className="h-10 w-10 rounded-md bg-muted flex items-center justify-center text-xs text-muted-foreground">N/A</div>
                      )}
                    </TableCell>
                    <TableCell>
                      <Link href={`/products/${product.id}`} className="font-medium hover:text-blue-400 transition-colors line-clamp-1 max-w-[240px]">
                        {product.name}
                      </Link>
                      <p className="text-xs text-muted-foreground mt-0.5">Đã bán: {product.sold_count}</p>
                    </TableCell>
                    <TableCell className="text-sm">{product.category_name || "—"}</TableCell>
                    <TableCell className="text-sm">{product.brand_name || "—"}</TableCell>
                    <TableCell className="text-right">
                      {product.sale_price ? (
                        <div>
                          <span className="text-sm font-semibold text-red-400">{formatCurrency(product.sale_price)}</span>
                          <br />
                          <span className="text-xs text-muted-foreground line-through">{formatCurrency(product.base_price)}</span>
                        </div>
                      ) : (
                        <span className="text-sm font-semibold">{formatCurrency(product.base_price)}</span>
                      )}
                    </TableCell>
                    <TableCell className="text-center">
                      <span className={`text-sm font-medium ${(product.stock_total ?? 0) <= 0 ? "text-red-400" : ""}`}>
                        {product.stock_total ?? 0}
                      </span>
                    </TableCell>
                    <TableCell className="text-center">
                      <Badge variant={product.is_active ? "default" : "secondary"} className="text-xs">
                        {product.is_active ? "Đang bán" : "Đã ẩn"}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-center">
                      {product.qdrant_vector_id ? (
                        <Badge variant="outline" className="text-xs text-emerald-400 border-emerald-400/30">
                          <Database className="h-3 w-3 mr-1" />Indexed
                        </Badge>
                      ) : (
                        <Badge variant="outline" className="text-xs text-muted-foreground">Chưa index</Badge>
                      )}
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex items-center justify-end gap-1 opacity-70 group-hover:opacity-100 transition-opacity">
                        <Button variant="ghost" size="icon" className="h-7 w-7"
                          onClick={() => handleToggle(product.id, product.is_active, product.name)}
                          title={product.is_active ? "Ẩn sản phẩm" : "Hiện sản phẩm"}>
                          {product.is_active ? <EyeOff className="h-3.5 w-3.5" /> : <Eye className="h-3.5 w-3.5" />}
                        </Button>
                        <Link href={`/products/${product.id}`} title="Chỉnh sửa" className={cn(buttonVariants({ variant: "ghost", size: "icon" }), "h-7 w-7")}>
                          <Pencil className="h-3.5 w-3.5" />
                        </Link>
                        <Button variant="ghost" size="icon" className="h-7 w-7 text-destructive hover:text-destructive"
                          onClick={() => setDeleteTarget({ id: product.id, name: product.name })} title="Xóa">
                          <Trash2 className="h-3.5 w-3.5" />
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      {/* ─── Pagination ────────────────────────────────── */}
      {totalPages > 1 && (
        <div className="flex items-center justify-between">
          <p className="text-sm text-muted-foreground">
            Trang {page + 1} / {totalPages} — {data?.total} kết quả
          </p>
          <div className="flex gap-2">
            <Button variant="outline" size="sm" disabled={page === 0} onClick={() => setPage(page - 1)}>
              <ChevronLeft className="h-4 w-4 mr-1" />Trước
            </Button>
            <Button variant="outline" size="sm" disabled={page >= totalPages - 1} onClick={() => setPage(page + 1)}>
              Sau<ChevronRight className="h-4 w-4 ml-1" />
            </Button>
          </div>
        </div>
      )}

      {/* ─── Delete Confirm Dialog ─────────────────────── */}
      <Dialog open={!!deleteTarget} onOpenChange={(open) => !open && setDeleteTarget(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Xác nhận xóa sản phẩm</DialogTitle>
            <DialogDescription>
              Bạn có chắc muốn xóa <strong>&quot;{deleteTarget?.name}&quot;</strong>? Hành động này không thể hoàn tác.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteTarget(null)}>Hủy</Button>
            <Button variant="destructive" onClick={handleDelete} disabled={deleteMutation.isPending}>
              {deleteMutation.isPending ? "Đang xóa..." : "Xóa sản phẩm"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
