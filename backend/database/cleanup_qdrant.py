import asyncio
import logging
from qdrant_client import models
from sqlalchemy import select

from app.db.session import engine, SessionLocal
from app.models.product import Product
from app.db.qdrant import qdrant_client

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger(__name__)

COLLECTION_NAME = "products"

async def cleanup_orphan_vectors():
    logger.info("============================================================")
    logger.info("🧹 BẮT ĐẦU DỌN DẸP VECTOR RÁC TRÊN QDRANT")
    logger.info("============================================================")

    # 1. Lấy danh sách toàn bộ ID hợp lệ từ PostgreSQL
    logger.info("1️⃣ Đang lấy danh sách vector hợp lệ từ PostgreSQL...")
    valid_pg_ids = set()
    async with SessionLocal() as session:
        result = await session.execute(
            select(Product.qdrant_vector_id).where(Product.qdrant_vector_id.isnot(None))
        )
        for row in result:
            valid_pg_ids.add(str(row[0]))
    
    logger.info(f"   => Tìm thấy {len(valid_pg_ids)} ID hợp lệ trong Database.")

    # 2. Quét (Scroll) toàn bộ ID hiện có trên Qdrant
    logger.info("\n2️⃣ Đang quét toàn bộ dữ liệu trên Qdrant Cloud...")
    qdrant_ids = set()
    offset = None
    while True:
        records, next_page = qdrant_client.scroll(
            collection_name=COLLECTION_NAME,
            limit=1000,
            with_payload=False,
            with_vectors=False,
            offset=offset,
        )
        for record in records:
            qdrant_ids.add(str(record.id))
            
        if next_page is None:
            break
        offset = next_page

    logger.info(f"   => Tìm thấy {len(qdrant_ids)} điểm (points) trên Qdrant.")

    # 3. So sánh để tìm ra vector rác (Có trên Qdrant nhưng không có trong PG)
    orphan_ids = list(qdrant_ids - valid_pg_ids)
    
    logger.info("\n3️⃣ KẾT QUẢ PHÂN TÍCH:")
    logger.info(f"   - Số lượng Vector hợp lệ: {len(qdrant_ids) - len(orphan_ids)}")
    logger.info(f"   - Số lượng Vector rác (Orphans) cần xóa: {len(orphan_ids)}")

    # 4. Thực hiện xóa rác
    if orphan_ids:
        logger.info("\n🗑️ Bắt đầu xóa các Vector rác khỏi Qdrant...")
        
        # Chia nhỏ để xóa nếu số lượng quá lớn
        batch_size = 500
        for i in range(0, len(orphan_ids), batch_size):
            batch_to_delete = orphan_ids[i:i + batch_size]
            qdrant_client.delete(
                collection_name=COLLECTION_NAME,
                points_selector=models.PointIdsList(
                    points=batch_to_delete
                )
            )
            logger.info(f"   Đã xóa {len(batch_to_delete)} vectors rác...")
            
        logger.info("✅ HOÀN TẤT DỌN DẸP! Qdrant của bạn đã sạch 100%.")
    else:
        logger.info("\n✨ Hệ thống đã sạch sẽ, không có vector rác nào cần xóa!")

    logger.info("============================================================")
    await engine.dispose()

if __name__ == "__main__":
    asyncio.run(cleanup_orphan_vectors())
