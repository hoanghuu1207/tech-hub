"""add user profile_summary and profile_updated_at

Revision ID: e7b2f1a3d4c5
Revises: d4969069f6c3
Create Date: 2026-06-12 14:10:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e7b2f1a3d4c5'
down_revision: Union[str, None] = 'd4969069f6c3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('users', sa.Column('profile_summary', sa.Text(), nullable=True))
    op.add_column('users', sa.Column('profile_updated_at', sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    op.drop_column('users', 'profile_updated_at')
    op.drop_column('users', 'profile_summary')
