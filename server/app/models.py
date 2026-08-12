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
    last_used_at: Mapped[int | None] = mapped_column(BigInteger, nullable=True)


class OAuthTransaction(Base):
    __tablename__ = "oauth_transactions"
    __table_args__ = (
        UniqueConstraint("state_hash", name="uq_oauth_transaction_state_hash"),
        UniqueConstraint("nonce_hash", name="uq_oauth_transaction_nonce_hash"),
        CheckConstraint(
            "purpose IN ('wechat_bind')",
            name="ck_oauth_transaction_purpose",
        ),
        CheckConstraint(
            "status IN ('created', 'provider_verified', 'completed', "
            "'expired', 'consumed', 'rejected')",
            name="ck_oauth_transaction_status",
        ),
        Index(
            "ix_oauth_transactions_user_provider_status",
            "cloud_user_id",
            "provider",
            "status",
        ),
        Index("ix_oauth_transactions_expiry", "expires_at"),
    )

    transaction_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    provider: Mapped[str] = mapped_column(String(32), nullable=False)
    purpose: Mapped[str] = mapped_column(String(24), nullable=False)
    cloud_user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("cloud_users.id"),
        nullable=False,
    )
    session_id: Mapped[str | None] = mapped_column(
        String(36),
        ForeignKey("auth_sessions.id"),
        nullable=True,
        index=True,
    )
    state_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    nonce_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    status: Mapped[str] = mapped_column(String(24), nullable=False)
    created_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    expires_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    consumed_at: Mapped[int | None] = mapped_column(BigInteger, nullable=True)


class ReauthenticationProof(Base):
    __tablename__ = "reauthentication_proofs"
    __table_args__ = (
        UniqueConstraint(
            "proof_hash",
            name="uq_reauthentication_proof_hash",
        ),
        CheckConstraint(
            "purpose IN ('wechat_bind')",
            name="ck_reauthentication_proof_purpose",
        ),
        CheckConstraint(
            "status IN ('created', 'consumed', 'expired', 'rejected')",
            name="ck_reauthentication_proof_status",
        ),
        Index(
            "ix_reauthentication_proofs_user_session_status",
            "cloud_user_id",
            "session_id",
            "status",
        ),
        Index("ix_reauthentication_proofs_expiry", "expires_at"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    cloud_user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("cloud_users.id"),
        nullable=False,
    )
    session_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("auth_sessions.id"),
        nullable=False,
    )
    purpose: Mapped[str] = mapped_column(String(24), nullable=False)
    proof_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    created_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    expires_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    consumed_at: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    status: Mapped[str] = mapped_column(String(24), nullable=False)


class AuthCredential(Base):
    __tablename__ = "auth_credentials"
    __table_args__ = (
        UniqueConstraint(
            "identity_id",
            "credential_type",
            name="uq_auth_credential_identity_type",
        ),
        CheckConstraint(
            "credential_type = 'password'",
            name="ck_auth_credential_type",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    identity_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("auth_identities.id"),
        nullable=False,
        index=True,
    )
    credential_type: Mapped[str] = mapped_column(String(24), nullable=False)
    password_hash: Mapped[str] = mapped_column(Text, nullable=False)
    password_algorithm: Mapped[str] = mapped_column(String(24), nullable=False)
    password_parameters_version: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )
    created_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    updated_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    password_changed_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    disabled_at: Mapped[int | None] = mapped_column(BigInteger, nullable=True)


class AuthSession(Base):
    __tablename__ = "auth_sessions"
    __table_args__ = (
        Index("ix_auth_sessions_active", "user_id", "revoked_at"),
        Index("ix_auth_sessions_expiry", "absolute_expires_at"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("cloud_users.id"),
        nullable=False,
        index=True,
    )
    identity_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("auth_identities.id"),
        nullable=False,
        index=True,
    )
    created_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    last_seen_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    absolute_expires_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    revoked_at: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    revoke_reason: Mapped[str | None] = mapped_column(String(48), nullable=True)
    client_installation_id_hash: Mapped[str | None] = mapped_column(
        String(64),
        nullable=True,
    )
    platform: Mapped[str | None] = mapped_column(String(16), nullable=True)
    app_version: Mapped[str | None] = mapped_column(String(64), nullable=True)
    user_agent_hash: Mapped[str | None] = mapped_column(
        String(64),
        nullable=True,
    )
    refresh_generation: Mapped[int] = mapped_column(Integer, nullable=False)
    legacy_migrated_at: Mapped[int | None] = mapped_column(
        BigInteger,
        nullable=True,
    )


