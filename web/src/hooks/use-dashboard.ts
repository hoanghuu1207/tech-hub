import { useQuery } from "@tanstack/react-query";
import api from "@/lib/api";
import type {
  DashboardStats,
  RevenueDataPoint,
  OrderStatusCount,
  TopProduct,
} from "@/types";

// ─── Dashboard Stats (KPI Cards) ────────────────────────

export function useDashboardStats() {
  return useQuery<DashboardStats>({
    queryKey: ["dashboard", "stats"],
    queryFn: async () => {
      const { data } = await api.get("/admin/dashboard/stats");
      return data.data;
    },
  });
}

// ─── Revenue Chart Data ─────────────────────────────────

export function useRevenueChart(days: number = 30) {
  return useQuery<RevenueDataPoint[]>({
    queryKey: ["dashboard", "chart", days],
    queryFn: async () => {
      const { data } = await api.get("/admin/dashboard/chart", {
        params: { days },
      });
      return data.data;
    },
  });
}

// ─── Order Status Breakdown ─────────────────────────────

export function useOrderStatusStats() {
  return useQuery<OrderStatusCount[]>({
    queryKey: ["dashboard", "order-status"],
    queryFn: async () => {
      const { data } = await api.get("/admin/dashboard/order-status");
      return data.data;
    },
  });
}

// ─── Top Products ───────────────────────────────────────

export function useTopProducts(limit: number = 5) {
  return useQuery<TopProduct[]>({
    queryKey: ["dashboard", "top-products", limit],
    queryFn: async () => {
      const { data } = await api.get("/admin/dashboard/top-products", {
        params: { limit },
      });
      return data.data;
    },
  });
}

// ─── Recent Orders ──────────────────────────────────────

interface RecentOrder {
  id: string;
  order_code: number | null;
  status: string;
  total_amount: number;
  payment_status: string;
  payment_method: string | null;
  created_at: string | null;
  user_name: string | null;
  user_email: string | null;
}

export function useRecentOrders(limit: number = 10) {
  return useQuery<RecentOrder[]>({
    queryKey: ["dashboard", "recent-orders", limit],
    queryFn: async () => {
      const { data } = await api.get("/admin/dashboard/recent-orders", {
        params: { limit },
      });
      return data.data;
    },
  });
}
