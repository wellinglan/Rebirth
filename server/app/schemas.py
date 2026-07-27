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


class HealthResponse(BaseModel):
    status: Literal["ok"] = "ok"
    service: Literal["rebirth-api"] = "rebirth-api"
    api_version: Literal[1] = 1
    sync_protocol_version: Literal[2] = 2
    environment: str


class DevLoginRequest(BaseModel):
    dev_user_key: str = Field(min_length=1, max_length=128)

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


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: Literal["bearer"] = "bearer"
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
