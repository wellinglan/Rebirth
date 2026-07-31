"""Add step-up reauthentication proofs and session-bound OAuth."""

from alembic import op
import sqlalchemy as sa


revision = "20260731_0006"
down_revision = "20260731_0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "reauthentication_proofs",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("cloud_user_id", sa.String(length=36), nullable=False),
        sa.Column("session_id", sa.String(length=36), nullable=False),
        sa.Column("purpose", sa.String(length=24), nullable=False),
        sa.Column("proof_hash", sa.String(length=64), nullable=False),
        sa.Column("created_at", sa.BigInteger(), nullable=False),
        sa.Column("expires_at", sa.BigInteger(), nullable=False),
        sa.Column("consumed_at", sa.BigInteger(), nullable=True),
        sa.Column("status", sa.String(length=24), nullable=False),
        sa.CheckConstraint(
            "purpose IN ('wechat_bind')",
            name="ck_reauthentication_proof_purpose",
        ),
        sa.CheckConstraint(
            "status IN ('created', 'consumed', 'expired', 'rejected')",
            name="ck_reauthentication_proof_status",
        ),
        sa.ForeignKeyConstraint(["cloud_user_id"], ["cloud_users.id"]),
        sa.ForeignKeyConstraint(["session_id"], ["auth_sessions.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "proof_hash",
            name="uq_reauthentication_proof_hash",
        ),
    )
    op.create_index(
        "ix_reauthentication_proofs_expiry",
        "reauthentication_proofs",
        ["expires_at"],
    )
    op.create_index(
        "ix_reauthentication_proofs_user_session_status",
        "reauthentication_proofs",
        ["cloud_user_id", "session_id", "status"],
    )

    with op.batch_alter_table("oauth_transactions") as batch_op:
        batch_op.drop_constraint(
            "ck_oauth_transaction_purpose",
            type_="check",
        )
        batch_op.add_column(
            sa.Column("session_id", sa.String(length=36), nullable=True)
        )
        batch_op.create_foreign_key(
            "fk_oauth_transactions_session_id_auth_sessions",
            "auth_sessions",
            ["session_id"],
            ["id"],
        )
    op.execute(
        "UPDATE oauth_transactions SET purpose = 'wechat_bind' "
        "WHERE purpose = 'bind'"
    )
    with op.batch_alter_table("oauth_transactions") as batch_op:
        batch_op.create_check_constraint(
            "ck_oauth_transaction_purpose",
            "purpose IN ('wechat_bind')",
        )
    op.create_index(
        "ix_oauth_transactions_session_id",
        "oauth_transactions",
        ["session_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_oauth_transactions_session_id",
        table_name="oauth_transactions",
    )
    with op.batch_alter_table("oauth_transactions") as batch_op:
        batch_op.drop_constraint(
            "ck_oauth_transaction_purpose",
            type_="check",
        )
    op.execute(
        "UPDATE oauth_transactions SET purpose = 'bind' "
        "WHERE purpose = 'wechat_bind'"
    )
    with op.batch_alter_table("oauth_transactions") as batch_op:
        batch_op.drop_constraint(
            "fk_oauth_transactions_session_id_auth_sessions",
            type_="foreignkey",
        )
        batch_op.drop_column("session_id")
        batch_op.create_check_constraint(
            "ck_oauth_transaction_purpose",
            "purpose IN ('bind')",
        )

    op.drop_index(
        "ix_reauthentication_proofs_user_session_status",
        table_name="reauthentication_proofs",
    )
    op.drop_index(
        "ix_reauthentication_proofs_expiry",
        table_name="reauthentication_proofs",
    )
    op.drop_table("reauthentication_proofs")
