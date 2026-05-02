"""
Seed Data — Tạo categories, brands và spec_templates ban đầu bằng Python ORM.

Sử dụng:
    docker-compose run --rm -e PYTHONPATH=/app backend python database/seed_data.py
"""

import asyncio
import logging
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

from app.core.config import settings
from app.models.product import Category, Brand, SpecTemplate

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("seeder")


async def seed():
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        # ── Kiểm tra xem đã seed chưa ──
        result = await session.execute(select(Category).limit(1))
        if result.scalar_one_or_none():
            logger.info("⚠️  Dữ liệu categories đã tồn tại, bỏ qua seed.")
            await engine.dispose()
            return

        logger.info("🌱 Bắt đầu seed data...")

        # ════════════════════════════════════════
        # CATEGORIES
        # ════════════════════════════════════════
        categories = {}

        # Parent categories
        parent_cats = [
            ("Điện thoại", "smartphone", "Điện thoại thông minh", 1),
            ("Laptop", "laptop", "Máy tính xách tay", 2),
            ("Máy tính bảng", "tablet", "Máy tính bảng", 3),
            ("Tai nghe", "headphone", "Tai nghe các loại", 4),
            ("Đồng hồ thông minh", "smartwatch", "Đồng hồ thông minh", 5),
            ("Phụ kiện", "accessory", "Phụ kiện công nghệ", 6),
        ]
        for name, slug, desc, order in parent_cats:
            cat = Category(id=uuid.uuid4(), name=name, slug=slug, description=desc, sort_order=order)
            session.add(cat)
            categories[slug] = cat

        await session.flush()

        # Sub categories
        sub_cats = [
            ("iPhone", "iphone", "smartphone", 1),
            ("Android Phone", "android-phone", "smartphone", 2),
            ("MacBook", "macbook", "laptop", 1),
            ("Windows Laptop", "windows-laptop", "laptop", 2),
            ("TWS", "tws", "headphone", 1),
            ("Over-Ear", "over-ear", "headphone", 2),
            ("Cáp sạc", "cable", "accessory", 1),
            ("Ốp lưng", "case", "accessory", 2),
            ("Sạc", "charger", "accessory", 3),
            ("Bàn phím", "keyboard", "accessory", 4),
        ]
        for name, slug, parent_slug, order in sub_cats:
            cat = Category(
                id=uuid.uuid4(),
                name=name,
                slug=slug,
                parent_id=categories[parent_slug].id,
                sort_order=order,
            )
            session.add(cat)
            categories[slug] = cat

        await session.flush()
        logger.info(f"  ✅ Tạo {len(categories)} categories")

        # ════════════════════════════════════════
        # BRANDS
        # ════════════════════════════════════════
        brand_list = [
            ("Apple", "apple", "Mỹ"),
            ("Samsung", "samsung", "Hàn Quốc"),
            ("Xiaomi", "xiaomi", "Trung Quốc"),
            ("OPPO", "oppo", "Trung Quốc"),
            ("Vivo", "vivo", "Trung Quốc"),
            ("Dell", "dell", "Mỹ"),
            ("HP", "hp", "Mỹ"),
            ("ASUS", "asus", "Đài Loan"),
            ("Lenovo", "lenovo", "Trung Quốc"),
            ("MSI", "msi", "Đài Loan"),
            ("Sony", "sony", "Nhật Bản"),
            ("JBL", "jbl", "Mỹ"),
            ("Bose", "bose", "Mỹ"),
            ("Garmin", "garmin", "Mỹ"),
            ("Huawei", "huawei", "Trung Quốc"),
            ("Honor", "honor", "Trung Quốc"),
            ("Realme", "realme", "Trung Quốc"),
            ("Coros", "coros", "Mỹ"),
            ("Huami", "huami", "Trung Quốc"),
            ("Kieslect", "kieslect", "Trung Quốc"),
            ("Soundpeats", "soundpeats", "Trung Quốc"),
            ("Black Shark", "black-shark", "Trung Quốc"),
            ("Masstel", "masstel", "Việt Nam"),
            ("SUUNTO", "suunto", "Phần Lan"),
            ("Mibro", "mibro", "Trung Quốc"),
            ("Viettel", "viettel", "Việt Nam"),
            ("Wonlex", "wonlex", "Trung Quốc"),
            ("Marshall", "marshall", "Anh"),
            ("Anker", "anker", "Trung Quốc"),
            ("Havit", "havit", "Trung Quốc"),
            ("Edifier", "edifier", "Trung Quốc"),
            ("Baseus", "baseus", "Trung Quốc"),
            ("Shokz", "shokz", "Mỹ"),
            ("Sennheiser", "sennheiser", "Đức"),
            ("Hyperx", "hyperx", "Mỹ"),
            ("Logitech", "logitech", "Thụy Sĩ"),
            ("Aukey", "aukey", "Trung Quốc"),
            ("Beats", "beats", "Mỹ"),
            ("Nothing", "nothing", "Anh"),
            ("QCY", "qcy", "Trung Quốc"),
            ("Ugreen", "ugreen", "Trung Quốc"),
            ("Tronsmart", "tronsmart", "Trung Quốc"),
            ("AKG", "akg", "Áo"),
            ("Bowers & Wilkins", "bowers-wilkins", "Anh"),
            ("Nakamichi", "nakamichi", "Nhật Bản"),
        ]
        for name, slug, country in brand_list:
            session.add(Brand(id=uuid.uuid4(), name=name, slug=slug, country=country))

        await session.flush()
        logger.info(f"  ✅ Tạo {len(brand_list)} brands")

        # ════════════════════════════════════════
        # SPEC TEMPLATES
        # ════════════════════════════════════════
        spec_count = 0

        # -- smartphone --
        smartphone_specs = [
            ("screen_size_inch", "Kích thước màn hình", "number", "inch", "Màn hình", True, 1),
            ("screen_resolution", "Độ phân giải", "text", None, "Màn hình", False, 2),
            ("screen_refresh_rate", "Tần số quét", "number", "Hz", "Màn hình", True, 3),
            ("chipset", "Chipset", "text", None, "Hiệu năng", True, 4),
            ("ram_gb", "RAM", "number", "GB", "Hiệu năng", True, 5),
            ("storage_gb", "Bộ nhớ trong", "number", "GB", "Hiệu năng", True, 6),
            ("os", "Hệ điều hành", "text", None, "Hiệu năng", True, 7),
            ("camera_main_mp", "Camera chính", "number", "MP", "Camera", True, 8),
            ("camera_front_mp", "Camera selfie", "number", "MP", "Camera", False, 9),
            ("battery_mah", "Dung lượng pin", "number", "mAh", "Pin & Sạc", True, 10),
            ("fast_charge_w", "Sạc nhanh", "number", "W", "Pin & Sạc", True, 11),
            ("weight_g", "Trọng lượng", "number", "g", "Thiết kế", False, 12),
            ("5g", "Hỗ trợ 5G", "boolean", None, "Kết nối", True, 13),
        ]
        for key, display, dtype, unit, group, filterable, order in smartphone_specs:
            session.add(SpecTemplate(
                id=uuid.uuid4(), category_id=categories["smartphone"].id,
                spec_key=key, display_name=display, data_type=dtype,
                unit=unit, spec_group=group, is_filterable=filterable, sort_order=order,
            ))
            spec_count += 1

        # -- laptop --
        laptop_specs = [
            ("screen_size_inch", "Kích thước màn hình", "number", "inch", "Màn hình", True, 1),
            ("screen_resolution", "Độ phân giải", "text", None, "Màn hình", False, 2),
            ("chipset", "Chipset", "text", None, "Hiệu năng", True, 3),
            ("ram_gb", "RAM", "number", "GB", "Hiệu năng", True, 4),
            ("storage_gb", "Ổ cứng", "number", "GB", "Hiệu năng", True, 5),
            ("os", "Hệ điều hành", "text", None, "Hiệu năng", True, 6),
            ("battery_hours", "Thời lượng pin", "number", "giờ", "Pin & Sạc", True, 7),
            ("weight_kg", "Trọng lượng", "number", "kg", "Thiết kế", False, 8),
        ]
        for key, display, dtype, unit, group, filterable, order in laptop_specs:
            session.add(SpecTemplate(
                id=uuid.uuid4(), category_id=categories["laptop"].id,
                spec_key=key, display_name=display, data_type=dtype,
                unit=unit, spec_group=group, is_filterable=filterable, sort_order=order,
            ))
            spec_count += 1

        # -- tablet --
        tablet_specs = [
            ("screen_size_inch", "Kích thước màn hình", "number", "inch", "Màn hình", True, 1),
            ("chipset", "Chipset", "text", None, "Hiệu năng", True, 2),
            ("ram_gb", "RAM", "number", "GB", "Hiệu năng", True, 3),
            ("storage_gb", "Bộ nhớ trong", "number", "GB", "Hiệu năng", True, 4),
            ("os", "Hệ điều hành", "text", None, "Hiệu năng", True, 5),
            ("camera_main_mp", "Camera chính", "number", "MP", "Camera", False, 6),
            ("battery_mah", "Dung lượng pin", "number", "mAh", "Pin & Sạc", True, 7),
        ]
        for key, display, dtype, unit, group, filterable, order in tablet_specs:
            session.add(SpecTemplate(
                id=uuid.uuid4(), category_id=categories["tablet"].id,
                spec_key=key, display_name=display, data_type=dtype,
                unit=unit, spec_group=group, is_filterable=filterable, sort_order=order,
            ))
            spec_count += 1

        # -- headphone --
        headphone_specs = [
            ("headphone_type", "Loại tai nghe", "text", None, "Thông tin", True, 1),
            ("battery_total_hours", "Thời lượng pin tổng", "number", "giờ", "Pin & Sạc", True, 2),
            ("bluetooth_version", "Phiên bản Bluetooth", "text", None, "Kết nối", False, 3),
            ("anc", "Chống ồn ANC", "boolean", None, "Tính năng", True, 4),
            ("ip_rating", "Chống nước", "text", None, "Thiết kế", True, 5),
        ]
        for key, display, dtype, unit, group, filterable, order in headphone_specs:
            session.add(SpecTemplate(
                id=uuid.uuid4(), category_id=categories["headphone"].id,
                spec_key=key, display_name=display, data_type=dtype,
                unit=unit, spec_group=group, is_filterable=filterable, sort_order=order,
            ))
            spec_count += 1

        # -- smartwatch --
        smartwatch_specs = [
            ("screen_size_mm", "Kích thước mặt", "number", "mm", "Màn hình", True, 1),
            ("os", "Hệ điều hành", "text", None, "Hiệu năng", True, 2),
            ("battery_hours", "Thời lượng pin", "number", "giờ", "Pin & Sạc", True, 3),
            ("ip_rating", "Chống nước", "text", None, "Thiết kế", True, 4),
            ("weight_g", "Trọng lượng", "number", "g", "Thiết kế", False, 5),
        ]
        for key, display, dtype, unit, group, filterable, order in smartwatch_specs:
            session.add(SpecTemplate(
                id=uuid.uuid4(), category_id=categories["smartwatch"].id,
                spec_key=key, display_name=display, data_type=dtype,
                unit=unit, spec_group=group, is_filterable=filterable, sort_order=order,
            ))
            spec_count += 1

        # -- accessory --
        accessory_specs = [
            ("accessory_type", "Loại phụ kiện", "text", None, "Thông tin", True, 1),
            ("compatible_model", "Tương thích với", "text", None, "Thông tin", True, 2),
            ("material", "Chất liệu", "text", None, "Thiết kế", False, 3),
        ]
        for key, display, dtype, unit, group, filterable, order in accessory_specs:
            session.add(SpecTemplate(
                id=uuid.uuid4(), category_id=categories["accessory"].id,
                spec_key=key, display_name=display, data_type=dtype,
                unit=unit, spec_group=group, is_filterable=filterable, sort_order=order,
            ))
            spec_count += 1

        await session.commit()
        logger.info(f"  ✅ Tạo {spec_count} spec_templates")

    logger.info("🎉 Seed data hoàn tất!")
    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(seed())
