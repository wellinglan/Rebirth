"""Add identity usage metadata for multi-identity account foundations."""

from alembic import op
import sqlalchemy as sa


revision = "20260731_0004"
down_revision = "20260730_0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    columns = {
        column["name"] for column in inspector.get_columns("auth_identities")
    }
    if "last_used_at" not in columns:
        with op.batch_alter_table("auth_identities") as batch_op:
            batch_op.add_column(
                sa.Column("last_used_at", sa.BigInteger(), nullable=True)
            )
    op.execute(
        sa.text(
            "UPDATE auth_identities "
            "SET last_used_at = updated_at "
            "WHERE last_used_at IS NULL"
        )
    )


def downgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    columns = {
        column["name"] for column in inspector.get_columns("auth_identities")
    }
    if "last_used_at" in columns:
        with op.batch_alter_table("auth_identities") as batch_op:
            batch_op.drop_column("last_used_at")
