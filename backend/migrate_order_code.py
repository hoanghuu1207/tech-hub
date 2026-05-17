"""Migration: Add order_code column to orders table."""
import asyncio
from sqlalchemy import text
from app.db.session import engine


async def migrate():
    async with engine.begin() as conn:
        result = await conn.execute(text(
            "SELECT column_name FROM information_schema.columns "
            "WHERE table_name='orders' AND column_name='order_code'"
        ))
        if result.first():
            print("Column order_code already exists")
        else:
            await conn.execute(text(
                "ALTER TABLE orders ADD COLUMN order_code BIGINT UNIQUE"
            ))
            await conn.execute(text(
                "CREATE INDEX ix_orders_order_code ON orders(order_code)"
            ))
            print("Added order_code column successfully")


if __name__ == "__main__":
    asyncio.run(migrate())
