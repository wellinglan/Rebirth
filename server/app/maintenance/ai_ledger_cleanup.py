from __future__ import annotations

import argparse
import json
import time

from app.ai.ledger import AiRequestLedger
from app.ai.service import utc_milliseconds
from app.config import load_settings
from app.database import Database


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Purge expired AI results and dedupe tombstones."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Count eligible rows without changing the database.",
    )
    args = parser.parse_args()
    settings = load_settings()
    database = Database(settings.database_url)
    started = time.perf_counter_ns()
    now = utc_milliseconds()
    try:
        with database.session_factory() as session:
            result = AiRequestLedger(settings).cleanup(
                session,
                now=now,
                dry_run=args.dry_run,
                emit_logs=False,
            )
    finally:
        database.engine.dispose()
    elapsed_ms = (time.perf_counter_ns() - started) // 1_000_000
    print(
        json.dumps(
            {
                "current_time_utc_ms": now,
                "would_purge_result_count": result.result_candidate_count,
                "would_delete_tombstone_count": result.tombstone_candidate_count,
                "actual_purge_result_count": result.result_purge_count,
                "actual_delete_tombstone_count": result.tombstone_delete_count,
                "elapsed_ms": elapsed_ms,
            },
            sort_keys=True,
            separators=(",", ":"),
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
