"""Add token reservation and settlement metadata to AI usage records."""

from alembic import op
import sqlalchemy as sa


revision = "20260822_0009"
down_revision = "20260812_0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("ai_usage_records") as batch:
        batch.add_column(
            sa.Column(
                "reserved_tokens",
                sa.Integer(),
                nullable=False,
                server_default="0",
            )
        )
        batch.add_column(
            sa.Column(
                "charged_tokens",
                sa.Integer(),
                nullable=False,
                server_default="0",
            )
        )
        batch.add_column(
            sa.Column("accounting_source", sa.String(length=32), nullable=True)
        )
        batch.create_check_constraint(
            "ck_ai_usage_record_reserved_tokens", "reserved_tokens >= 0"
        )
        batch.create_check_constraint(
            "ck_ai_usage_record_charged_tokens", "charged_tokens >= 0"
        )
    op.execute(
        "UPDATE ai_usage_records "
        "SET charged_tokens = COALESCE(total_tokens, 0), "
        "accounting_source = CASE WHEN total_tokens IS NULL "
        "THEN 'legacy_unknown' ELSE 'provider' END"
    )


def downgrade() -> None:
    with op.batch_alter_table("ai_usage_records") as batch:
        batch.drop_constraint(
            "ck_ai_usage_record_charged_tokens", type_="check"
        )
        batch.drop_constraint(
            "ck_ai_usage_record_reserved_tokens", type_="check"
        )
        batch.drop_column("accounting_source")
        batch.drop_column("charged_tokens")
        batch.drop_column("reserved_tokens")
