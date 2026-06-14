"use client";

import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip, Legend } from "recharts";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { useOrderStatusStats } from "@/hooks/use-dashboard";

const STATUS_CONFIG: Record<string, { label: string; color: string }> = {
  pending: { label: "Chờ xử lý", color: "hsl(38, 92%, 50%)" },
  pending_payment: { label: "Chờ thanh toán", color: "hsl(38, 92%, 50%)" },
  confirmed: { label: "Đã xác nhận", color: "hsl(217, 91%, 60%)" },
  shipping: { label: "Đang giao", color: "hsl(262, 83%, 58%)" },
  delivered: { label: "Đã giao", color: "hsl(142, 71%, 45%)" },
  cancelled: { label: "Đã hủy", color: "hsl(0, 84%, 60%)" },
  paid: { label: "Đã thanh toán", color: "hsl(172, 66%, 50%)" },
};

export function OrderStatusChart() {
  const { data, isLoading } = useOrderStatusStats();

  if (isLoading) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Trạng thái đơn hàng</CardTitle>
        </CardHeader>
        <CardContent>
          <Skeleton className="h-[300px] w-full" />
        </CardContent>
      </Card>
    );
  }

  const chartData = (data || []).map((item) => ({
    name: STATUS_CONFIG[item.status]?.label || item.status,
    value: item.count,
    color: STATUS_CONFIG[item.status]?.color || "hsl(0, 0%, 50%)",
  }));

  const total = chartData.reduce((sum, item) => sum + item.value, 0);

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Trạng thái đơn hàng</CardTitle>
      </CardHeader>
      <CardContent>
        {chartData.length === 0 ? (
          <div className="h-[300px] flex items-center justify-center text-muted-foreground text-sm">
            Chưa có đơn hàng
          </div>
        ) : (
          <div className="flex flex-col items-center">
            <ResponsiveContainer width="100%" height={220}>
              <PieChart>
                <Pie
                  data={chartData}
                  cx="50%"
                  cy="50%"
                  innerRadius={55}
                  outerRadius={90}
                  paddingAngle={3}
                  dataKey="value"
                  stroke="none"
                >
                  {chartData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip
                  contentStyle={{
                    backgroundColor: "hsl(0, 0%, 12%)",
                    border: "1px solid hsl(0, 0%, 20%)",
                    borderRadius: "8px",
                    fontSize: "12px",
                  }}
                  formatter={(value) => [`${value} đơn`, ""]}
                />
                <Legend
                  verticalAlign="bottom"
                  iconType="circle"
                  iconSize={8}
                  formatter={(value) => (
                    <span className="text-xs text-muted-foreground ml-1">{value}</span>
                  )}
                />
              </PieChart>
            </ResponsiveContainer>
            <p className="text-center text-sm text-muted-foreground -mt-2">
              Tổng: <span className="font-semibold text-foreground">{total}</span> đơn hàng
            </p>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
