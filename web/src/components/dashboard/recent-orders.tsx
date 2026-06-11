"use client";

import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { useRecentOrders } from "@/hooks/use-dashboard";
import { formatCurrency, formatRelativeTime } from "@/lib/format";
import { ORDER_STATUS_MAP, PAYMENT_STATUS_MAP } from "@/lib/constants";

export function RecentOrdersTable() {
  const { data, isLoading } = useRecentOrders(8);

  if (isLoading) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Đơn hàng gần đây</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            {Array.from({ length: 5 }).map((_, i) => (
              <Skeleton key={i} className="h-10 w-full" />
            ))}
          </div>
        </CardContent>
      </Card>
    );
  }

  const orders = data || [];

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Đơn hàng gần đây</CardTitle>
      </CardHeader>
      <CardContent>
        {orders.length === 0 ? (
          <div className="h-32 flex items-center justify-center text-muted-foreground text-sm">
            Chưa có đơn hàng nào
          </div>
        ) : (
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead className="w-[100px]">Mã đơn</TableHead>
                <TableHead>Khách hàng</TableHead>
                <TableHead>Tổng tiền</TableHead>
                <TableHead>Trạng thái</TableHead>
                <TableHead>Thanh toán</TableHead>
                <TableHead className="text-right">Thời gian</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {orders.map((order) => {
                const statusInfo = ORDER_STATUS_MAP[order.status] || {
                  label: order.status,
                  variant: "secondary" as const,
                };
                const paymentInfo = PAYMENT_STATUS_MAP[order.payment_status] || {
                  label: order.payment_status,
                  variant: "secondary" as const,
                };

                return (
                  <TableRow key={order.id} className="cursor-pointer hover:bg-muted/50">
                    <TableCell className="font-mono text-xs">
                      #{order.order_code || "—"}
                    </TableCell>
                    <TableCell>
                      <div>
                        <p className="text-sm font-medium truncate max-w-[140px]">
                          {order.user_name || "—"}
                        </p>
                        <p className="text-xs text-muted-foreground truncate max-w-[140px]">
                          {order.user_email}
                        </p>
                      </div>
                    </TableCell>
                    <TableCell className="font-semibold text-sm">
                      {formatCurrency(order.total_amount)}
                    </TableCell>
                    <TableCell>
                      <Badge variant={statusInfo.variant} className="text-xs">
                        {statusInfo.label}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      <Badge variant={paymentInfo.variant} className="text-xs">
                        {paymentInfo.label}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-right text-xs text-muted-foreground">
                      {formatRelativeTime(order.created_at)}
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        )}
      </CardContent>
    </Card>
  );
}
