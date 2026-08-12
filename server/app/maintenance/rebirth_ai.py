from __future__ import annotations

import argparse
import json
import sys

from app.ai.prompt_evaluation import (
    PromptEvaluationError,
    compare_offline,
    evaluate_offline,
    validate_prompt_governance,
)
from app.ai.prompts import PROMPT_REGISTRY
from app.ai.prompt_provider_evaluation import run_provider_evaluation
from app.ai.operations import (
    audit_usage,
    check_ledger_consistency,
    configuration_summary,
    monitor_operations,
)
from app.ai.service import utc_milliseconds
from app.ai.feedback import feedback_audit
from app.config import load_settings
from app.database import Database


def main() -> int:
    parser = _parser()
    args = parser.parse_args()
    try:
        if args.command.startswith("prompt-"):
            if args.command == "prompt-provider-evaluate":
                settings = load_settings()
                result = run_provider_evaluation(
                    settings=settings,
                    prompt_id=args.prompt_id,
                    prompt_version=args.prompt_version,
                    provider_name=args.provider,
                    model=args.model,
                    max_cases=args.max_cases,
                    max_output_tokens=args.max_output_tokens,
                    max_estimated_cost_usd=args.max_estimated_cost_usd,
                    input_cost_per_million=args.input_cost_per_million,
                    output_cost_per_million=args.output_cost_per_million,
                )
            else:
                result = _prompt_command(args)
            print(json.dumps(result, separators=(",", ":"), sort_keys=True))
            if args.strict and result.get("status") not in {"ok", "pass"}:
                return 2
            return 0
        settings = load_settings(
            validate_ai_provider_configuration=args.command != "config-check"
        )
        now = utc_milliseconds()
        if args.command == "config-check":
            result = configuration_summary(settings)
        else:
            database = Database(settings.database_url)
            try:
                with database.session_factory() as session:
                    if args.command == "audit":
                        result = audit_usage(
                            session, days=args.days, now=now
                        )
                    elif args.command == "feedback-audit":
                        result = feedback_audit(
                            session, days=args.days, now=now
                        )
                    elif args.command == "monitor":
                        result = monitor_operations(
                            session,
                            settings=settings,
                            window_minutes=args.window_minutes,
                            now=now,
                        )
                    else:
                        result = check_ledger_consistency(
                            session, days=args.days, now=now
                        )
            finally:
                database.engine.dispose()
    except PromptEvaluationError as error:
        print(
            json.dumps(
                {
                    "status": "error",
                    "error_code": "prompt_evaluation_failed",
                    "detail": str(error),
                },
                separators=(",", ":"),
                sort_keys=True,
            ),
            file=sys.stderr,
        )
        return 2
    except Exception:
        print(
            json.dumps(
                {"status": "error", "error_code": "operation_failed"},
                separators=(",", ":"),
                sort_keys=True,
            ),
            file=sys.stderr,
        )
        return 1
    print(json.dumps(result, separators=(",", ":"), sort_keys=True))
    return 0 if result.get("status") != "inconsistent" else 2


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Read-only Rebirth AI production operations tools."
    )
    commands = parser.add_subparsers(dest="command", required=True)
    audit = commands.add_parser("audit", help="Aggregate recent UTC usage.")
    audit.add_argument("--days", type=_positive_int, default=7)
    feedback = commands.add_parser(
        "feedback-audit",
        help="Aggregate privacy-safe AI Report feedback quality signals.",
    )
    feedback.add_argument("--days", type=_positive_int, default=30)
    commands.add_parser(
        "config-check", help="Inspect non-secret AI configuration."
    )
    monitor = commands.add_parser(
        "monitor", help="Evaluate budget and Provider safety signals."
    )
    monitor.add_argument("--window-minutes", type=_positive_int, default=60)
    ledger = commands.add_parser(
        "ledger-check", help="Compare generation and usage ledgers."
    )
    ledger.add_argument("--days", type=_positive_int, default=7)
    prompt_list = commands.add_parser(
        "prompt-list", help="List non-secret Prompt Registry metadata."
    )
    prompt_list.add_argument("--strict", action="store_true")
    prompt_show = commands.add_parser(
        "prompt-show-metadata", help="Show one Prompt without its instructions."
    )
    prompt_show.add_argument("prompt_id")
    prompt_show.add_argument("prompt_version")
    prompt_show.add_argument("--strict", action="store_true")
    prompt_validate = commands.add_parser(
        "prompt-validate", help="Run offline Prompt governance validation."
    )
    prompt_validate.add_argument("--strict", action="store_true")
    prompt_evaluate = commands.add_parser(
        "prompt-evaluate", help="Evaluate committed synthetic outputs offline."
    )
    prompt_evaluate.add_argument("--offline", action="store_true")
    prompt_evaluate.add_argument("--strict", action="store_true")
    prompt_compare = commands.add_parser(
        "prompt-compare", help="Compare two registered Prompt versions offline."
    )
    prompt_compare.add_argument("prompt_id")
    prompt_compare.add_argument("baseline_version")
    prompt_compare.add_argument("candidate_version")
    prompt_compare.add_argument("--offline", action="store_true")
    prompt_compare.add_argument("--strict", action="store_true")
    prompt_provider = commands.add_parser(
        "prompt-provider-evaluate",
        help="Run an explicitly authorized real Provider evaluation.",
    )
    prompt_provider.add_argument("--provider", required=True)
    prompt_provider.add_argument("--model", required=True)
    prompt_provider.add_argument("--prompt-id", required=True)
    prompt_provider.add_argument("--prompt-version", required=True)
    prompt_provider.add_argument("--max-cases", type=_positive_int, required=True)
    prompt_provider.add_argument(
        "--max-output-tokens", type=_positive_int, required=True
    )
    prompt_provider.add_argument(
        "--max-estimated-cost-usd", type=float, required=True
    )
    prompt_provider.add_argument(
        "--input-cost-per-million", type=float, required=True
    )
    prompt_provider.add_argument(
        "--output-cost-per-million", type=float, required=True
    )
    prompt_provider.add_argument("--strict", action="store_true")
    return parser


def _prompt_command(args: argparse.Namespace) -> dict[str, object]:
    if args.command == "prompt-list":
        return {
            "status": "ok",
            "read_only": True,
            "provider_called": False,
            "prompts": PROMPT_REGISTRY.metadata(),
        }
    if args.command == "prompt-show-metadata":
        definition = PROMPT_REGISTRY.get(
            args.prompt_id, args.prompt_version
        )
        if definition is None:
            raise PromptEvaluationError("Prompt metadata was not found")
        return {
            "status": "ok",
            "read_only": True,
            "provider_called": False,
            "prompt": next(
                item
                for item in PROMPT_REGISTRY.metadata()
                if item["prompt_id"] == args.prompt_id
                and item["prompt_version"] == args.prompt_version
            ),
        }
    if args.command == "prompt-validate":
        return validate_prompt_governance()
    if args.command == "prompt-evaluate":
        return evaluate_offline()
    return compare_offline(
        prompt_id=args.prompt_id,
        baseline_version=args.baseline_version,
        candidate_version=args.candidate_version,
    )


def _positive_int(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("value must be a positive integer")
    return parsed


if __name__ == "__main__":
    raise SystemExit(main())
