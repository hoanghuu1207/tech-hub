"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { DollarSign, ShoppingCart, Users, Package, TrendingUp, TrendingDown } from "lucide-react";
import { useDashboardStats } from "@/hooks/use-dashboard";
import { formatCurrency, formatCompact } from "@/lib/format";

export function StatsCards() {
  const { data, isLoading } = useDashboardStats();

  if (isLoading) {
    return (
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <Card key={i}>
            <CardHeader className="flex flex-row items-center justify-between pb-2">
              <Skeleton className="h-4 w-24" />
              <Skeleton className="h-8 w-8 rounded-lg" />
            </CardHeader>
            <CardContent>
              <Skeleton className="h-8 w-28 mb-1" />
              <Skeleton className="h-3 w-20" />
            </CardContent>
          </Card>
        ))}
      </div>
    );
  }

  const stats = [
    {
      title: "Tổng doanh thu",
      value: data ? formatCurrency(data.total_revenue) : "0 ₫",
      change: data?.revenue_change ?? 0,
      icon: DollarSign,
      gradient: "from-emerald-500 to-green-600",
      shadowColor: "shadow-emerald-500/25",
    },
    {
      title: "Đơn hàng",
      value: data ? formatCompact(data.total_orders) : "0",
      change: data?.orders_change ?? 0,
      icon: ShoppingCart,
      gradient: "from-blue-500 to-indigo-600",
      shadowColor: "shadow-blue-500/25",
    },
    {
      title: "Khách hàng mới",
      value: data ? formatCompact(data.new_customers) : "0",
      change: data?.customers_change ?? 0,
      icon: Users,
      gradient: "from-violet-500 to-purple-600",
      shadowColor: "shadow-violet-500/25",
    },
    {
      title: "Sản phẩm",
      value: data ? formatCompact(data.active_products) : "0",
      change: null, // no change for products
      icon: Package,
      gradient: "from-orange-500 to-amber-600",
      shadowColor: "shadow-orange-500/25",
    },
  ];

  return (
    <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
      {stats.map((stat) => (
        <Card key={stat.title} className="relative overflow-hidden group hover:shadow-lg transition-shadow duration-300">
          <CardHeader className="flex flex-row items-center justify-between pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">
              {stat.title}
            </CardTitle>
            <div
              className={`rounded-lg bg-gradient-to-br ${stat.gradient} p-2.5 shadow-lg ${stat.shadowColor} group-hover:scale-110 transition-transform duration-300`}
            >
              <stat.icon className="h-4 w-4 text-white" />
            </div>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold tracking-tight">{stat.value}</div>
            {stat.change !== null && (
              <div className="flex items-center gap-1 mt-1">
                {stat.change >= 0 ? (
                  <TrendingUp className="h-3 w-3 text-emerald-500" />
                ) : (
                  <TrendingDown className="h-3 w-3 text-red-500" />
                )}
                <span
                  className={`text-xs font-medium ${
                    stat.change >= 0 ? "text-emerald-500" : "text-red-500"
                  }`}
                >
                  {stat.change >= 0 ? "+" : ""}
                  {stat.change}%
                </span>
                <span className="text-xs text-muted-foreground">vs tháng trước</span>
              </div>
            )}
            {stat.change === null && (
              <p className="text-xs text-muted-foreground mt-1">đang hoạt động</p>
            )}
          </CardContent>
          {/* Decorative gradient strip */}
          <div
            className={`absolute bottom-0 left-0 right-0 h-0.5 bg-gradient-to-r ${stat.gradient} opacity-0 group-hover:opacity-100 transition-opacity duration-300`}
          />
        </Card>
      ))}
    </div>
  );
}
