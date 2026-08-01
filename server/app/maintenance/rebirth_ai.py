from __future__ import annotations

import argparse
import json
import sys

from app.ai.operations import (
    audit_usage,
    check_ledger_consistency,
    configuration_summary,
    monitor_operations,
)
from app.ai.service import utc_milliseconds
from app.config import load_settings
from app.database import Database


def main() -> int:
    parser = _parser()
    args = parser.parse_args()
    try:
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
    return parser


def _positive_int(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("value must be a positive integer")
    return parsed


if __name__ == "__main__":
    raise SystemExit(main())
