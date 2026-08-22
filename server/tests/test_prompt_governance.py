from __future__ import annotations

from dataclasses import replace

import pytest

from app.ai.prompt_contracts import (
    CHAT_PROMPT_ID,
    CHAT_PROMPT_VERSION,
    DAILY_CANDIDATE_PROMPT_VERSION,
    DAILY_CHINESE_PROMPT_VERSION,
    DAILY_PROMPT_ID,
    DAILY_PROMPT_VERSION,
    WEEKLY_CANDIDATE_PROMPT_VERSION,
    WEEKLY_CHINESE_PROMPT_VERSION,
    WEEKLY_PROMPT_ID,
    WEEKLY_PROMPT_VERSION,
)
from app.ai.prompts import (
    PROMPT_REGISTRY,
    PromptRegistry,
    PromptRegistryError,
    PromptStatus,
    all_prompt_definitions,
    chat_definition,
    get_generation_prompt,
    report_definitions,
)
from app.ai.schemas import (
    AiChatTurnResponse,
    AiDailyCandidateGenerateResponse,
    AiDailyChineseGenerateResponse,
    AiWeeklyCandidateGenerateResponse,
    AiWeeklyChineseGenerateResponse,
)


def test_registry_has_explicit_active_and_candidate_versions() -> None:
    definitions = all_prompt_definitions()
    assert [item.prompt_version for item in definitions] == [
        CHAT_PROMPT_VERSION,
        DAILY_PROMPT_VERSION,
        DAILY_CANDIDATE_PROMPT_VERSION,
        DAILY_CHINESE_PROMPT_VERSION,
        WEEKLY_PROMPT_VERSION,
        WEEKLY_CANDIDATE_PROMPT_VERSION,
        WEEKLY_CHINESE_PROMPT_VERSION,
    ]
    assert [item.prompt_version for item in report_definitions()] == [
        DAILY_CHINESE_PROMPT_VERSION,
        WEEKLY_CHINESE_PROMPT_VERSION,
    ]
    assert PROMPT_REGISTRY.require_active(DAILY_PROMPT_ID).status is PromptStatus.ACTIVE
    assert PROMPT_REGISTRY.require_active(WEEKLY_PROMPT_ID).status is PromptStatus.ACTIVE
    assert PROMPT_REGISTRY.require_active(CHAT_PROMPT_ID).status is PromptStatus.ACTIVE


def test_candidate_never_becomes_generation_prompt_implicitly() -> None:
    assert get_generation_prompt(CHAT_PROMPT_ID, CHAT_PROMPT_VERSION) is not None
    assert get_generation_prompt(DAILY_PROMPT_ID, DAILY_PROMPT_VERSION) is not None
    assert get_generation_prompt(WEEKLY_PROMPT_ID, WEEKLY_PROMPT_VERSION) is not None
    assert (
        get_generation_prompt(DAILY_PROMPT_ID, DAILY_CHINESE_PROMPT_VERSION)
        is not None
    )
    assert (
        get_generation_prompt(WEEKLY_PROMPT_ID, WEEKLY_CHINESE_PROMPT_VERSION)
        is not None
    )
    assert get_generation_prompt(DAILY_PROMPT_ID, DAILY_CANDIDATE_PROMPT_VERSION) is None
    assert get_generation_prompt(WEEKLY_PROMPT_ID, WEEKLY_CANDIDATE_PROMPT_VERSION) is None


def test_active_and_candidate_response_models_match_their_versions() -> None:
    assert chat_definition().response_model is AiChatTurnResponse
    assert (
        PROMPT_REGISTRY.require_active(DAILY_PROMPT_ID).response_model
        is AiDailyChineseGenerateResponse
    )
    assert (
        PROMPT_REGISTRY.require_active(WEEKLY_PROMPT_ID).response_model
        is AiWeeklyChineseGenerateResponse
    )
    assert (
        PROMPT_REGISTRY.get(
            DAILY_PROMPT_ID, DAILY_CANDIDATE_PROMPT_VERSION
        ).response_model
        is AiDailyCandidateGenerateResponse
    )
    assert (
        PROMPT_REGISTRY.get(
            WEEKLY_PROMPT_ID, WEEKLY_CANDIDATE_PROMPT_VERSION
        ).response_model
        is AiWeeklyCandidateGenerateResponse
    )


