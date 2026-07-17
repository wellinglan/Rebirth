# Manual Test: AI Pending Recovery

## Preparation

1. Back up the Server database and run `alembic upgrade head`.
2. Start Uvicorn with `REBIRTH_AI_PROVIDER=fake`, `REBIRTH_AI_FAKE_SCENARIO=success`, and the Flutter runtime endpoint.
3. Start the Windows Flutter App, save/test the endpoint, development-login, and enable AI data consent.
4. Verify `/ai/capabilities` reports durable ledger/status recovery and the configured retention values.

For the repeatable real-Uvicorn Flutter/Dio smoke, keep the Fake Server running and execute:

```powershell
$env:REBIRTH_RUN_FAKE_FULL_STACK = '1'
$env:REBIRTH_FAKE_FULL_STACK_URL = 'http://127.0.0.1:8000'
flutter test test/features/ai_coach/data/ai_fake_full_stack_test.dart
```

This covers Dio, JWT, Router, Ledger, Fake Provider, local Drift completion, Binding removal, History readback, and status replay. The interactive Windows steps below still verify actual App navigation and rendering.

## Full Stack Success

1. Select explicit scopes, build Preview, and open final confirmation.
2. Verify the dialog shows result TTL, tombstone TTL, no input payload/source/canonical storage, no exactly-once claim, outcome-unknown risk, and no automatic retry.
3. Cancel and verify no pending local report and no ledger row.
4. Confirm once and verify Flutter pending, Dio POST, JWT router, ledger processing, Fake Provider, ledger completed, local completed, History, and Detail.
5. Send the same user/request ID again with the same payload using an HTTP diagnostic client and verify replay plus Fake Provider counter 1.
6. Send the same request ID with a different valid hash and verify `409 idempotency_conflict` with no Provider call.

## Lost Response And Recovery

1. During a Fake request, deliberately interrupt the client response after the Server commits completed.
2. Verify local report and Binding remain pending and no POST retry occurs.
3. Restart the App, open Local Reports, and tap “检查服务器状态”.
4. Verify one status GET restores completed content, deletes Binding, refreshes History/Detail, and does not invoke Provider.
5. Repeat with an active processing row and verify processing remains pending.
6. Query a request absent from the bound Server, verify it remains pending, then confirm “标记为失败” and verify only the local report becomes `server_state_not_found` with no generation POST.
6. Expire its lease with an injected test clock or controlled database fixture; verify `outcome_unknown`, no Provider call, controlled local failure, and no claim that no fee occurred.

## Binding Guards

1. Leave a pending binding, switch runtime endpoint, and tap status check. Verify no HTTP request and an original-server message.
2. Restore endpoint, switch account, and verify no status request and an original-account message.
3. Restore endpoint/account, revoke Consent, and verify status GET still reconciles the existing request.
4. Remove a Binding and verify the report remains pending with an unable-to-confirm message.
5. Return status not-found and verify no POST retry or automatic failed transition.

## Failure And Retention

1. Run Fake timeout/refusal/unavailable scenarios and verify a controlled failed ledger/local report; duplicate POST returns the same failure and Provider counter stays 1.
2. Advance beyond result TTL and trigger lazy cleanup; verify status is `result_expired`, no report body is returned, and the tombstone remains.
3. Advance beyond dedupe TTL and trigger cleanup; verify the ledger row is physically removed.
4. Soft-delete a local report and verify its Binding is deleted while Today, Journal, Health, Plan, and Growth remain unchanged.

Record Windows execution, PostgreSQL marker result, optional real OpenAI smoke, and Android physical-device execution separately. FastAPI TestClient coverage does not replace this Uvicorn/Dio/Windows flow.
