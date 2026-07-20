from __future__ import annotations

from datetime import date, timedelta
from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class AiPeriod(StrictModel):
    start_date: date
    end_date: date

    @model_validator(mode="after")
    def require_seven_day_period(self) -> "AiPeriod":
        if self.end_date - self.start_date != timedelta(days=6):
            raise ValueError("weekly period must contain exactly seven dates")
        return self


class AiDailyPeriod(StrictModel):
    start_date: date
    end_date: date

    @model_validator(mode="after")
    def require_single_day_period(self) -> "AiDailyPeriod":
        if self.start_date != self.end_date:
            raise ValueError("daily period must contain exactly one date")
        return self


class AiSource(StrictModel):
    table: Literal["today_records", "health_records", "journal_entries"]
    id: str = Field(min_length=1, max_length=128)
    updated_at: int = Field(ge=0)


class MetricSummary(StrictModel):
    recorded_day_count: int = Field(ge=0, le=7)
    total: float | int
    average: float | int | None
    minimum: float | int | None
    maximum: float | int | None


class GrowthSummaryData(StrictModel):
    period_days: Literal[7]
    research: MetricSummary
    learning: MetricSummary
    exercise: MetricSummary
    sleep: MetricSummary
    mood: MetricSummary
    energy: MetricSummary
    journal_recorded_days: int = Field(ge=0, le=7)
    journal_completed_days: int = Field(ge=0, le=7)


class TodayMetricData(StrictModel):
    record_date: date
    research_minutes: int | None = Field(default=None, ge=0)
    learning_minutes: int | None = Field(default=None, ge=0)
    mood_score: int | None = Field(default=None, ge=1, le=5)
    energy_score: int | None = Field(default=None, ge=1, le=5)
    populated_priority_count: int = Field(ge=0, le=3)
    completed_priority_count: int = Field(ge=0, le=3)
    status: Literal["draft", "completed", "skipped"]


class HealthMetricData(StrictModel):
    record_date: date
    sleep_duration_minutes: int | None = Field(default=None, ge=0)
    exercise_duration_minutes: int | None = Field(default=None, ge=0)
    physical_state_score: int | None = Field(default=None, ge=1, le=5)
    water_intake_ml: int | None = Field(default=None, ge=0)
    weight_kg: float | int | None = Field(default=None, ge=0)


class JournalReflectionData(StrictModel):
    entry_date: date
    status: Literal["draft", "completed", "skipped"]
    most_important_accomplishment: str | None
    most_draining_event: str | None
    emotion_source: str | None
    learning: str | None
    tomorrow_adjustment: str | None


class AiWeeklyData(StrictModel):
    growth_summary: GrowthSummaryData | None = None
    today_metrics: list[TodayMetricData] | None = Field(default=None, max_length=7)
    health_metrics: list[HealthMetricData] | None = Field(default=None, max_length=7)
    journal_reflections: list[JournalReflectionData] | None = Field(
        default=None, max_length=7
    )


class AiDailyData(StrictModel):
    today_metrics: list[TodayMetricData] | None = Field(default=None, max_length=1)
    health_metrics: list[HealthMetricData] | None = Field(default=None, max_length=1)
    journal_reflections: list[JournalReflectionData] | None = Field(
        default=None, max_length=1
    )


WEEKLY_SCOPES = frozenset(
    {
        "growth_summary",
        "today_metrics",
        "health_metrics",
        "journal_reflections",
    }
)
DAILY_SCOPES = frozenset(
    {"today_metrics", "health_metrics", "journal_reflections"}
)


class AiWeeklyPayload(StrictModel):
    schema_version: int
    report_type: str
    prompt_version: str
    period: AiPeriod
    scopes: list[str] = Field(min_length=1, max_length=4)
    data: AiWeeklyData
    sources: list[AiSource]

    @field_validator("scopes")
    @classmethod
    def unique_scopes(cls, value: list[str]) -> list[str]:
        if len(value) != len(set(value)):
            raise ValueError("scopes must be unique")
        return value

    @model_validator(mode="after")
    def data_matches_scopes(self) -> "AiWeeklyPayload":
        _validate_data_scope_match(self.data, self.scopes, WEEKLY_SCOPES)
        _validate_dates(self.data, self.period.start_date, self.period.end_date)
        return self


class AiDailyPayload(StrictModel):
    schema_version: int
    report_type: str
    prompt_version: str
    period: AiDailyPeriod
    scopes: list[str] = Field(min_length=1, max_length=3)
    data: AiDailyData
    sources: list[AiSource]

    @field_validator("scopes")
    @classmethod
    def unique_scopes(cls, value: list[str]) -> list[str]:
        if len(value) != len(set(value)):
            raise ValueError("scopes must be unique")
        return value

    @model_validator(mode="after")
    def data_matches_scopes(self) -> "AiDailyPayload":
        _validate_data_scope_match(self.data, self.scopes, DAILY_SCOPES)
        _validate_dates(self.data, self.period.start_date, self.period.end_date)
        return self


def _validate_data_scope_match(
    data: AiWeeklyData | AiDailyData,
    scopes: list[str],
    known_scopes: frozenset[str],
) -> None:
    present = {
        name
        for name in known_scopes
        if hasattr(data, name) and getattr(data, name) is not None
    }
    if present != set(scopes).intersection(known_scopes):
        raise ValueError("data fields must exactly match selected scopes")


def _validate_dates(
    data: AiWeeklyData | AiDailyData,
    start_date: date,
    end_date: date,
) -> None:
    for rows, date_field in (
        (data.today_metrics, "record_date"),
        (data.health_metrics, "record_date"),
        (data.journal_reflections, "entry_date"),
    ):
        for row in rows or []:
            value = getattr(row, date_field)
            if value < start_date or value > end_date:
                raise ValueError("data date must be inside the report period")


