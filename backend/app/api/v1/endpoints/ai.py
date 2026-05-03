"""
AI Search Endpoints — Tìm kiếm sản phẩm bằng ngôn ngữ tự nhiên.

Endpoints:
    POST /api/v1/ai/search   — Tìm kiếm ngữ nghĩa
    POST /api/v1/ai/suggest  — Gợi ý tìm kiếm
"""

import logging
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.ai import (
    AISearchRequest,
    AISearchResponse,
    AISuggestRequest,
    AISuggestResponse,
)
from app.services.ai_search_service import ai_search_service

logger = logging.getLogger("ai_search")

router = APIRouter()


@router.post(
    "/search",
    response_model=AISearchResponse,
    summary="Tìm kiếm sản phẩm bằng AI",
    description=(
        "Nhận câu truy vấn bằng ngôn ngữ tự nhiên (vd: 'laptop mỏng nhẹ dưới 20 triệu'), "
        "chuyển thành vector embedding qua Gemini, tìm kiếm trên Qdrant Cloud, "
        "và trả về danh sách sản phẩm xếp hạng theo độ tương đồng."
    ),
)
async def ai_search(
    request: AISearchRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Tìm kiếm sản phẩm bằng ngôn ngữ tự nhiên qua AI.

    - **query**: Câu hỏi / mô tả sản phẩm cần tìm
    - **filters**: Bộ lọc tuỳ chọn (category, brand, giá)
    - **limit**: Số kết quả tối đa (mặc định 10, tối đa 50)
    """
    try:
        result = await ai_search_service.search(
            query=request.query,
            db=db,
            filters=request.filters,
            limit=request.limit,
        )

        return AISearchResponse(
            success=True,
            message=f"Tìm thấy {result.total} sản phẩm phù hợp",
            data=result,
        )

    except ValueError as e:
        logger.warning(f"[AI Search] ValueError: {e}")
        return AISearchResponse(
            success=False,
            message="Không thể thực hiện tìm kiếm",
            error=str(e),
        )

    except Exception as e:
        logger.error(f"[AI Search] Unexpected error: {e}")
        return AISearchResponse(
            success=False,
            message="Lỗi hệ thống khi tìm kiếm",
            error="Internal server error",
        )


@router.post(
    "/suggest",
    response_model=AISuggestResponse,
    summary="Gợi ý tìm kiếm thông minh",
    description=(
        "Nhận từ khoá ngắn và trả về danh sách gợi ý sản phẩm "
        "dựa trên vector similarity từ Qdrant."
    ),
)
async def ai_suggest(request: AISuggestRequest):
    """
    Gợi ý tìm kiếm dựa trên AI.

    - **query**: Từ khoá để gợi ý (vd: 'iphone', 'tai nghe')
    - **limit**: Số gợi ý tối đa (mặc định 5)
    """
    try:
        suggestions = await ai_search_service.suggest(
            query=request.query,
            limit=request.limit,
        )

        return AISuggestResponse(
            success=True,
            message=f"Tìm thấy {len(suggestions)} gợi ý",
            data=suggestions,
        )

    except ValueError as e:
        logger.warning(f"[AI Suggest] ValueError: {e}")
        return AISuggestResponse(
            success=False,
            message="Không thể gợi ý",
            error=str(e),
        )

    except Exception as e:
        logger.error(f"[AI Suggest] Unexpected error: {e}")
        return AISuggestResponse(
            success=False,
            message="Lỗi hệ thống",
            error="Internal server error",
        )
