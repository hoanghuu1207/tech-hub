"use client";

import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import api from "@/lib/api";
import { formatCurrency, formatDateTime } from "@/lib/format";
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
import {
  Search, X, ChevronLeft, ChevronRight, Eye, Package, Truck, CheckCircle, XCircle, Clock,
} from "lucide-react";
import { toast } from "sonner";

// ─── Types ──────────────────────────────────────────────

interface OrderItem {
  id: string;
  product_id: string;
  variant_id: string | null;
  quantity: number;
  unit_price: number;
  subtotal: number;
  product_name: string | null;
  product_image: string | null;
}

interface OrderAddress {
  recipient_name: string;
  phone: string;
  province: string | null;
  district: string | null;
  ward: string | null;
  street: string | null;
}

interface AdminOrder {
  id: string;
  order_code: number | null;
  status: string;
  total_amount: number;
  discount_amount: number;
  shipping_fee: number;
  payment_method: string | null;
  payment_status: string;
  note: string | null;
  created_at: string | null;
  updated_at: string | null;
  user_name: string | null;
  user_email: string | null;
  items: OrderItem[];
  address: OrderAddress | null;
  item_count: number;
}

interface OrdersResponse {
  data: AdminOrder[];
  pagination: { total: number; page: number; limit: number; total_pages: number };
}

// ─── Status Maps ────────────────────────────────────────

const ORDER_STATUS_MAP: Record<string, { label: string; color: string; icon: React.ElementType }> = {
  pending: { label: "Chờ xử lý", color: "bg-yellow-500/15 text-yellow-400 border-yellow-500/30", icon: Clock },
  confirmed: { label: "Đã xác nhận", color: "bg-blue-500/15 text-blue-400 border-blue-500/30", icon: CheckCircle },
  shipping: { label: "Đang giao", color: "bg-purple-500/15 text-purple-400 border-purple-500/30", icon: Truck },
  delivered: { label: "Đã giao", color: "bg-green-500/15 text-green-400 border-green-500/30", icon: CheckCircle },
  cancelled: { label: "Đã hủy", color: "bg-red-500/15 text-red-400 border-red-500/30", icon: XCircle },
};

const PAYMENT_STATUS_MAP: Record<string, { label: string; variant: "default" | "secondary" | "destructive" | "outline" }> = {
  pending: { label: "Chờ thanh toán", variant: "outline" },
  paid: { label: "Đã thanh toán", variant: "default" },
  failed: { label: "Thất bại", variant: "destructive" },
  refunded: { label: "Đã hoàn tiền", variant: "secondary" },
};

const PAYMENT_METHOD_MAP: Record<string, string> = {
  payos: "PayOS (QR)",
  cod: "COD",
};

// ─── Hooks ──────────────────────────────────────────────

function useAdminOrders(filters: { status?: string; payment_status?: string; page: number; limit: number }) {
  return useQuery<OrdersResponse>({
    queryKey: ["admin", "orders", filters],
    queryFn: async () => {
      const params: Record<string, string | number> = { page: filters.page, limit: filters.limit };
      if (filters.status) params.status = filters.status;
      if (filters.payment_status) params.payment_status = filters.payment_status;
      const { data } = await api.get("/admin/orders", { params });
      return { data: data.data, pagination: data.pagination };
    },
  });
}

function useUpdateOrderStatus() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, status }: { id: string; status: string }) => {
      const { data } = await api.put(`/admin/orders/${id}/status?status=${status}`);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin", "orders"] });
      queryClient.invalidateQueries({ queryKey: ["admin", "dashboard"] });
    },
  });
}

function useUpdatePaymentStatus() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, payment_status }: { id: string; payment_status: string }) => {
      const { data } = await api.put(`/admin/orders/${id}/payment-status?payment_status=${payment_status}`);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["admin", "orders"] });
      queryClient.invalidateQueries({ queryKey: ["admin", "dashboard"] });
    },
  });
}

// ─── Main Page ──────────────────────────────────────────

