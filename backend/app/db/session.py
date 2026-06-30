from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from app.core.config import settings

# Khởi tạo Async Engine (production-tuned connection pool)
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=False,              # Tắt SQL logging (production) — giảm I/O overhead
    future=True,
    pool_size=20,            # Số connections giữ sẵn trong pool (mặc định chỉ 5)
    max_overflow=30,         # Số connections tạm thêm khi pool đầy (tổng tối đa: 50)
    pool_recycle=3600,       # Tái tạo connection sau 1 giờ — tránh bị PostgreSQL đóng
    pool_pre_ping=True,      # Kiểm tra connection còn sống trước khi dùng — tránh lỗi "connection closed"
    pool_timeout=30,         # Timeout (giây) khi chờ lấy connection từ pool
)

# Khởi tạo Async Session Factory
SessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    Dependency dùng để mở kết nối Database cho mỗi request và chủ động close khi xong.
    """
    async with SessionLocal() as session:
        yield session
