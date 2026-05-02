"""
Index Qdrant — Đọc sản phẩm từ PostgreSQL và đẩy lên Qdrant Cloud.

Script này hoạt động ĐỘC LẬP với import_products.py.
Chạy sau khi data đã nằm trong PostgreSQL.

Sử dụng:
    # Index toàn bộ sản phẩm
    docker-compose run --rm -e PYTHONPATH=/app backend python database/index_qdrant.py

    # Chỉ index sản phẩm chưa có vector (chưa từng index)
    docker-compose run --rm -e PYTHONPATH=/app backend python database/index_qdrant.py --only-new

    # Index lại từ đầu (xóa collection cũ, tạo mới)
    docker-compose run --rm -e PYTHONPATH=/app backend python database/index_qdrant.py --recreate
"""

import asyncio
import argparse
import logging
import uuid

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import settings
from app.db.qdrant import qdrant_client
from app.models.product import Product, ProductVariant, ProductImage, Category, Brand, ProductLine

from database.indexer import ProductIndexer

from qdrant_client.models import VectorParams, Distance, PayloadSchemaType

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("qdrant_indexer")

COLLECTION_NAME = "products"
BATCH_SIZE = 50  # Số sản phẩm mỗi batch (tránh quá tải OpenAI API)


async def setup_collection(recreate: bool = False):
    """Tạo hoặc recreate Qdrant collection + payload indexes."""
    existing = [c.name for c in qdrant_client.get_collections().collections]

    if recreate and COLLECTION_NAME in existing:
        logger.info(f"🗑️  Xoá collection '{COLLECTION_NAME}' cũ...")
        qdrant_client.delete_collection(COLLECTION_NAME)
        existing.remove(COLLECTION_NAME)

    if COLLECTION_NAME not in existing:
        logger.info(f"📦 Tạo collection '{COLLECTION_NAME}'...")
        qdrant_client.create_collection(
            collection_name=COLLECTION_NAME,
            vectors_config=VectorParams(size=3072, distance=Distance.COSINE),
        )



        # Tạo payload indexes
        payload_indexes = [
            ("category_slug", PayloadSchemaType.KEYWORD),
            ("brand_slug", PayloadSchemaType.KEYWORD),
            ("line_slug", PayloadSchemaType.KEYWORD),
            ("status", PayloadSchemaType.KEYWORD),
            ("base_price", PayloadSchemaType.FLOAT),
            ("sale_price", PayloadSchemaType.FLOAT),
            ("rating_avg", PayloadSchemaType.FLOAT),
            ("sold_count", PayloadSchemaType.INTEGER),
            ("is_active", PayloadSchemaType.BOOL),
            ("ram_gb", PayloadSchemaType.INTEGER),
            ("storage_gb", PayloadSchemaType.INTEGER),
            ("screen_size", PayloadSchemaType.FLOAT),
        ]
        for field_name, schema_type in payload_indexes:
            try:
                qdrant_client.create_payload_index(
                    collection_name=COLLECTION_NAME,
                    field_name=field_name,
                    field_schema=schema_type,
                )
            except Exception:
                pass  # Index đã tồn tại

        logger.info("✅ Collection và payload indexes đã sẵn sàng.")
    else:
        logger.info(f"✅ Collection '{COLLECTION_NAME}' đã tồn tại.")


async def load_products_from_db(session: AsyncSession, only_new: bool = False) -> list[dict]:
    """Đọc sản phẩm từ PostgreSQL và chuẩn bị data cho indexer."""

    query = (
        select(Product)
        .options(
            selectinload(Product.category),
            selectinload(Product.brand),
            selectinload(Product.line),
            selectinload(Product.variants),
            selectinload(Product.images),
        )
        .where(Product.is_active == True)
    )

    if only_new:
        query = query.where(Product.qdrant_vector_id == None)

    result = await session.execute(query)
    products = result.scalars().all()

    product_data_list = []
    for p in products:
        # Tìm primary image
        primary_image = None
        for img in sorted(p.images, key=lambda x: x.sort_order):
            if img.is_primary:
                primary_image = img.image_url
                break
        if not primary_image and p.images:
            primary_image = p.images[0].image_url

        # Lấy danh sách màu
        colors = [v.color_name for v in sorted(p.variants, key=lambda x: x.sort_order)]

        product_data_list.append({
            "product_id": str(p.id),
            "name": p.name,
            "brand_name": p.brand.name if p.brand else "",
            "brand_slug": p.brand.slug if p.brand else "",
            "line_name": p.line.name if p.line else None,
            "line_slug": p.line.slug if p.line else None,
            "category_name": p.category.name if p.category else "",
            "category_slug": p.category.slug if p.category else "",
            "description": p.description,
            "base_price": float(p.base_price) if p.base_price else 0,
            "sale_price": float(p.sale_price) if p.sale_price else None,
            "status": p.status or "new",
            "specs": p.specs or {},
            "colors": colors,
            "primary_image": primary_image,
            "original_url": p.original_url,
            "highlight_features": p.highlight_features or [],
            "rating_avg": float(p.rating_avg) if p.rating_avg else 0,
            "rating_count": p.rating_count or 0,
            "sold_count": p.sold_count or 0,
            "is_active": p.is_active,
            "qdrant_vector_id": p.qdrant_vector_id,
        })

    return product_data_list


