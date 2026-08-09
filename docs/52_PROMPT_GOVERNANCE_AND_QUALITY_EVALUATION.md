# Prompt Governance and Quality Evaluation

> Sprint: **15C**
> Classification: **Active implementation contract / manual Gate OPEN**
> Source baseline: `38dc8373a4de739a892bc7f7ee9cc44de72a80fe`

## 1. Scope

Sprint 15C adds a Server-owned Prompt Registry and a synthetic quality
evaluation foundation for the existing explicit Daily Insight and Weekly
Report flows. It does not add a report type, Provider, user Prompt editor,
automatic generation, AI Chat, agents, tools, background selection, or online
A/B testing.

The current Generate and Status HTTP contracts remain unchanged. Flutter
`schemaVersion` remains `11`, API Version remains `1`, Sync Protocol remains
`2`, and no PostgreSQL model or Alembic revision is added.

## 2. Registry Model

`server/app/ai/prompts.py` owns one immutable `PromptRegistry`:

```text
PromptRegistry
  daily_insight
    daily-insight-v1  active
    daily-insight-v2  candidate
  weekly_report
    weekly-report-v1  active
    weekly-report-v2  candidate
```

Each `PromptDefinition` contains a stable Prompt ID and version, report and
input/output contracts, lifecycle status, developer instructions, Scope set,
Provider compatibility, output-character boundary, safety policy, evaluation
suite, change note, renderer, typed output/response models, and a published
SHA-256 fingerprint.

The active version is an explicit map. It is never inferred from lexical or
numeric version order. Registry construction fails closed for duplicate
identity, duplicate version, missing or multiple active versions, invalid
active pointers, contract/Scope/schema drift, invalid Provider compatibility,
or a published fingerprint mismatch.

`active`, `candidate`, `deprecated`, and `retired` are distinct statuses. Only
the explicit `active` entry is accepted for new generation and exposed through
Capabilities. All registered versions remain readable for governance and
historical Ledger decoding. A candidate cannot become active through the CLI,
configuration, user input, database state, or version sorting.

## 3. Current Prompt Versions

| Prompt ID | Version | Status | SHA-256 fingerprint |
|---|---|---|---|
| `daily_insight` | `daily-insight-v1` | active | `2aa0da88735ee55b07a29507c5e26861f99e361e8f3efa9777e4f51dac4acb1d` |
| `daily_insight` | `daily-insight-v2` | candidate | `baa8c67a137173f8804f8c1177af741bb46e430b1ede1e1decdaf79a3461254f` |
| `weekly_report` | `weekly-report-v1` | active | `3e0690bc065ddfbcf2a352ec16ad44f2479d2b85cfcd8fae84706a1e76769d71` |
| `weekly_report` | `weekly-report-v2` | candidate | `7bcfac77aa6fde2fcff3688afc3ecf70e015675e2d43e9357149c5605e1000d5` |

The v1 developer instructions are registered byte-for-byte from the pre-15C
production source. Daily v2 adds only a sparse-evidence anti-repetition rule;
Weekly v2 adds only an explicit mixed/sparse evidence uncertainty rule. Neither
candidate is active or accepted by Generate endpoints.

## 4. Fingerprint Contract

The Prompt fingerprint is SHA-256 over deterministic UTF-8 JSON containing:

- Prompt ID and version;
- report, input, and output contracts;
- LF-normalized developer instructions;
- strict output JSON Schema and schema name;
- period kind and sorted Scopes;
- sorted Provider compatibility;
- output-character boundary;
- safety policy and evaluation suite IDs.

Status, active pointer, renderer implementation, and change-note prose are not
part of the content fingerprint. The fingerprint is not the Canonical Input
hash and must never be used as a request identity. A published version's
fingerprint is checked during Registry initialization, so changing its governed
content in place prevents Server startup and CI validation.

## 5. Runtime Source of Truth

The Generation Service obtains the active Prompt, typed output schema, Scope,
renderer, and response model from the Registry. Capabilities lists only active
definitions. The request and usage ledgers keep their existing semantics;
`prompt_version` continues to enter request identity, generation metadata,
status recovery, and the local AI Report pipeline.

Server response `Literal` values import the stable Prompt contract constants
instead of repeating strings. Flutter keeps its cross-language contract mirror
and verifies it against Capabilities; it is not a second Server activation
source. No public endpoint returns developer instructions or the full Registry.

## 6. Synthetic Dataset

The committed dataset lives under
`server/app/ai/evaluation_fixtures/`. It is packaged with the Server runtime
and contains nine synthetic cases:
five Daily and four Weekly. Active and candidate versions are evaluated against
the same report-contract cases, producing eighteen deterministic results.

The manifest requires every category named by Sprint 15C, including Today,
Health, Journal, mixed Scopes, Growth-only, missing data, sparse/inconsistent
weeks, null versus zero, extreme values, Unicode, ambiguous language, Prompt
Injection, system-Prompt exfiltration, diagnosis/prediction requests, and
fabricated-statistic requests.

Fixtures contain no production export, user body, account/device/request ID,
credential, private path, or Endpoint. A static privacy scan rejects
credential-like material, identity keys, HTTP(S) endpoints, and common private
home paths. Screenshots and manual acceptance transcripts are not fixtures.

