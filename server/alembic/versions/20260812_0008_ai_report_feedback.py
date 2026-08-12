"""Add account-scoped AI report feedback aggregate."""

from alembic import op
import sqlalchemy as sa


revision = "20260812_0008"
down_revision = "20260801_0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "ai_report_feedback",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("cloud_user_id", sa.String(length=36), nullable=False),
        sa.Column("report_record_id", sa.String(length=36), nullable=False),
        sa.Column("report_version_number", sa.Integer(), nullable=False),
        sa.Column("report_type", sa.String(length=32), nullable=False),
        sa.Column("helpfulness", sa.String(length=16), nullable=False),
        sa.Column("reason_codes_json", sa.Text(), nullable=False),
        sa.Column("prompt_id", sa.String(length=64), nullable=False),
        sa.Column("prompt_version", sa.String(length=64), nullable=False),
        sa.Column("server_version", sa.BigInteger(), nullable=False),
        sa.Column("created_at", sa.BigInteger(), nullable=False),
        sa.Column("updated_at", sa.BigInteger(), nullable=False),
        sa.Column("deleted_at", sa.BigInteger(), nullable=True),
        sa.CheckConstraint(
            "helpfulness IN ('helpful', 'not_helpful')",
            name="ck_ai_report_feedback_helpfulness",
        ),
        sa.CheckConstraint(
            "server_version >= 1",
            name="ck_ai_report_feedback_server_version",
        ),
        sa.ForeignKeyConstraint(["cloud_user_id"], ["cloud_users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "cloud_user_id",
            "report_record_id",
            "report_version_number",
            name="uq_ai_report_feedback_user_report_version",
        ),
    )
    op.create_index(
        "ix_ai_report_feedback_cloud_user_id",
        "ai_report_feedback",
        ["cloud_user_id"],
    )
    op.create_index(
        "ix_ai_report_feedback_prompt",
        "ai_report_feedback",
        ["prompt_id", "prompt_version"],
    )
    op.create_index(
        "ix_ai_report_feedback_updated",
        "ai_report_feedback",
        ["updated_at"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_ai_report_feedback_updated", table_name="ai_report_feedback"
    )
    op.drop_index(
        "ix_ai_report_feedback_prompt", table_name="ai_report_feedback"
    )
    op.drop_index(
        "ix_ai_report_feedback_cloud_user_id", table_name="ai_report_feedback"
    )
    op.drop_table("ai_report_feedback")
