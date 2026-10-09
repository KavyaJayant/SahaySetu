"""Add incident relationship to complaints

Revision ID: cf52f4452ea7
Revises:
Create Date: 2026-10-03 23:35:07.776891
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "cf52f4452ea7"
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column(
        "complaints",
        sa.Column("incident_id", sa.Integer(), nullable=True)
    )

    op.create_foreign_key(
        "fk_complaints_incident_id",
        "complaints",
        "incidents",
        ["incident_id"],
        ["id"]
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint(
        "fk_complaints_incident_id",
        "complaints",
        type_="foreignkey"
    )

    op.drop_column("complaints", "incident_id")