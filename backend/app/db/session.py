from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from app.core.config import settings

# Khởi tạo Async Engine
engine = create_async_engine(settings.DATABASE_URL, echo=settings.DEBUG, future=True)

# Khởi tạo Async Session Factory
SessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    Dependency dùng để mở kết nối Database cho mỗi request và chủ động close khi xong.
    """
    async with SessionLocal() as session:
        yield session
