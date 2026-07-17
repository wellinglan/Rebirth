"""Add the durable AI generation request ledger."""

from alembic import op
import sqlalchemy as sa


revision = "20260717_0002"
down_revision = "20260716_0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    if "ai_generation_requests" in inspector.get_table_names():
        return
    op.create_table(
        "ai_generation_requests",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), nullable=False),
        sa.Column("request_id", sa.String(36), nullable=False),
        sa.Column("input_hash", sa.String(64), nullable=False),
        sa.Column("report_type", sa.String(32), nullable=False),
        sa.Column("prompt_version", sa.String(64), nullable=False),
        sa.Column("status", sa.String(24), nullable=False),
        sa.Column("provider", sa.String(32), nullable=True),
        sa.Column("model", sa.String(128), nullable=True),
        sa.Column("output_schema_version", sa.Integer(), nullable=True),
        sa.Column("report_content", sa.Text(), nullable=True),
        sa.Column("structured_output_json", sa.Text(), nullable=True),
        sa.Column("error_code", sa.String(64), nullable=True),
        sa.Column("created_at", sa.BigInteger(), nullable=False),
        sa.Column("updated_at", sa.BigInteger(), nullable=False),
        sa.Column("lease_expires_at", sa.BigInteger(), nullable=True),
        sa.Column("result_expires_at", sa.BigInteger(), nullable=True),
        sa.Column("dedupe_expires_at", sa.BigInteger(), nullable=False),
        sa.Column("result_purged_at", sa.BigInteger(), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["cloud_users.id"]),
        sa.UniqueConstraint(
            "user_id",
            "request_id",
            name="uq_ai_generation_request_user_request",
        ),
        sa.CheckConstraint(
            "status IN ('processing', 'completed', 'failed', 'outcome_unknown')",
            name="ck_ai_generation_request_status",
        ),
        sa.CheckConstraint(
            "length(input_hash) = 64",
            name="ck_ai_generation_request_input_hash_length",
        ),
        sa.CheckConstraint(
            "input_hash = lower(input_hash)",
            name="ck_ai_generation_request_input_hash_lowercase",
        ),
        sa.CheckConstraint(
            "error_code IS NULL OR error_code IN ("
            "'gateway_disabled', 'invalid_request', 'invalid_input', "
            "'input_hash_mismatch', 'unsupported_report_type', "
            "'unsupported_prompt_version', 'unsupported_scope', "
            "'provider_authentication_failed', 'provider_rate_limited', "
            "'provider_timeout', 'provider_unavailable', 'provider_refused', "
            "'response_invalid', 'request_failed', 'unknown')",
            name="ck_ai_generation_request_error_code",
        ),
    )
    op.create_index(
        "ix_ai_generation_requests_user_id",
        "ai_generation_requests",
        ["user_id"],
    )
    op.create_index(
        "ix_ai_generation_requests_lease",
        "ai_generation_requests",
        ["lease_expires_at"],
    )
    op.create_index(
        "ix_ai_generation_requests_result_expiry",
        "ai_generation_requests",
        ["result_expires_at"],
    )
    op.create_index(
        "ix_ai_generation_requests_dedupe_expiry",
        "ai_generation_requests",
        ["dedupe_expires_at"],
    )


def downgrade() -> None:
    op.drop_table("ai_generation_requests")
