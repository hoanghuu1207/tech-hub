"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/api";
import type { Category, Brand } from "@/types";
import { useAdminCategories, useAdminBrands } from "@/hooks/use-products";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table";
import {
  Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle,
} from "@/components/ui/dialog";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  Plus, Pencil, Trash2, Search, X, GripVertical,
} from "lucide-react";
import { toast } from "sonner";

// ─── Types ──────────────────────────────────────────────

interface ProductLine {
  id: string;
  name: string;
  slug: string;
  brand_id: string;
  brand_name: string | null;
  category_id: string;
  category_name: string | null;
  description: string | null;
  is_active: boolean;
  sort_order: number;
}

// ─── Hooks ──────────────────────────────────────────────

function useProductLines(filters: { category_id?: string; brand_id?: string }) {
  return useQuery<ProductLine[]>({
    queryKey: ["admin", "product-lines", "all", filters],
    queryFn: async () => {
      const params: Record<string, string> = {};
      if (filters.category_id) params.category_id = filters.category_id;
      if (filters.brand_id) params.brand_id = filters.brand_id;
      const { data } = await api.get("/admin/product-lines", { params });
      return data.data;
    },
  });
}

function useCreateProductLine() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (body: Record<string, unknown>) => {
      const { data } = await api.post("/admin/product-lines", body);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin", "product-lines"] });
    },
  });
}

function useUpdateProductLine() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...body }: Record<string, unknown> & { id: string }) => {
      const { data } = await api.put(`/admin/product-lines/${id}`, body);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin", "product-lines"] });
    },
  });
}

function useDeleteProductLine() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      const { data } = await api.delete(`/admin/product-lines/${id}`);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin", "product-lines"] });
    },
  });
}

// ─── Form ───────────────────────────────────────────────

interface LineFormData {
  name: string;
  slug: string;
  brand_id: string;
  category_id: string;
  description: string;
  sort_order: number;
  is_active: boolean;
}

const emptyForm: LineFormData = {
  name: "",
  slug: "",
  brand_id: "",
  category_id: "",
  description: "",
  sort_order: 0,
  is_active: true,
};

function slugify(text: string): string {
  return text
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/g, "d")
    .replace(/Đ/g, "D")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}

// ─── Main Page ──────────────────────────────────────────

