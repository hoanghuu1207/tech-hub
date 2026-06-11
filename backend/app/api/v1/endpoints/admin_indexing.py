"""
Admin Qdrant Indexing Endpoints.

Index / Re-index sản phẩm vào Qdrant vector database.
Tất cả endpoints yêu cầu role=admin.
"""

import asyncio
import logging
from uuid import UUID
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, BackgroundTasks
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from sqlalchemy import select, func, and_

from app.db.session import get_db
from app.db.qdrant import qdrant_client
from app.models.user import User
from app.models.product import Product, ProductVariant, ProductImage
from app.api.v1.endpoints.admin import require_admin
from database.indexer import ProductIndexer, COLLECTION_NAME

logger = logging.getLogger("admin_indexing")

router = APIRouter()
indexer = ProductIndexer()


# ─── Schemas ─────────────────────────────────────────────

class IndexResult(BaseModel):
    product_id: str
    product_name: str
    qdrant_vector_id: str | None = None
    status: str  # "success" | "error"
    error: str | None = None


class ReindexStatus(BaseModel):
    task_id: str
    status: str  # "running" | "completed" | "error"
    total: int = 0
    processed: int = 0
    success: int = 0
    errors: int = 0
    error_details: list[dict] = []

# In-memory task tracking (simple approach)
_reindex_tasks: dict[str, ReindexStatus] = {}


# ─── Helpers ─────────────────────────────────────────────

def _product_to_indexer_data(p: Product) -> dict:
    """Convert ORM Product → dict format expected by ProductIndexer."""
    primary_image = None
    if p.images:
        primary = next((img for img in p.images if img.is_primary), None)
        primary_image = primary.image_url if primary else p.images[0].image_url if p.images else None

    colors = []
    if p.variants:
        for v in p.variants:
            if v.is_active and v.color_name:
                colors.append({
                    "name": v.color_name,
                    "hex": v.color_hex,
                })

    return {
        "product_id": str(p.id),
        "name": p.name,
        "slug": p.slug,
        "description": p.description,
        "highlight_features": p.highlight_features or [],
        "base_price": float(p.base_price),
        "sale_price": float(p.sale_price) if p.sale_price else None,
        "status": p.status,
        "specs": p.specs or {},
        "is_active": p.is_active,
        "rating_avg": float(p.rating_avg) if p.rating_avg else 0,
        "sold_count": p.sold_count or 0,
        "qdrant_vector_id": p.qdrant_vector_id,
        "category_name": p.category.name if p.category else None,
        "category_slug": p.category.slug if p.category else None,
        "brand_name": p.brand.name if p.brand else None,
        "brand_slug": p.brand.slug if p.brand else None,
        "line_name": p.line.name if p.line else None,
        "line_slug": p.line.slug if p.line else None,
        "primary_image": primary_image,
        "colors": colors,
    }


# ─── Index Single Product ───────────────────────────────

