"""add product_views table for recent view tracking

Revision ID: a1b2c3d4e5f7
Revises: f8a2c3d4e5f6
Create Date: 2026-06-30 20:38:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID


# revision identifiers, used by Alembic.
revision: str = 'a1b2c3d4e5f7'
down_revision: str = 'f8a2c3d4e5f6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'product_views',
        sa.Column('id', UUID(as_uuid=True), primary_key=True, server_default=sa.text('gen_random_uuid()')),
        sa.Column('user_id', UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('product_id', UUID(as_uuid=True), sa.ForeignKey('products.product_id', ondelete='CASCADE'), nullable=False),
        sa.Column('brand_id', UUID(as_uuid=True), nullable=True),
        sa.Column('category_id', UUID(as_uuid=True), nullable=True),
        sa.Column('line_id', UUID(as_uuid=True), nullable=True),
        sa.Column('viewed_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    # Index để query nhanh: lấy N sản phẩm xem gần đây nhất của 1 user
    op.create_index('ix_product_views_user_viewed', 'product_views', ['user_id', 'viewed_at'])


def downgrade() -> None:
    op.drop_index('ix_product_views_user_viewed', table_name='product_views')
    op.drop_table('product_views')
