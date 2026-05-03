"""
Script xoá qdrant_vector_id trong DB để chạy lại Qdrant Indexer
"""

import asyncio
import logging
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

from app.core.config import settings

logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger("clear_vectors")

async def run_clear():
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    try:
        async with engine.begin() as conn:
            result = await conn.execute(text("UPDATE products SET qdrant_vector_id = NULL;"))
            logger.info(f"✅ Đã reset {result.rowcount} bản ghi qdrant_vector_id về NULL thành công!")
    except Exception as e:
        logger.error(f"❌ Lỗi: {e}")
    finally:
        await engine.dispose()

if __name__ == "__main__":
    asyncio.run(run_clear())
