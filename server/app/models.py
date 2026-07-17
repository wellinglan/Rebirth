from __future__ import annotations

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class CloudUser(Base):
    __tablename__ = "cloud_users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    display_name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    created_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    updated_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    deleted_at: Mapped[int | None] = mapped_column(BigInteger, nullable=True)


class AuthIdentity(Base):
    __tablename__ = "auth_identities"
    __table_args__ = (
        UniqueConstraint(
            "provider",
            "provider_subject",
            name="uq_auth_identity_provider_subject",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("cloud_users.id"),
        nullable=False,
        index=True,
    )
    provider: Mapped[str] = mapped_column(String(32), nullable=False)
    provider_subject: Mapped[str] = mapped_column(String(255), nullable=False)
    provider_union_id: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
    )
    created_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    updated_at: Mapped[int] = mapped_column(BigInteger, nullable=False)


class Device(Base):
    __tablename__ = "devices"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "local_installation_id",
            name="uq_device_user_installation",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("cloud_users.id"),
        nullable=False,
        index=True,
    )
    local_installation_id: Mapped[str] = mapped_column(
        String(128),
        nullable=False,
    )
    platform: Mapped[str] = mapped_column(String(16), nullable=False)
    device_name: Mapped[str] = mapped_column(String(128), nullable=False)
    app_version: Mapped[str] = mapped_column(String(64), nullable=False)
    created_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    last_seen_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    revoked_at: Mapped[int | None] = mapped_column(BigInteger, nullable=True)


class SyncItem(Base):
    __tablename__ = "sync_items"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "table_name",
            "record_id",
            name="uq_sync_item_user_table_record",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("cloud_users.id"),
        nullable=False,
        index=True,
    )
    table_name: Mapped[str] = mapped_column(String(64), nullable=False)
    record_id: Mapped[str] = mapped_column(String(128), nullable=False)
    payload_json: Mapped[str] = mapped_column(Text, nullable=False)
    server_version: Mapped[int] = mapped_column(
        BigInteger,
        nullable=False,
        index=True,
    )
    client_updated_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    server_updated_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    deleted_at: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    origin_device_id: Mapped[str] = mapped_column(String(128), nullable=False)


class SyncClock(Base):
    __tablename__ = "sync_clock"

    id: Mapped[int] = mapped_column(primary_key=True)
    current_version: Mapped[int] = mapped_column(BigInteger, nullable=False)


class AiGenerationRequest(Base):
    __tablename__ = "ai_generation_requests"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "request_id",
            name="uq_ai_generation_request_user_request",
        ),
        CheckConstraint(
            "status IN ('processing', 'completed', 'failed', 'outcome_unknown')",
            name="ck_ai_generation_request_status",
        ),
        CheckConstraint(
            "length(input_hash) = 64",
            name="ck_ai_generation_request_input_hash_length",
        ),
        CheckConstraint(
            "input_hash = lower(input_hash)",
            name="ck_ai_generation_request_input_hash_lowercase",
        ),
        CheckConstraint(
            "error_code IS NULL OR error_code IN ("
            "'gateway_disabled', 'invalid_request', 'invalid_input', "
            "'input_hash_mismatch', 'unsupported_report_type', "
            "'unsupported_prompt_version', 'unsupported_scope', "
            "'provider_authentication_failed', 'provider_rate_limited', "
            "'provider_timeout', 'provider_unavailable', 'provider_refused', "
            "'response_invalid', 'request_failed', 'unknown')",
            name="ck_ai_generation_request_error_code",
        ),
        Index("ix_ai_generation_requests_lease", "lease_expires_at"),
        Index("ix_ai_generation_requests_result_expiry", "result_expires_at"),
        Index("ix_ai_generation_requests_dedupe_expiry", "dedupe_expires_at"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("cloud_users.id"),
        nullable=False,
        index=True,
    )
    request_id: Mapped[str] = mapped_column(String(36), nullable=False)
    input_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    report_type: Mapped[str] = mapped_column(String(32), nullable=False)
    prompt_version: Mapped[str] = mapped_column(String(64), nullable=False)
    status: Mapped[str] = mapped_column(String(24), nullable=False)
    provider: Mapped[str | None] = mapped_column(String(32), nullable=True)
    model: Mapped[str | None] = mapped_column(String(128), nullable=True)
    output_schema_version: Mapped[int | None] = mapped_column(
        Integer, nullable=True
    )
    report_content: Mapped[str | None] = mapped_column(Text, nullable=True)
    structured_output_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    error_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    updated_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    lease_expires_at: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    result_expires_at: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    dedupe_expires_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    result_purged_at: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