export default function OrdersPage() {
  const [filterStatus, setFilterStatus] = useState("all");
  const [filterPayment, setFilterPayment] = useState("all");
  const [page, setPage] = useState(1);
  const [detailOrder, setDetailOrder] = useState<AdminOrder | null>(null);

  const { data: result, isLoading } = useAdminOrders({
    status: filterStatus !== "all" ? filterStatus : undefined,
    payment_status: filterPayment !== "all" ? filterPayment : undefined,
    page,
    limit: 15,
  });

  const updateStatusMutation = useUpdateOrderStatus();
  const updatePaymentMutation = useUpdatePaymentStatus();

  const orders = result?.data ?? [];
  const pagination = result?.pagination;

  const handleStatusChange = async (orderId: string, newStatus: string) => {
    try {
      await updateStatusMutation.mutateAsync({ id: orderId, status: newStatus });
      toast.success(`Đã cập nhật trạng thái đơn hàng → ${ORDER_STATUS_MAP[newStatus]?.label}`);
      if (detailOrder?.id === orderId) {
        setDetailOrder({ ...detailOrder, status: newStatus });
      }
    } catch {
      toast.error("Cập nhật trạng thái thất bại");
    }
  };

  const handlePaymentStatusChange = async (orderId: string, newStatus: string) => {
    try {
      await updatePaymentMutation.mutateAsync({ id: orderId, payment_status: newStatus });
      toast.success(`Đã cập nhật thanh toán → ${PAYMENT_STATUS_MAP[newStatus]?.label}`);
      if (detailOrder?.id === orderId) {
        setDetailOrder({ ...detailOrder, payment_status: newStatus });
      }
    } catch {
      toast.error("Cập nhật trạng thái thanh toán thất bại");
    }
  };

  return (
    <div className="space-y-4">
      {/* ─── Header ──────────────────────────────────────── */}
      <div>
        <h2 className="text-2xl font-bold tracking-tight">Đơn hàng</h2>
        <p className="text-muted-foreground text-sm">
          {pagination ? `${pagination.total} đơn hàng` : "Đang tải..."}
        </p>
      </div>

      {/* ─── Filters ─────────────────────────────────────── */}
      <Card>
        <CardContent className="pt-4 pb-3">
          <div className="flex flex-wrap gap-3 items-end">
            <div className="space-y-1">
              <span className="text-xs text-muted-foreground">Trạng thái đơn</span>
              <Select value={filterStatus} onValueChange={(v) => { setFilterStatus(v ?? "all"); setPage(1); }}>
                <SelectTrigger className="w-[160px] h-9">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Tất cả</SelectItem>
                  {Object.entries(ORDER_STATUS_MAP).map(([k, v]) => (
                    <SelectItem key={k} value={k}>{v.label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-1">
              <span className="text-xs text-muted-foreground">Thanh toán</span>
              <Select value={filterPayment} onValueChange={(v) => { setFilterPayment(v ?? "all"); setPage(1); }}>
                <SelectTrigger className="w-[160px] h-9">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Tất cả</SelectItem>
                  {Object.entries(PAYMENT_STATUS_MAP).map(([k, v]) => (
                    <SelectItem key={k} value={k}>{v.label}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {(filterStatus !== "all" || filterPayment !== "all") && (
              <Button variant="ghost" size="sm" className="h-9" onClick={() => { setFilterStatus("all"); setFilterPayment("all"); setPage(1); }}>
                <X className="h-4 w-4 mr-1" /> Xóa bộ lọc
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
                <TableHead>Mã đơn</TableHead>
                <TableHead>Khách hàng</TableHead>
                <TableHead>Sản phẩm</TableHead>
                <TableHead className="text-right">Tổng tiền</TableHead>
                <TableHead className="text-center">Trạng thái</TableHead>
                <TableHead className="text-center">Thanh toán</TableHead>
                <TableHead>Ngày tạo</TableHead>
                <TableHead className="text-right w-[80px]">Chi tiết</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading ? (
                Array.from({ length: 8 }).map((_, i) => (
                  <TableRow key={i}>
                    {Array.from({ length: 8 }).map((_, j) => (
                      <TableCell key={j}><Skeleton className="h-5 w-full" /></TableCell>
                    ))}
                  </TableRow>
                ))
              ) : orders.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={8} className="text-center py-12 text-muted-foreground">
                    Không có đơn hàng nào
                  </TableCell>
                </TableRow>
              ) : (
                orders.map((order) => {
                  const statusInfo = ORDER_STATUS_MAP[order.status] || ORDER_STATUS_MAP.pending;
                  const paymentInfo = PAYMENT_STATUS_MAP[order.payment_status] || PAYMENT_STATUS_MAP.pending;
                  const StatusIcon = statusInfo.icon;

                  return (
                    <TableRow key={order.id} className="group">
                      <TableCell>
                        <span className="font-mono text-sm font-medium">
                          #{order.order_code || "—"}
                        </span>
                      </TableCell>

                      <TableCell>
                        <div>
                          <p className="text-sm font-medium">{order.user_name || "—"}</p>
                          <p className="text-xs text-muted-foreground">{order.user_email || ""}</p>
                        </div>
                      </TableCell>

                      <TableCell>
                        <span className="text-sm text-muted-foreground">
                          {order.item_count} sản phẩm
                        </span>
                      </TableCell>

                      <TableCell className="text-right">
                        <span className="font-medium text-sm">{formatCurrency(order.total_amount)}</span>
                      </TableCell>

                      <TableCell className="text-center">
                        <Badge variant="outline" className={`text-xs gap-1 ${statusInfo.color}`}>
                          <StatusIcon className="h-3 w-3" />
                          {statusInfo.label}
                        </Badge>
                      </TableCell>

                      <TableCell className="text-center">
                        <Badge variant={paymentInfo.variant} className="text-xs">
                          {paymentInfo.label}
                        </Badge>
                      </TableCell>

                      <TableCell className="text-sm text-muted-foreground">
                        {formatDateTime(order.created_at)}
                      </TableCell>

                      <TableCell className="text-right">
                        <Button
                          variant="ghost" size="icon" className="h-7 w-7"
                          onClick={() => setDetailOrder(order)} title="Xem chi tiết"
                        >
                          <Eye className="h-3.5 w-3.5" />
                        </Button>
                      </TableCell>
                    </TableRow>
                  );
                })
              )}
            </TableBody>
          </Table>
        </CardContent>

        {/* Pagination */}
        {pagination && pagination.total_pages > 1 && (
          <div className="flex items-center justify-between px-4 py-3 border-t">
            <p className="text-sm text-muted-foreground">
              Trang {pagination.page} / {pagination.total_pages} ({pagination.total} đơn)
            </p>
            <div className="flex gap-1">
              <Button
                variant="outline" size="icon" className="h-8 w-8"
                disabled={page <= 1}
                onClick={() => setPage(page - 1)}
              >
                <ChevronLeft className="h-4 w-4" />
              </Button>
              <Button
                variant="outline" size="icon" className="h-8 w-8"
                disabled={page >= pagination.total_pages}
                onClick={() => setPage(page + 1)}
              >
                <ChevronRight className="h-4 w-4" />
              </Button>
            </div>
          </div>
        )}
      </Card>

      {/* ─── Order Detail Dialog ─────────────────────────── */}
      <Dialog open={!!detailOrder} onOpenChange={(open) => !open && setDetailOrder(null)}>
        <DialogContent className="sm:max-w-[640px] max-h-[85vh] overflow-y-auto">
          {detailOrder && (
            <>
              <DialogHeader>
                <DialogTitle className="flex items-center gap-2">
                  <Package className="h-5 w-5" />
                  Đơn hàng #{detailOrder.order_code || "—"}
                </DialogTitle>
                <DialogDescription>
                  {detailOrder.user_name} • {formatDateTime(detailOrder.created_at)}
                </DialogDescription>
              </DialogHeader>

              <div className="space-y-5 py-2">
                {/* Status controls */}
                <div className="grid grid-cols-2 gap-3">
                  <div className="space-y-1.5">
                    <span className="text-xs font-medium text-muted-foreground">Trạng thái đơn</span>
                    <Select
                      value={detailOrder.status}
                      onValueChange={(v) => v && handleStatusChange(detailOrder.id, v)}
                    >
                      <SelectTrigger className="h-9">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {Object.entries(ORDER_STATUS_MAP).map(([k, v]) => (
                          <SelectItem key={k} value={k}>{v.label}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="space-y-1.5">
                    <span className="text-xs font-medium text-muted-foreground">Trạng thái thanh toán</span>
                    <Select
                      value={detailOrder.payment_status}
                      onValueChange={(v) => v && handlePaymentStatusChange(detailOrder.id, v)}
                    >
                      <SelectTrigger className="h-9">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {Object.entries(PAYMENT_STATUS_MAP).map(([k, v]) => (
                          <SelectItem key={k} value={k}>{v.label}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                </div>

                {/* Order summary */}
                <div className="rounded-lg border p-3 space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Phương thức TT</span>
                    <span className="font-medium">{PAYMENT_METHOD_MAP[detailOrder.payment_method || ""] || detailOrder.payment_method || "—"}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Phí vận chuyển</span>
                    <span>{formatCurrency(detailOrder.shipping_fee)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Giảm giá</span>
                    <span>{detailOrder.discount_amount > 0 ? `-${formatCurrency(detailOrder.discount_amount)}` : "—"}</span>
                  </div>
                  <div className="flex justify-between border-t pt-2">
                    <span className="font-medium">Tổng cộng</span>
                    <span className="font-bold text-base">{formatCurrency(detailOrder.total_amount)}</span>
                  </div>
                </div>

                {/* Shipping address */}
                {detailOrder.address && (
                  <div className="rounded-lg border p-3 space-y-1">
                    <p className="text-xs font-medium text-muted-foreground mb-1.5">Địa chỉ giao hàng</p>
                    <p className="text-sm font-medium">{detailOrder.address.recipient_name} — {detailOrder.address.phone}</p>
                    <p className="text-sm text-muted-foreground">
                      {[detailOrder.address.street, detailOrder.address.ward, detailOrder.address.district, detailOrder.address.province].filter(Boolean).join(", ")}
                    </p>
                  </div>
                )}

                {/* Items */}
                <div>
                  <p className="text-xs font-medium text-muted-foreground mb-2">Sản phẩm ({detailOrder.items.length})</p>
                  <div className="space-y-2">
                    {detailOrder.items.map((item) => (
                      <div key={item.id} className="flex items-center gap-3 rounded-lg border p-2.5">
                        {item.product_image ? (
                          <img src={item.product_image} alt="" className="h-12 w-12 rounded object-contain bg-muted p-0.5 shrink-0" />
                        ) : (
                          <div className="h-12 w-12 rounded bg-muted flex items-center justify-center shrink-0">
                            <Package className="h-5 w-5 text-muted-foreground" />
                          </div>
                        )}
                        <div className="flex-1 min-w-0">
                          <p className="text-sm font-medium truncate">{item.product_name || "Sản phẩm"}</p>
                          <p className="text-xs text-muted-foreground">
                            {formatCurrency(item.unit_price)} × {item.quantity}
                          </p>
                        </div>
                        <span className="text-sm font-medium shrink-0">{formatCurrency(item.subtotal)}</span>
                      </div>
                    ))}
                  </div>
                </div>

                {/* Note */}
                {detailOrder.note && (
                  <div className="rounded-lg border p-3">
                    <p className="text-xs font-medium text-muted-foreground mb-1">Ghi chú</p>
                    <p className="text-sm">{detailOrder.note}</p>
                  </div>
                )}
              </div>

              <DialogFooter>
                <Button variant="outline" onClick={() => setDetailOrder(null)}>Đóng</Button>
              </DialogFooter>
            </>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
