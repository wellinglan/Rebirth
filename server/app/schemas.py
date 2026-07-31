from __future__ import annotations

from datetime import date
import re
from typing import Any, Literal
from uuid import UUID

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
    model_validator,
)


Platform = Literal["windows", "android", "ios", "macos", "web"]
MobilePlatform = Literal["android", "ios"]
SyncTable = Literal[
    "user_profiles",
    "today_records",
    "journal_prompt_configurations",
    "journal_entries",
    "goals",
    "health_records",
]
PlanGoalLevel = Literal["life", "year", "quarter", "month", "week", "day", "custom"]
PlanGoalStatus = Literal[
    "not_started",
    "in_progress",
    "completed",
    "paused",
    "cancelled",
]
TodayRecordStatus = Literal["draft", "completed"]
JournalEntryStatus = Literal["draft", "completed"]
JournalPromptSource = Literal["system", "user", "future_ai"]
JournalResponseKind = Literal["long_text"]
HealthDataSource = Literal["manual", "health_connect", "apple_health"]


class PlanSyncPayload(BaseModel):
    model_config = ConfigDict(extra="ignore")

    parent_goal_id: str | None
    title: str
    description: str | None
    goal_level: PlanGoalLevel
    status: PlanGoalStatus
    start_date: str | None
    target_date: str | None
    completed_at: int | None = Field(ge=0)
    archived_at: int | None = Field(ge=0)
    sort_order: int = Field(ge=0)
    created_at: int = Field(ge=0)

    @field_validator("parent_goal_id")
    @classmethod
    def validate_parent_goal_id(cls, value: str | None) -> str | None:
        if value is None:
            return None
        UUID(value)
        return value

    @field_validator("title")
    @classmethod
    def validate_title(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("title must not be blank")
        return value.strip()

    @field_validator("start_date", "target_date")
    @classmethod
    def validate_local_date(cls, value: str | None) -> str | None:
        if value is None:
            return None
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
            raise ValueError("date must use YYYY-MM-DD")
        date.fromisoformat(value)
        return value

    @model_validator(mode="after")
    def validate_business_consistency(self) -> "PlanSyncPayload":
        if (
            self.start_date is not None
            and self.target_date is not None
            and self.target_date < self.start_date
        ):
            raise ValueError("target_date must not be before start_date")
        if self.status == "completed" and self.completed_at is None:
            raise ValueError("completed goals require completed_at")
        if self.status != "completed" and self.completed_at is not None:
            raise ValueError("non-completed goals must not have completed_at")
        return self


class TodaySyncPayload(BaseModel):
    model_config = ConfigDict(extra="forbid")

    record_date: str
    timezone_offset_minutes: int = Field(ge=-840, le=840)
    priority_1: str | None
    priority_1_completed: bool
    priority_1_goal_id: str | None
    priority_2: str | None
    priority_2_completed: bool
    priority_2_goal_id: str | None
    priority_3: str | None
    priority_3_completed: bool
    priority_3_goal_id: str | None
    mood_score: int | None = Field(default=None, ge=1, le=5)
    energy_score: int | None = Field(default=None, ge=1, le=5)
    research_minutes: int | None = Field(default=None, ge=0)
    learning_minutes: int | None = Field(default=None, ge=0)
    daily_note: str | None
    record_status: TodayRecordStatus
    created_at: int = Field(ge=0)

    @field_validator("record_date")
    @classmethod
    def validate_record_date(cls, value: str) -> str:
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
            raise ValueError("record_date must use YYYY-MM-DD")
        date.fromisoformat(value)
        return value

    @field_validator(
        "priority_1_goal_id",
        "priority_2_goal_id",
        "priority_3_goal_id",
    )
    @classmethod
    def validate_goal_id(cls, value: str | None) -> str | None:
        if value is None:
            return None
        UUID(value)
        return value

    @field_validator("priority_1", "priority_2", "priority_3")
    @classmethod
    def validate_priority_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        trimmed = value.strip()
        if not trimmed:
            raise ValueError("priority text must not be blank")
        return trimmed

    @model_validator(mode="after")
    def validate_priority_consistency(self) -> "TodaySyncPayload":
        priorities = (
            (self.priority_1, self.priority_1_completed, self.priority_1_goal_id),
            (self.priority_2, self.priority_2_completed, self.priority_2_goal_id),
            (self.priority_3, self.priority_3_completed, self.priority_3_goal_id),
        )
        if any(
            text is None and (completed or goal_id is not None)
            for text, completed, goal_id in priorities
        ):
            raise ValueError(
                "empty priorities cannot be completed or linked to goals"
            )
        return self


class JournalPromptItemSyncPayload(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str
    source_prompt_id: str | None
    source_prompt_stable_key: str | None
    source_prompt_version: int = Field(ge=1)
    prompt_source: JournalPromptSource
    question_text_snapshot: str = Field(min_length=1, max_length=500)
    helper_text_snapshot: str | None = Field(default=None, max_length=500)
    response_kind: JournalResponseKind
    display_order: int = Field(ge=0)
    answer_text: str | None = Field(default=None, max_length=20000)
    created_at: int = Field(ge=0)
    updated_at: int = Field(ge=0)

    @field_validator("id", "source_prompt_id")
    @classmethod
    def validate_uuid(cls, value: str | None) -> str | None:
        if value is not None:
            UUID(value)
        return value

    @field_validator(
        "question_text_snapshot",
        "helper_text_snapshot",
        "answer_text",
    )
    @classmethod
    def validate_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        trimmed = value.strip()
        if not trimmed:
            raise ValueError("Journal prompt text must not be blank")
        return trimmed


class JournalSyncPayload(BaseModel):
    model_config = ConfigDict(extra="forbid")

    entry_date: str
    timezone_offset_minutes: int = Field(ge=-840, le=840)
    journal_payload_schema_version: Literal[2] | None = None
    prompt_items: list[JournalPromptItemSyncPayload] | None = None
    most_important_accomplishment: str | None = None
    most_draining_event: str | None = None
    emotion_source: str | None = None
    learning: str | None = None
    tomorrow_adjustment: str | None = None
    entry_status: JournalEntryStatus
    created_at: int = Field(ge=0)

    @field_validator("entry_date")
    @classmethod
    def validate_entry_date(cls, value: str) -> str:
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
            raise ValueError("entry_date must use YYYY-MM-DD")
        date.fromisoformat(value)
        return value

    @field_validator(
        "most_important_accomplishment",
        "most_draining_event",
        "emotion_source",
        "learning",
        "tomorrow_adjustment",
    )
    @classmethod
    def validate_content(cls, value: str | None) -> str | None:
        if value is None:
            return None
        trimmed = value.strip()
        if not trimmed or len(value) > 20000:
            raise ValueError("Journal content must be valid")
        return trimmed

    @model_validator(mode="after")
    def validate_has_content(self) -> "JournalSyncPayload":
        v1_fields = {
            "most_important_accomplishment",
            "most_draining_event",
            "emotion_source",
            "learning",
            "tomorrow_adjustment",
        }
        if self.journal_payload_schema_version == 2:
            if self.prompt_items is None or self.model_fields_set & v1_fields:
                raise ValueError("Journal v2 must use prompt_items only")
            ids = {item.id for item in self.prompt_items}
            identities = {
                (item.source_prompt_id, item.source_prompt_version)
                for item in self.prompt_items
                if item.source_prompt_id is not None
            }
            source_count = sum(
                item.source_prompt_id is not None for item in self.prompt_items
            )
            if (
                not self.prompt_items
                or len(self.prompt_items) > 100
                or len(ids) != len(self.prompt_items)
                or len(identities) != source_count
                or not any(item.answer_text for item in self.prompt_items)
            ):
                raise ValueError("Journal v2 prompt_items are invalid")
            return self
        if self.prompt_items is not None or not v1_fields.issubset(
            self.model_fields_set
        ):
            raise ValueError("Journal v1 fields are incomplete")
        if not any(
            (
                self.most_important_accomplishment,
                self.most_draining_event,
                self.emotion_source,
                self.learning,
                self.tomorrow_adjustment,
            )
        ):
            raise ValueError("Journal requires at least one content field")
        return self


class JournalPromptDefinitionSyncPayload(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str
    stable_key: str | None
    source: JournalPromptSource
    question_text: str = Field(min_length=1, max_length=500)
    helper_text: str | None = Field(default=None, max_length=500)
    response_kind: JournalResponseKind
    display_order: int = Field(ge=0)
    is_enabled: bool
    prompt_version: int = Field(ge=1)
    created_at: int = Field(ge=0)
    updated_at: int = Field(ge=0)
    deleted_at: int | None = Field(default=None, ge=0)

    @field_validator("id")
    @classmethod
    def validate_id(cls, value: str) -> str:
        UUID(value)
        return value

    @field_validator("question_text", "helper_text")
    @classmethod
    def validate_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        trimmed = value.strip()
        if not trimmed:
            raise ValueError("Journal prompt text must not be blank")
        return trimmed

    @model_validator(mode="after")
    def validate_source_identity(self) -> "JournalPromptDefinitionSyncPayload":
        if self.source == "system":
            if self.stable_key is None or not self.stable_key.strip():
                raise ValueError("System prompts require stable_key")
        elif self.stable_key is not None:
            raise ValueError("Non-system prompts cannot use stable_key")
        if self.deleted_at is not None and self.is_enabled:
            raise ValueError("Deleted prompts cannot be enabled")
        return self


class JournalPromptConfigurationSyncPayload(BaseModel):
    model_config = ConfigDict(extra="forbid")

    payload_schema_version: Literal[1]
    logical_key: Literal["default"]
    configuration_version: int = Field(ge=1)
    created_at: int = Field(ge=0)
    prompts: list[JournalPromptDefinitionSyncPayload] = Field(
        min_length=1,
        max_length=100,
    )

    @model_validator(mode="after")
    def validate_prompt_set(self) -> "JournalPromptConfigurationSyncPayload":
        ids = {prompt.id for prompt in self.prompts}
        stable_keys = {
            prompt.stable_key
            for prompt in self.prompts
            if prompt.stable_key is not None
        }
        enabled_count = sum(
            prompt.deleted_at is None and prompt.is_enabled
            for prompt in self.prompts
        )
        if len(ids) != len(self.prompts):
            raise ValueError("Prompt IDs must be unique")
        if len(stable_keys) != sum(
            prompt.stable_key is not None for prompt in self.prompts
        ):
            raise ValueError("System stable keys must be unique")
        if enabled_count < 1 or enabled_count > 20:
            raise ValueError("Enabled prompt count is invalid")
        return self


class HealthSyncPayload(BaseModel):
    model_config = ConfigDict(extra="forbid")

    record_date: str
    timezone_offset_minutes: int = Field(ge=-840, le=840)
    sleep_duration_minutes: int | None = Field(default=None, ge=0)
    weight_kg: float | None = Field(default=None, gt=0)
    water_intake_ml: int | None = Field(default=None, ge=0)
    exercise_type: str | None
    exercise_duration_minutes: int | None = Field(default=None, ge=0)
    physical_state_score: int | None = Field(default=None, ge=1, le=5)
    note: str | None
    data_source: HealthDataSource
    source_record_id: str | None
    created_at: int = Field(ge=0)

    @field_validator("record_date")
    @classmethod
    def validate_record_date(cls, value: str) -> str:
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
            raise ValueError("record_date must use YYYY-MM-DD")
        date.fromisoformat(value)
        return value

    @field_validator("exercise_type", "note", "source_record_id")
    @classmethod
    def validate_optional_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        trimmed = value.strip()
        if not trimmed:
            raise ValueError("Health text must not be blank")
        return trimmed


class HealthResponse(BaseModel):
    status: Literal["ok"] = "ok"
    service: Literal["rebirth-api"] = "rebirth-api"
    api_version: Literal[1] = 1
    sync_protocol_version: Literal[2] = 2
    environment: str


class DevLoginRequest(BaseModel):
    dev_user_key: str = Field(min_length=1, max_length=128)
    client_installation_id: str | None = Field(
        default=None,
        min_length=1,
        max_length=128,
    )
    platform: Platform | None = None
    app_version: str | None = Field(default=None, min_length=1, max_length=64)

    @field_validator("dev_user_key")
    @classmethod
    def trim_dev_user_key(cls, value: str) -> str:
        trimmed = value.strip()
        if not trimmed:
            raise ValueError("dev_user_key must not be blank")
        return trimmed


class AuthUserResponse(BaseModel):
    id: str
    display_name: str | None


class AuthIdentitySummaryResponse(BaseModel):
    provider: str
    created_at: int
    last_used_at: int | None


class AuthIdentitiesResponse(BaseModel):
    identities: list[AuthIdentitySummaryResponse]


class WeChatBindingStartResponse(BaseModel):
    status: Literal["provider_unavailable"] = "provider_unavailable"
    provider: Literal["wechat"] = "wechat"
    requires_reauthentication: Literal[True] = True
    message: str = "WeChat binding is not configured in this release."


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: Literal["bearer"] = "bearer"
    access_expires_at: int
    refresh_expires_at: int
    session_id: str
    session_absolute_expires_at: int
    identity_provider: str
    user: AuthUserResponse


class PasswordRegisterRequest(BaseModel):
    username: str = Field(min_length=4, max_length=64)
    password: str = Field(min_length=12, max_length=128)
    display_name: str | None = Field(default=None, max_length=128)
    client_installation_id: str | None = Field(
        default=None,
        min_length=1,
        max_length=128,
    )
    platform: Platform | None = None
    app_version: str | None = Field(default=None, min_length=1, max_length=64)


class PasswordLoginRequest(BaseModel):
    username: str = Field(min_length=4, max_length=64)
    password: str = Field(min_length=1, max_length=128)
    client_installation_id: str | None = Field(
        default=None,
        min_length=1,
        max_length=128,
    )
    platform: Platform | None = None
    app_version: str | None = Field(default=None, min_length=1, max_length=64)


class RefreshTokenRequest(BaseModel):
    refresh_token: str = Field(min_length=1, max_length=4096)
    client_installation_id: str | None = Field(
        default=None,
        min_length=1,
        max_length=128,
    )
    platform: Platform | None = None
    app_version: str | None = Field(default=None, min_length=1, max_length=64)


class LogoutRequest(BaseModel):
    refresh_token: str | None = Field(default=None, min_length=1, max_length=4096)


class LogoutResponse(BaseModel):
    status: Literal["signed_out"] = "signed_out"


class AuthSessionResponse(BaseModel):
    session_id: str
    provider: str
    access_expires_at: int
    session_absolute_expires_at: int
    revoked: Literal[False] = False
    user: AuthUserResponse


class PasswordAttachRequest(BaseModel):
    dev_user_key: str = Field(min_length=1, max_length=128)
    username: str = Field(min_length=4, max_length=64)
    password: str = Field(min_length=12, max_length=128)
    display_name: str | None = Field(default=None, max_length=128)


class PasswordAttachResponse(BaseModel):
    status: Literal["attached"] = "attached"
    provider: Literal["password_username"] = "password_username"
    user: AuthUserResponse


class WeChatMobileRequest(BaseModel):
    code: str = Field(min_length=1)
    platform: MobilePlatform


class NotImplementedResponse(BaseModel):
    status: Literal["not_implemented"] = "not_implemented"
    message: str = "WeChat login requires configured Open Platform credentials."


class DeviceRegisterRequest(BaseModel):
    local_installation_id: str = Field(min_length=1, max_length=128)
    platform: Platform
    device_name: str = Field(min_length=1, max_length=128)
    app_version: str = Field(min_length=1, max_length=64)


class DeviceRegisterResponse(BaseModel):
    device_id: str
    server_time: int


class SyncPushItem(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    table_name: SyncTable = Field(alias="table")
    record_id: str = Field(alias="id", min_length=1, max_length=128)
    payload: dict[str, Any]
    updated_at: int = Field(ge=0)
    deleted_at: int | None = Field(default=None, ge=0)
    origin_device_id: str = Field(min_length=1, max_length=128)
    client_version: int = Field(ge=0)


class SyncPushRequest(BaseModel):
    device_id: str = Field(min_length=1)
    items: list[SyncPushItem] = Field(max_length=500)


class SyncAcceptedItem(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    table_name: str = Field(alias="table")
    record_id: str = Field(alias="id")
    server_version: int


class SyncConflictResponse(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    table_name: str = Field(alias="table")
    record_id: str = Field(alias="id")
    server_version: int
    reason: str
    remote_record_id: str | None = None


class SyncPushResponse(BaseModel):
    accepted: list[SyncAcceptedItem]
    conflicts: list[SyncConflictResponse]


class SyncPullRequest(BaseModel):
    device_id: str = Field(min_length=1)
    since_server_version: int = Field(ge=0)
    tables: list[SyncTable] = Field(min_length=1, max_length=20)


class SyncPullItem(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    table_name: str = Field(alias="table")
    record_id: str = Field(alias="id")
    payload: dict[str, Any]
    updated_at: int
    deleted_at: int | None
    origin_device_id: str
    server_version: int


class SyncPullResponse(BaseModel):
    server_version: int
    items: list[SyncPullItem]


OwnershipVerificationTable = Literal["user_profiles", "goals"]
OwnershipVerificationStatus = Literal["verified", "unknown", "rejected"]


class OwnershipVerificationEvidence(BaseModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    table_name: OwnershipVerificationTable = Field(alias="table")
    record_id: str = Field(alias="id", min_length=1, max_length=128)
    server_version: int = Field(ge=1)
    metadata_fingerprint: str = Field(
        pattern=r"^[0-9a-f]{64}$",
    )


class OwnershipVerificationRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    evidence: list[OwnershipVerificationEvidence] = Field(max_length=500)


class OwnershipVerificationResponse(BaseModel):
    status: OwnershipVerificationStatus
    verified_count: int = Field(ge=0)
    rejected_count: int = Field(ge=0)
    unknown_count: int = Field(ge=0)
    reason: str
