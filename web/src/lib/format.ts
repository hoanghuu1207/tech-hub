/**
 * Format số tiền VND.
 * 12500000 → "12.500.000 ₫"
 */
export function formatCurrency(amount: number): string {
  return new Intl.NumberFormat("vi-VN", {
    style: "currency",
    currency: "VND",
    maximumFractionDigits: 0,
  }).format(amount);
}

/**
 * Format số gọn.
 * 1500 → "1.5K", 1500000 → "1.5M"
 */
export function formatCompact(value: number): string {
  if (value >= 1_000_000_000) return `${(value / 1_000_000_000).toFixed(1)}B`;
  if (value >= 1_000_000) return `${(value / 1_000_000).toFixed(1)}M`;
  if (value >= 1_000) return `${(value / 1_000).toFixed(1)}K`;
  return value.toString();
}

/**
 * Format date ngắn: "2025-06-11" → "11/06"
 */
export function formatShortDate(dateStr: string): string {
  if (!dateStr) return "";
  const parts = dateStr.split("-");
  if (parts.length === 3) {
    return `${parts[2]}/${parts[1]}`;
  }
  return dateStr;
}

/**
 * Format datetime đầy đủ: ISO → "11/06/2025 14:30"
 */
export function formatDateTime(isoStr: string | null): string {
  if (!isoStr) return "—";
  try {
    const date = new Date(isoStr);
    return new Intl.DateTimeFormat("vi-VN", {
      day: "2-digit",
      month: "2-digit",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    }).format(date);
  } catch {
    return isoStr;
  }
}

/**
 * Format relative time: "2 giờ trước", "3 ngày trước"
 */
export function formatRelativeTime(isoStr: string | null): string {
  if (!isoStr) return "—";
  try {
    const date = new Date(isoStr);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMin = Math.floor(diffMs / 60000);
    const diffHour = Math.floor(diffMs / 3600000);
    const diffDay = Math.floor(diffMs / 86400000);

    if (diffMin < 1) return "Vừa xong";
    if (diffMin < 60) return `${diffMin} phút trước`;
    if (diffHour < 24) return `${diffHour} giờ trước`;
    if (diffDay < 30) return `${diffDay} ngày trước`;
    return formatDateTime(isoStr);
  } catch {
    return isoStr;
  }
}
