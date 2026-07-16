"""Create the cloud account, sync item, and sync clock schema."""

from alembic import op
import sqlalchemy as sa


revision = "20260716_0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    existing = set(inspector.get_table_names())

    if "cloud_users" not in existing:
        op.create_table(
            "cloud_users",
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column("display_name", sa.String(128), nullable=True),
            sa.Column("created_at", sa.BigInteger(), nullable=False),
            sa.Column("updated_at", sa.BigInteger(), nullable=False),
            sa.Column("deleted_at", sa.BigInteger(), nullable=True),
        )
    if "auth_identities" not in existing:
        op.create_table(
            "auth_identities",
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column("user_id", sa.String(36), nullable=False),
            sa.Column("provider", sa.String(32), nullable=False),
            sa.Column("provider_subject", sa.String(255), nullable=False),
            sa.Column("provider_union_id", sa.String(255), nullable=True),
            sa.Column("created_at", sa.BigInteger(), nullable=False),
            sa.Column("updated_at", sa.BigInteger(), nullable=False),
            sa.ForeignKeyConstraint(["user_id"], ["cloud_users.id"]),
            sa.UniqueConstraint(
                "provider",
                "provider_subject",
                name="uq_auth_identity_provider_subject",
            ),
        )
        op.create_index(
            "ix_auth_identities_user_id", "auth_identities", ["user_id"]
        )
    if "devices" not in existing:
        op.create_table(
            "devices",
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column("user_id", sa.String(36), nullable=False),
            sa.Column("local_installation_id", sa.String(128), nullable=False),
            sa.Column("platform", sa.String(16), nullable=False),
            sa.Column("device_name", sa.String(128), nullable=False),
            sa.Column("app_version", sa.String(64), nullable=False),
            sa.Column("created_at", sa.BigInteger(), nullable=False),
            sa.Column("last_seen_at", sa.BigInteger(), nullable=False),
            sa.Column("revoked_at", sa.BigInteger(), nullable=True),
            sa.ForeignKeyConstraint(["user_id"], ["cloud_users.id"]),
            sa.UniqueConstraint(
                "user_id",
                "local_installation_id",
                name="uq_device_user_installation",
            ),
        )
        op.create_index("ix_devices_user_id", "devices", ["user_id"])
    if "sync_items" not in existing:
        op.create_table(
            "sync_items",
            sa.Column("id", sa.String(36), primary_key=True),
            sa.Column("user_id", sa.String(36), nullable=False),
            sa.Column("table_name", sa.String(64), nullable=False),
            sa.Column("record_id", sa.String(128), nullable=False),
            sa.Column("payload_json", sa.Text(), nullable=False),
            sa.Column("server_version", sa.BigInteger(), nullable=False),
            sa.Column("client_updated_at", sa.BigInteger(), nullable=False),
            sa.Column("server_updated_at", sa.BigInteger(), nullable=False),
            sa.Column("deleted_at", sa.BigInteger(), nullable=True),
            sa.Column("origin_device_id", sa.String(128), nullable=False),
            sa.ForeignKeyConstraint(["user_id"], ["cloud_users.id"]),
            sa.UniqueConstraint(
                "user_id",
                "table_name",
                "record_id",
                name="uq_sync_item_user_table_record",
            ),
        )
        op.create_index("ix_sync_items_user_id", "sync_items", ["user_id"])
        op.create_index(
            "ix_sync_items_server_version", "sync_items", ["server_version"]
        )
    if "sync_clock" not in existing:
        op.create_table(
            "sync_clock",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("current_version", sa.BigInteger(), nullable=False),
        )


def downgrade() -> None:
    op.drop_table("sync_clock")
    op.drop_table("sync_items")
    op.drop_table("devices")
    op.drop_table("auth_identities")
    op.drop_table("cloud_users")

