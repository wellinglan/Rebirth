"""Add durable OAuth transaction replay protection."""

from alembic import op
import sqlalchemy as sa


revision = "20260731_0005"
down_revision = "20260731_0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "oauth_transactions",
        sa.Column("transaction_id", sa.String(length=36), nullable=False),
        sa.Column("provider", sa.String(length=32), nullable=False),
        sa.Column("purpose", sa.String(length=24), nullable=False),
        sa.Column("cloud_user_id", sa.String(length=36), nullable=False),
        sa.Column("state_hash", sa.String(length=64), nullable=False),
        sa.Column("nonce_hash", sa.String(length=64), nullable=False),
        sa.Column("status", sa.String(length=24), nullable=False),
        sa.Column("created_at", sa.BigInteger(), nullable=False),
        sa.Column("expires_at", sa.BigInteger(), nullable=False),
        sa.Column("consumed_at", sa.BigInteger(), nullable=True),
        sa.CheckConstraint(
            "purpose IN ('bind')",
            name="ck_oauth_transaction_purpose",
        ),
        sa.CheckConstraint(
            "status IN ('created', 'provider_verified', 'completed', "
            "'expired', 'consumed', 'rejected')",
            name="ck_oauth_transaction_status",
        ),
        sa.ForeignKeyConstraint(
            ["cloud_user_id"],
            ["cloud_users.id"],
        ),
        sa.PrimaryKeyConstraint("transaction_id"),
        sa.UniqueConstraint(
            "nonce_hash",
            name="uq_oauth_transaction_nonce_hash",
        ),
        sa.UniqueConstraint(
            "state_hash",
            name="uq_oauth_transaction_state_hash",
        ),
    )
    op.create_index(
        "ix_oauth_transactions_expiry",
        "oauth_transactions",
        ["expires_at"],
    )
    op.create_index(
        "ix_oauth_transactions_user_provider_status",
        "oauth_transactions",
        ["cloud_user_id", "provider", "status"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_oauth_transactions_user_provider_status",
        table_name="oauth_transactions",
    )
    op.drop_index(
        "ix_oauth_transactions_expiry",
        table_name="oauth_transactions",
    )
    op.drop_table("oauth_transactions")
