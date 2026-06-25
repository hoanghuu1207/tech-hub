"""add payment_expires_at to orders

Revision ID: f8a2c3d4e5f6
Revises: e7b2f1a3d4c5
Create Date: 2026-06-26 00:08:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f8a2c3d4e5f6'
down_revision: str = 'e7b2f1a3d4c5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'orders',
        sa.Column('payment_expires_at', sa.DateTime(timezone=True), nullable=True),
    )
    # Tạo index để scheduler query nhanh
    op.create_index(
        'ix_orders_payment_expiry',
        'orders',
        ['payment_status', 'payment_expires_at'],
        postgresql_where=sa.text("payment_status = 'pending' AND payment_expires_at IS NOT NULL"),
    )


def downgrade() -> None:
    op.drop_index('ix_orders_payment_expiry', table_name='orders')
    op.drop_column('orders', 'payment_expires_at')
