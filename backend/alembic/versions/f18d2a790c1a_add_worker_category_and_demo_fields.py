"""add worker category and demo metadata

Revision ID: f18d2a790c1a
Revises: 951b3b8c680f
Create Date: 2026-10-15

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "f18d2a790c1a"
down_revision: Union[str, Sequence[str], None] = "951b3b8c680f"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("worker_category", sa.String(), nullable=True),
    )
    op.add_column(
        "users",
        sa.Column(
            "is_demo_worker",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    op.alter_column("users", "is_demo_worker", server_default=None)


def downgrade() -> None:
    op.drop_column("users", "is_demo_worker")
    op.drop_column("users", "worker_category")
