"use client";

import { Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { useTopProducts } from "@/hooks/use-dashboard";

export function TopProductsChart() {
  const { data, isLoading } = useTopProducts(5);

  if (isLoading) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Top sản phẩm bán chạy</CardTitle>
        </CardHeader>
        <CardContent>
          <Skeleton className="h-[300px] w-full" />
        </CardContent>
      </Card>
    );
  }

  const chartData = (data || []).map((item) => ({
    name: item.name.length > 25 ? item.name.slice(0, 25) + "…" : item.name,
    fullName: item.name,
    sold: item.sold_count,
  }));

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Top sản phẩm bán chạy</CardTitle>
      </CardHeader>
      <CardContent>
        {chartData.length === 0 ? (
          <div className="h-[300px] flex items-center justify-center text-muted-foreground text-sm">
            Chưa có dữ liệu bán hàng
          </div>
        ) : (
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={chartData} layout="vertical" margin={{ left: 10 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="hsl(0, 0%, 20%)" horizontal={false} />
              <XAxis
                type="number"
                stroke="hsl(0, 0%, 45%)"
                fontSize={11}
                tickLine={false}
                axisLine={false}
              />
              <YAxis
                dataKey="name"
                type="category"
                width={160}
                stroke="hsl(0, 0%, 45%)"
                fontSize={11}
                tickLine={false}
                axisLine={false}
              />
              <Tooltip
                contentStyle={{
                  backgroundColor: "hsl(0, 0%, 12%)",
                  border: "1px solid hsl(0, 0%, 20%)",
                  borderRadius: "8px",
                  fontSize: "12px",
                }}
                formatter={(value: number) => [`${value} sản phẩm`, "Đã bán"]}
                labelFormatter={(label: string, payload) => {
                  if (payload?.[0]?.payload?.fullName) return payload[0].payload.fullName;
                  return label;
                }}
              />
              <Bar
                dataKey="sold"
                fill="hsl(217, 91%, 60%)"
                radius={[0, 4, 4, 0]}
                maxBarSize={28}
              />
            </BarChart>
          </ResponsiveContainer>
        )}
      </CardContent>
    </Card>
  );
}
