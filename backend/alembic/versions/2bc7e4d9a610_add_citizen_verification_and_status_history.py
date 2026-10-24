"""add citizen verification and complaint status history

Revision ID: 2bc7e4d9a610
Revises: f18d2a790c1a
Create Date: 2026-10-16

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "2bc7e4d9a610"
down_revision: Union[str, Sequence[str], None] = "f18d2a790c1a"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "complaint_status_history",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "complaint_id",
            sa.Integer(),
            sa.ForeignKey("complaints.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("event_type", sa.String(length=40), nullable=False),
        sa.Column("status", sa.String(length=40), nullable=False),
        sa.Column("changed_at", sa.DateTime(), nullable=False),
        sa.Column(
            "actor_user_id",
            sa.Integer(),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column(
            "assigned_worker_id",
            sa.Integer(),
            sa.ForeignKey("users.id"),
            nullable=True,
        ),
    )
    op.create_index(
        "ix_complaint_status_history_complaint_id",
        "complaint_status_history",
        ["complaint_id"],
    )
    op.create_table(
        "citizen_verifications",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "complaint_id",
            sa.Integer(),
            sa.ForeignKey("complaints.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "citizen_user_id",
            sa.Integer(),
            sa.ForeignKey("users.id"),
            nullable=False,
        ),
        sa.Column(
            "completion_event_id",
            sa.Integer(),
            sa.ForeignKey(
                "complaint_status_history.id",
                ondelete="CASCADE",
            ),
            nullable=False,
        ),
        sa.Column("result", sa.String(length=20), nullable=False),
        sa.Column("feedback", sa.String(length=2000), nullable=True),
        sa.Column("evidence_filename", sa.String(length=80), nullable=True),
        sa.Column("evidence_content_type", sa.String(length=32), nullable=True),
        sa.Column("submitted_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint(
            "completion_event_id",
            name="uq_citizen_verifications_completion_event",
        ),
        sa.CheckConstraint(
            "(evidence_filename IS NULL AND evidence_content_type IS NULL) OR "
            "(evidence_filename IS NOT NULL AND evidence_content_type IS NOT NULL)",
            name="ck_citizen_verifications_evidence_pair",
        ),
    )


def downgrade() -> None:
    op.drop_table("citizen_verifications")
    op.drop_index(
        "ix_complaint_status_history_complaint_id",
        table_name="complaint_status_history",
    )
    op.drop_table("complaint_status_history")