class AuthRefreshToken(Base):
    __tablename__ = "auth_refresh_tokens"
    __table_args__ = (
        UniqueConstraint("token_hash", name="uq_auth_refresh_token_hash"),
        Index("ix_auth_refresh_tokens_expiry", "expires_at"),
        Index("ix_auth_refresh_tokens_session_active", "session_id", "revoked_at"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    session_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("auth_sessions.id"),
        nullable=False,
        index=True,
    )
    token_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    parent_token_id: Mapped[str | None] = mapped_column(
        String(36),
        ForeignKey("auth_refresh_tokens.id"),
        nullable=True,
    )
    issued_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    expires_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    used_at: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    revoked_at: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    revoke_reason: Mapped[str | None] = mapped_column(String(48), nullable=True)
    replaced_by_token_id: Mapped[str | None] = mapped_column(
        String(36),
        ForeignKey("auth_refresh_tokens.id"),
        nullable=True,
    )
    generation: Mapped[int] = mapped_column(Integer, nullable=False)


class AuthLoginThrottle(Base):
    __tablename__ = "auth_login_throttles"
    __table_args__ = (Index("ix_auth_login_throttles_updated", "updated_at"),)

    bucket_key: Mapped[str] = mapped_column(String(64), primary_key=True)
    failed_count: Mapped[int] = mapped_column(Integer, nullable=False)
    window_started_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    blocked_until: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    updated_at: Mapped[int] = mapped_column(BigInteger, nullable=False)


class LegacyRefreshMigration(Base):
    __tablename__ = "legacy_refresh_migrations"
    __table_args__ = (
        UniqueConstraint(
            "legacy_token_hash",
            name="uq_legacy_refresh_migration_hash",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    legacy_token_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    session_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("auth_sessions.id"),
        nullable=False,
        index=True,
    )
    migrated_at: Mapped[int] = mapped_column(BigInteger, nullable=False)


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
            "'ai_disabled', 'usage_limit_reached', 'provider_auth_failed', "
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


class AiUsageControl(Base):
    __tablename__ = "ai_usage_controls"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    updated_at: Mapped[int] = mapped_column(BigInteger, nullable=False)


class AiUsageRecord(Base):
    __tablename__ = "ai_usage_records"
    __table_args__ = (
        CheckConstraint(
            "status IN ('processing', 'completed', 'failed', 'expired')",
            name="ck_ai_usage_record_status",
        ),
        CheckConstraint(
            "input_tokens IS NULL OR input_tokens >= 0",
            name="ck_ai_usage_record_input_tokens",
        ),
        CheckConstraint(
            "output_tokens IS NULL OR output_tokens >= 0",
            name="ck_ai_usage_record_output_tokens",
        ),
        CheckConstraint(
            "total_tokens IS NULL OR total_tokens >= 0",
            name="ck_ai_usage_record_total_tokens",
        ),
        Index("ix_ai_usage_records_created_at", "created_at"),
        Index(
            "ix_ai_usage_records_user_created_at",
            "user_id",
            "created_at",
        ),
        Index(
            "ix_ai_usage_records_active_lease",
            "status",
            "lease_expires_at",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("cloud_users.id"),
        nullable=False,
        index=True,
    )
    request_id: Mapped[str] = mapped_column(String(36), nullable=False)
    provider: Mapped[str] = mapped_column(String(32), nullable=False)
    model: Mapped[str] = mapped_column(String(128), nullable=False)
    request_type: Mapped[str] = mapped_column(String(32), nullable=False)
    input_tokens: Mapped[int | None] = mapped_column(Integer, nullable=True)
    output_tokens: Mapped[int | None] = mapped_column(Integer, nullable=True)
    total_tokens: Mapped[int | None] = mapped_column(Integer, nullable=True)
    status: Mapped[str] = mapped_column(String(24), nullable=False)
    created_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    updated_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    lease_expires_at: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    completed_at: Mapped[int | None] = mapped_column(BigInteger, nullable=True)


class AiReportFeedback(Base):
    __tablename__ = "ai_report_feedback"
    __table_args__ = (
        UniqueConstraint(
            "cloud_user_id",
            "report_record_id",
            "report_version_number",
            name="uq_ai_report_feedback_user_report_version",
        ),
        CheckConstraint(
            "helpfulness IN ('helpful', 'not_helpful')",
            name="ck_ai_report_feedback_helpfulness",
        ),
        CheckConstraint(
            "server_version >= 1",
            name="ck_ai_report_feedback_server_version",
        ),
        Index("ix_ai_report_feedback_prompt", "prompt_id", "prompt_version"),
        Index("ix_ai_report_feedback_updated", "updated_at"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    cloud_user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("cloud_users.id"),
        nullable=False,
        index=True,
    )
    report_record_id: Mapped[str] = mapped_column(String(36), nullable=False)
    report_version_number: Mapped[int] = mapped_column(Integer, nullable=False)
    report_type: Mapped[str] = mapped_column(String(32), nullable=False)
    helpfulness: Mapped[str] = mapped_column(String(16), nullable=False)
    reason_codes_json: Mapped[str] = mapped_column(Text, nullable=False)
    prompt_id: Mapped[str] = mapped_column(String(64), nullable=False)
    prompt_version: Mapped[str] = mapped_column(String(64), nullable=False)
    server_version: Mapped[int] = mapped_column(BigInteger, nullable=False)
    created_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    updated_at: Mapped[int] = mapped_column(BigInteger, nullable=False)
    deleted_at: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
