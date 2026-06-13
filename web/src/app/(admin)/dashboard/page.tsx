"use client";

import { StatsCards } from "@/components/dashboard/stats-cards";
import { RevenueChart } from "@/components/charts/revenue-chart";
import { OrderStatusChart } from "@/components/charts/order-status-chart";
import { TopProductsChart } from "@/components/charts/top-products-chart";
import { RecentOrdersTable } from "@/components/dashboard/recent-orders";

export default function DashboardPage() {
  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div>
        <h2 className="text-2xl font-bold tracking-tight">Dashboard</h2>
        <p className="text-muted-foreground">
          Tổng quan hoạt động hệ thống TechHub
        </p>
      </div>

      {/* KPI Cards */}
      <StatsCards />

      {/* Charts Row 1: Revenue + Order Status */}
      <div className="grid gap-4 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <RevenueChart />
        </div>
        <div className="lg:col-span-1">
          <OrderStatusChart />
        </div>
      </div>

      {/* Charts Row 2: Top Products + Recent Orders */}
      <div className="grid gap-4 lg:grid-cols-2">
        <TopProductsChart />
        <RecentOrdersTable />
      </div>
    </div>
  );
}
