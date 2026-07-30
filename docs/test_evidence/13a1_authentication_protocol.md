# Sprint 13A.1 Authentication Protocol Automated Evidence

## Scope

This file records automated evidence only. It does not convert any item in the
manual matrix into PASS.

- Sprint 12D archive commit:
  `153985f203f5918fc3b03951ea8f019468031b0d`
- Sprint 13A.1 baseline:
  `153985f203f5918fc3b03951ea8f019468031b0d`
- Implementation commit: pending
- Flutter schemaVersion: 9
- Server API Version: 1
- Sync Protocol: 2
- Beijing Alpha deployment: NOT PERFORMED

## Local Evidence

Final command results will be recorded after the implementation worktree is
complete:

| Verification | Status |
|---|---|
| Flutter dependency resolution | PASS |
| Flutter analyze | PASS, no issues |
| Flutter full test | PASS, 1057 passed / 2 skipped |
| Server SQLite test suite | PASS, 188 passed / 1 skipped / 10 PostgreSQL deselected |
| Server auth protocol targeted | PASS, 15 cases |
| Flutter auth store/manager/service targeted | PASS, 20 cases |
| Local Alembic upgrade/downgrade/upgrade | PASS, five auth tables present |
| Windows release build | PASS |
| Windows startup smoke | PASS, process remained alive |
| Windows secure-storage user lifecycle | NOT EXECUTED, manual matrix |
| Android split release build | PASS, three ABI APKs |
| Android arm64 startup/secure-storage lifecycle | NOT EXECUTED, manual matrix |
| PostgreSQL marker and concurrent refresh | CI REQUIRED |
| Multi-worker auth verification | CI REQUIRED |

## GitHub Evidence

| Workflow | Run | Status |
|---|---|---|
| Quality | pending | NOT RUN |
| Publish Alpha Images | pending | NOT RUN |

Image tags and digest remain pending until the implementation commit is pushed.

## Manual Gates

See `docs/manual_tests/40_authentication_protocol_and_secure_session.md`.
All new manual checks remain `NOT EXECUTED`.
