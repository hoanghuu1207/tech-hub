# transformers/specs_normalizer.py
import re

def normalize_specs(raw_specs: dict, category: str) -> dict:
    """
    Chuyển dict thô từ bảng HTML (key tiếng Việt, value string)
    thành JSONB chuẩn theo category.
    """

    def extract_number(s: str) -> float | None:
        m = re.search(r'[\d,.]+', str(s))
        if m:
            return float(m.group().replace(',', '.'))
        return None

    def extract_list(s: str) -> list[str]:
        return [x.strip() for x in re.split(r'[,\n/]', str(s))
                if x.strip()]

    # Map key tiếng Việt → key chuẩn
    KEY_MAP = {
        # Screen
        # "Màn hình":           "screen.technology",
        "Kích thước màn hình":"screen.size_inch",
        "Độ phân giải":       "screen.resolution",
        "Tần số quét":        "screen.refresh_rate_hz",
        # Performance
        "Chip":               "performance.chipset",
        "Chipset":            "performance.chipset",
        "CPU":                "performance.cpu",
        "GPU":                "performance.gpu",
        "Dung lượng RAM":                "performance.ram_gb",
        "Bộ nhớ trong":       "performance.storage_gb",
        "Ổ cứng":             "performance.storage_gb",
        "Hệ điều hành":       "performance.os",
        # Camera
        "Camera sau":         "camera_rear.raw",
        "Camera trước":       "camera_front.raw",
        "Webcam":             "webcam.raw",
        # Battery
        "Pin":                "battery.raw",
        "Dung lượng pin":     "battery.raw",
        "Thời lượng pin":     "battery.raw",
        # Design
        "Kích thước":         "design.dimensions_raw",
        "Trọng lượng":        "design.weight_raw",
        "Chất liệu":          "design.material",
        "Màu sắc":            "design.colors_raw",
        # Connectivity
        # "Cổng kết nối":       "connectivity.ports_raw",
        "Bluetooth":          "connectivity.bluetooth",
        "Wi-Fi":              "connectivity.wifi",
        # "NFC":                "connectivity.nfc",
        "Tính năng đặc biệt": "special_features_raw",
    }

    # ── Bước 1: Map keys ──────────────────────────────────
    mapped = {}
    for vn_key, value in raw_specs.items():
        for pattern, std_key in KEY_MAP.items():
            if pattern.lower() in vn_key.lower():
                mapped[std_key] = value
                break
        else:
            # Giữ lại key gốc nếu không map được
            mapped[f"_raw.{vn_key}"] = value

    # ── Bước 2: Parse từng field theo category ─────────────
    result = {}

    if category in ("smartphone", "tablet"):
        result = _parse_phone_specs(mapped)
    elif category == "laptop":
        result = _parse_laptop_specs(mapped)
    elif category == "headphone":
        result = _parse_headphone_specs(mapped)
    elif category == "smartwatch":
        result = _parse_watch_specs(mapped)
    else:
        # accessory và các category khác: giữ raw
        result = {"raw": mapped}

    return result


def _parse_phone_specs(m: dict) -> dict:
    def num(key):
        return _extract_num(m.get(key, ""))

    return {
        "screen": {
            "size_inch":       _parse_screen_size(m.get("screen.size_inch","")),
            "resolution":      m.get("screen.resolution"),
            "refresh_rate_hz": _parse_refresh(m.get("screen.refresh_rate_hz","")),
            # "technology":      m.get("screen.technology"),
        },
        "camera_rear":  _parse_camera(m.get("camera_rear.raw", "")),
        "camera_front": _parse_camera_front(m.get("camera_front.raw", "")),
        "performance": {
            "chipset":     m.get("performance.chipset"),
            "cpu":         m.get("performance.cpu"),
            "gpu":         m.get("performance.gpu"),
            "ram_gb":      _parse_storage(m.get("performance.ram_gb", "")),
            "storage_gb":  _parse_storage(m.get("performance.storage_gb", "")),
            "os":          m.get("performance.os"),
        },
        "battery":      _parse_battery(m.get("battery.raw", "")),
        "design": {
            "dimensions_mm": m.get("design.dimensions_raw"),
            "weight_g":      _parse_weight(m.get("design.weight_raw", "")),
            "material":      m.get("design.material"),
        },
        "connectivity": _parse_connectivity(m),
        "special_features": _parse_features(
            m.get("special_features_raw", "")
        ),
    }