async def run_index(only_new: bool = False, recreate: bool = False):
    """Main indexing function."""

    # ── 1. Setup Qdrant collection ──
    logger.info("=" * 60)
    logger.info("🔍 QDRANT INDEXER — Bắt đầu")
    logger.info("=" * 60)

    await setup_collection(recreate=recreate)

    # ── 2. Load products from PostgreSQL ──
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        # Đếm tổng
        count_query = select(func.count()).select_from(Product).where(Product.is_active == True)
        if only_new:
            count_query = count_query.where(Product.qdrant_vector_id == None)
        result = await session.execute(count_query)
        total = result.scalar()

        logger.info(f"📊 Tìm thấy {total} sản phẩm cần index")

        if total == 0:
            logger.info("Không có sản phẩm nào cần index. Thoát.")
            await engine.dispose()
            return

        # Load full data
        product_data_list = await load_products_from_db(session, only_new=only_new)

    logger.info(f"📥 Đã load {len(product_data_list)} sản phẩm từ PostgreSQL")

    # ── 3. Index theo batch ──
    indexer = ProductIndexer()
    total_indexed = 0
    all_results = []  # [(product_id, vector_id), ...]

    for i in range(0, len(product_data_list), BATCH_SIZE):
        batch = product_data_list[i:i + BATCH_SIZE]
        batch_num = (i // BATCH_SIZE) + 1
        total_batches = (len(product_data_list) + BATCH_SIZE - 1) // BATCH_SIZE

        logger.info(f"  🔄 Batch {batch_num}/{total_batches} ({len(batch)} sản phẩm)...")

        max_retries = 3
        for attempt in range(max_retries):
            try:
                vector_ids = await indexer.reindex_all(batch)

                for j, item in enumerate(batch):
                    all_results.append((item["product_id"], vector_ids[j]))

                total_indexed += len(batch)
                logger.info(f"     ✅ Batch {batch_num} thành công — Tổng: {total_indexed}/{len(product_data_list)}")
                break # Thành công thì thoát khỏi vòng lặp retry

            except Exception as e:
                error_msg = str(e)
                if "429" in error_msg or "Quota exceeded" in error_msg:
                    logger.warning(f"     ⚠️ Quá tải API. Đang chờ 35s để thử lại (Attempt {attempt + 1}/{max_retries})...")
                    await asyncio.sleep(35)
                else:
                    logger.error(f"     ❌ Batch {batch_num} lỗi không xác định: {e}")
                    if attempt == max_retries - 1:
                        logger.error(f"     ⏭️  Bỏ qua batch {batch_num} sau {max_retries} lần thử.")
                    await asyncio.sleep(5)
            
        # Nghỉ định kỳ 35 giây sau mỗi 2 batch (100 sản phẩm) để tránh chạm trần limit
        if batch_num % 2 == 0:
            logger.info("⏳ Tạm nghỉ 35 giây để reset quota Gemini...")
            await asyncio.sleep(35)


    # ── 4. Cập nhật qdrant_vector_id vào PostgreSQL ──
    if all_results:
        logger.info(f"\n💾 Cập nhật {len(all_results)} vector IDs vào PostgreSQL...")
        async with async_session() as session:
            for product_id, vector_id in all_results:
                result = await session.execute(
                    select(Product).where(Product.id == uuid.UUID(product_id))
                )
                product = result.scalar_one_or_none()
                if product:
                    product.qdrant_vector_id = vector_id
            await session.commit()
        logger.info("✅ Đã cập nhật qdrant_vector_id vào PostgreSQL")

    # ── 5. Report ──
    logger.info(f"\n{'=' * 60}")
    logger.info(f"KẾT QUẢ INDEX QDRANT:")
    logger.info(f"  ✅ Indexed: {total_indexed}/{len(product_data_list)} sản phẩm")
    logger.info(f"  ❌ Failed:  {len(product_data_list) - total_indexed}")

    # Kiểm tra collection info
    try:
        info = qdrant_client.get_collection(COLLECTION_NAME)
        logger.info(f"  📦 Collection points: {info.points_count}")
    except Exception:
        pass

    logger.info(f"{'=' * 60}")

    await engine.dispose()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Index products from PostgreSQL to Qdrant Cloud")
    parser.add_argument(
        "--only-new",
        action="store_true",
        help="Chỉ index sản phẩm chưa có qdrant_vector_id",
    )
    parser.add_argument(
        "--recreate",
        action="store_true",
        help="Xoá collection cũ và tạo lại từ đầu",
    )
    args = parser.parse_args()

    asyncio.run(run_index(only_new=args.only_new, recreate=args.recreate))
