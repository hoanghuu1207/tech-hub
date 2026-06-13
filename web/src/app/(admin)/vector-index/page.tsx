"use client";

import { useState } from "react";
import { useIndexingStatus, useReindexAll, useReindexTask, useIndexProduct, useRemoveFromIndex } from "@/hooks/use-indexing";
import { useProducts } from "@/hooks/use-products";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Progress } from "@/components/ui/progress";
import { Skeleton } from "@/components/ui/skeleton";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import {
  Database, RefreshCw, Loader2, CheckCircle2, XCircle, AlertTriangle,
  ArrowUpCircle, Trash2, ChevronLeft, ChevronRight, Server, HardDrive, Layers,
} from "lucide-react";
import { toast } from "sonner";

const PAGE_SIZE = 20;

export default function VectorIndexPage() {
  const { data: status, isLoading: statusLoading } = useIndexingStatus();
  const reindexMutation = useReindexAll();
  const indexMutation = useIndexProduct();
  const removeMutation = useRemoveFromIndex();

  const [activeTaskId, setActiveTaskId] = useState<string | null>(null);
  const { data: taskData } = useReindexTask(activeTaskId);

  const [showConfirm, setShowConfirm] = useState(false);
  const [page, setPage] = useState(0);
  const [filterMode, setFilterMode] = useState<"all" | "indexed" | "unindexed">("unindexed");

  // Products with indexing filter
  const { data: productsData, isLoading: productsLoading } = useProducts({
    indexed: filterMode === "indexed" ? true : filterMode === "unindexed" ? false : undefined,
    sort_by: "created_at",
    sort_order: "desc",
    limit: PAGE_SIZE,
    offset: page * PAGE_SIZE,
  });

  const handleReindexAll = async () => {
    try {
      const result = await reindexMutation.mutateAsync();
      setActiveTaskId(result.data.task_id);
      setShowConfirm(false);
      toast.success("Đã bắt đầu reindex tất cả sản phẩm");
    } catch {
      toast.error("Không thể bắt đầu reindex");
    }
  };

  const handleIndexSingle = async (productId: string, name: string) => {
    try {
      await indexMutation.mutateAsync(productId);
      toast.success(`Đã index "${name}"`);
    } catch {
      toast.error(`Index "${name}" thất bại`);
    }
  };

  const handleRemove = async (productId: string, name: string) => {
    try {
      await removeMutation.mutateAsync(productId);
      toast.success(`Đã xóa "${name}" khỏi Qdrant`);
    } catch {
      toast.error(`Xóa "${name}" khỏi index thất bại`);
    }
  };

  const db = status?.database;
  const qdrant = status?.qdrant;
  const runningTask = taskData?.status === "running" || taskData?.status === "pending" ? taskData : status?.running_tasks?.[0];
  const totalPages = productsData ? Math.ceil(productsData.total / PAGE_SIZE) : 0;

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">Vector Index</h2>
          <p className="text-muted-foreground text-sm">Quản lý Qdrant vector database cho AI search</p>
        </div>
        <Button
          onClick={() => setShowConfirm(true)}
          disabled={!!runningTask}
          className="bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-700 hover:to-teal-700 text-white"
        >
          {runningTask ? (
            <><Loader2 className="mr-2 h-4 w-4 animate-spin" />Đang chạy...</>
          ) : (
            <><RefreshCw className="mr-2 h-4 w-4" />Reindex tất cả</>
          )}
        </Button>
      </div>

      {/* Overview Cards */}
      {statusLoading ? (
        <div className="grid gap-4 md:grid-cols-4">
          {Array.from({ length: 4 }).map((_, i) => (
            <Card key={i}><CardContent className="pt-6"><Skeleton className="h-16 w-full" /></CardContent></Card>
          ))}
        </div>
      ) : (
        <div className="grid gap-4 md:grid-cols-4">
          <Card>
            <CardContent className="pt-5">
              <div className="flex items-center gap-3">
                <div className="p-2 rounded-lg bg-blue-500/10"><HardDrive className="h-5 w-5 text-blue-400" /></div>
                <div>
                  <p className="text-xs text-muted-foreground">Tổng SP active</p>
                  <p className="text-2xl font-bold">{db?.total_active_products ?? 0}</p>
                </div>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="pt-5">
              <div className="flex items-center gap-3">
                <div className="p-2 rounded-lg bg-emerald-500/10"><CheckCircle2 className="h-5 w-5 text-emerald-400" /></div>
                <div>
                  <p className="text-xs text-muted-foreground">Đã index</p>
                  <p className="text-2xl font-bold text-emerald-400">{db?.indexed_products ?? 0}</p>
                </div>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="pt-5">
              <div className="flex items-center gap-3">
                <div className="p-2 rounded-lg bg-amber-500/10"><AlertTriangle className="h-5 w-5 text-amber-400" /></div>
                <div>
                  <p className="text-xs text-muted-foreground">Chưa index</p>
                  <p className="text-2xl font-bold text-amber-400">{db?.not_indexed_products ?? 0}</p>
                </div>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="pt-5">
              <div className="flex items-center gap-3">
                <div className="p-2 rounded-lg bg-purple-500/10"><Layers className="h-5 w-5 text-purple-400" /></div>
                <div>
                  <p className="text-xs text-muted-foreground">Coverage</p>
                  <p className="text-2xl font-bold">{db?.coverage_percent ?? 0}%</p>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Qdrant Info + Running Task */}
      <div className="grid gap-4 lg:grid-cols-2">
        {/* Qdrant Collection */}
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-base flex items-center gap-2">
              <Server className="h-4 w-4" />Qdrant Collection
            </CardTitle>
          </CardHeader>
          <CardContent>
            {qdrant?.error ? (
              <div className="flex items-center gap-2 text-red-400">
                <XCircle className="h-4 w-4" /><span className="text-sm">{qdrant.error}</span>
              </div>
            ) : (
              <div className="grid gap-2 text-sm">
                <div className="flex justify-between"><span className="text-muted-foreground">Collection</span><span className="font-mono">products</span></div>
                <div className="flex justify-between"><span className="text-muted-foreground">Points</span><span className="font-mono">{qdrant?.points_count ?? "—"}</span></div>
                <div className="flex justify-between"><span className="text-muted-foreground">Vectors</span><span className="font-mono">{qdrant?.vectors_count ?? "—"}</span></div>
                <div className="flex justify-between"><span className="text-muted-foreground">Status</span>
                  <Badge variant="outline" className="text-xs text-emerald-400 border-emerald-400/30">{qdrant?.status || "—"}</Badge>
                </div>
                <div className="flex justify-between"><span className="text-muted-foreground">Segments</span><span className="font-mono">{qdrant?.segments_count ?? "—"}</span></div>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Running Task */}
        <Card>
          <CardHeader className="pb-3">
            <CardTitle className="text-base flex items-center gap-2">
              <RefreshCw className="h-4 w-4" />Tiến trình Reindex
            </CardTitle>
          </CardHeader>
          <CardContent>
            {runningTask ? (
              <div className="space-y-3">
                <div className="flex items-center justify-between text-sm">
                  <span>Task: <span className="font-mono text-xs">{runningTask.task_id}</span></span>
                  <Badge variant={runningTask.status === "running" ? "default" : runningTask.status === "completed" ? "secondary" : "destructive"} className="text-xs">
                    {runningTask.status === "running" && <Loader2 className="h-3 w-3 mr-1 animate-spin" />}
                    {runningTask.status}
                  </Badge>
                </div>
                <Progress value={runningTask.total > 0 ? (runningTask.processed / runningTask.total) * 100 : 0} className="h-2" />
                <div className="flex justify-between text-xs text-muted-foreground">
                  <span>{runningTask.processed} / {runningTask.total} đã xử lý</span>
                  <span className="text-emerald-400">{runningTask.success} thành công</span>
                  {runningTask.errors > 0 && <span className="text-red-400">{runningTask.errors} lỗi</span>}
                </div>
              </div>
            ) : (
              <p className="text-sm text-muted-foreground text-center py-4">Không có task nào đang chạy</p>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Products Table */}
      <Card>
        <CardHeader className="pb-3">
          <div className="flex items-center justify-between">
            <CardTitle className="text-base">Danh sách sản phẩm</CardTitle>
            <div className="flex gap-1.5">
              {(["unindexed", "indexed", "all"] as const).map((mode) => (
                <Button key={mode} variant={filterMode === mode ? "default" : "outline"} size="sm" className="h-7 text-xs"
                  onClick={() => { setFilterMode(mode); setPage(0); }}>
                  {mode === "unindexed" ? "Chưa index" : mode === "indexed" ? "Đã index" : "Tất cả"}
                </Button>
              ))}
            </div>
          </div>
        </CardHeader>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead className="w-[50px]">Ảnh</TableHead>
                <TableHead>Tên sản phẩm</TableHead>
                <TableHead>Danh mục</TableHead>
                <TableHead>Thương hiệu</TableHead>
                <TableHead className="text-center">Trạng thái</TableHead>
                <TableHead className="text-right w-[140px]">Thao tác</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {productsLoading ? (
                Array.from({ length: 5 }).map((_, i) => (
                  <TableRow key={i}>{Array.from({ length: 6 }).map((_, j) => (
                    <TableCell key={j}><Skeleton className="h-5 w-full" /></TableCell>
                  ))}</TableRow>
                ))
              ) : productsData?.items.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={6} className="text-center py-12 text-muted-foreground">
                    {filterMode === "unindexed" ? "🎉 Tất cả sản phẩm đã được index!" : "Không có sản phẩm nào"}
                  </TableCell>
                </TableRow>
              ) : (
                productsData?.items.map((p) => (
                  <TableRow key={p.id} className="group">
                    <TableCell>
                      {p.primary_image ? (
                        <img src={p.primary_image} alt="" className="h-9 w-9 rounded object-cover bg-muted" />
                      ) : (
                        <div className="h-9 w-9 rounded bg-muted" />
                      )}
                    </TableCell>
                    <TableCell className="font-medium text-sm max-w-[280px] truncate">{p.name}</TableCell>
                    <TableCell className="text-sm text-muted-foreground">{p.category_name || "—"}</TableCell>
                    <TableCell className="text-sm text-muted-foreground">{p.brand_name || "—"}</TableCell>
                    <TableCell className="text-center">
                      {p.qdrant_vector_id ? (
                        <Badge variant="outline" className="text-xs text-emerald-400 border-emerald-400/30">
                          <Database className="h-3 w-3 mr-1" />Indexed
                        </Badge>
                      ) : (
                        <Badge variant="outline" className="text-xs text-amber-400 border-amber-400/30">Chưa index</Badge>
                      )}
                    </TableCell>
                    <TableCell className="text-right">
                      <div className="flex items-center justify-end gap-1 opacity-70 group-hover:opacity-100 transition-opacity">
                        {p.qdrant_vector_id ? (
                          <>
                            <Button variant="ghost" size="sm" className="h-7 text-xs" onClick={() => handleIndexSingle(p.id, p.name)}
                              disabled={indexMutation.isPending} title="Re-index">
                              <RefreshCw className="h-3.5 w-3.5" />
                            </Button>
                            <Button variant="ghost" size="sm" className="h-7 text-xs text-destructive" onClick={() => handleRemove(p.id, p.name)}
                              disabled={removeMutation.isPending} title="Xóa khỏi index">
                              <Trash2 className="h-3.5 w-3.5" />
                            </Button>
                          </>
                        ) : (
                          <Button variant="ghost" size="sm" className="h-7 text-xs text-emerald-400" onClick={() => handleIndexSingle(p.id, p.name)}
                            disabled={indexMutation.isPending} title="Index">
                            <ArrowUpCircle className="h-3.5 w-3.5 mr-1" />Index
                          </Button>
                        )}
                      </div>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-between">
          <p className="text-sm text-muted-foreground">Trang {page + 1} / {totalPages}</p>
          <div className="flex gap-2">
            <Button variant="outline" size="sm" disabled={page === 0} onClick={() => setPage(page - 1)}>
              <ChevronLeft className="h-4 w-4 mr-1" />Trước
            </Button>
            <Button variant="outline" size="sm" disabled={page >= totalPages - 1} onClick={() => setPage(page + 1)}>
              Sau<ChevronRight className="h-4 w-4 ml-1" />
            </Button>
          </div>
        </div>
      )}

      {/* Reindex Confirm Dialog */}
      <Dialog open={showConfirm} onOpenChange={setShowConfirm}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Reindex tất cả sản phẩm</DialogTitle>
            <DialogDescription>
              Hành động này sẽ re-index <strong>{db?.total_active_products ?? 0}</strong> sản phẩm active vào Qdrant.
              Quá trình chạy nền và có thể mất vài phút. Bạn có thể theo dõi tiến trình trên trang này.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowConfirm(false)}>Hủy</Button>
            <Button onClick={handleReindexAll} disabled={reindexMutation.isPending}
              className="bg-gradient-to-r from-emerald-600 to-teal-600 text-white">
              {reindexMutation.isPending ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : <RefreshCw className="mr-2 h-4 w-4" />}
              Bắt đầu Reindex
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
