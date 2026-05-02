"""
Import Products — Đọc dữ liệu JSON từ thư mục crawl và import vào PostgreSQL + Qdrant Cloud.

Sử dụng:
    docker-compose run --rm -e PYTHONPATH=/app backend python database/import_products.py

Hoặc chỉ import PostgreSQL (bỏ qua Qdrant/OpenAI):
    docker-compose run --rm -e PYTHONPATH=/app backend python database/import_products.py --skip-qdrant
"""

import asyncio
import json
import glob
import os
import re
import sys
import logging
import uuid
import argparse
from pathlib import Path
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

# ── App imports ──
from app.core.config import settings
from app.db.base import Base
from app.models.product import (
    Category, Brand, ProductLine, Product, ProductVariant, ProductImage
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("importer")

# ════════════════════════════════════════════════════════════
# BRAND MAPPING — Chuẩn hóa tên brand từ crawler sang slug DB
# ════════════════════════════════════════════════════════════
BRAND_MAP = {
    # Apple variants
    "điện thoại apple": "apple",
    "mac":              "apple",
    "ipad":             "apple",
    "apple watch":      "apple",
    "apple":            "apple",
    "beats":            "beats",
    # Samsung
    "samsung":          "samsung",
    # Xiaomi
    "xiaomi":           "xiaomi",
    # OPPO
    "oppo":             "oppo",
    # Vivo
    "vivo":             "vivo",
    # Dell
    "dell":             "dell",
    # HP
    "hp":               "hp",
    # ASUS / Asus
    "asus":             "asus",
    "điện thoại asus":  "asus",
    # Lenovo
    "lenovo":           "lenovo",
    # MSI
    "msi":              "msi",
    # Sony
    "sony":             "sony",
    # JBL
    "jbl":              "jbl",
    # Bose
    "bose":             "bose",
    # Garmin
    "garmin":           "garmin",
    # Huawei
    "huawei":           "huawei",
    # Honor
    "honor":            "honor",
    # Realme
    "realme":           "realme",
    # Coros
    "coros":            "coros",
    # Huami
    "huami":            "huami",
    # Kieslect
    "kieslect":         "kieslect",
    # Soundpeats
    "soundpeats":       "soundpeats",
    # Black Shark
    "black shark":      "black-shark",
    # Masstel
    "masstel":          "masstel",
    # SUUNTO
    "suunto":           "suunto",
    # Mibro
    "mibro":            "mibro",
    # Viettel
    "viettel":          "viettel",
    # Wonlex
    "wonlex":           "wonlex",
    # Marshall
    "marshall":         "marshall",
    # Anker
    "anker":            "anker",
    # Havit
    "havit":            "havit",
    # Edifier
    "edifier":          "edifier",
    # Baseus
    "baseus":           "baseus",
    # Shokz
    "shokz":            "shokz",
    # Sennheiser
    "sennheiser":       "sennheiser",
    # Hyperx
    "hyperx":           "hyperx",
    # Logitech
    "logitech":         "logitech",
    # Aukey
    "aukey":            "aukey",
    # Nothing
    "nothing":          "nothing",
    # QCY
    "qcy":              "qcy",
    # Ugreen
    "ugreen":           "ugreen",
    # Tronsmart
    "tronsmart":        "tronsmart",
    # AKG
    "akg":              "akg",
    # Bowers & Wilkins
    "bowers&wilkins":   "bowers-wilkins",
    "bowers&amp;wilkins": "bowers-wilkins",
    # Nakamichi
    "nakamichi":        "nakamichi",
    # ── Brands mới phát hiện từ crawl nhưng chưa có trong seed ──
    "acer":             "acer",
    "alpha works":      "alpha-works",
    "beecube":          "beecube",
    "dareu":            "dareu",
    "devia":            "devia",
    "earfun":           "earfun",
    "goojodoq":         "goojodoq",
    "gigabyte":         "gigabyte",
    "kz":               "kz",
    "lg":               "lg",
    "microsoft surface": "microsoft-surface",
    "nubia":            "nubia",
    "oneodio":          "oneodio",
    "riversong":        "riversong",
    "robot":            "robot",
    "soul":             "soul",
    "stargo":           "stargo",
    "teclast":          "teclast",
    "trusmi":           "trusmi",
    "myalo":            "myalo",
}


def slugify(text: str) -> str:
    """Tạo URL-safe slug từ text tiếng Việt/Unicode."""
    if not text:
        return ""
    text = text.lower().strip()
    # Bỏ dấu tiếng Việt cơ bản
    replacements = {
        "à": "a", "á": "a", "ả": "a", "ã": "a", "ạ": "a",
        "ă": "a", "ằ": "a", "ắ": "a", "ẳ": "a", "ẵ": "a", "ặ": "a",
        "â": "a", "ầ": "a", "ấ": "a", "ẩ": "a", "ẫ": "a", "ậ": "a",
        "è": "e", "é": "e", "ẻ": "e", "ẽ": "e", "ẹ": "e",
        "ê": "e", "ề": "e", "ế": "e", "ể": "e", "ễ": "e", "ệ": "e",
        "ì": "i", "í": "i", "ỉ": "i", "ĩ": "i", "ị": "i",
        "ò": "o", "ó": "o", "ỏ": "o", "õ": "o", "ọ": "o",
        "ô": "o", "ồ": "o", "ố": "o", "ổ": "o", "ỗ": "o", "ộ": "o",
        "ơ": "o", "ờ": "o", "ớ": "o", "ở": "o", "ỡ": "o", "ợ": "o",
        "ù": "u", "ú": "u", "ủ": "u", "ũ": "u", "ụ": "u",
        "ư": "u", "ừ": "u", "ứ": "u", "ử": "u", "ữ": "u", "ự": "u",
        "ỳ": "y", "ý": "y", "ỷ": "y", "ỹ": "y", "ỵ": "y",
        "đ": "d",
    }
    for vn, en in replacements.items():
        text = text.replace(vn, en)
    # Thay khoảng trắng và ký tự đặc biệt thành dấu gạch ngang
    text = re.sub(r"[^a-z0-9]+", "-", text)
    text = text.strip("-")
    # Xoá dấu gạch ngang trùng
    text = re.sub(r"-+", "-", text)
    return text


def resolve_brand_slug(raw_brand: str) -> str:
    """Tra bảng mapping để lấy brand_slug chuẩn."""
    if not raw_brand:
        return "unknown"
    key = raw_brand.lower().strip()
    return BRAND_MAP.get(key, slugify(raw_brand))


def clean_product_name(name: str) -> str:
    """Bỏ hậu tố ' | Chính hãng...' ra khỏi tên sản phẩm."""
    if not name:
        return ""
    # Cắt phần " | Chính hãng..." nếu có
    name = re.split(r"\s*\|\s*Chính hãng", name, maxsplit=1)[0]
    return name.strip()


def extract_slug_from_url(url: str) -> str:
    """Rút slug từ URL sản phẩm trên CellphoneS.
    VD: https://cellphones.com.vn/iphone-17-pro-max.html → iphone-17-pro-max
    """
    if not url:
        return ""
    parts = url.rstrip("/").split("/")
    last = parts[-1]
    return last.replace(".html", "")


# ════════════════════════════════════════════════════════════
# MAIN IMPORT LOGIC
# ════════════════════════════════════════════════════════════

async def run_import(data_dir: str, skip_qdrant: bool = False):
    """Main import function."""
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    # ── 1. Load all JSON files ──
    json_files = sorted(glob.glob(os.path.join(data_dir, "*.json")))
    logger.info(f"Tìm thấy {len(json_files)} file JSON trong {data_dir}")

    if not json_files:
        logger.error("Không tìm thấy file JSON nào!")
        return

    # ── 2. Pre-load lookup tables ──
    async with async_session() as session:
        # Categories
        result = await session.execute(select(Category))
        categories = {c.slug: c for c in result.scalars().all()}
        logger.info(f"Loaded {len(categories)} categories")

        # Brands
        result = await session.execute(select(Brand))
        brands = {b.slug: b for b in result.scalars().all()}
        logger.info(f"Loaded {len(brands)} brands")

        # Product Lines
        result = await session.execute(select(ProductLine))
        product_lines = {pl.slug: pl for pl in result.scalars().all()}
        logger.info(f"Loaded {len(product_lines)} product_lines")

        # Existing product slugs (để skip duplicate)
        result = await session.execute(select(Product.slug))
        existing_slugs = {row[0] for row in result.all()}
        logger.info(f"Loaded {len(existing_slugs)} existing products")

    # ── 3. Parse & Import ──
    stats = {"imported": 0, "skipped": 0, "errors": 0, "brands_created": 0, "lines_created": 0}
    # Tích lũy products cho Qdrant batch import
    qdrant_queue = []

    for file_path in json_files:
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                raw = json.load(f)

            product_name = clean_product_name(raw.get("name", ""))
            product_slug = extract_slug_from_url(raw.get("url", ""))

            if not product_slug:
                product_slug = slugify(product_name)

            if not product_name or not product_slug:
                logger.warning(f"Bỏ qua file (thiếu name/slug): {file_path}")
                stats["errors"] += 1
                continue

            # Skip duplicate
            if product_slug in existing_slugs:
                stats["skipped"] += 1
                continue

            # ── Resolve category ──
            cat_slug = raw.get("category", "").lower()
            category = categories.get(cat_slug)
            if not category:
                logger.warning(f"Không tìm thấy category '{cat_slug}' cho {product_name}")
                stats["errors"] += 1
                continue

            # ── Resolve brand ──
            brand_slug = resolve_brand_slug(raw.get("brand", ""))
            brand = brands.get(brand_slug)

            if not brand:
                # Auto-create brand nếu chưa tồn tại
                async with async_session() as session:
                    brand = Brand(
                        name=raw.get("brand", brand_slug).strip(),
                        slug=brand_slug,
                        is_active=True,
                    )
                    session.add(brand)
                    await session.commit()
                    await session.refresh(brand)
                    brands[brand_slug] = brand
                    stats["brands_created"] += 1
                    logger.info(f"  [+] Auto-created brand: {brand.name} ({brand_slug})")

            # ── Resolve product_line ──
            line = None
            line_raw = raw.get("product_line")
            if line_raw:
                line_slug = slugify(line_raw)
                line = product_lines.get(line_slug)

                if not line:
                    async with async_session() as session:
                        line = ProductLine(
                            brand_id=brand.id,
                            category_id=category.id,
                            name=line_raw.strip(),
                            slug=line_slug,
                            is_active=True,
                        )
                        session.add(line)
                        await session.commit()
                        await session.refresh(line)
                        product_lines[line_slug] = line
                        stats["lines_created"] += 1
                        logger.info(f"  [+] Auto-created product_line: {line.name} ({line_slug})")

            # ── Xử lý giá ──
            base_price = raw.get("price", 0) or 0
            sale_price = raw.get("sale_price")
            # Nếu sale_price > price → swap (crawler có thể lưu ngược)
            if sale_price and base_price and sale_price > base_price:
                sale_price = None  # giá gốc cao hơn = không sale

            # ── Create Product ──
            async with async_session() as session:
                product = Product(
                    category_id=category.id,
                    brand_id=brand.id,
                    line_id=line.id if line else None,
                    name=product_name,
                    slug=product_slug,
                    original_url=raw.get("url"),
                    description=raw.get("description"),
                    highlight_features=raw.get("features", []),
                    base_price=Decimal(str(base_price)),
                    sale_price=Decimal(str(sale_price)) if sale_price else None,
                    status=raw.get("status", "new"),
                    specs=raw.get("specs", {}),
                    rating_avg=Decimal(str(raw.get("rating") or 0)),
                    rating_count=raw.get("rating_count", 0),
                    is_active=True,
                )
                session.add(product)
                await session.flush()  # Lấy product.id

                # ── Create Variants (colors) ──
                colors = raw.get("colors", [])
                if colors:
                    for i, color in enumerate(colors):
                        variant = ProductVariant(
                            product_id=product.id,
                            color_name=color,
                            stock_quantity=10,  # Default stock
                            is_active=True,
                            sort_order=i,
                        )
                        session.add(variant)

                # ── Create Images ──
                images = raw.get("images", [])
                for i, img_url in enumerate(images):
                    image = ProductImage(
                        product_id=product.id,
                        image_url=img_url,
                        alt_text=product_name,
                        is_primary=(i == 0),
                        sort_order=i,
                    )
                    session.add(image)

                await session.commit()
                await session.refresh(product)

                existing_slugs.add(product_slug)
                stats["imported"] += 1

                # Gom data cho Qdrant
                qdrant_queue.append({
                    "product_id": str(product.id),
                    "name": product_name,
                    "brand_name": brand.name,
                    "brand_slug": brand.slug,
                    "line_name": line.name if line else None,
                    "line_slug": line.slug if line else None,
                    "category_name": category.name,
                    "category_slug": category.slug,
                    "description": raw.get("description"),
                    "base_price": base_price,
                    "sale_price": sale_price,
                    "status": raw.get("status", "new"),
                    "specs": raw.get("specs", {}),
                    "colors": colors,
                    "primary_image": images[0] if images else None,
                    "original_url": raw.get("url"),
                    "highlight_features": raw.get("features", []),
                    "rating_avg": raw.get("rating") or 0,
                    "rating_count": raw.get("rating_count", 0),
                    "sold_count": 0,
                    "is_active": True,
                })

                if stats["imported"] % 100 == 0:
                    logger.info(f"  ... đã import {stats['imported']} sản phẩm")

        except Exception as e:
            logger.error(f"Lỗi khi xử lý {file_path}: {e}")
            stats["errors"] += 1
            continue

    # ── 4. Qdrant Import ──
    if not skip_qdrant and qdrant_queue:
        logger.info(f"\n{'='*60}")
        logger.info(f"Bắt đầu index {len(qdrant_queue)} sản phẩm lên Qdrant Cloud...")
        logger.info(f"{'='*60}")
        try:
            from database.indexer import ProductIndexer
            indexer = ProductIndexer()
            vector_ids = await indexer.reindex_all(qdrant_queue)

            # Cập nhật qdrant_vector_id vào PostgreSQL
            async with async_session() as session:
                for i, item in enumerate(qdrant_queue):
                    product_id = item["product_id"]
                    vector_id = vector_ids[i]
                    result = await session.execute(
                        select(Product).where(Product.id == uuid.UUID(product_id))
                    )
                    product = result.scalar_one_or_none()
                    if product:
                        product.qdrant_vector_id = vector_id
                await session.commit()

            logger.info(f"[Qdrant] Đã index thành công {len(vector_ids)} sản phẩm!")
        except Exception as e:
            logger.error(f"[Qdrant] Lỗi khi index: {e}")
            logger.info("[Qdrant] Dữ liệu PostgreSQL vẫn an toàn. Có thể chạy lại với Qdrant sau.")
    elif skip_qdrant:
        logger.info("\n[SKIP] Bỏ qua Qdrant indexing (--skip-qdrant)")

    # ── 5. Report ──
    logger.info(f"\n{'='*60}")
    logger.info(f"KẾT QUẢ IMPORT:")
    logger.info(f"  ✅ Imported: {stats['imported']} sản phẩm")
    logger.info(f"  ⏭️  Skipped (trùng): {stats['skipped']}")
    logger.info(f"  ❌ Errors: {stats['errors']}")
    logger.info(f"  🏷️  Brands tạo mới: {stats['brands_created']}")
    logger.info(f"  📂 Product Lines tạo mới: {stats['lines_created']}")
    logger.info(f"{'='*60}")

    await engine.dispose()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Import crawled products to PostgreSQL & Qdrant")
    parser.add_argument(
        "--data-dir",
        default="/app/data/raw",
        help="Đường dẫn thư mục chứa file JSON (default: /app/data/raw trong Docker)",
    )
    parser.add_argument(
        "--skip-qdrant",
        action="store_true",
        help="Bỏ qua bước index Qdrant (chỉ import PostgreSQL)",
    )
    args = parser.parse_args()

    asyncio.run(run_import(args.data_dir, args.skip_qdrant))
