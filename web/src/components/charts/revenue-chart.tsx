"use client";

import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { useRevenueChart } from "@/hooks/use-dashboard";
import { formatCurrency, formatShortDate } from "@/lib/format";

export function RevenueChart() {
  const { data, isLoading } = useRevenueChart(30);

  if (isLoading) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Doanh thu 30 ngày gần nhất</CardTitle>
        </CardHeader>
        <CardContent>
          <Skeleton className="h-[300px] w-full" />
        </CardContent>
      </Card>
    );
  }

  const chartData = data || [];

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Doanh thu 30 ngày gần nhất</CardTitle>
      </CardHeader>
      <CardContent>
        {chartData.length === 0 ? (
          <div className="h-[300px] flex items-center justify-center text-muted-foreground text-sm">
            Chưa có dữ liệu doanh thu
          </div>
        ) : (
          <ResponsiveContainer width="100%" height={300}>
            <AreaChart data={chartData}>
              <defs>
                <linearGradient id="revenueGradient" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="hsl(217, 91%, 60%)" stopOpacity={0.3} />
                  <stop offset="95%" stopColor="hsl(217, 91%, 60%)" stopOpacity={0} />
                </linearGradient>
                <linearGradient id="ordersGradient" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="hsl(142, 71%, 45%)" stopOpacity={0.3} />
                  <stop offset="95%" stopColor="hsl(142, 71%, 45%)" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="hsl(0, 0%, 20%)" />
              <XAxis
                dataKey="date"
                tickFormatter={formatShortDate}
                stroke="hsl(0, 0%, 45%)"
                fontSize={11}
                tickLine={false}
                axisLine={false}
              />
              <YAxis
                yAxisId="revenue"
                tickFormatter={(v) => `${(v / 1_000_000).toFixed(0)}M`}
                stroke="hsl(0, 0%, 45%)"
                fontSize={11}
                tickLine={false}
                axisLine={false}
                width={50}
              />
              <YAxis
                yAxisId="orders"
                orientation="right"
                stroke="hsl(0, 0%, 45%)"
                fontSize={11}
                tickLine={false}
                axisLine={false}
                width={30}
              />
              <Tooltip
                contentStyle={{
                  backgroundColor: "hsl(0, 0%, 12%)",
                  border: "1px solid hsl(0, 0%, 20%)",
                  borderRadius: "8px",
                  fontSize: "12px",
                }}
                formatter={(value, name) => {
                  if (name === "revenue") return [formatCurrency(Number(value)), "Doanh thu"];
                  return [value, "Đơn hàng"];
                }}
                labelFormatter={(label) => formatShortDate(String(label))}
              />
              <Area
                yAxisId="revenue"
                type="monotone"
                dataKey="revenue"
                stroke="hsl(217, 91%, 60%)"
                fill="url(#revenueGradient)"
                strokeWidth={2}
                dot={false}
                activeDot={{ r: 4, fill: "hsl(217, 91%, 60%)" }}
              />
              <Area
                yAxisId="orders"
                type="monotone"
                dataKey="orders"
                stroke="hsl(142, 71%, 45%)"
                fill="url(#ordersGradient)"
                strokeWidth={2}
                dot={false}
                activeDot={{ r: 4, fill: "hsl(142, 71%, 45%)" }}
              />
            </AreaChart>
          </ResponsiveContainer>
        )}
      </CardContent>
    </Card>
  );
}