@router.post("/indexing/products/{product_id}", summary="Index single product to Qdrant")
async def index_single_product(
    product_id: UUID,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Index hoặc re-index 1 sản phẩm vào Qdrant."""
    result = await db.execute(
        select(Product)
        .where(Product.id == product_id)
        .options(
            selectinload(Product.category),
            selectinload(Product.brand),
            selectinload(Product.line),
            selectinload(Product.variants),
            selectinload(Product.images),
        )
    )
    product = result.unique().scalar_one_or_none()
    if not product:
        raise HTTPException(404, "Product not found")

    try:
        product_data = _product_to_indexer_data(product)
        vector_id = await indexer.index_product(product_data)

        # Update qdrant_vector_id in PostgreSQL
        product.qdrant_vector_id = vector_id
        await db.commit()

        return {
            "success": True,
            "message": f"Product '{product.name}' indexed successfully",
            "data": {
                "product_id": str(product.id),
                "qdrant_vector_id": vector_id,
            },
        }
    except Exception as e:
        logger.error(f"Failed to index product {product_id}: {e}")
        raise HTTPException(500, f"Indexing failed: {str(e)}")


# ─── Delete from Qdrant ─────────────────────────────────

@router.delete("/indexing/products/{product_id}", summary="Remove product from Qdrant")
async def remove_from_qdrant(
    product_id: UUID,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Xóa product khỏi Qdrant index."""
    result = await db.execute(select(Product).where(Product.id == product_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(404, "Product not found")

    try:
        await indexer.delete_product(str(product_id))
        product.qdrant_vector_id = None
        await db.commit()

        return {
            "success": True,
            "message": f"Product removed from Qdrant index",
        }
    except Exception as e:
        logger.error(f"Failed to remove product {product_id} from Qdrant: {e}")
        raise HTTPException(500, f"Remove failed: {str(e)}")


# ─── Reindex All (Background Task) ──────────────────────

async def _reindex_all_task(task_id: str, db_url: str):
    """Background task to reindex all active products."""
    from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession as AS
    from sqlalchemy.orm import sessionmaker

    task = _reindex_tasks[task_id]
    task.status = "running"

    engine = create_async_engine(db_url)
    async_session = sessionmaker(engine, class_=AS, expire_on_commit=False)

    try:
        async with async_session() as db:
            # Count total
            count_result = await db.execute(
                select(func.count(Product.id)).where(Product.is_active == True)
            )
            task.total = count_result.scalar_one()

            # Process in batches
            batch_size = 20
            offset = 0

            while offset < task.total:
                result = await db.execute(
                    select(Product)
                    .where(Product.is_active == True)
                    .options(
                        selectinload(Product.category),
                        selectinload(Product.brand),
                        selectinload(Product.line),
                        selectinload(Product.variants),
                        selectinload(Product.images),
                    )
                    .order_by(Product.created_at)
                    .offset(offset)
                    .limit(batch_size)
                )
                products = list(result.unique().scalars().all())

                if not products:
                    break

                for product in products:
                    try:
                        product_data = _product_to_indexer_data(product)
                        vector_id = await indexer.index_product(product_data)
                        product.qdrant_vector_id = vector_id
                        task.success += 1
                    except Exception as e:
                        task.errors += 1
                        task.error_details.append({
                            "product_id": str(product.id),
                            "name": product.name,
                            "error": str(e),
                        })
                        logger.error(f"Reindex error for {product.id}: {e}")

                        # If rate limited, try switching API key
                        if "429" in str(e) or "quota" in str(e).lower():
                            if indexer.switch_api_key():
                                await asyncio.sleep(5)

                    task.processed += 1

                await db.commit()
                offset += batch_size

                # Small delay to avoid API rate limits
                await asyncio.sleep(1)

        task.status = "completed"
        logger.info(f"Reindex task {task_id} completed: {task.success}/{task.total} success, {task.errors} errors")

    except Exception as e:
        task.status = "error"
        task.error_details.append({"error": str(e)})
        logger.error(f"Reindex task {task_id} failed: {e}")
    finally:
        await engine.dispose()


@router.post("/indexing/reindex-all", summary="Reindex all products (background)")
async def reindex_all_products(
    background_tasks: BackgroundTasks,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Trigger re-index tất cả sản phẩm active. Chạy nền."""
    import uuid
    from app.core.config import settings

    # Check if a task is already running
    for tid, t in _reindex_tasks.items():
        if t.status == "running":
            return {
                "success": False,
                "message": "A reindex task is already running",
                "data": t.model_dump(),
            }

    task_id = str(uuid.uuid4())[:8]
    _reindex_tasks[task_id] = ReindexStatus(task_id=task_id, status="pending")

    # Get DB URL from settings
    db_url = str(settings.DATABASE_URL)

    background_tasks.add_task(_reindex_all_task, task_id, db_url)

    return {
        "success": True,
        "message": "Reindex task started",
        "data": {"task_id": task_id},
    }


# ─── Reindex Status ─────────────────────────────────────

@router.get("/indexing/tasks/{task_id}", summary="Get reindex task status")
async def get_reindex_status(
    task_id: str,
    admin: User = Depends(require_admin),
):
    """Kiểm tra tiến trình reindex."""
    task = _reindex_tasks.get(task_id)
    if not task:
        raise HTTPException(404, "Task not found")

    return {"success": True, "data": task.model_dump()}


@router.get("/indexing/tasks", summary="List all reindex tasks")
async def list_reindex_tasks(
    admin: User = Depends(require_admin),
):
    """Danh sách tất cả reindex tasks."""
    return {
        "success": True,
        "data": [t.model_dump() for t in _reindex_tasks.values()],
    }


# ─── Collection Status ──────────────────────────────────

@router.get("/indexing/status", summary="Qdrant collection status")
async def get_indexing_status(
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Trả về thông tin collection Qdrant và thống kê indexing."""
    # DB stats
    total_products = await db.execute(
        select(func.count(Product.id)).where(Product.is_active == True)
    )
    total = total_products.scalar_one()

    indexed_count = await db.execute(
        select(func.count(Product.id)).where(
            and_(Product.is_active == True, Product.qdrant_vector_id.isnot(None))
        )
    )
    indexed = indexed_count.scalar_one()

    not_indexed = total - indexed

    # Qdrant collection info
    qdrant_info = {}
    try:
        collection = qdrant_client.get_collection(COLLECTION_NAME)
        qdrant_info = {
            "points_count": getattr(collection, "points_count", None),
            "vectors_count": getattr(collection, "vectors_count", getattr(collection, "points_count", None)),
            "status": str(getattr(collection, "status", "unknown")),
            "segments_count": len(collection.segments) if getattr(collection, "segments", None) else 0,
        }
    except Exception as e:
        qdrant_info = {"error": str(e)}

    # Running tasks
    running_tasks = [t.model_dump() for t in _reindex_tasks.values() if t.status == "running"]

    return {
        "success": True,
        "data": {
            "database": {
                "total_active_products": total,
                "indexed_products": indexed,
                "not_indexed_products": not_indexed,
                "coverage_percent": round(indexed / total * 100, 1) if total > 0 else 0,
            },
            "qdrant": qdrant_info,
            "running_tasks": running_tasks,
        },
    }
