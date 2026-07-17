# Manual Test: AI Weekly Generation

## Fake Provider

1. In `server`, set `REBIRTH_AI_PROVIDER=fake` and `REBIRTH_AI_FAKE_SCENARIO=success`.
2. Start FastAPI on the runtime endpoint used by Flutter.
3. In Rebirth, log in/register the device and enable AI data consent.
4. Open AI Coach, select explicit scopes, separately confirm Journal if used, and build Preview.
5. Confirm Preview contains only expected minimized fields and no full canonical JSON.
6. Tap Generate and verify the final dialog shows period, Provider/model, scopes, Journal state, shortened hash, Server forwarding, no source IDs, `store=false` limitation, accuracy/cost warning, and no automatic retry.
7. Cancel and verify no pending History row appears.
8. Confirm generation; verify one pending becomes completed and Detail shows Fake provider/model and deterministic development output.
9. Verify History refreshes, then soft-delete the report and confirm Today/Journal/Health/Plan/Growth remain unchanged.
10. Repeat with `REBIRTH_AI_FAKE_SCENARIO=timeout`; verify one failed report with a friendly timeout message and no automatic second call.

## Disabled Provider

1. Set `REBIRTH_AI_PROVIDER=disabled` and restart Server.
2. Build a local Preview successfully.
3. Verify the generation area says AI generation is disabled and no pending row is created.

## Optional Real OpenAI Smoke

This can incur Provider cost and is not part of normal CI.

1. Set `OPENAI_API_KEY`, `REBIRTH_AI_MODEL`, and `REBIRTH_AI_PROVIDER=openai` only in the Server environment.
2. Optionally run the single smoke test with `REBIRTH_RUN_OPENAI_SMOKE=1`.
3. Generate the minimum number of reports and verify completed content, actual provider/model, History, and Detail.
4. Confirm the key is absent from UI, logs, API bodies, errors, Git changes, and local Flutter storage.
5. Remove the temporary environment values after verification.

## Android

1. Configure the Android runtime Server endpoint to a reachable LAN HTTPS/approved development HTTP address.
2. Log in, build Preview, inspect the scrollable final dialog, and generate with Fake Provider.
3. Verify History and Detail after relaunch.
4. Record Android physical-device execution as not executed when only APK build validation was performed.