class AiWeeklyGenerateRequest(StrictModel):
    request_id: UUID
    input_hash: str = Field(pattern=r"^[0-9a-f]{64}$")
    payload: AiWeeklyPayload


class AiDailyGenerateRequest(StrictModel):
    request_id: UUID
    input_hash: str = Field(pattern=r"^[0-9a-f]{64}$")
    payload: AiDailyPayload


AiGenerateRequest = AiWeeklyGenerateRequest | AiDailyGenerateRequest
AiInputPayload = AiWeeklyPayload | AiDailyPayload


class AiObservation(StrictModel):
    statement: str = Field(min_length=1)
    evidence: list[str]

    @field_validator("statement")
    @classmethod
    def reject_blank_statement(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("statement must not be blank")
        return value.strip()


class AiSuggestion(StrictModel):
    action: str = Field(min_length=1)
    reason: str = Field(min_length=1)


class AiWeeklyStructuredOutput(StrictModel):
    title: str = Field(min_length=1)
    summary: str = Field(min_length=1)
    observations: list[AiObservation] = Field(max_length=5)
    suggestions: list[AiSuggestion] = Field(max_length=3)
    data_limitations: list[str]

    @field_validator("title", "summary")
    @classmethod
    def reject_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("value must not be blank")
        return value.strip()


class AiPossibleFactor(StrictModel):
    factor: str = Field(min_length=1)
    caveat: str = Field(min_length=1)

    @field_validator("factor", "caveat")
    @classmethod
    def reject_blank_factor_text(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("factor text must not be blank")
        return value.strip()


class AiTomorrowAdjustment(StrictModel):
    action: str = Field(min_length=1)
    reason: str = Field(min_length=1)

    @field_validator("action", "reason")
    @classmethod
    def reject_blank_adjustment_text(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("adjustment text must not be blank")
        return value.strip()


class AiDailyStructuredOutput(StrictModel):
    title: str = Field(min_length=1)
    summary: str = Field(min_length=1)
    observations: list[AiObservation] = Field(max_length=4)
    possible_factors: list[AiPossibleFactor] = Field(max_length=3)
    tomorrow_adjustments: list[AiTomorrowAdjustment] = Field(max_length=3)
    data_limitations: list[str]

    @field_validator("title", "summary")
    @classmethod
    def reject_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("value must not be blank")
        return value.strip()


AiStructuredOutput = Annotated[
    AiDailyStructuredOutput | AiWeeklyStructuredOutput,
    Field(union_mode="left_to_right"),
]


class AiReportContractResponse(StrictModel):
    report_type: Literal["daily_insight", "weekly_report"]
    prompt_versions: list[str] = Field(min_length=1)
    input_schema_version: Literal[1] = 1
    output_schema_version: Literal[1] = 1
    period_kind: Literal["single_day", "seven_days"]
    supported_scopes: list[str] = Field(min_length=1)


class AiCapabilitiesResponse(StrictModel):
    enabled: bool
    provider: str
    provider_label: str
    model: str | None
    supported_report_types: list[str]
    prompt_versions: list[str]
    input_schema_version: Literal[1] = 1
    output_schema_version: Literal[1] = 1
    report_contracts: list[AiReportContractResponse] = Field(min_length=2)
    streaming: Literal[False] = False
    response_storage_requested: Literal[False] = False
    durable_request_ledger: Literal[True] = True
    request_status_recovery: Literal[True] = True
    result_retention_hours: int = Field(gt=0)
    dedupe_retention_days: int = Field(gt=0)
    processing_lease_minutes: int = Field(gt=0)
    exactly_once_guaranteed: Literal[False] = False


class AiWeeklyGenerateResponse(StrictModel):
    request_id: UUID
    report_type: Literal["weekly_report"] = "weekly_report"
    prompt_version: Literal["weekly-report-v1"] = "weekly-report-v1"
    input_hash: str = Field(pattern=r"^[0-9a-f]{64}$")
    provider: str
    model: str
    output_schema_version: Literal[1] = 1
    report_content: str = Field(min_length=1)
    structured_output: AiWeeklyStructuredOutput


class AiDailyGenerateResponse(StrictModel):
    request_id: UUID
    report_type: Literal["daily_insight"] = "daily_insight"
    prompt_version: Literal["daily-insight-v1"] = "daily-insight-v1"
    input_hash: str = Field(pattern=r"^[0-9a-f]{64}$")
    provider: str
    model: str
    output_schema_version: Literal[1] = 1
    report_content: str = Field(min_length=1)
    structured_output: AiDailyStructuredOutput


AiGenerateResponse = AiWeeklyGenerateResponse | AiDailyGenerateResponse


AiRequestStatus = Literal[
    "processing",
    "completed",
    "failed",
    "outcome_unknown",
    "result_expired",
]


class AiRequestStatusResponse(StrictModel):
    request_id: UUID
    input_hash: str = Field(pattern=r"^[0-9a-f]{64}$")
    report_type: str
    prompt_version: str
    status: AiRequestStatus
    provider: str | None = None
    model: str | None = None
    output_schema_version: int | None = None
    report_content: str | None = None
    structured_output: AiStructuredOutput | None = None
    error_code: str | None = None
    created_at: int
    lease_expires_at: int | None = None
    result_expires_at: int | None = None
    outcome_note: str | None = None


class AiErrorDetail(StrictModel):
    code: str
    message: str


class AiErrorResponse(StrictModel):
    detail: AiErrorDetail
