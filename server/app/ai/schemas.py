from __future__ import annotations

from datetime import date, timedelta
import json
from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.ai.prompt_contracts import (
    DAILY_CANDIDATE_PROMPT_VERSION,
    DAILY_PROMPT_VERSION,
    CHAT_PROMPT_VERSION,
    WEEKLY_CANDIDATE_PROMPT_VERSION,
    WEEKLY_PROMPT_VERSION,
)


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


class AiChatPeriod(StrictModel):
    start_date: date
    end_date: date

    @model_validator(mode="after")
    def require_bounded_period(self) -> "AiChatPeriod":
        delta = self.end_date - self.start_date
        if delta < timedelta(0) or delta > timedelta(days=6):
            raise ValueError("chat context period must contain one to seven dates")
        return self


class AiChatMessage(StrictModel):
    role: Literal["user", "assistant"]
    content: str = Field(min_length=1, max_length=2000)

    @field_validator("content")
    @classmethod
    def normalize_content(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("chat message must not be blank")
        return normalized


class AiChatTodayMetricData(StrictModel):
    record_date: date
    research_minutes: int | None = Field(default=None, ge=0)
    learning_minutes: int | None = Field(default=None, ge=0)
    mood_score: int | None = Field(default=None, ge=1, le=10)
    energy_score: int | None = Field(default=None, ge=1, le=10)
    wellbeing_score_scale: Literal[10] = 10
    populated_priority_count: int = Field(ge=0, le=3)
    completed_priority_count: int = Field(ge=0, le=3)
    status: Literal["draft", "completed", "skipped"]


class AiChatHealthMetricData(StrictModel):
    record_date: date
    sleep_duration_minutes: int | None = Field(default=None, ge=0)
    exercise_duration_minutes: int | None = Field(default=None, ge=0)
    physical_state_score: int | None = Field(default=None, ge=1, le=10)
    physical_state_score_scale: Literal[10] = 10
    water_intake_ml: int | None = Field(default=None, ge=0)
    weight_kg: float | int | None = Field(default=None, ge=0)


class AiChatContextData(StrictModel):
    growth_summary: GrowthSummaryData | None = None
    today_metrics: list[AiChatTodayMetricData] | None = Field(
        default=None, max_length=7
    )
    health_metrics: list[AiChatHealthMetricData] | None = Field(
        default=None, max_length=7
    )
    journal_reflections: list[JournalReflectionData] | None = Field(
        default=None, max_length=7
    )


CHAT_SCOPES = WEEKLY_SCOPES


class AiChatPayload(StrictModel):
    schema_version: Literal[1] = 1
    request_type: Literal["coach_chat"] = "coach_chat"
    prompt_version: Literal[CHAT_PROMPT_VERSION] = CHAT_PROMPT_VERSION
    messages: list[AiChatMessage] = Field(min_length=1, max_length=12)
    context_period: AiChatPeriod
    scopes: list[str] = Field(default_factory=list, max_length=4)
    optional_context: AiChatContextData
    sources: list[AiSource] = Field(default_factory=list, max_length=32)

    @property
    def report_type(self) -> str:
        # The existing ledger column retains its historical name. Chat remains
        # a separate request capability and never creates an AI Report row.
        return self.request_type

    @field_validator("scopes")
    @classmethod
    def unique_chat_scopes(cls, value: list[str]) -> list[str]:
        if len(value) != len(set(value)):
            raise ValueError("scopes must be unique")
        if any(item not in CHAT_SCOPES for item in value):
            raise ValueError("unsupported chat scope")
        return value

    @model_validator(mode="after")
    def validate_chat_contract(self) -> "AiChatPayload":
        if self.messages[0].role != "user" or self.messages[-1].role != "user":
            raise ValueError("chat must start and end with a user message")
        for previous, current in zip(self.messages, self.messages[1:]):
            if previous.role == current.role:
                raise ValueError("chat roles must alternate")
        if sum(len(item.content) for item in self.messages) > 12_000:
            raise ValueError("chat message history is too large")
        _validate_data_scope_match(
            self.optional_context,
            self.scopes,
            CHAT_SCOPES,
        )
        _validate_dates(
            self.optional_context,
            self.context_period.start_date,
            self.context_period.end_date,
        )
        encoded_context = json.dumps(
            self.optional_context.model_dump(mode="json", exclude_none=True),
            ensure_ascii=False,
            separators=(",", ":"),
        )
        if len(encoded_context) > 32_000:
            raise ValueError("chat optional context is too large")
        if not self.scopes and self.sources:
            raise ValueError("text-only chat cannot include source references")
        return self


def _validate_data_scope_match(
    data: AiWeeklyData | AiDailyData | AiChatContextData,
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
    data: AiWeeklyData | AiDailyData | AiChatContextData,
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


class AiChatTurnRequest(StrictModel):
    request_id: UUID
    input_hash: str = Field(pattern=r"^[0-9a-f]{64}$")
    payload: AiChatPayload


AiGenerateRequest = AiWeeklyGenerateRequest | AiDailyGenerateRequest | AiChatTurnRequest
AiInputPayload = AiWeeklyPayload | AiDailyPayload | AiChatPayload


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


class AiChatStructuredOutput(StrictModel):
    reply: str = Field(min_length=1, max_length=6000)
    safety_category: Literal["normal", "caution", "high_risk"]

    @field_validator("reply")
    @classmethod
    def normalize_reply(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("chat reply must not be blank")
        return normalized


AiStructuredOutput = Annotated[
    AiDailyStructuredOutput | AiWeeklyStructuredOutput | AiChatStructuredOutput,
    Field(union_mode="left_to_right"),
]


class AiReportContractResponse(StrictModel):
    report_type: Literal["daily_insight", "weekly_report"]
    prompt_versions: list[str] = Field(min_length=1)
    input_schema_version: Literal[1] = 1
    output_schema_version: Literal[1] = 1
    period_kind: Literal["single_day", "seven_days"]
    supported_scopes: list[str] = Field(min_length=1)


class AiChatContractResponse(StrictModel):
    request_type: Literal["coach_chat"] = "coach_chat"
    prompt_version: Literal[CHAT_PROMPT_VERSION] = CHAT_PROMPT_VERSION
    input_schema_version: Literal[1] = 1
    output_schema_version: Literal[1] = 1
    max_messages: Literal[12] = 12
    max_message_characters: Literal[2000] = 2000
    max_history_characters: Literal[12000] = 12000
    max_context_characters: Literal[32000] = 32000
    supported_scopes: list[str] = Field(max_length=4)
    streaming: Literal[False] = False


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
    chat_contract: AiChatContractResponse
    streaming: Literal[False] = False
    response_storage_requested: Literal[False] = False
    durable_request_ledger: Literal[True] = True
    request_status_recovery: Literal[True] = True
    result_retention_hours: int = Field(gt=0)
    dedupe_retention_days: int = Field(gt=0)
    processing_lease_minutes: int = Field(gt=0)
    exactly_once_guaranteed: Literal[False] = False


class AiUsageResponse(StrictModel):
    enabled: bool
    status: Literal["available", "disabled", "limit_reached"]
    daily_limit: int = Field(gt=0)
    used: int = Field(ge=0)
    remaining: int = Field(ge=0)
    resets_at: int = Field(gt=0)
    reset_timezone: Literal["UTC"] = "UTC"


class AiWeeklyGenerateResponse(StrictModel):
    request_id: UUID
    report_type: Literal["weekly_report"] = "weekly_report"
    prompt_version: Literal[WEEKLY_PROMPT_VERSION] = WEEKLY_PROMPT_VERSION
    input_hash: str = Field(pattern=r"^[0-9a-f]{64}$")
    provider: str
    model: str
    output_schema_version: Literal[1] = 1
    report_content: str = Field(min_length=1)
    structured_output: AiWeeklyStructuredOutput


class AiDailyGenerateResponse(StrictModel):
    request_id: UUID
    report_type: Literal["daily_insight"] = "daily_insight"
    prompt_version: Literal[DAILY_PROMPT_VERSION] = DAILY_PROMPT_VERSION
    input_hash: str = Field(pattern=r"^[0-9a-f]{64}$")
    provider: str
    model: str
    output_schema_version: Literal[1] = 1
    report_content: str = Field(min_length=1)
    structured_output: AiDailyStructuredOutput


class AiChatTurnResponse(StrictModel):
    request_id: UUID
    request_type: Literal["coach_chat"] = "coach_chat"
    prompt_version: Literal[CHAT_PROMPT_VERSION] = CHAT_PROMPT_VERSION
    input_hash: str = Field(pattern=r"^[0-9a-f]{64}$")
    provider: str
    model: str
    output_schema_version: Literal[1] = 1
    reply: str = Field(min_length=1, max_length=6000)
    safety_category: Literal["normal", "caution", "high_risk"]
    structured_output: AiChatStructuredOutput

    @property
    def report_type(self) -> str:
        return self.request_type

    @property
    def report_content(self) -> str:
        return self.reply


class AiWeeklyCandidateGenerateResponse(AiWeeklyGenerateResponse):
    prompt_version: Literal[WEEKLY_CANDIDATE_PROMPT_VERSION] = (
        WEEKLY_CANDIDATE_PROMPT_VERSION
    )


class AiDailyCandidateGenerateResponse(AiDailyGenerateResponse):
    prompt_version: Literal[DAILY_CANDIDATE_PROMPT_VERSION] = (
        DAILY_CANDIDATE_PROMPT_VERSION
    )


AiGenerateResponse = AiWeeklyGenerateResponse | AiDailyGenerateResponse | AiChatTurnResponse


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


AiReportFeedbackReason = Literal[
    "repetitive",
    "not_factually_grounded",
    "not_actionable",
    "too_generic",
    "missed_important_context",
    "tone_not_helpful",
    "hard_to_understand",
]


class AiReportFeedbackWriteRequest(StrictModel):
    feedback_id: UUID
    report_id: UUID
    report_version: int = Field(ge=1)
    report_type: Literal["daily_insight", "weekly_report"]
    helpfulness: Literal["helpful", "not_helpful"]
    reason_codes: list[AiReportFeedbackReason] = Field(max_length=7)
    prompt_id: Literal["daily_insight", "weekly_report"]
    prompt_version: str = Field(min_length=1, max_length=64)
    expected_server_version: int | None = Field(default=None, ge=1)

    @model_validator(mode="after")
    def validate_feedback(self) -> "AiReportFeedbackWriteRequest":
        if len(set(self.reason_codes)) != len(self.reason_codes):
            raise ValueError("feedback reasons must be unique")
        if self.reason_codes != sorted(self.reason_codes):
            raise ValueError("feedback reasons must use canonical order")
        if self.helpfulness == "helpful" and self.reason_codes:
            raise ValueError("helpful feedback cannot include reasons")
        if self.helpfulness == "not_helpful" and not self.reason_codes:
            raise ValueError("not helpful feedback requires a reason")
        if self.prompt_id != self.report_type:
            raise ValueError("prompt identity must match report type")
        return self


class AiReportFeedbackDeleteRequest(StrictModel):
    feedback_id: UUID
    report_id: UUID
    report_version: int = Field(ge=1)
    expected_server_version: int | None = Field(default=None, ge=1)


class AiReportFeedbackItem(StrictModel):
    feedback_id: UUID
    report_id: UUID
    report_version: int
    report_type: str
    helpfulness: Literal["helpful", "not_helpful"]
    reason_codes: list[AiReportFeedbackReason]
    prompt_id: str
    prompt_version: str
    server_version: int
    created_at: int
    updated_at: int
    deleted_at: int | None


class AiReportFeedbackMutationResponse(StrictModel):
    outcome: Literal["applied", "conflict"]
    item: AiReportFeedbackItem


class AiReportFeedbackListResponse(StrictModel):
    items: list[AiReportFeedbackItem]
