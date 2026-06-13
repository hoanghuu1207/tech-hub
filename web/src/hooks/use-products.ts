import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/api";
import type { Product, Category, Brand, ProductLine, PaginatedResponse } from "@/types";

// ─── Products List ──────────────────────────────────────

interface ProductFilters {
  search?: string;
  category_id?: string;
  brand_id?: string;
  status?: string;
  is_active?: boolean;
  indexed?: boolean;
  sort_by?: string;
  sort_order?: string;
  limit?: number;
  offset?: number;
}

export function useProducts(filters: ProductFilters = {}) {
  return useQuery<PaginatedResponse<Product>>({
    queryKey: ["admin", "products", filters],
    queryFn: async () => {
      const params: Record<string, string | number | boolean> = {};
      if (filters.search) params.search = filters.search;
      if (filters.category_id) params.category_id = filters.category_id;
      if (filters.brand_id) params.brand_id = filters.brand_id;
      if (filters.status) params.status = filters.status;
      if (filters.is_active !== undefined) params.is_active = filters.is_active;
      if (filters.indexed !== undefined) params.indexed = filters.indexed;
      if (filters.sort_by) params.sort_by = filters.sort_by;
      if (filters.sort_order) params.sort_order = filters.sort_order;
      params.limit = filters.limit ?? 20;
      params.offset = filters.offset ?? 0;

      const { data } = await api.get("/admin/products", { params });
      return data.data;
    },
  });
}

// ─── Single Product ─────────────────────────────────────

export function useProduct(id: string | undefined) {
  return useQuery<Product>({
    queryKey: ["admin", "product", id],
    queryFn: async () => {
      const { data } = await api.get(`/admin/products/${id}`);
      return data.data;
    },
    enabled: !!id,
  });
}

// ─── Create Product ─────────────────────────────────────

export function useCreateProduct() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (body: Record<string, unknown>) => {
      const { data } = await api.post("/admin/products", body);
      return data.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin", "products"] });
    },
  });
}

// ─── Update Product ─────────────────────────────────────

export function useUpdateProduct(id: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (body: Record<string, unknown>) => {
      const { data } = await api.put(`/admin/products/${id}`, body);
      return data.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin", "products"] });
      queryClient.invalidateQueries({ queryKey: ["admin", "product", id] });
    },
  });
}

// ─── Delete Product ─────────────────────────────────────

export function useDeleteProduct() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      const { data } = await api.delete(`/admin/products/${id}`);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin", "products"] });
    },
  });
}

// ─── Toggle Status ──────────────────────────────────────

export function useToggleProductStatus() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, is_active }: { id: string; is_active: boolean }) => {
      const { data } = await api.patch(`/admin/products/${id}/status`, { is_active });
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin", "products"] });
    },
  });
}

// ─── Cascading Dropdown Data ────────────────────────────

/**
 * Root categories only (parent_id = null).
 */
export function useAdminCategories() {
  return useQuery<Category[]>({
    queryKey: ["admin", "categories"],
    queryFn: async () => {
      const { data } = await api.get("/admin/categories");
      return data.data;
    },
    staleTime: 5 * 60 * 1000,
  });
}

/**
 * Brands that belong to a specific category (via product_lines).
 * Only fetches when categoryId is provided.
 */
export function useAdminBrandsByCategory(categoryId?: string) {
  return useQuery<Brand[]>({
    queryKey: ["admin", "brands-by-category", categoryId],
    queryFn: async () => {
      const { data } = await api.get(`/admin/categories/${categoryId}/brands`);
      return data.data;
    },
    enabled: !!categoryId,
    staleTime: 5 * 60 * 1000,
  });
}

/**
 * All brands (fallback, for non-cascading usage).
 */
export function useAdminBrands() {
  return useQuery<Brand[]>({
    queryKey: ["admin", "brands"],
    queryFn: async () => {
      const { data } = await api.get("/admin/brands");
      return data.data;
    },
    staleTime: 5 * 60 * 1000,
  });
}

/**
 * Product lines filtered by brand + category.
 * Only fetches when both are provided.
 */
export function useAdminProductLines(brandId?: string, categoryId?: string) {
  return useQuery<ProductLine[]>({
    queryKey: ["admin", "product-lines", brandId, categoryId],
    queryFn: async () => {
      const params: Record<string, string> = {};
      if (brandId) params.brand_id = brandId;
      if (categoryId) params.category_id = categoryId;
      const { data } = await api.get("/admin/product-lines", { params });
      return data.data;
    },
    enabled: !!brandId && !!categoryId,
    staleTime: 5 * 60 * 1000,
  });
}

// ─── Spec Templates ─────────────────────────────────────

export interface SpecTemplate {
  id: string;
  spec_key: string;
  display_name: string;
  data_type: string;
  unit: string | null;
  spec_group: string | null;
  is_filterable: boolean;
  sort_order: number;
}

export function useSpecTemplates(categoryId?: string) {
  return useQuery<SpecTemplate[]>({
    queryKey: ["admin", "spec-templates", categoryId],
    queryFn: async () => {
      const { data } = await api.get("/admin/spec-templates", {
        params: { category_id: categoryId },
      });
      return data.data;
    },
    enabled: !!categoryId,
    staleTime: 5 * 60 * 1000,
  });
}
