from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


Platform = Literal["windows", "android", "ios", "macos", "web"]
MobilePlatform = Literal["android", "ios"]
SyncTable = Literal[
    "user_profiles",
    "today_records",
    "journal_entries",
    "goals",
    "health_records",
]


class HealthResponse(BaseModel):
    status: Literal["ok"] = "ok"
    service: Literal["rebirth-api"] = "rebirth-api"


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
