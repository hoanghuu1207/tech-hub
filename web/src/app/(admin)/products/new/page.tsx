"use client";

import { useState, useMemo } from "react";
import { useRouter } from "next/navigation";
import { useCreateProduct, useAdminCategories, useAdminBrands, useAdminProductLines, useSpecTemplates } from "@/hooks/use-products";
import { Button, buttonVariants } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Badge } from "@/components/ui/badge";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { ArrowLeft, Save, Loader2, Plus, Trash2, X, GripVertical, AlertTriangle } from "lucide-react";
import { toast } from "sonner";
import Link from "next/link";
import type { SpecTemplate } from "@/hooks/use-products";

interface VariantRow { color_name: string; color_hex: string; price_override: string; sale_price_override: string; stock_quantity: string; sku: string; is_active: boolean; sort_order: number; }
interface ImageRow { image_url: string; alt_text: string; is_primary: boolean; sort_order: number; }

export default function NewProductPage() {
  const router = useRouter();
  const createMutation = useCreateProduct();

  const [name, setName] = useState("");
  const [slug, setSlug] = useState("");
  const [categoryId, setCategoryId] = useState("");
  const [brandId, setBrandId] = useState("");
  const [lineId, setLineId] = useState("");
  const [description, setDescription] = useState("");
  const [features, setFeatures] = useState<string[]>([]);
  const [featureInput, setFeatureInput] = useState("");
  const [basePrice, setBasePrice] = useState("");
  const [salePrice, setSalePrice] = useState("");
  const [status, setStatus] = useState("new");
  const [specsMap, setSpecsMap] = useState<Record<string, Record<string, string>>>({});
  const [isActive, setIsActive] = useState(true);
  const [variants, setVariants] = useState<VariantRow[]>([]);
  const [images, setImages] = useState<ImageRow[]>([]);
  const [activeTab, setActiveTab] = useState("basic");

  // Cascading dropdowns
  const { data: categories } = useAdminCategories();
  const { data: allBrands } = useAdminBrands();
  const { data: productLines } = useAdminProductLines(brandId || undefined, categoryId || undefined);
  const { data: specTemplates } = useSpecTemplates(categoryId || undefined);

  // Map spec_group display names (Vietnamese) to JSONB group keys (English)
  const SPEC_GROUP_TO_KEY: Record<string, string> = {
    "Màn hình": "screen", "Hiệu năng": "performance", "Camera": "camera_rear",
    "Camera sau": "camera_rear", "Camera trước": "camera_front",
    "Pin & Sạc": "battery", "Thiết kế": "design", "Kết nối": "connectivity",
    "Thông tin": "raw", "Tính năng": "special_features", "Webcam": "webcam",
    "Khác": "other",
  };
  const SPEC_GROUP_LABELS: Record<string, string> = {
    design: "Thiết kế", screen: "Màn hình", performance: "Hiệu năng",
    camera_rear: "Camera sau", camera_front: "Camera trước",
    connectivity: "Kết nối", battery: "Pin", webcam: "Webcam",
    special_features: "Tính năng đặc biệt", raw: "Thông tin khác", other: "Khác",
  };

  // Group spec templates by JSONB group key (English)
  const specGroups = useMemo(() => {
    if (!specTemplates) return {};
    const groups: Record<string, SpecTemplate[]> = {};
    for (const t of specTemplates) {
      const groupKey = SPEC_GROUP_TO_KEY[t.spec_group || "Khác"] || t.spec_group || "other";
      if (!groups[groupKey]) groups[groupKey] = [];
      groups[groupKey].push(t);
    }
    return groups;
  }, [specTemplates]);

  const generateSlug = (t: string) => t.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/đ/g, "d").replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");
  const handleCategoryChange = (v: string | null) => { setCategoryId(v ?? ""); setBrandId(""); setLineId(""); };
  const handleBrandChange = (v: string | null) => { setBrandId(v ?? ""); setLineId(""); };
  const updateSpecValue = (group: string, key: string, value: string) => { setSpecsMap(prev => ({ ...prev, [group]: { ...(prev[group] || {}), [key]: value } })); };

  const addVariant = () => setVariants([...variants, { color_name: "", color_hex: "#000000", price_override: "", sale_price_override: "", stock_quantity: "0", sku: "", is_active: true, sort_order: variants.length }]);
  const updateVariant = (i: number, f: keyof VariantRow, v: string | boolean | number) => { const u = [...variants]; (u[i] as unknown as Record<string, unknown>)[f] = v; setVariants(u); };

  const addImage = () => setImages([...images, { image_url: "", alt_text: "", is_primary: images.length === 0, sort_order: images.length }]);
  const updateImage = (i: number, f: keyof ImageRow, v: string | boolean | number) => { const u = [...images]; if (f === "is_primary" && v === true) u.forEach((img, j) => { img.is_primary = j === i; }); else (u[i] as unknown as Record<string, unknown>)[f] = v; setImages(u); };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name || !slug || !categoryId || !brandId || !basePrice) { toast.error("Vui lòng điền đầy đủ các trường bắt buộc"); return; }
    if (variants.length === 0) { toast.error("Phải có ít nhất 1 biến thể sản phẩm"); setActiveTab("variants"); return; }
    if (variants.some(v => !v.color_name)) { toast.error("Tên màu biến thể không được để trống"); setActiveTab("variants"); return; }

    // specsMap is already in JSONB format (group_key → spec_key → value) — clean and send
    const specsForApi: Record<string, Record<string, string>> = {};
    for (const [group, fields] of Object.entries(specsMap)) {
      const cleaned: Record<string, string> = {};
      for (const [k, v] of Object.entries(fields)) {
        if (v !== undefined && v !== "") cleaned[k] = v;
      }
      if (Object.keys(cleaned).length > 0) specsForApi[group] = cleaned;
    }

    const body = {
      name, slug, category_id: categoryId, brand_id: brandId, line_id: lineId || null,
      description: description || null, highlight_features: features,
      base_price: parseFloat(basePrice), sale_price: salePrice ? parseFloat(salePrice) : null,
      status, specs: specsForApi, is_active: isActive,
      variants: variants.map(v => ({ color_name: v.color_name, color_hex: v.color_hex || null, price_override: v.price_override ? parseFloat(v.price_override) : null, sale_price_override: v.sale_price_override ? parseFloat(v.sale_price_override) : null, stock_quantity: parseInt(v.stock_quantity) || 0, sku: v.sku || null, is_active: v.is_active, sort_order: v.sort_order })),
      images: images.map(img => ({ image_url: img.image_url, alt_text: img.alt_text || null, is_primary: img.is_primary, sort_order: img.sort_order })),
    };
    try {
      await createMutation.mutateAsync(body);
      toast.success("Tạo sản phẩm thành công!");
      router.push("/products");
    } catch (error: unknown) {
      const err = error as { response?: { data?: { detail?: string } } };
      toast.error(err?.response?.data?.detail || "Tạo sản phẩm thất bại");
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Link href="/products" className={cn(buttonVariants({ variant: "ghost", size: "icon" }))}><ArrowLeft className="h-4 w-4" /></Link>
          <div><h2 className="text-xl font-bold tracking-tight">Thêm sản phẩm mới</h2><p className="text-sm text-muted-foreground">Tạo sản phẩm và biến thể</p></div>
        </div>
        <Button type="submit" disabled={createMutation.isPending} className="bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white">
          {createMutation.isPending ? <><Loader2 className="mr-2 h-4 w-4 animate-spin" />Đang tạo...</> : <><Save className="mr-2 h-4 w-4" />Tạo sản phẩm</>}
        </Button>
      </div>

      <Tabs value={activeTab} onValueChange={setActiveTab} className="space-y-4">
        <TabsList>
          <TabsTrigger value="basic">Thông tin cơ bản</TabsTrigger>
          <TabsTrigger value="specs">Thông số</TabsTrigger>
          <TabsTrigger value="variants" className="gap-1.5">Biến thể {variants.length > 0 ? <Badge variant="secondary" className="text-xs px-1.5">{variants.length}</Badge> : <AlertTriangle className="h-3.5 w-3.5 text-amber-400" />}</TabsTrigger>
          <TabsTrigger value="images">Hình ảnh {images.length > 0 && <Badge variant="secondary" className="ml-1.5 text-xs px-1.5">{images.length}</Badge>}</TabsTrigger>
        </TabsList>

        {/* TAB: Basic */}
        <TabsContent value="basic" className="space-y-4">
          <div className="grid gap-4 lg:grid-cols-3">
            <Card className="lg:col-span-2">
              <CardHeader><CardTitle className="text-base">Thông tin sản phẩm</CardTitle></CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-2"><Label>Tên sản phẩm *</Label><Input value={name} onChange={(e) => { setName(e.target.value); setSlug(generateSlug(e.target.value)); }} placeholder="VD: iPhone 16 Pro Max 256GB" /></div>
                <div className="space-y-2"><Label>Slug *</Label><Input value={slug} onChange={(e) => setSlug(e.target.value)} /></div>
                <div className="space-y-2"><Label>Mô tả</Label><Textarea value={description} onChange={(e) => setDescription(e.target.value)} rows={4} /></div>
                <div className="space-y-2">
                  <Label>Điểm nổi bật</Label>
                  <div className="flex gap-2">
                    <Input value={featureInput} onChange={(e) => setFeatureInput(e.target.value)} placeholder="VD: Chip A18 Pro" onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); if (featureInput.trim()) { setFeatures([...features, featureInput.trim()]); setFeatureInput(""); } } }} />
                    <Button type="button" variant="outline" size="sm" onClick={() => { if (featureInput.trim()) { setFeatures([...features, featureInput.trim()]); setFeatureInput(""); } }}><Plus className="h-4 w-4" /></Button>
                  </div>
                  {features.length > 0 && <div className="flex flex-wrap gap-1.5 mt-2">{features.map((f, i) => <Badge key={i} variant="secondary" className="gap-1 pr-1">{f}<button type="button" onClick={() => setFeatures(features.filter((_, j) => j !== i))}><X className="h-3 w-3" /></button></Badge>)}</div>}
                </div>
              </CardContent>
            </Card>
            <div className="space-y-4">
              <Card>
                <CardHeader><CardTitle className="text-base">Phân loại</CardTitle></CardHeader>
                <CardContent className="space-y-3">
                  <div className="space-y-1.5"><Label>Danh mục *</Label>
                    <Select value={categoryId} onValueChange={handleCategoryChange}><SelectTrigger><SelectValue placeholder="Chọn danh mục" /></SelectTrigger><SelectContent>{categories?.map(c => <SelectItem key={c.id} value={c.id}>{c.name}</SelectItem>)}</SelectContent></Select>
                  </div>
                  <div className="space-y-1.5"><Label>Thương hiệu *</Label>
                    <Select value={brandId} onValueChange={handleBrandChange}><SelectTrigger><SelectValue placeholder="Chọn thương hiệu" /></SelectTrigger><SelectContent>{allBrands?.map(b => <SelectItem key={b.id} value={b.id}>{b.name}</SelectItem>)}</SelectContent></Select>
                  </div>
                  <div className="space-y-1.5"><Label>Dòng SP</Label>
                    <Select value={lineId || " "} onValueChange={(v) => setLineId((v ?? "").trim())} disabled={!brandId}><SelectTrigger><SelectValue placeholder={!brandId ? "Chọn thương hiệu trước" : "Chọn dòng SP"} /></SelectTrigger><SelectContent><SelectItem value=" ">-- Không chọn --</SelectItem>{productLines?.map(l => <SelectItem key={l.id} value={l.id}>{l.name}</SelectItem>)}</SelectContent></Select>
                  </div>
                </CardContent>
              </Card>
              <Card>
                <CardHeader><CardTitle className="text-base">Giá & Trạng thái</CardTitle></CardHeader>
                <CardContent className="space-y-3">
                  <div className="space-y-1.5"><Label>Giá gốc (₫) *</Label><Input type="number" value={basePrice} onChange={(e) => setBasePrice(e.target.value)} /></div>
                  <div className="space-y-1.5"><Label>Giá sale (₫)</Label><Input type="number" value={salePrice} onChange={(e) => setSalePrice(e.target.value)} /></div>
                  <div className="space-y-1.5"><Label>Trạng thái</Label><Select value={status} onValueChange={(v) => setStatus(v ?? "new")}><SelectTrigger><SelectValue /></SelectTrigger><SelectContent><SelectItem value="new">Mới</SelectItem><SelectItem value="active">Đang bán</SelectItem><SelectItem value="inactive">Ngừng bán</SelectItem></SelectContent></Select></div>
                  <div className="flex items-center gap-2"><input type="checkbox" id="is_active" checked={isActive} onChange={(e) => setIsActive(e.target.checked)} className="rounded" /><Label htmlFor="is_active" className="text-sm">Hiển thị trên app</Label></div>
                </CardContent>
              </Card>
            </div>
          </div>
        </TabsContent>

        {/* TAB: Specs — from spec_templates with proper JSONB keys */}
        <TabsContent value="specs">
          {!categoryId ? (
            <Card><CardContent className="py-12 text-center text-muted-foreground">Vui lòng chọn danh mục trước để hiển thị thông số kỹ thuật.</CardContent></Card>
          ) : !specTemplates || specTemplates.length === 0 ? (
            <Card><CardContent className="py-12 text-center text-muted-foreground">Danh mục này chưa có mẫu thông số kỹ thuật.</CardContent></Card>
          ) : (
            <div className="space-y-4">
              {Object.entries(specGroups).map(([groupKey, templates]) => (
                <Card key={groupKey}>
                  <CardHeader><CardTitle className="text-base">{SPEC_GROUP_LABELS[groupKey] || groupKey}</CardTitle></CardHeader>
                  <CardContent><div className="grid gap-3 sm:grid-cols-2">{templates.map(t => (
                    <div key={t.id} className="space-y-1"><Label className="text-sm">{t.display_name} {t.unit && <span className="text-muted-foreground">({t.unit})</span>}</Label><Input value={specsMap[groupKey]?.[t.spec_key] || ""} onChange={(e) => updateSpecValue(groupKey, t.spec_key, e.target.value)} placeholder={`Nhập ${t.display_name.toLowerCase()}`} className="h-8" /></div>
                  ))}</div></CardContent>
                </Card>
              ))}
            </div>
          )}
        </TabsContent>

        {/* TAB: Variants — Required */}
        <TabsContent value="variants">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between">
              <div><CardTitle className="text-base">Biến thể sản phẩm</CardTitle><p className="text-xs text-muted-foreground mt-1">Bắt buộc ít nhất 1 biến thể. Tồn kho được quản lý tại đây.</p></div>
              <Button type="button" variant="outline" size="sm" onClick={addVariant}><Plus className="mr-1 h-4 w-4" />Thêm biến thể</Button>
            </CardHeader>
            <CardContent>
              {variants.length === 0 ? (
                <div className="text-center py-8 border-2 border-dashed rounded-lg border-amber-400/30 bg-amber-400/5">
                  <AlertTriangle className="h-8 w-8 mx-auto text-amber-400 mb-2" /><p className="text-sm font-medium text-amber-400">Chưa có biến thể nào</p><p className="text-xs text-muted-foreground mt-1">Sản phẩm cần ít nhất 1 biến thể</p>
                  <Button type="button" variant="outline" size="sm" className="mt-3" onClick={addVariant}><Plus className="mr-1 h-4 w-4" />Thêm biến thể đầu tiên</Button>
                </div>
              ) : (
                <div className="space-y-3">{variants.map((v, idx) => (
                  <div key={idx} className="flex items-start gap-3 p-3 rounded-lg border bg-card">
                    <GripVertical className="h-4 w-4 mt-2.5 text-muted-foreground shrink-0" />
                    <div className="grid gap-3 sm:grid-cols-6 flex-1">
                      <div className="space-y-1"><Label className="text-xs">Tên màu *</Label><Input value={v.color_name} onChange={(e) => updateVariant(idx, "color_name", e.target.value)} className="h-8" /></div>
                      <div className="space-y-1"><Label className="text-xs">Mã màu</Label><div className="flex gap-1.5 items-center"><input type="color" value={v.color_hex || "#000000"} onChange={(e) => updateVariant(idx, "color_hex", e.target.value)} className="h-8 w-8 rounded cursor-pointer" /><Input value={v.color_hex} onChange={(e) => updateVariant(idx, "color_hex", e.target.value)} className="h-8 flex-1" /></div></div>
                      <div className="space-y-1"><Label className="text-xs">Giá riêng</Label><Input type="number" value={v.price_override} onChange={(e) => updateVariant(idx, "price_override", e.target.value)} className="h-8" /></div>
                      <div className="space-y-1"><Label className="text-xs">Tồn kho *</Label><Input type="number" value={v.stock_quantity} onChange={(e) => updateVariant(idx, "stock_quantity", e.target.value)} className="h-8" /></div>
                      <div className="space-y-1"><Label className="text-xs">SKU</Label><Input value={v.sku} onChange={(e) => updateVariant(idx, "sku", e.target.value)} className="h-8" /></div>
                      <div className="flex items-end"><Button type="button" variant="ghost" size="icon" className="h-8 w-8 text-destructive" onClick={() => setVariants(variants.filter((_, i) => i !== idx))}><Trash2 className="h-4 w-4" /></Button></div>
                    </div>
                  </div>
                ))}</div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        {/* TAB: Images */}
        <TabsContent value="images">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between"><CardTitle className="text-base">Hình ảnh</CardTitle><Button type="button" variant="outline" size="sm" onClick={addImage}><Plus className="mr-1 h-4 w-4" />Thêm ảnh</Button></CardHeader>
            <CardContent>
              {images.length === 0 ? <p className="text-sm text-muted-foreground text-center py-8">Chưa có hình ảnh.</p> : (
                <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">{images.map((img, idx) => (
                  <div key={idx} className="border rounded-lg p-3 space-y-2 bg-card">
                    {img.image_url && <img src={img.image_url} alt={img.alt_text || "preview"} className="w-full h-32 object-contain rounded bg-muted" />}
                    <Input value={img.image_url} onChange={(e) => updateImage(idx, "image_url", e.target.value)} placeholder="URL hình ảnh" className="h-8 text-xs" />
                    <div className="flex items-center justify-between">
                      <label className="flex items-center gap-1.5 text-xs cursor-pointer"><input type="radio" name="primary_img" checked={img.is_primary} onChange={() => updateImage(idx, "is_primary", true)} />Ảnh chính</label>
                      <Button type="button" variant="ghost" size="icon" className="h-6 w-6 text-destructive" onClick={() => setImages(images.filter((_, i) => i !== idx))}><Trash2 className="h-3.5 w-3.5" /></Button>
                    </div>
                  </div>
                ))}</div>
              )}
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </form>
  );
}
