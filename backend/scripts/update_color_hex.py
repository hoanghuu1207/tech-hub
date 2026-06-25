"""
Script: Cập nhật color_hex cho bảng product_variants dựa trên color_name.

Cách chạy (trong Docker):
    docker exec techshop_backend python scripts/update_color_hex.py
"""

import asyncio
import os
import sys

# Thêm project root vào sys.path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import text
from app.db.session import SessionLocal

# ──────────────────────────────────────────────────────────
# Bảng ánh xạ color_name -> color_hex
# ──────────────────────────────────────────────────────────

COLOR_MAP = {
    # === ĐEN ===
    "Đen": "#1A1A1A",
    "Đen bóng": "#0A0A0A",
    "Đen bóng - Dây đen": "#0A0A0A",
    "Đen nhám": "#2C2C2C",
    "Đen huyền": "#0D0D0D",
    "Đen than": "#1C1C1C",
    "Đen titan": "#2A2A2E",
    "Đen trong suốt": "#1A1A1A",
    "Đen tuyền": "#0B0B0B",
    "Đen Bóng Đêm": "#0E0E1A",
    "Đen Không Gian": "#111122",
    "Đen Classic": "#1A1A1A",
    "Đen Đồng": "#2E2015",
    "Đen - 46mm": "#1A1A1A",
    "Đen - Chỉ có tại CPS": "#1A1A1A",
    "Đen/Trắng": "#1A1A1A",
    "Đen/Tím": "#1A1A2E",
    "Đen/Vàng": "#1A1A1A",
    "Đen/Đỏ": "#1A1A1A",

    # === TRẮNG ===
    "Trắng": "#F5F5F5",
    "Trắng (kèm tay cầm chơi game)": "#F5F5F5",
    "Trắng (độc quyền)": "#F5F5F5",
    "Trắng - 41mm": "#F5F5F5",
    "Trắng - Chỉ có tại CPS": "#F5F5F5",
    "Trắng Classic": "#F5F5F5",
    "Trắng Mây": "#F0EDE8",
    "Trắng Xanh": "#E8F0F0",
    "Trắng be": "#F5F0E8",
    "Trắng ngà": "#FAEBD7",
    "Trắng trong suốt": "#F5F5F5",
    "Trắng tím": "#F0E8F5",
    "Trắng vàng": "#FFF8E7",
    "Trắng Ánh Trăng": "#F5F3EE",
    "Trắng đen": "#E8E8E8",
    "Trắng/Vàng": "#F5F5F5",
    "Trắng/bạc": "#F0F0F0",
    "Canvas White": "#F5F0E8",

    # === XÁM ===
    "Xám": "#808080",
    "Xám (Camo)": "#6B6B5E",
    "Xám (Độc quyền)": "#808080",
    "Xám - 46mm": "#808080",
    "Xám Carbon": "#555555",
    "Xám Titan": "#8A8A8E",
    "Xám Trắng": "#B0B0B0",
    "Xám bóng": "#707070",
    "Xám bạc": "#A0A0A8",
    "Xám khói": "#6E6E6E",
    "Xám không gian": "#4A4A50",
    "Xám không gian - Dây đen": "#4A4A50",
    "Xám sương mờ": "#B8B8C0",
    "Xám ánh trăng": "#A0A0AA",
    "Xám đen": "#3A3A3A",
    "Xám đá phiến": "#5A5A60",
    "Xám/Bạc": "#909098",
    "Xám/Vàng": "#808080",
    "Xám/Xanh": "#708090",
    "Ghi": "#7A7A7A",
    "Vải Xám": "#8C8C8C",

    # === BẠC ===
    "Bạc": "#C0C0C0",
    "Bạc - Dây tím": "#C0C0C0",
    "Bạc/Đen": "#C0C0C0",

    # === XANH DƯƠNG / XANH LAM ===
    "Xanh": "#2196F3",
    "Xanh Da Trời": "#87CEEB",
    "Xanh Sky Blue": "#87CEEB",
    "Xanh da trời": "#87CEEB",
    "Xanh dương": "#1E88E5",
    "Xanh dương nhạt": "#64B5F6",
    "Xanh dương đậm": "#0D47A1",
    "Xanh lam": "#1976D2",
    "Xanh Lam Khói": "#4A6680",
    "Xanh biển": "#006994",
    "Xanh Indigo": "#3F51B5",
    "Indigo Blue": "#3F51B5",
    "Xanh Lưu Ly": "#26619C",
    "Xanh navy": "#001F3F",
    "Xanh Đậm": "#0A3055",
    "Xanh đậm": "#0A3055",
    "Xanh Đen": "#102030",
    "Xanh Đại Dương": "#006BA6",
    "Xanh bóng": "#1565C0",
    "Xanh bóng đêm": "#0D1B2A",
    "Xanh băng": "#A5D8E6",
    "Xanh chạng vạng": "#1A3050",
    "Xanh nhạt": "#90CAF9",
    "Xanh sáng": "#42A5F5",
    "Xanh tím": "#5C6BC0",
    "Xanh ánh trăng": "#3A5070",
    "Xanh đá": "#4A6A8A",
    "Xanh/Trắng": "#2196F3",
    "Xanh/xám": "#5080A0",

    # === XANH LÁ / XANH LỤC ===
    "Xanh lá": "#4CAF50",
    "Xanh Lá Xô Thơm": "#6B8E23",
    "Xanh Lục": "#2E7D32",
    "Xanh lục bảo": "#50C878",
    "Xanh Rêu": "#556B2F",
    "Xanh forest": "#228B22",
    "Xanh quân đội": "#4B5320",

    # === XANH NGỌC / XANH MINT ===
    "Xanh ngọc": "#00BFA5",
    "Xanh ngọc bích": "#00897B",
    "Xanh bạc hà": "#98FF98",
    "Xanh mint": "#98FF98",
    "Xanh Mòng Két": "#009688",
    "Xanh nhiệt đới": "#00BCD4",
    "Ngọc Lam": "#40E0D0",

    # === VÀNG ===
    "Vàng": "#FFD700",
    "Vàng (Chỉ có tại CPS)": "#FFD700",
    "Vàng Be": "#D4B896",
    "Vàng Beige": "#D4B896",
    "Vàng Bình Minh": "#FFCC33",
    "Vàng Citrus": "#E8D44D",
    "Vàng Hồng": "#E8B4B8",
    "Vàng Hồng - Dây hồng": "#E8B4B8",
    "Vàng Nhạt": "#FFECB3",
    "Vàng Trắng": "#FFF5CC",
    "Vàng chanh": "#FFF44F",
    "Vàng cát": "#C2B280",
    "Vàng gold": "#FFD700",
    "Vàng kem": "#FFF8DC",
    "Vàng sa mạc": "#C49B5F",
    "Vàng ánh kim": "#D4AF37",
    "Vàng Đồng": "#B8860B",
    "Vàng/Xám": "#D4AF37",
    "Gold": "#FFD700",
    "Gold Edition": "#D4AF37",

    # === ĐỎ ===
    "Đỏ": "#E53935",
    "Đỏ mận": "#8E4585",
    "Đỏ san hô": "#FF6F61",
    "Đỏ/Trắng": "#E53935",

    # === HỒNG ===
    "Hồng": "#FF69B4",
    "Hồng Cam Đào": "#FFAB91",
    "Hồng Khói": "#C9A0A0",
    "Hồng Phớt": "#FFB6C1",
    "Hồng be": "#E8C8B8",
    "Hồng khói": "#C9A0A0",

    # === TÍM ===
    "Tím": "#9C27B0",
    "Tím - 41mm": "#9C27B0",
    "Tím Bóng Đêm": "#4A148C",
    "Tím Cobalt": "#6A5ACD",
    "Tím Oải Hương": "#9370DB",
    "Tím bạc": "#B8A9C9",
    "Tím xanh": "#7B68EE",

    # === CAM ===
    "Cam": "#FF6D00",
    "Cam Vũ Trụ": "#FF5722",

    # === NÂU ===
    "Nâu": "#795548",
    "Nâu Cát Trắng": "#C4A882",
    "Nâu Đồng": "#8B6914",
    "Nâu đỏ": "#8B4513",
    "Nâu - 41mm": "#795548",

    # === KEM / BE ===
    "Kem": "#FFFDD0",
    "Be": "#F5F5DC",
    "Beige": "#F5F5DC",
    "Latte": "#C8A882",

    # === TITAN ===
    "Titan": "#878681",
    "Titan Sa Mạc": "#B5A68C",
    "Titan Trắng": "#E3E3DD",
    "Titan Tự Nhiên": "#A09A8D",
    "Titan Tự Nhiên - Dây tự nhiên": "#A09A8D",
    "Titan Tự Nhiên - Dây xanh": "#A09A8D",
    "Titan Tự Nhiên - Dây xám": "#A09A8D",
    "Titan Vàng - Dây hồng": "#C8B890",
    "Titan Vàng - Dây vàng": "#C8B890",
    "Titan Xanh": "#394D60",
    "Titan Đen": "#3A3A3E",
    "Titan Đen - Dây đen": "#3A3A3E",

    # === KÍCH THƯỚC + MÀU ===
    "41mm Nâu": "#795548",
    "41mm Trắng": "#F5F5F5",
    "41mm Xanh": "#2196F3",
    "41mm bạc": "#C0C0C0",
    "46mm Nâu": "#795548",
    "46mm Xanh": "#2196F3",
    "46mm xanh lá": "#4CAF50",
    "46mm xám": "#808080",
    "46mm đen": "#1A1A1A",

    # === ĐẶC BIỆT ===
    "Anthracite Black": "#383838",
    "Copper Edition": "#B87333",
    "Denim": "#4A6FA5",
    "Sa thạch": "#C2B280",
    "Trong suốt": "#E8E8E8",
    "Cầu vồng": "#FF6B6B",
    "Kim cương": "#B9F2FF",
    "Ánh sao": "#E8DCC8",
    "Ánh sao - Dây trắng": "#E8DCC8",

    # === PHIÊN BẢN ĐẶC BIỆT ===
    "Phiên bản Hà Nội": "#C41E3A",
    "Phiên bản Sài Gòn": "#2196F3",
    "Phiên bản sấm sét - Lightning": "#FFD700",
    "Phiên bản điện quang - Tronics": "#00BCD4",

    # === MÀU DỰ KIẾN ===
    "Màu dự kiến 1": "#808080",
    "Màu dự kiến 2": "#A0A0A0",
    "Màu dự kiến 3": "#606060",

    # === MÀU KHÁC ===
    "Màu mận": "#8E4585",
    "Đêm xanh thẳm": "#0D1B3E",
    "Đêm xanh thẳm - Dây đen": "#0D1B3E",
}


