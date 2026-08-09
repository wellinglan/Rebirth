# AI Report Generation Pipeline Consolidation

> Sprint: **15B**
> Classification: **Active implementation contract / Gate closed with accepted limitations**
> Source baseline: `3a65cf13ec468b7688b3472f5d156d51021cf25e`

Sprint 15B consolidates Daily and Weekly AI Report generation behind one
application-layer coordinator. It does not add new AI product capability, change
prompts, change Provider behavior, add API endpoints, deploy a Server, or modify
Sync Protocol.

## Coordinator Boundary

The single entry point for app-layer generation is
`AiReportGenerationCoordinator`.

```text
AI Coach / Daily presentation controller
  -> preview integrity check
  -> AiReportGenerationCoordinator
  -> AiConsentRepository
  -> AuthSessionStore
  -> AiReportRepository
  -> AiGenerationRequestBindingStore
  -> AiGenerationGateway
```

Presentation continues to own UI state, confirmation, SnackBars, and navigation.
It no longer decides Provider retry policy, request binding persistence, pending
recovery strategy, terminal report writes, or reusable completed-report safety.

The pending-recovery controller uses the same coordinator. Recovery performs
status lookup only and never submits a new generation POST.

## Shared Daily and Weekly Flow

Daily and Weekly generation share the same pipeline:

1. validate the already-confirmed preview bundle;
2. verify consent and active authenticated account;
3. load Server capabilities;
4. compute an endpoint-scoped generation identity;
5. check for a matching completed local report;
6. create one local pending report;
7. save one request binding;
8. submit one remote generation request;
9. apply a terminal completed or failed result once;
10. leave pending state recoverable for network uncertainty or remote
    `processing`.

No path polls, retries POST, changes Prompt Version, expands scopes, stores input
snapshots by default, or automatically synchronizes AI Reports.

## Endpoint-scoped Reuse

Reusable completed reports still require:

- active local account;
- report type;
- period start and end;
- prompt version;
- input hash;
- completed lifecycle status;
- not soft-deleted.

Sprint 15B adds a generation endpoint hash to the local input metadata used by
new pending reports. The hash is derived from the normalized Server endpoint and
stored in the existing `input_sources_json` metadata object. It is not a Server
secret and it is not displayed to users.

Coordinator-driven reuse now requires the endpoint hash to match. Older
completed reports without this metadata remain readable in history and export,
but they are not reused by the consolidated generation pipeline when a current
endpoint identity is required.

## Request Binding and Recovery

`AiGenerationRequestBindingStore` remains the durable bridge between a local
pending report and a Server generation request. The binding still stores only:

- local report ID;
- request ID;
- normalized endpoint;
- cloud user ID;
- input hash;
- report type;
- prompt version;
- creation time.

The coordinator checks endpoint and account before recovery. A mismatch does not
call the Server. A missing binding, `processing`, network uncertainty, or Server
not-found remains safe and non-mutating until the user takes the existing
explicit action. Completed and controlled failed remote states reconcile the
local pending report and delete the binding.

If consent or account scope changes after a generation request has been
submitted but before a remote result is applied, the coordinator keeps the local
report pending and preserves the binding for explicit recovery rather than
writing content under the wrong scope.

## Single-flight and Retry Semantics

The coordinator single-flights concurrent generation attempts with the same
cloud user, endpoint hash, report type, period, prompt version, input hash, and
scope set. A duplicate tap or duplicate controller invocation shares the same
in-flight work instead of creating another pending report, binding, request ID,
or Provider call.

There is still no automatic Provider retry. Users may start a new explicit
generation only after a controlled terminal failure path allows it.

## Deprecated Fake Boundary

`FakeAiReportGenerationService` remains test-only scaffolding for the local
versioned aggregate. It is not part of production composition and must not become
a second AI Report generation path. Real generation continues to go through the
Gateway and Server Provider boundary.

## Persistence, Sync, and Privacy

- Flutter `schemaVersion` remains `11`; no Drift migration is added.
- Server Alembic, PostgreSQL models, API Version `1`, and Sync Protocol `2` are
  unchanged.
- AI Report sync remains manual and unchanged.
- No Prompt, Provider, Usage Ledger, or Server Generation Ledger code changes.
- No request body, canonical input JSON, prompt, Journal body, Health note,
  Provider secret, token, endpoint credential, or report body is written to
  logs by this pipeline.

## Release Gate

The `AI Report Generation Pipeline Gate` is **CLOSED WITH ACCEPTED LIMITATIONS**
at 35 PASS / 0 FAIL / 7 NOT EXECUTED. All applicable Windows and Android rows
passed. Six controlled pending-recovery state injections and one request-binding
persistence failure injection remain unavailable at product level. Automated
tests cover those paths, but they remain honestly distinct from manual PASS.
GitHub Quality
[run 31073858896](https://github.com/wellinglan/Rebirth/actions/runs/31073858896)
passed for implementation commit
`ab3bc862006ba21924595966190d93f6a661867a`, including Server SQLite,
PostgreSQL multiprocess/multi-worker, Flutter analyze/test, and Android Debug.

## Sprint 15C Succession

Sprint 15B's statement that it made no Prompt change remains true for that
Sprint. Sprint 15C later moves Server Prompt governance into one immutable
Registry and adds non-active v2 candidates plus synthetic quality Gates. The
15B client coordinator and recovery behavior remain unchanged, and Capabilities
still exposes only active v1 contracts. See
`docs/52_PROMPT_GOVERNANCE_AND_QUALITY_EVALUATION.md`.

## Sprint 16A Presentation Succession

Sprint 16A changes how users reach this pipeline, not the pipeline itself.
Daily and Weekly task pages still perform preview-integrity checks and call the
same `AiReportGenerationCoordinator`. Reuse, single-flight, request binding,
pending recovery, endpoint/account safety, terminal writes, quota, and no
automatic retry/sync semantics are unchanged. The Coach home never calls
Generate or Status merely because it is opened.