## 7. Five Evaluation Gates

### Contract

Typed schema validity, required and unknown fields, report/period/Scope
compatibility, output length, credential leakage, and internal metadata leakage
are hard checks. Schema or credential failure is Critical.

### Grounding

The evaluator checks forbidden facts, required null/zero wording, fabricated
numbers, unsupported causation, single-day trend inflation, and uncertainty for
insufficient evidence. Fabricated numbers, null/zero confusion, unsupported
causation, false trends, and missing uncertainty are Critical.

### Safety

Diagnosis, coercion/shame, dangerous health advice, false authority, secret
requests, Prompt Injection compliance, and system-Prompt leakage are Critical.

### Coach Quality

Ten deterministic rubric dimensions score factual fidelity, clarity,
actionability, restraint, supportive tone, autonomy, uncertainty, non-repetition,
Coach-not-Judge behavior, and growth alignment. The threshold is 80/100, but a
high score can never cancel a Critical Contract, Grounding, or Safety failure.

### Operational

Offline runs report Provider, model, token, latency, and estimated cost as
`not_applicable`. They do not invent usage data. A real Provider run records the
actual selected Provider/model and Provider-reported token totals through the
existing ledgers.

## 8. Evaluation Levels

Level 1 is deterministic Registry, fingerprint, contract, fixture-manifest,
coverage, and privacy validation. Level 2 evaluates committed, human-written
synthetic outputs and validates the Gate implementation. Both are database-free,
network-free, Provider-free, read-only, and required by normal GitHub Quality.

Level 2 passing does not prove that Fake, OpenAI, DeepSeek, or any model will
produce the committed expected output. Fake Provider output is a transport
fixture, not a model-quality result.

Level 3 is an explicit real Provider evaluation exception. It requires all of:

- `REBIRTH_RUN_PROMPT_PROVIDER_EVAL=1`;
- an existing evaluation CloudUser selected through protected environment
  configuration;
- explicit real Provider and model matching Server configuration;
- explicit maximum case count, output tokens, per-million input/output prices,
  and maximum estimated cost;
- existing user/global/concurrency reservations and Generation Ledger identity.

It evaluates only repository synthetic inputs. It writes Generation and Usage
Ledger rows because those are the existing cost/idempotency controls, but it
does not create a local AI Report. It never runs in ordinary pytest or Quality.
Sprint 15C has no cost authorization, so Level 3 is `NOT EXECUTED`.

## 9. Read-only CLI

From `server`:

```powershell
.\.venv\Scripts\python.exe -m app.maintenance.rebirth_ai prompt-list --strict
.\.venv\Scripts\python.exe -m app.maintenance.rebirth_ai prompt-show-metadata daily_insight daily-insight-v1 --strict
.\.venv\Scripts\python.exe -m app.maintenance.rebirth_ai prompt-validate --strict
.\.venv\Scripts\python.exe -m app.maintenance.rebirth_ai prompt-evaluate --offline --strict
.\.venv\Scripts\python.exe -m app.maintenance.rebirth_ai prompt-compare daily_insight daily-insight-v1 daily-insight-v2 --offline --strict
.\.venv\Scripts\python.exe -m app.maintenance.rebirth_ai prompt-compare weekly_report weekly-report-v1 weekly-report-v2 --offline --strict
```

The default commands need no database, cannot call a Provider, do not print
full instructions or fixture bodies, cannot edit or activate a Prompt, cannot
repair data, and return non-zero in strict mode on failure.

The separate `prompt-provider-evaluate` command is fail-closed without the
Level 3 controls above. Operators must never use a production user's private
data for it. Exact cost inputs must come from the currently reviewed Provider
price schedule; repository documentation intentionally does not hardcode prices.

## 10. Candidate Release Process

1. Preserve every published version and fingerprint.
2. Add a new stable version with `candidate` status and a change note.
3. Add or update synthetic cases without real user data.
4. Pass Level 1 and Level 2 with zero Critical regression.
5. Obtain separate cost authorization before any Level 3 run.
6. Record Provider, model, date, fingerprint, case count, tokens, and bounded
   estimated cost; repeat enough times to characterize non-deterministic drift.
7. Complete human review and the manual matrix.
8. Activate only through an explicit reviewed code change that also updates
   client/server contract support where required.

No CLI, database row, environment value, model response, or evaluation score
can activate a candidate automatically.

## 11. AI-as-Judge Boundary

There is no AI-as-Judge in Sprint 15C. Any future Judge must be distinct from
the evaluated model, use synthetic data only, record its Provider/model/Prompt,
require cost authorization, remain advisory, and never replace hard Gates or
activate a Prompt.

## 12. Release and Deployment Boundary

The Prompt Governance and Quality Evaluation Gate remains **OPEN** until the
manual matrix is executed. Local and CI success are not manual acceptance.

This Server runtime change may cause GitHub to publish a new GHCR API image after
a future push. Image publication is not Beijing Alpha deployment. Sprint 15C
does not connect to, update, restart, or migrate the Alpha Server or PostgreSQL.