async def main():
    print("🔌 Kết nối database...")

    async with SessionLocal() as session:
        # 1. Lấy danh sách color_name cần cập nhật
        result = await session.execute(text("""
            SELECT DISTINCT color_name
            FROM product_variants
            WHERE color_hex IS NULL
            ORDER BY color_name
        """))
        color_names = [row[0] for row in result.fetchall()]
        print(f"📋 Tìm thấy {len(color_names)} color_name chưa có color_hex")

        # 2. Kiểm tra color_name chưa được map
        unmapped = [name for name in color_names if name not in COLOR_MAP]
        if unmapped:
            print(f"\n⚠️  Có {len(unmapped)} color_name chưa được ánh xạ:")
            for name in unmapped:
                print(f"   - '{name}'")
            print()

        # 3. Cập nhật color_hex cho từng color_name
        updated_count = 0
        for color_name in color_names:
            hex_code = COLOR_MAP.get(color_name)
            if hex_code:
                result = await session.execute(
                    text("""
                        UPDATE product_variants
                        SET color_hex = :hex
                        WHERE color_name = :name AND color_hex IS NULL
                    """),
                    {"hex": hex_code, "name": color_name}
                )
                count = result.rowcount
                updated_count += count
                print(f"  ✅ '{color_name}' → {hex_code} ({count} rows)")
            else:
                print(f"  ❌ '{color_name}' → SKIPPED (chưa có mapping)")

        # 4. Commit
        await session.commit()
        print(f"\n🎉 Hoàn tất! Đã cập nhật {updated_count} bản ghi.")

        # 5. Kiểm tra kết quả
        result = await session.execute(text("""
            SELECT COUNT(*) as total,
                   COUNT(color_hex) as has_hex,
                   COUNT(*) - COUNT(color_hex) as missing_hex
            FROM product_variants
        """))
        row = result.fetchone()
        print(f"📊 Tổng: {row[0]} | Có hex: {row[1]} | Thiếu hex: {row[2]}")


if __name__ == "__main__":
    asyncio.run(main())
