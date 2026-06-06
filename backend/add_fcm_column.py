import asyncio
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from app.core.config import settings

async def add_column():
    engine = create_async_engine(settings.DATABASE_URL)
    async with engine.begin() as conn:
        result = await conn.execute(
            text("SELECT column_name FROM information_schema.columns WHERE table_name='users' AND column_name='fcm_token'")
        )
        if result.fetchone() is None:
            await conn.execute(text("ALTER TABLE users ADD COLUMN fcm_token VARCHAR DEFAULT NULL"))
            print("Added fcm_token column")
        else:
            print("fcm_token column already exists")
    await engine.dispose()

asyncio.run(add_column())
