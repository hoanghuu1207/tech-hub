"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/api";
import type { Brand } from "@/types";
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
import {
  Plus, Pencil, Trash2, Search, X, Globe,
} from "lucide-react";
import { toast } from "sonner";

// ─── Hooks ──────────────────────────────────────────────

function useBrands() {
  return useQuery<Brand[]>({
    queryKey: ["admin", "brands"],
    queryFn: async () => {
      const { data } = await api.get("/admin/brands");
      return data.data;
    },
  });
}

function useCreateBrand() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (body: Record<string, unknown>) => {
      const { data } = await api.post("/admin/brands", body);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin", "brands"] });
    },
  });
}

function useUpdateBrand() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...body }: Record<string, unknown> & { id: string }) => {
      const { data } = await api.put(`/admin/brands/${id}`, body);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin", "brands"] });
    },
  });
}

function useDeleteBrand() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      const { data } = await api.delete(`/admin/brands/${id}`);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin", "brands"] });
    },
  });
}

// ─── Form ───────────────────────────────────────────────

interface BrandFormData {
  name: string;
  slug: string;
  logo_url: string;
  country: string;
  is_active: boolean;
}

const emptyForm: BrandFormData = {
  name: "",
  slug: "",
  logo_url: "",
  country: "",
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

export default function BrandsPage() {
  const { data: brands, isLoading } = useBrands();
  const createMutation = useCreateBrand();
  const updateMutation = useUpdateBrand();
  const deleteMutation = useDeleteBrand();

  const [search, setSearch] = useState("");
  const [formOpen, setFormOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<BrandFormData>(emptyForm);
  const [deleteTarget, setDeleteTarget] = useState<{ id: string; name: string } | null>(null);

  // Filter
  const filtered = search
    ? (brands ?? []).filter((b) =>
        b.name.toLowerCase().includes(search.toLowerCase()) ||
        b.slug.includes(search.toLowerCase())
      )
    : (brands ?? []);

  // ─── Handlers ──────────────────────────────────────────

  const openCreate = () => {
    setEditingId(null);
    setForm(emptyForm);
    setFormOpen(true);
  };

  const openEdit = (brand: Brand) => {
    setEditingId(brand.id);
    setForm({
      name: brand.name,
      slug: brand.slug,
      logo_url: brand.logo_url ?? "",
      country: brand.country ?? "",
      is_active: brand.is_active,
    });
    setFormOpen(true);
  };

  const handleSave = async () => {
    if (!form.name.trim()) {
      toast.error("Tên thương hiệu không được để trống");
      return;
    }

    const body: Record<string, unknown> = {
      name: form.name.trim(),
      slug: form.slug.trim() || slugify(form.name),
      logo_url: form.logo_url.trim() || null,
      country: form.country.trim() || null,
      is_active: form.is_active,
    };

    try {
      if (editingId) {
        await updateMutation.mutateAsync({ id: editingId, ...body });
        toast.success(`Đã cập nhật thương hiệu "${form.name}"`);
      } else {
        await createMutation.mutateAsync(body);
        toast.success(`Đã tạo thương hiệu "${form.name}"`);
      }
      setFormOpen(false);
    } catch {
      toast.error(editingId ? "Cập nhật thất bại" : "Tạo thương hiệu thất bại");
    }
  };

  const handleDelete = async () => {
    if (!deleteTarget) return;
    try {
      await deleteMutation.mutateAsync(deleteTarget.id);
      toast.success(`Đã xóa thương hiệu "${deleteTarget.name}"`);
      setDeleteTarget(null);
    } catch {
      toast.error("Xóa thương hiệu thất bại. Thương hiệu có thể đang có sản phẩm.");
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
          <h2 className="text-2xl font-bold tracking-tight">Thương hiệu</h2>
          <p className="text-muted-foreground text-sm">
            {brands ? `${brands.length} thương hiệu` : "Đang tải..."}
          </p>
        </div>
        <Button
          onClick={openCreate}
          className="bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white"
        >
          <Plus className="mr-2 h-4 w-4" />
          Thêm thương hiệu
        </Button>
      </div>

      {/* ─── Search ──────────────────────────────────────── */}
      <Card>
        <CardContent className="pt-4 pb-3">
          <div className="flex gap-3 items-center">
            <div className="relative flex-1 max-w-sm">
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
          </div>
        </CardContent>
      </Card>

      {/* ─── Data Table ──────────────────────────────────── */}
      <Card>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead className="w-[50px]">Logo</TableHead>
                <TableHead>Tên thương hiệu</TableHead>
                <TableHead>Slug</TableHead>
                <TableHead>Quốc gia</TableHead>
                <TableHead className="text-center">Trạng thái</TableHead>
                <TableHead className="text-right w-[120px]">Thao tác</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading ? (
                Array.from({ length: 5 }).map((_, i) => (
                  <TableRow key={i}>
                    {Array.from({ length: 6 }).map((_, j) => (
                      <TableCell key={j}><Skeleton className="h-5 w-full" /></TableCell>
                    ))}
                  </TableRow>
                ))
              ) : filtered.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={6} className="text-center py-12 text-muted-foreground">
                    {search ? "Không tìm thấy thương hiệu nào" : "Chưa có thương hiệu nào"}
                  </TableCell>
                </TableRow>
              ) : (
                filtered.map((brand) => (
                  <TableRow key={brand.id} className="group">
                    <TableCell>
                      {brand.logo_url ? (
                        <img
                          src={brand.logo_url}
                          alt={brand.name}
                          className="h-8 w-8 rounded-md object-contain bg-muted p-0.5"
                        />
                      ) : (
                        <div className="h-8 w-8 rounded-md bg-muted flex items-center justify-center text-xs font-bold text-muted-foreground">
                          {brand.name.charAt(0)}
                        </div>
                      )}
                    </TableCell>

                    <TableCell>
                      <span className="font-medium">{brand.name}</span>
                    </TableCell>

                    <TableCell>
                      <code className="text-xs text-muted-foreground bg-muted px-1.5 py-0.5 rounded">
                        {brand.slug}
                      </code>
                    </TableCell>

                    <TableCell className="text-sm text-muted-foreground">
                      {brand.country ? (
                        <div className="flex items-center gap-1.5">
                          <Globe className="h-3.5 w-3.5" />
                          <span>{brand.country}</span>
                        </div>
                      ) : "—"}
                    </TableCell>

                    <TableCell className="text-center">
                      <Badge variant={brand.is_active ? "default" : "secondary"} className="text-xs">
                        {brand.is_active ? "Hoạt động" : "Ẩn"}
                      </Badge>
                    </TableCell>

                    <TableCell className="text-right">
                      <div className="flex items-center justify-end gap-1 opacity-70 group-hover:opacity-100 transition-opacity">
                        <Button
                          variant="ghost" size="icon" className="h-7 w-7"
                          onClick={() => openEdit(brand)} title="Chỉnh sửa"
                        >
                          <Pencil className="h-3.5 w-3.5" />
                        </Button>
                        <Button
                          variant="ghost" size="icon"
                          className="h-7 w-7 text-destructive hover:text-destructive"
                          onClick={() => setDeleteTarget({ id: brand.id, name: brand.name })} title="Xóa"
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
        <DialogContent className="sm:max-w-[500px]">
          <DialogHeader>
            <DialogTitle>{editingId ? "Chỉnh sửa thương hiệu" : "Thêm thương hiệu mới"}</DialogTitle>
            <DialogDescription>
              {editingId ? "Cập nhật thông tin thương hiệu" : "Tạo một thương hiệu mới"}
            </DialogDescription>
          </DialogHeader>

          <div className="grid gap-4 py-4">
            <div className="grid gap-2">
              <Label htmlFor="brand-name">Tên thương hiệu *</Label>
              <Input
                id="brand-name"
                placeholder="Ví dụ: Apple"
                value={form.name}
                onChange={(e) => handleNameChange(e.target.value)}
              />
            </div>

            <div className="grid gap-2">
              <Label htmlFor="brand-slug">Slug</Label>
              <Input
                id="brand-slug"
                placeholder="apple"
                value={form.slug}
                onChange={(e) => setForm((prev) => ({ ...prev, slug: e.target.value }))}
              />
              <p className="text-xs text-muted-foreground">Tự động tạo từ tên nếu để trống</p>
            </div>

            <div className="grid gap-2">
              <Label htmlFor="brand-logo">URL Logo</Label>
              <Input
                id="brand-logo"
                placeholder="https://example.com/logo.png"
                value={form.logo_url}
                onChange={(e) => setForm((prev) => ({ ...prev, logo_url: e.target.value }))}
              />
              {form.logo_url && (
                <div className="flex items-center gap-2 mt-1">
                  <img src={form.logo_url} alt="Preview" className="h-8 w-8 rounded object-contain bg-muted p-0.5" />
                  <span className="text-xs text-muted-foreground">Xem trước</span>
                </div>
              )}
            </div>

            <div className="flex gap-4">
              <div className="grid gap-2 flex-1">
                <Label htmlFor="brand-country">Quốc gia</Label>
                <Input
                  id="brand-country"
                  placeholder="Ví dụ: Mỹ"
                  value={form.country}
                  onChange={(e) => setForm((prev) => ({ ...prev, country: e.target.value }))}
                />
              </div>
              <div className="grid gap-2 flex-1">
                <Label htmlFor="brand-status">Trạng thái</Label>
                <Select
                  value={form.is_active ? "active" : "inactive"}
                  onValueChange={(v) => setForm((prev) => ({ ...prev, is_active: v === "active" }))}
                >
                  <SelectTrigger id="brand-status">
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
              {isSaving ? "Đang lưu..." : editingId ? "Cập nhật" : "Tạo thương hiệu"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* ─── Delete Confirm Dialog ───────────────────────── */}
      <Dialog open={!!deleteTarget} onOpenChange={(open) => !open && setDeleteTarget(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Xác nhận xóa thương hiệu</DialogTitle>
            <DialogDescription>
              Bạn có chắc muốn xóa thương hiệu <strong>&quot;{deleteTarget?.name}&quot;</strong>?
              Các sản phẩm liên quan có thể bị ảnh hưởng.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteTarget(null)}>Hủy</Button>
            <Button variant="destructive" onClick={handleDelete} disabled={deleteMutation.isPending}>
              {deleteMutation.isPending ? "Đang xóa..." : "Xóa thương hiệu"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