def _parse_laptop_specs(m: dict) -> dict:
    return {
        "screen": {
            "size_inch":       _parse_screen_size(m.get("screen.size_inch","")),
            "resolution":      m.get("screen.resolution"),
            "refresh_rate_hz": _parse_refresh(m.get("screen.refresh_rate_hz","")),
            "technology":      m.get("screen.technology"),
        },
        "webcam":  _parse_webcam(m.get("webcam.raw", "")),
        "performance": {
            "chipset":    m.get("performance.chipset"),
            "cpu":        m.get("performance.cpu"),
            "gpu":        m.get("performance.gpu"),
            "ram_gb":     _parse_storage(m.get("performance.ram_gb", "")),
            "storage_gb": _parse_storage(m.get("performance.storage_gb", "")),
            "os":         m.get("performance.os"),
        },
        "battery":  _parse_battery(m.get("battery.raw", "")),
        "design": {
            "dimensions_cm": m.get("design.dimensions_raw"),
            "weight_kg":     _parse_weight_kg(m.get("design.weight_raw", "")),
            "material":      m.get("design.material"),
        },
        "connectivity":    _parse_connectivity(m),
        "special_features": _parse_features(
            m.get("special_features_raw", "")
        ),
    }


def _parse_headphone_specs(m: dict) -> dict:
    raw_dim = m.get("design.dimensions_raw", "")
    dims    = _parse_headphone_dimensions(raw_dim)
    return {
        "battery": _parse_headphone_battery(m.get("battery.raw", "")),
        "design":  dims,
        "connectivity": _parse_connectivity(m),
        "special_features": _parse_features(
            m.get("special_features_raw", "")
        ),
    }


def _parse_watch_specs(m: dict) -> dict:
    return {
        "screen": {
            "size_mm":    _extract_num(m.get("screen.size_inch", "")),
            "resolution": m.get("screen.resolution"),
            "technology": m.get("screen.technology"),
        },
        "performance": {
            "os":         m.get("performance.os"),
        },
        "battery": _parse_headphone_battery(m.get("battery.raw", "")),
        "design": {
            "case_size_mm": m.get("design.dimensions_raw"),
            "weight_g":     _parse_weight(m.get("design.weight_raw", "")),
            "material":     m.get("design.material"),
        },
        "special_features": _parse_features(
            m.get("special_features_raw", "")
        ),
    }


# ── Utility parsers ────────────────────────────────────────────────────────

def _extract_num(s: str) -> float | None:
    m = re.search(r'[\d]+[,.]?[\d]*', str(s))
    return float(m.group().replace(',', '.')) if m else None

def _parse_screen_size(s: str) -> float | None:
    m = re.search(r'(\d+[.,]\d+|\d+)\s*(?:inch|")', str(s), re.IGNORECASE)
    if m: return float(m.group(1).replace(',', '.'))
    return _extract_num(s)

def _parse_refresh(s: str) -> int | None:
    m = re.search(r'(\d+)\s*Hz', str(s), re.IGNORECASE)
    return int(m.group(1)) if m else None

def _parse_storage(s: str) -> int | None:
    # "8 GB RAM" → 8,  "512GB" → 512, "1TB" → 1024
    m = re.search(r'(\d+)\s*(GB|TB)', str(s), re.IGNORECASE)
    if m:
        val = int(m.group(1))
        if m.group(2).upper() == 'TB': val *= 1024
        return val
    return None

