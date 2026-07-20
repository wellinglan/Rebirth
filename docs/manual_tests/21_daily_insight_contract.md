# Daily Insight Contract Manual Test

## Purpose

Verify the Sprint 9A developer contract without exposing a product UI or calling real OpenAI. Use only a development database and Fake Provider.

## Automated Baseline

```powershell
cd E:\Projects\Rebirth
flutter test test/features/ai_coach

cd server
.\.venv\Scripts\python.exe -m pytest -m "not postgres"
```

Both suites must verify the shared Daily fixture hash in `test/fixtures`, preserve `null` versus `0`, and keep Weekly tests green.

## Start Fake Server

```powershell
cd E:\Projects\Rebirth\server
$env:REBIRTH_AI_PROVIDER = 'fake'
$env:REBIRTH_AI_FAKE_SCENARIO = 'success'
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

In another terminal, obtain a development JWT with `POST /auth/dev-login`, then call `GET /ai/capabilities` with `Authorization: Bearer <token>`. Confirm `report_contracts` contains:

- `daily_insight` + `daily-insight-v1` + `single_day`;
- `weekly_report` + `weekly-report-v1` + `seven_days`;
- Daily scopes contain only Today, Health, and Journal.

## Daily Generate

Build a request from `test/fixtures/ai_daily_insight_input_v1.json`, use the expected fixture hash, assign a UUID request ID, and call `POST /ai/reports/daily/generate`.

Confirm:

1. HTTP 200 returns matching request ID, hash, report type, and prompt version.
2. Structured output has only the Daily v1 fields and respects 4/3/3 limits.
3. Markdown is rendered from the validated output.
4. Repeating the same request returns the same result without another Provider start event.
5. `GET /ai/requests/{request_id}` returns `completed` and the same validated result.

## Negative Contract Checks

Use a new request ID for each case:

1. Change the hash and confirm `input_hash_mismatch`; no Provider start event.
2. Set start and end to different dates and confirm rejection.
3. Pair Daily with `weekly-report-v1` and confirm rejection.
4. Add `growth_summary` or `active_goals` and confirm rejection.
5. Add a selected scope with `[]` and confirm it remains present and produces no fake Source.
6. Remove an unselected scope key and confirm it remains absent.
7. Compare explicit `0` with `null` and confirm distinct canonical hashes.
8. Reuse one request ID across Daily and Weekly and confirm `idempotency_conflict` without another Provider call.

## Failure And Privacy Checks

Restart with each `REBIRTH_AI_FAKE_SCENARIO`: `timeout`, `refusal`, `invalid`, and `unavailable`. Confirm only controlled error codes are returned and no automatic POST retry occurs.

Inspect `rebirth.ai` logs and the `ai_generation_requests` row. The following must not appear: payload, canonical JSON, Sources/source IDs, the fixture sensitive marker, full input hash, Journal input, token, API key, raw structured output, or report Markdown. Temporary validated output in the ledger is allowed for recovery.

## PostgreSQL Marker

```powershell
cd E:\Projects\Rebirth\server
docker compose -f docker-compose.test.yml up -d
$env:REBIRTH_POSTGRES_TEST_URL = 'postgresql+psycopg://rebirth_test@127.0.0.1:55432/rebirth_test'
.\.venv\Scripts\python.exe -m pytest -m postgres
docker compose -f docker-compose.test.yml down -v
```

Confirm the Daily four-process test reports one claim owner and one ledger row. The existing Weekly multi-worker verification remains unchanged.

## Expected Result

Daily assembly, canonical hashing, strict endpoint, Fake Provider, Markdown rendering, replay, status, and privacy boundaries pass. No Daily button appears in Today, Journal, or AI Coach; Flutter `schemaVersion` remains 3.
