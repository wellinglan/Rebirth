# AI Coach MVP Product Experience

> Sprint: **16A**
> Classification: **Active / Gate closed with accepted limitations**
> Starting HEAD: `72eb4ac2b5161aeefad3f101ad08ea6eac05e10b`

## 1. Purpose

Sprint 16A consolidates the existing Daily Insight, Weekly Report, consent,
usage, generation recovery, and report-library capabilities into one
task-oriented AI Coach experience. It changes Flutter presentation, routing,
view composition, tests, and documentation only. It does not add an AI
capability or change generation semantics.

The canonical first-level entry is `AI 教练` at `/ai-coach`. Windows wide
layouts use the existing shell's navigation rail. Android and compact layouts
use the existing bottom navigation system. Settings retains `AI 数据与隐私`
for consent and revocation, but is no longer the primary route to AI Coach or
the report library.

## 2. Canonical Product Flow

```text
AI 教练
  -> 今日洞察 / 每周回顾
  -> 选择本次允许使用的数据
  -> 本次使用的数据
  -> 显式确认 Provider、Model、费用与执行
  -> existing AiReportGenerationCoordinator
  -> processing / controlled recovery / completed
  -> canonical AI Report Detail
```

The flow continues to use the existing consent repository, input assembler,
usage gateway, generation coordinator, request binding, pending recovery,
account scope, report repository, canonical report library, and canonical
detail page. There is no second generator, report list, report detail, or sync
path.

Legacy `/ai-coach/reports/:reportId` links redirect to
`/ai-reports/:reportId`. Daily and Weekly task pages remain explicit routes
under `/ai-coach`, while `/ai-coach` itself is the stable home.

## 3. Home Composition

The AI Coach home has four user-facing areas:

1. `今日洞察`: current date, reusable/current report state, and a natural CTA;
2. `每周回顾`: the applicable seven-day range, report state, and a natural CTA;
3. `最近报告`: at most three privacy-safe rows from the existing
   `AiReportHistoryController`, plus `查看全部` to the canonical library;
4. AI availability: available, disabled, checking, unknown/network-limited,
   or daily-limit-reached, including a reset time when known.

Unknown usage is never rendered as zero. Opening the home may perform the
existing read-only consent, usage, and report-list reads. It does not submit a
Generate request, poll, recover a pending request, sync, or automatically
select and upload source data.

## 4. State and CTA Mapping

| State | Primary user message or action |
|---|---|
| Consent missing | `设置 AI 授权` |
| No matching report | `生成今日洞察` / `生成每周回顾` |
| Completed or archived report | `查看今日洞察` / `查看本周报告` |
| Pending or generating report | `继续查看生成结果` |
| Previous controlled failure | Re-enter selection and explicitly try again |
| AI disabled | `AI 服务当前暂不可用` and existing reports stay available |
| Daily limit reached | Disabled generation CTA, reset time when known |
| Usage unknown | Honest unknown state; never converted to zero |
| No selected data | Ask the user to select at least one category |
| No saved source records | Limited links to Today, Journal, and Health |
| Outcome uncertain | Explain that the result and possible fee are unknown; no automatic retry |

Consent opens the canonical consent page and returns to the originating AI
Coach flow. Granting consent does not automatically generate anything.

## 5. Technical Information Downgrade

Ordinary pages use `本次使用的数据`, dates, categories, record availability,
and explicit confirmation language. `Prompt Version` and `Input Hash` no
longer appear on the home or primary CTA. The preview keeps only a collapsed
`技术信息` section containing the prompt-template version and a shortened input
digest. The section is closed by default.

The primary flow does not render request binding, endpoint, contract, payload,
canonical JSON, internal report/account IDs, token, secret, or raw Provider
error codes. The final confirmation still names Provider and Model because a
real paid call requires explicit user authorization. It also states that the
output may be inaccurate, may incur a fee, and will not be automatically
retried.

## 6. Account and Privacy Boundary

Account changes invalidate consent, usage, preview families, manual generation
families, pending recovery, recent reports, coordinator state, and report
export state through the existing account-scoped invalidation boundary. One
account's report list, quota, preview, or in-flight presentation state must not
remain visible after switching accounts.

Recent-report rows show only title, report type, period, and lifecycle state.
They do not show report body, source bodies, prompt, input digest, Provider,
token, endpoint, or internal IDs. Full report content remains available only in
the existing canonical detail.

## 7. Responsive and Accessibility Contract

- compact navigation keeps all six primary destinations discoverable;
- labels are reduced at high text scale while tooltips and semantics remain;
- Windows wide layout uses a rail and keeps content within the existing width;
- task cards stack on compact layouts and use two columns only when space
  permits;
- 320, 360, 412, and 1200 px plus TextScaler 2.0 are automated targets;
- keyboard navigation, Android Back, semantics, loading, empty, and error
  states remain part of manual acceptance.

## 8. Unchanged Technical Boundaries

- Flutter `schemaVersion` remains `11`;
- API Version remains `1`;
- Sync Protocol remains `2`;
- PostgreSQL and Alembic are unchanged;
- Server runtime is unchanged;
- active Prompts remain `daily-insight-v1` and `weekly-report-v1`;
- Provider, model configuration, quota, Usage Ledger, Generation Ledger, and
  cost rules are unchanged;
- AI Report sync remains explicit and manual;
- no AI Chat, agent, tool calling, background generation, new report type,
  import, restore, deployment, or automatic sync is added.

## 9. Acceptance

The `AI Coach MVP Product Experience Gate` is **CLOSED WITH ACCEPTED
LIMITATIONS**. On 2026-08-10 the user reported all 29 applicable Windows,
Android, consent, real-Provider Daily/Weekly, reuse, responsive, keyboard,
Back, account, privacy, and canonical-report checks as PASS. G1-G8 remain
honestly `NOT EXECUTED`; the user explicitly accepted their named automated
evidence instead of adding dangerous product fault-injection controls.

See
[`manual_tests/58_ai_coach_mvp_product_experience.md`](manual_tests/58_ai_coach_mvp_product_experience.md).
