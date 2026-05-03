"""
Update Prices — Đọc lại toàn bộ JSON từ crawler, cập nhật đúng base_price & sale_price
vào PostgreSQL cho tất cả sản phẩm.

Sử dụng:
    docker-compose run --rm -e PYTHONPATH=/app backend python database/update_prices.py
"""

import asyncio
import json
import glob
import os
import re
import logging
from decimal import Decimal

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

from app.core.config import settings
from app.models.product import Product

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("price_updater")


def extract_slug_from_url(url: str) -> str:
    """Rút slug từ URL sản phẩm."""
    if not url:
        return ""
    parts = url.rstrip("/").split("/")
    last = parts[-1]
    return last.replace(".html", "")


async def run_update(data_dir: str):
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    # 1. Load all JSON files
    json_files = sorted(glob.glob(os.path.join(data_dir, "*.json")))
    logger.info(f"Tìm thấy {len(json_files)} file JSON trong {data_dir}")

    if not json_files:
        logger.error("Không tìm thấy file JSON nào!")
        return

    # 2. Build slug → price mapping từ JSON
    price_map = {}  # slug -> (base_price, sale_price)
    for file_path in json_files:
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                raw = json.load(f)

            slug = extract_slug_from_url(raw.get("url", ""))
            if not slug:
                continue

            # Từ JSON crawler CellphoneS:
            #   price = giá đang bán (giá KM hiện tại)
            #   sale_price = giá gốc niêm yết (giá cũ, thường cao hơn)
            raw_current_price = raw.get("price", 0) or 0
            raw_original_price = raw.get("sale_price")

            if raw_original_price and raw_current_price and raw_original_price > raw_current_price:
                base_price = raw_original_price     # Giá gốc = giá niêm yết
                sale_price = raw_current_price       # Giá KM = giá đang bán
            elif raw_current_price and raw_original_price and raw_current_price >= raw_original_price:
                # price >= sale_price → không có KM, giá hiện tại là giá gốc
                base_price = raw_current_price
                sale_price = None
            else:
                base_price = raw_current_price or raw_original_price or 0
                sale_price = None

            price_map[slug] = (base_price, sale_price)

        except Exception as e:
            logger.error(f"Lỗi đọc {file_path}: {e}")
            continue

    logger.info(f"Đã parse giá từ {len(price_map)} file JSON")

    # 3. Cập nhật PostgreSQL
    updated = 0
    not_found = 0
    no_change = 0

    async with async_session() as session:
        # Lấy toàn bộ products
        result = await session.execute(select(Product))
        products = result.scalars().all()
        logger.info(f"Tìm thấy {len(products)} sản phẩm trong DB")

        for product in products:
            if product.slug not in price_map:
                not_found += 1
                continue

            new_base, new_sale = price_map[product.slug]
            new_base_decimal = Decimal(str(new_base)) if new_base else None
            new_sale_decimal = Decimal(str(new_sale)) if new_sale else None

            # Kiểm tra có thay đổi không
            if product.base_price == new_base_decimal and product.sale_price == new_sale_decimal:
                no_change += 1
                continue

            product.base_price = new_base_decimal
            product.sale_price = new_sale_decimal
            updated += 1

        await session.commit()

    logger.info(f"\n{'='*60}")
    logger.info(f"KẾT QUẢ CẬP NHẬT GIÁ:")
    logger.info(f"  ✅ Cập nhật: {updated} sản phẩm")
    logger.info(f"  ⏭️  Không đổi: {no_change}")
    logger.info(f"  ❌ Không tìm thấy JSON: {not_found}")
    logger.info(f"{'='*60}")

    await engine.dispose()


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Cập nhật lại giá từ JSON vào PostgreSQL")
    parser.add_argument(
        "--data-dir",
        default="/app/data/raw",
        help="Thư mục chứa JSON (default: /app/data/raw)",
    )
    args = parser.parse_args()
    asyncio.run(run_update(args.data_dir))