export default function ProductLinesPage() {
  // Filter state
  const [filterCategory, setFilterCategory] = useState<string>("all");
  const [filterBrand, setFilterBrand] = useState<string>("all");
  const [search, setSearch] = useState("");

  // Data
  const { data: categories } = useAdminCategories();
  const { data: allBrands } = useAdminBrands();
  const { data: lines, isLoading } = useProductLines({
    category_id: filterCategory !== "all" ? filterCategory : undefined,
    brand_id: filterBrand !== "all" ? filterBrand : undefined,
  });

  const createMutation = useCreateProductLine();
  const updateMutation = useUpdateProductLine();
  const deleteMutation = useDeleteProductLine();

  // Form state
  const [formOpen, setFormOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<LineFormData>(emptyForm);
  const [deleteTarget, setDeleteTarget] = useState<{ id: string; name: string } | null>(null);

  // Local search filter
  const filtered = search
    ? (lines ?? []).filter((l) =>
        l.name.toLowerCase().includes(search.toLowerCase()) ||
        l.slug.includes(search.toLowerCase())
      )
    : (lines ?? []);

  // ─── Handlers ──────────────────────────────────────────

  const openCreate = () => {
    setEditingId(null);
    setForm(emptyForm);
    setFormOpen(true);
  };

  const openEdit = (line: ProductLine) => {
    setEditingId(line.id);
    setForm({
      name: line.name,
      slug: line.slug,
      brand_id: line.brand_id,
      category_id: line.category_id,
      description: line.description ?? "",
      sort_order: line.sort_order,
      is_active: line.is_active,
    });
    setFormOpen(true);
  };

  const handleSave = async () => {
    if (!form.name.trim()) {
      toast.error("Tên dòng sản phẩm không được để trống");
      return;
    }
    if (!form.category_id) {
      toast.error("Vui lòng chọn danh mục");
      return;
    }
    if (!form.brand_id) {
      toast.error("Vui lòng chọn thương hiệu");
      return;
    }

    const body: Record<string, unknown> = {
      name: form.name.trim(),
      slug: form.slug.trim() || slugify(form.name),
      brand_id: form.brand_id,
      category_id: form.category_id,
      description: form.description.trim() || null,
      sort_order: form.sort_order,
      is_active: form.is_active,
    };

    try {
      if (editingId) {
        await updateMutation.mutateAsync({ id: editingId, ...body });
        toast.success(`Đã cập nhật "${form.name}"`);
      } else {
        await createMutation.mutateAsync(body);
        toast.success(`Đã tạo "${form.name}"`);
      }
      setFormOpen(false);
    } catch {
      toast.error(editingId ? "Cập nhật thất bại" : "Tạo dòng sản phẩm thất bại");
    }
  };

  const handleDelete = async () => {
    if (!deleteTarget) return;
    try {
      await deleteMutation.mutateAsync(deleteTarget.id);
      toast.success(`Đã xóa "${deleteTarget.name}"`);
      setDeleteTarget(null);
    } catch {
      toast.error("Xóa thất bại. Dòng sản phẩm có thể đang có sản phẩm.");
    }
  };

  const handleNameChange = (name: string) => {
    setForm((prev) => ({
      ...prev,
      name,
      slug: editingId ? prev.slug : slugify(name),
    }));
  };

  const isSaving = createMutation.isPending || updateMutation.isPending;

  return (
    <div className="space-y-4">
      {/* ─── Header ──────────────────────────────────────── */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">Dòng sản phẩm</h2>
          <p className="text-muted-foreground text-sm">
            {lines ? `${lines.length} dòng sản phẩm` : "Đang tải..."}
          </p>
        </div>
        <Button
          onClick={openCreate}
          className="bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white"
        >
          <Plus className="mr-2 h-4 w-4" />
          Thêm dòng SP
        </Button>
      </div>

      {/* ─── Filters ─────────────────────────────────────── */}
      <Card>
        <CardContent className="pt-4 pb-3">
          <div className="flex flex-wrap gap-3 items-end">
            {/* Search */}
            <div className="relative flex-1 min-w-[200px]">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
              <Input
                placeholder="Tìm theo tên hoặc slug..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="pl-9 h-9"
              />
            </div>
            {search && (
              <Button variant="ghost" size="sm" onClick={() => setSearch("")} className="h-9">
                <X className="h-4 w-4" />
              </Button>
            )}

            {/* Category filter */}
            <div className="space-y-1">
              <span className="text-xs text-muted-foreground">Danh mục</span>
              <Select value={filterCategory} onValueChange={(v) => { setFilterCategory(v ?? "all"); setFilterBrand("all"); }}>
                <SelectTrigger className="w-[160px] h-9">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Tất cả</SelectItem>
                  {categories?.map((c) => (
                    <SelectItem key={c.id} value={c.id}>{c.name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {/* Brand filter */}
            <div className="space-y-1">
              <span className="text-xs text-muted-foreground">Thương hiệu</span>
              <Select value={filterBrand} onValueChange={(v) => setFilterBrand(v ?? "all")}>
                <SelectTrigger className="w-[160px] h-9">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Tất cả</SelectItem>
                  {allBrands?.map((b) => (
                    <SelectItem key={b.id} value={b.id}>{b.name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* ─── Data Table ──────────────────────────────────── */}
      <Card>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Tên dòng sản phẩm</TableHead>
                <TableHead>Slug</TableHead>
                <TableHead>Danh mục</TableHead>
                <TableHead>Thương hiệu</TableHead>
                <TableHead className="text-center">Thứ tự</TableHead>
                <TableHead className="text-center">Trạng thái</TableHead>
                <TableHead className="text-right w-[120px]">Thao tác</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading ? (
                Array.from({ length: 5 }).map((_, i) => (
                  <TableRow key={i}>
                    {Array.from({ length: 7 }).map((_, j) => (
                      <TableCell key={j}><Skeleton className="h-5 w-full" /></TableCell>
                    ))}
                  </TableRow>
                ))
              ) : filtered.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={7} className="text-center py-12 text-muted-foreground">
                    {search ? "Không tìm thấy dòng sản phẩm nào" : "Chưa có dòng sản phẩm nào"}
                  </TableCell>
                </TableRow>
              ) : (
                filtered.map((line) => (
                  <TableRow key={line.id} className="group">
                    <TableCell>
                      <span className="font-medium">{line.name}</span>
                    </TableCell>

                    <TableCell>
                      <code className="text-xs text-muted-foreground bg-muted px-1.5 py-0.5 rounded">
                        {line.slug}
                      </code>
                    </TableCell>

                    <TableCell className="text-sm">
                      <Badge variant="outline" className="text-xs font-normal">
                        {line.category_name ?? "—"}
                      </Badge>
                    </TableCell>

                    <TableCell className="text-sm text-muted-foreground">
                      {line.brand_name ?? "—"}
                    </TableCell>

                    <TableCell className="text-center">
                      <div className="flex items-center justify-center gap-1 text-muted-foreground">
                        <GripVertical className="h-3.5 w-3.5" />
                        <span className="text-sm">{line.sort_order}</span>
                      </div>
                    </TableCell>

                    <TableCell className="text-center">
                      <Badge variant={line.is_active ? "default" : "secondary"} className="text-xs">
                        {line.is_active ? "Hoạt động" : "Ẩn"}
                      </Badge>
                    </TableCell>

                    <TableCell className="text-right">
                      <div className="flex items-center justify-end gap-1 opacity-70 group-hover:opacity-100 transition-opacity">
                        <Button
                          variant="ghost" size="icon" className="h-7 w-7"
                          onClick={() => openEdit(line)} title="Chỉnh sửa"
                        >
                          <Pencil className="h-3.5 w-3.5" />
                        </Button>
                        <Button
                          variant="ghost" size="icon"
                          className="h-7 w-7 text-destructive hover:text-destructive"
                          onClick={() => setDeleteTarget({ id: line.id, name: line.name })} title="Xóa"
                        >
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

      {/* ─── Create / Edit Dialog ────────────────────────── */}
      <Dialog open={formOpen} onOpenChange={(open) => !open && setFormOpen(false)}>
        <DialogContent className="sm:max-w-[520px]">
          <DialogHeader>
            <DialogTitle>{editingId ? "Chỉnh sửa dòng sản phẩm" : "Thêm dòng sản phẩm mới"}</DialogTitle>
            <DialogDescription>
              {editingId ? "Cập nhật thông tin dòng sản phẩm" : "Tạo dòng sản phẩm mới (ví dụ: iPhone 15 Series, Galaxy S24 Series)"}
            </DialogDescription>
          </DialogHeader>

          <div className="grid gap-4 py-4">
            <div className="grid gap-2">
              <Label htmlFor="line-name">Tên dòng sản phẩm *</Label>
              <Input
                id="line-name"
                placeholder="Ví dụ: iPhone 16 Series"
                value={form.name}
                onChange={(e) => handleNameChange(e.target.value)}
              />
            </div>

            <div className="grid gap-2">
              <Label htmlFor="line-slug">Slug</Label>
              <Input
                id="line-slug"
                placeholder="iphone-16-series"
                value={form.slug}
                onChange={(e) => setForm((prev) => ({ ...prev, slug: e.target.value }))}
              />
              <p className="text-xs text-muted-foreground">Tự động tạo từ tên nếu để trống</p>
            </div>

            <div className="flex gap-4">
              <div className="grid gap-2 flex-1">
                <Label htmlFor="line-category">Danh mục *</Label>
                <Select
                  value={form.category_id || "none"}
                  onValueChange={(v) => setForm((prev) => ({ ...prev, category_id: v === "none" ? "" : v }))}
                >
                  <SelectTrigger id="line-category">
                    <SelectValue placeholder="Chọn danh mục">
                      {form.category_id
                        ? categories?.find((c) => c.id === form.category_id)?.name ?? "Chọn danh mục"
                        : "Chọn danh mục"}
                    </SelectValue>
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="none" disabled>Chọn danh mục</SelectItem>
                    {categories?.map((c) => (
                      <SelectItem key={c.id} value={c.id}>{c.name}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div className="grid gap-2 flex-1">
                <Label htmlFor="line-brand">Thương hiệu *</Label>
                <Select
                  value={form.brand_id || "none"}
                  onValueChange={(v) => setForm((prev) => ({ ...prev, brand_id: v === "none" ? "" : v }))}
                >
                  <SelectTrigger id="line-brand">
                    <SelectValue placeholder="Chọn thương hiệu">
                      {form.brand_id
                        ? allBrands?.find((b) => b.id === form.brand_id)?.name ?? "Chọn thương hiệu"
                        : "Chọn thương hiệu"}
                    </SelectValue>
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="none" disabled>Chọn thương hiệu</SelectItem>
                    {allBrands?.map((b) => (
                      <SelectItem key={b.id} value={b.id}>{b.name}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>

            <div className="grid gap-2">
              <Label htmlFor="line-desc">Mô tả</Label>
              <Textarea
                id="line-desc"
                placeholder="Mô tả ngắn..."
                value={form.description}
                onChange={(e) => setForm((prev) => ({ ...prev, description: e.target.value }))}
                rows={2}
              />
            </div>

            <div className="flex gap-4">
              <div className="grid gap-2 flex-1">
                <Label htmlFor="line-sort">Thứ tự sắp xếp</Label>
                <Input
                  id="line-sort"
                  type="number"
                  value={form.sort_order}
                  onChange={(e) => setForm((prev) => ({ ...prev, sort_order: parseInt(e.target.value) || 0 }))}
                />
              </div>
              <div className="grid gap-2 flex-1">
                <Label htmlFor="line-status">Trạng thái</Label>
                <Select
                  value={form.is_active ? "active" : "inactive"}
                  onValueChange={(v) => setForm((prev) => ({ ...prev, is_active: v === "active" }))}
                >
                  <SelectTrigger id="line-status">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="active">Hoạt động</SelectItem>
                    <SelectItem value="inactive">Ẩn</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>
          </div>

          <DialogFooter>
            <Button variant="outline" onClick={() => setFormOpen(false)}>Hủy</Button>
            <Button
              onClick={handleSave} disabled={isSaving}
              className="bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white"
            >
              {isSaving ? "Đang lưu..." : editingId ? "Cập nhật" : "Tạo dòng SP"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ─── Delete Confirm Dialog ───────────────────────── */}
      <Dialog open={!!deleteTarget} onOpenChange={(open) => !open && setDeleteTarget(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Xác nhận xóa dòng sản phẩm</DialogTitle>
            <DialogDescription>
              Bạn có chắc muốn xóa <strong>&quot;{deleteTarget?.name}&quot;</strong>?
              Các sản phẩm thuộc dòng này có thể bị ảnh hưởng.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteTarget(null)}>Hủy</Button>
            <Button variant="destructive" onClick={handleDelete} disabled={deleteMutation.isPending}>
              {deleteMutation.isPending ? "Đang xóa..." : "Xóa"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
