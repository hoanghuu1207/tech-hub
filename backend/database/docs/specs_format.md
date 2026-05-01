# JSONB Specs Format — Tài liệu chuẩn hóa

Tài liệu mô tả format của field `specs` (kiểu JSONB) trong bảng `products`.
Mỗi category có cấu trúc specs khác nhau.

---

## 1. Smartphone & Tablet

```json
{
  "screen": {
    "size_inch": 6.3,
    "resolution": "2556 x 1179",
    "refresh_rate_hz": 120,
    "technology": "Super Retina XDR OLED"
  },
  "camera_rear": {
    "main_mp": 48,
    "ultra_wide_mp": 12,
    "telephoto_mp": 12,
    "optical_zoom": "5x",
    "video": "4K@60fps"
  },
  "camera_front": {
    "resolution_mp": 12,
    "video": "4K@60fps"
  },
  "performance": {
    "chipset": "Apple A18 Pro",
    "cpu": "6-core",
    "gpu": "6-core GPU",
    "ram_gb": 8,
    "storage_gb": 256,
    "os": "iOS 18"
  },
  "battery": {
    "capacity_mah": 4685,
    "usage_hours": 33,
    "fast_charge_w": 30,
    "wireless_charge": true
  },
  "design": {
    "dimensions_mm": "163.0 x 77.6 x 8.25",
    "weight_g": 227,
    "material": "Titan cấp hàng không"
  },
  "connectivity": {
    "ports": ["USB-C 3.0"],
    "wifi": "Wi-Fi 7",
    "bluetooth": "5.3",
    "nfc": true,
    "5g": true
  },
  "special_features": ["Face ID", "MagSafe", "IP68"]
}
```

---

## 2. Laptop

```json
{
  "screen": {
    "size_inch": 14.2,
    "resolution": "3024 x 1964",
    "refresh_rate_hz": 120,
    "technology": "Liquid Retina XDR"
  },
  "webcam": {
    "resolution_mp": 12,
    "features": ["Center Stage"]
  },
  "performance": {
    "chipset": "Apple M4 Pro",
    "cpu": "14-core",
    "gpu": "20-core GPU",
    "ram_gb": 24,
    "storage_gb": 512,
    "os": "macOS Sequoia",
    "ram_type": "Unified Memory"
  },
  "battery": {
    "capacity_wh": 72.4,
    "usage_hours": 24,
    "fast_charge_w": 96
  },
  "design": {
    "dimensions_cm": "31.7 x 22.1 x 1.41",
    "weight_kg": 1.61,
    "material": "Nhôm nguyên khối"
  },
  "connectivity": {
    "ports": ["Thunderbolt 4 x3", "HDMI", "SD Card"],
    "wifi": "Wi-Fi 6E",
    "bluetooth": "5.3"
  },
  "special_features": ["Touch ID", "Force Touch Trackpad"]
}
```

---

## 3. Headphone (Tai nghe)

```json
{
  "battery": {
    "capacity_mah": 400,
    "earbuds_hours": 6,
    "case_hours": 24,
    "total_hours": 30,
    "wireless_charge": true
  },
  "design": {
    "earbuds_dimensions_mm": "30.2 x 18.3 x 18.1",
    "case_dimensions_mm": "46.2 x 50.1 x 21.2",
    "earbuds_weight_g": 5.3,
    "total_weight_g": 50.9,
    "ip_rating": "IP54"
  },
  "connectivity": {
    "ports": ["USB-C"],
    "bluetooth": "5.3"
  },
  "special_features": [
    "Active Noise Cancellation",
    "Transparency Mode",
    "Spatial Audio"
  ]
}
```

---

## 4. Smartwatch

```json
{
  "screen": {
    "size_mm": 45,
    "resolution": "484 x 396",
    "technology": "LTPO OLED"
  },
  "performance": {
    "os": "watchOS 11"
  },
  "battery": {
    "usage_hours": 18,
    "total_hours": 18
  },
  "design": {
    "case_size_mm": "45 x 38 x 10.7",
    "weight_g": 51.5,
    "material": "Nhôm"
  },
  "special_features": [
    "Apple Pay",
    "Emergency SOS",
    "Đo nhịp tim",
    "Chống nước 5 ATM"
  ]
}
```

---

## 5. Accessory (Phụ kiện)

Phụ kiện sử dụng trường `accessory_type` để phân biệt loại.

### Cáp sạc
```json
{
  "accessory_type": "cable",
  "connector_a": "USB-C",
  "connector_b": "Lightning",
  "length_m": 1.0,
  "max_power_w": 60,
  "data_transfer": "USB 2.0",
  "material": "Dù bện"
}
```

### Ốp lưng
```json
{
  "accessory_type": "case",
  "compatible_model": "iPhone 17 Pro",
  "material": "Silicone",
  "magsafe_compatible": true
}
```

### Bàn phím
```json
{
  "accessory_type": "keyboard",
  "layout": "TKL",
  "connectivity": ["USB", "Bluetooth"],
  "backlight": "RGB"
}
```

---

## Quy tắc chung

| Quy tắc | Mô tả |
|---------|--------|
| **Null-safe** | Nếu specs nào không có, bỏ trống key đó thay vì set `null` |
| **Đơn vị** | Đơn vị luôn nằm trong key name (`_gb`, `_inch`, `_mah`, `_mm`...) |
| **Arrays** | Dùng JSON array cho danh sách (ports, features, sensors) |
| **Nested** | Nhóm specs liên quan vào cùng object (screen, battery...) |
| **GIN Index** | Field `specs` đã được index bằng GIN để hỗ trợ query JSONB |