def _parse_weight(s: str) -> float | None:
    # "227 g" or "227g"
    m = re.search(r'(\d+[.,]?\d*)\s*g', str(s), re.IGNORECASE)
    return float(m.group(1).replace(',', '.')) if m else None

def _parse_weight_kg(s: str) -> float | None:
    m = re.search(r'(\d+[.,]\d+)\s*kg', str(s), re.IGNORECASE)
    if m: return float(m.group(1).replace(',', '.'))
    g = _parse_weight(s)
    return round(g / 1000, 3) if g else None

def _parse_camera(s: str) -> dict:
    result = {}
    mp = re.findall(r'(\d+)\s*MP', str(s), re.IGNORECASE)
    if mp: result["main_mp"] = int(mp[0])
    zoom = re.search(r'(\d+)x\s*(?:zoom|optical)', str(s), re.IGNORECASE)
    if zoom: result["optical_zoom"] = f"{zoom.group(1)}x"
    return result

def _parse_camera_front(s: str) -> dict:
    mp = re.findall(r'(\d+)\s*MP', str(s), re.IGNORECASE)
    return {"resolution_mp": int(mp[0])} if mp else {}

def _parse_webcam(s: str) -> dict:
    mp = re.findall(r'(\d+)\s*MP', str(s), re.IGNORECASE)
    return {"resolution_mp": int(mp[0])} if mp else {"raw": s}

def _parse_battery(s: str) -> dict:
    result = {}
    mah = re.search(r'(\d+)\s*mAh', str(s), re.IGNORECASE)
    if mah: result["capacity_mah"] = int(mah.group(1))
    wh = re.search(r'(\d+[.,]\d*)\s*Wh', str(s), re.IGNORECASE)
    if wh: result["capacity_wh"] = float(wh.group(1).replace(',', '.'))
    hours = re.search(r'(\d+)\s*giờ', str(s))
    if hours: result["usage_hours"] = int(hours.group(1))
    return result

def _parse_headphone_battery(s: str) -> dict:
    result = _parse_battery(s)
    # "6 giờ (tai nghe) + 24 giờ (hộp)"
    buds  = re.search(r'(\d+)\s*giờ.{0,20}(?:tai nghe|buds)', s, re.I)
    case  = re.search(r'(\d+)\s*giờ.{0,20}(?:hộp|case)', s, re.I)
    if buds: result["earbuds_hours"] = int(buds.group(1))
    if case: result["case_hours"]    = int(case.group(1))
    return result

def _parse_headphone_dimensions(s: str) -> dict:
    # Tìm 2 bộ kích thước: tai nghe và hộp sạc
    dims = re.findall(r'[\d.]+\s*x\s*[\d.]+\s*x\s*[\d.]+\s*mm', s, re.I)
    result = {}
    if len(dims) >= 1: result["earbuds_dimensions_mm"] = dims[0].strip()
    if len(dims) >= 2: result["case_dimensions_mm"]    = dims[1].strip()
    weights = re.findall(r'([\d.]+)\s*g', s)
    if len(weights) >= 1: result["earbuds_weight_g"] = float(weights[0])
    if len(weights) >= 2: result["total_weight_g"]   = float(weights[1])
    return result

def _parse_connectivity(m: dict) -> dict:
    # ports_raw = m.get("connectivity.ports_raw", "")
    return {
        # "ports":     [p.strip() for p in re.split(r'[,\n]', ports_raw)
        #               if p.strip()] if ports_raw else [],
        "bluetooth": m.get("connectivity.bluetooth"),
        "wifi":      m.get("connectivity.wifi"),
        # "nfc":       "NFC" in str(m.get("connectivity.nfc", "")),
    }

def _parse_features(s: str) -> list[str]:
    if not s: return []
    return [f.strip() for f in re.split(r'[,\n]', str(s)) if f.strip()]