def test_published_prompt_fingerprints_are_stable() -> None:
    assert {
        item.prompt_version: item.fingerprint for item in all_prompt_definitions()
    } == {
        CHAT_PROMPT_VERSION: (
            "9005fb13c4c8a8e9cacc1b0142d32ec38f3735d3d9ca76ccaf7d3a9d30077a07"
        ),
        DAILY_PROMPT_VERSION: (
            "2aa0da88735ee55b07a29507c5e26861f99e361e8f3efa9777e4f51dac4acb1d"
        ),
        DAILY_CANDIDATE_PROMPT_VERSION: (
            "baa8c67a137173f8804f8c1177af741bb46e430b1ede1e1decdaf79a3461254f"
        ),
        DAILY_CHINESE_PROMPT_VERSION: (
            "dd269f7feec3992526d898f90eb7ec8b9629502cdc31640bb8e7f6a90bccd246"
        ),
        WEEKLY_PROMPT_VERSION: (
            "3e0690bc065ddfbcf2a352ec16ad44f2479d2b85cfcd8fae84706a1e76769d71"
        ),
        WEEKLY_CANDIDATE_PROMPT_VERSION: (
            "7bcfac77aa6fde2fcff3688afc3ecf70e015675e2d43e9357149c5605e1000d5"
        ),
        WEEKLY_CHINESE_PROMPT_VERSION: (
            "14648a2e8f1c8a36d674416db005d2792adcc38f252d75d544bdb26ca47422d3"
        ),
    }


def test_duplicate_prompt_version_fails_closed() -> None:
    daily = PROMPT_REGISTRY.require_active(DAILY_PROMPT_ID)
    with pytest.raises(PromptRegistryError, match="duplicate"):
        PromptRegistry(
            (daily, daily),
            active_versions={DAILY_PROMPT_ID: DAILY_PROMPT_VERSION},
        )


def test_missing_active_pointer_fails_closed() -> None:
    with pytest.raises(PromptRegistryError, match="explicit active"):
        PromptRegistry(all_prompt_definitions(), active_versions={})


def test_multiple_active_versions_fail_closed() -> None:
    daily_active = PROMPT_REGISTRY.require_active(DAILY_PROMPT_ID)
    daily_candidate = PROMPT_REGISTRY.get(
        DAILY_PROMPT_ID, DAILY_CANDIDATE_PROMPT_VERSION
    )
    assert daily_candidate is not None
    second_active = replace(daily_candidate, status=PromptStatus.ACTIVE)
    with pytest.raises(PromptRegistryError, match="exactly one active"):
        PromptRegistry(
            (daily_active, second_active),
            active_versions={DAILY_PROMPT_ID: DAILY_PROMPT_VERSION},
        )


def test_contract_scope_or_schema_mismatch_fails_closed() -> None:
    daily = PROMPT_REGISTRY.require_active(DAILY_PROMPT_ID)
    invalid = replace(
        daily,
        supported_scopes=(*daily.supported_scopes, "growth_summary"),
    )
    with pytest.raises(PromptRegistryError, match="contract, Scope, or schema"):
        PromptRegistry(
            (invalid,),
            active_versions={DAILY_PROMPT_ID: DAILY_PROMPT_VERSION},
        )


def test_published_version_cannot_change_in_place() -> None:
    daily = PROMPT_REGISTRY.require_active(DAILY_PROMPT_ID)
    changed = replace(
        daily,
        developer_instructions=daily.developer_instructions + " Changed.",
    )
    with pytest.raises(PromptRegistryError, match="without a new version"):
        PromptRegistry(
            (changed,),
            active_versions={DAILY_PROMPT_ID: DAILY_PROMPT_VERSION},
        )


def test_registry_metadata_excludes_full_prompt() -> None:
    serialized = str(PROMPT_REGISTRY.metadata())
    assert "developer_instructions" not in serialized
    assert "You create a Daily Insight" not in serialized
    assert "fingerprint" in serialized
