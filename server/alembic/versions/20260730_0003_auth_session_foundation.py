"""Add password credentials and durable authentication sessions."""

from alembic import op
import sqlalchemy as sa


revision = "20260730_0003"
down_revision = "20260717_0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    existing = set(inspector.get_table_names())
    if "auth_credentials" not in existing:
        op.create_table(
            "auth_credentials",
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column("identity_id", sa.String(36), nullable=False),
            sa.Column("credential_type", sa.String(24), nullable=False),
            sa.Column("password_hash", sa.Text(), nullable=False),
            sa.Column("password_algorithm", sa.String(24), nullable=False),
            sa.Column("password_parameters_version", sa.Integer(), nullable=False),
            sa.Column("created_at", sa.BigInteger(), nullable=False),
            sa.Column("updated_at", sa.BigInteger(), nullable=False),
            sa.Column("password_changed_at", sa.BigInteger(), nullable=False),
            sa.Column("disabled_at", sa.BigInteger(), nullable=True),
            sa.ForeignKeyConstraint(["identity_id"], ["auth_identities.id"]),
            sa.UniqueConstraint(
                "identity_id",
                "credential_type",
                name="uq_auth_credential_identity_type",
            ),
            sa.CheckConstraint(
                "credential_type = 'password'",
                name="ck_auth_credential_type",
            ),
        )
        op.create_index(
            "ix_auth_credentials_identity_id",
            "auth_credentials",
            ["identity_id"],
        )
    if "auth_sessions" not in existing:
        op.create_table(
            "auth_sessions",
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column("user_id", sa.String(36), nullable=False),
            sa.Column("identity_id", sa.String(36), nullable=False),
            sa.Column("created_at", sa.BigInteger(), nullable=False),
            sa.Column("last_seen_at", sa.BigInteger(), nullable=False),
            sa.Column("absolute_expires_at", sa.BigInteger(), nullable=False),
            sa.Column("revoked_at", sa.BigInteger(), nullable=True),
            sa.Column("revoke_reason", sa.String(48), nullable=True),
            sa.Column(
                "client_installation_id_hash",
                sa.String(64),
                nullable=True,
            ),
            sa.Column("platform", sa.String(16), nullable=True),
            sa.Column("app_version", sa.String(64), nullable=True),
            sa.Column("user_agent_hash", sa.String(64), nullable=True),
            sa.Column("refresh_generation", sa.Integer(), nullable=False),
            sa.Column("legacy_migrated_at", sa.BigInteger(), nullable=True),
            sa.ForeignKeyConstraint(["user_id"], ["cloud_users.id"]),
            sa.ForeignKeyConstraint(["identity_id"], ["auth_identities.id"]),
        )
        op.create_index(
            "ix_auth_sessions_user_id",
            "auth_sessions",
            ["user_id"],
        )
        op.create_index(
            "ix_auth_sessions_identity_id",
            "auth_sessions",
            ["identity_id"],
        )
        op.create_index(
            "ix_auth_sessions_active",
            "auth_sessions",
            ["user_id", "revoked_at"],
        )
        op.create_index(
            "ix_auth_sessions_expiry",
            "auth_sessions",
            ["absolute_expires_at"],
        )
    if "auth_refresh_tokens" not in existing:
        op.create_table(
            "auth_refresh_tokens",
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column("session_id", sa.String(36), nullable=False),
            sa.Column("token_hash", sa.String(64), nullable=False),
            sa.Column("parent_token_id", sa.String(36), nullable=True),
            sa.Column("issued_at", sa.BigInteger(), nullable=False),
            sa.Column("expires_at", sa.BigInteger(), nullable=False),
            sa.Column("used_at", sa.BigInteger(), nullable=True),
            sa.Column("revoked_at", sa.BigInteger(), nullable=True),
            sa.Column("revoke_reason", sa.String(48), nullable=True),
            sa.Column("replaced_by_token_id", sa.String(36), nullable=True),
            sa.Column("generation", sa.Integer(), nullable=False),
            sa.ForeignKeyConstraint(["session_id"], ["auth_sessions.id"]),
            sa.ForeignKeyConstraint(
                ["parent_token_id"],
                ["auth_refresh_tokens.id"],
            ),
            sa.ForeignKeyConstraint(
                ["replaced_by_token_id"],
                ["auth_refresh_tokens.id"],
            ),
            sa.UniqueConstraint(
                "token_hash",
                name="uq_auth_refresh_token_hash",
            ),
        )
        op.create_index(
            "ix_auth_refresh_tokens_session_id",
            "auth_refresh_tokens",
            ["session_id"],
        )
        op.create_index(
            "ix_auth_refresh_tokens_expiry",
            "auth_refresh_tokens",
            ["expires_at"],
        )
        op.create_index(
            "ix_auth_refresh_tokens_session_active",
            "auth_refresh_tokens",
            ["session_id", "revoked_at"],
        )
    if "auth_login_throttles" not in existing:
        op.create_table(
            "auth_login_throttles",
            sa.Column("bucket_key", sa.String(64), primary_key=True),
            sa.Column("failed_count", sa.Integer(), nullable=False),
            sa.Column("window_started_at", sa.BigInteger(), nullable=False),
            sa.Column("blocked_until", sa.BigInteger(), nullable=True),
            sa.Column("updated_at", sa.BigInteger(), nullable=False),
        )
        op.create_index(
            "ix_auth_login_throttles_updated",
            "auth_login_throttles",
            ["updated_at"],
        )
    if "legacy_refresh_migrations" not in existing:
        op.create_table(
            "legacy_refresh_migrations",
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column("legacy_token_hash", sa.String(64), nullable=False),
            sa.Column("session_id", sa.String(36), nullable=False),
            sa.Column("migrated_at", sa.BigInteger(), nullable=False),
            sa.ForeignKeyConstraint(["session_id"], ["auth_sessions.id"]),
            sa.UniqueConstraint(
                "legacy_token_hash",
                name="uq_legacy_refresh_migration_hash",
            ),
        )
        op.create_index(
            "ix_legacy_refresh_migrations_session_id",
            "legacy_refresh_migrations",
            ["session_id"],
        )


def downgrade() -> None:
    op.drop_table("legacy_refresh_migrations")
    op.drop_table("auth_login_throttles")
    op.drop_table("auth_refresh_tokens")
    op.drop_table("auth_sessions")
    op.drop_table("auth_credentials")
