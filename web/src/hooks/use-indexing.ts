import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/api";

// ─── Types ──────────────────────────────────────────────

export interface IndexingStatus {
  database: {
    total_active_products: number;
    indexed_products: number;
    not_indexed_products: number;
    coverage_percent: number;
  };
  qdrant: {
    points_count?: number;
    vectors_count?: number;
    status?: string;
    segments_count?: number;
    error?: string;
  };
  running_tasks: ReindexTask[];
}

export interface ReindexTask {
  task_id: string;
  status: "pending" | "running" | "completed" | "error";
  total: number;
  processed: number;
  success: number;
  errors: number;
  error_details: Array<{ product_id?: string; name?: string; error: string }>;
}

// ─── Collection Status ──────────────────────────────────

export function useIndexingStatus() {
  return useQuery<IndexingStatus>({
    queryKey: ["admin", "indexing", "status"],
    queryFn: async () => {
      const { data } = await api.get("/admin/indexing/status");
      return data.data;
    },
    refetchInterval: 10000, // auto-refresh every 10s
  });
}

// ─── Index Single Product ───────────────────────────────

export function useIndexProduct() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (productId: string) => {
      const { data } = await api.post(`/admin/indexing/products/${productId}`);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin", "indexing"] });
      queryClient.invalidateQueries({ queryKey: ["admin", "products"] });
    },
  });
}

// ─── Remove from Qdrant ─────────────────────────────────

export function useRemoveFromIndex() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (productId: string) => {
      const { data } = await api.delete(`/admin/indexing/products/${productId}`);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin", "indexing"] });
      queryClient.invalidateQueries({ queryKey: ["admin", "products"] });
    },
  });
}

// ─── Reindex All ────────────────────────────────────────

export function useReindexAll() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async () => {
      const { data } = await api.post("/admin/indexing/reindex-all");
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin", "indexing"] });
    },
  });
}

// ─── Task Status ────────────────────────────────────────

export function useReindexTask(taskId: string | null) {
  return useQuery<ReindexTask>({
    queryKey: ["admin", "indexing", "task", taskId],
    queryFn: async () => {
      const { data } = await api.get(`/admin/indexing/tasks/${taskId}`);
      return data.data;
    },
    enabled: !!taskId,
    refetchInterval: (query) => {
      const status = query.state.data?.status;
      if (status === "running" || status === "pending") return 3000;
      return false;
    },
  });
}

// ─── All Tasks ──────────────────────────────────────────

export function useReindexTasks() {
  return useQuery<ReindexTask[]>({
    queryKey: ["admin", "indexing", "tasks"],
    queryFn: async () => {
      const { data } = await api.get("/admin/indexing/tasks");
      return data.data;
    },
  });
}
