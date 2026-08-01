"""Add real AI provider cost-safety usage ledger."""

from alembic import op
import sqlalchemy as sa


revision = "20260801_0007"
down_revision = "20260731_0006"
branch_labels = None
depends_on = None


_UPGRADED_ERROR_CODES = (
    "error_code IS NULL OR error_code IN ("
    "'gateway_disabled', 'ai_disabled', 'usage_limit_reached', "
    "'invalid_request', 'invalid_input', 'input_hash_mismatch', "
    "'unsupported_report_type', 'unsupported_prompt_version', "
    "'unsupported_scope', 'provider_authentication_failed', "
    "'provider_auth_failed', 'provider_rate_limited', "
    "'provider_timeout', 'provider_unavailable', 'provider_refused', "
    "'response_invalid', 'request_failed', 'unknown')"
)

_LEGACY_ERROR_CODES = (
    "error_code IS NULL OR error_code IN ("
    "'gateway_disabled', 'invalid_request', 'invalid_input', "
    "'input_hash_mismatch', 'unsupported_report_type', "
    "'unsupported_prompt_version', 'unsupported_scope', "
    "'provider_authentication_failed', 'provider_rate_limited', "
    "'provider_timeout', 'provider_unavailable', 'provider_refused', "
    "'response_invalid', 'request_failed', 'unknown')"
)


def upgrade() -> None:
    with op.batch_alter_table("ai_generation_requests") as batch_op:
        batch_op.drop_constraint(
            "ck_ai_generation_request_error_code",
            type_="check",
        )
        batch_op.create_check_constraint(
            "ck_ai_generation_request_error_code",
            _UPGRADED_ERROR_CODES,
        )

    op.create_table(
        "ai_usage_controls",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("updated_at", sa.BigInteger(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.bulk_insert(
        sa.table(
            "ai_usage_controls",
            sa.column("id", sa.Integer()),
            sa.column("updated_at", sa.BigInteger()),
        ),
        [{"id": 1, "updated_at": 0}],
    )
    op.create_table(
        "ai_usage_records",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("user_id", sa.String(length=36), nullable=False),
        sa.Column("request_id", sa.String(length=36), nullable=False),
        sa.Column("provider", sa.String(length=32), nullable=False),
        sa.Column("model", sa.String(length=128), nullable=False),
        sa.Column("request_type", sa.String(length=32), nullable=False),
        sa.Column("input_tokens", sa.Integer(), nullable=True),
        sa.Column("output_tokens", sa.Integer(), nullable=True),
        sa.Column("total_tokens", sa.Integer(), nullable=True),
        sa.Column("status", sa.String(length=24), nullable=False),
        sa.Column("created_at", sa.BigInteger(), nullable=False),
        sa.Column("updated_at", sa.BigInteger(), nullable=False),
        sa.Column("lease_expires_at", sa.BigInteger(), nullable=True),
        sa.Column("completed_at", sa.BigInteger(), nullable=True),
        sa.CheckConstraint(
            "status IN ('processing', 'completed', 'failed', 'expired')",
            name="ck_ai_usage_record_status",
        ),
        sa.CheckConstraint(
            "input_tokens IS NULL OR input_tokens >= 0",
            name="ck_ai_usage_record_input_tokens",
        ),
        sa.CheckConstraint(
            "output_tokens IS NULL OR output_tokens >= 0",
            name="ck_ai_usage_record_output_tokens",
        ),
        sa.CheckConstraint(
            "total_tokens IS NULL OR total_tokens >= 0",
            name="ck_ai_usage_record_total_tokens",
        ),
        sa.ForeignKeyConstraint(["user_id"], ["cloud_users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_ai_usage_records_user_id",
        "ai_usage_records",
        ["user_id"],
    )
    op.create_index(
        "ix_ai_usage_records_created_at",
        "ai_usage_records",
        ["created_at"],
    )
    op.create_index(
        "ix_ai_usage_records_user_created_at",
        "ai_usage_records",
        ["user_id", "created_at"],
    )
    op.create_index(
        "ix_ai_usage_records_active_lease",
        "ai_usage_records",
        ["status", "lease_expires_at"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_ai_usage_records_active_lease",
        table_name="ai_usage_records",
    )
    op.drop_index(
        "ix_ai_usage_records_user_created_at",
        table_name="ai_usage_records",
    )
    op.drop_index(
        "ix_ai_usage_records_created_at",
        table_name="ai_usage_records",
    )
    op.drop_index(
        "ix_ai_usage_records_user_id",
        table_name="ai_usage_records",
    )
    op.drop_table("ai_usage_records")
    op.drop_table("ai_usage_controls")

    op.execute(
        "UPDATE ai_generation_requests SET error_code = 'gateway_disabled' "
        "WHERE error_code = 'ai_disabled'"
    )
    op.execute(
        "UPDATE ai_generation_requests "
        "SET error_code = 'provider_authentication_failed' "
        "WHERE error_code = 'provider_auth_failed'"
    )
    op.execute(
        "UPDATE ai_generation_requests SET error_code = 'request_failed' "
        "WHERE error_code = 'usage_limit_reached'"
    )
    with op.batch_alter_table("ai_generation_requests") as batch_op:
        batch_op.drop_constraint(
            "ck_ai_generation_request_error_code",
            type_="check",
        )
        batch_op.create_check_constraint(
            "ck_ai_generation_request_error_code",
            _LEGACY_ERROR_CODES,
        )
