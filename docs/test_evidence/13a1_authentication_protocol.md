# Sprint 13A.1 Authentication Protocol Automated Evidence

## Scope

This file records automated evidence only. It does not convert any item in the
manual matrix into PASS.

- Sprint 12D archive commit:
  `153985f203f5918fc3b03951ea8f019468031b0d`
- Sprint 13A.1 baseline:
  `153985f203f5918fc3b03951ea8f019468031b0d`
- Implementation commit:
  `f9ac726bc4ad2c665dabf3e5842876f7d7ea7aef`
- CI fixture correction:
  `7bbeb3e980b02416b9915d7bfc4dcdf839771f8b`
- Flutter schemaVersion: 9
- Server API Version: 1
- Sync Protocol: 2
- Beijing Alpha deployment: NOT PERFORMED

## Local Evidence

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
| PostgreSQL marker and concurrent refresh | PASS in GitHub Quality |
| Multi-worker auth verification | PASS in GitHub Quality, 2 workers |

## GitHub Evidence

| Workflow | Run | Status |
|---|---|---|
| Quality | [30524655900](https://github.com/wellinglan/Rebirth/actions/runs/30524655900) | PASS |
| Publish Alpha Images | [30524655917](https://github.com/wellinglan/Rebirth/actions/runs/30524655917) | PASS |

Quality passed Flutter analyze and test, Android Debug build, Server SQLite,
Alembic upgrade, all 10 selected PostgreSQL tests, and the two-worker
verification. The first implementation run
([30524162801](https://github.com/wellinglan/Rebirth/actions/runs/30524162801))
correctly rejected one pre-existing short PostgreSQL test secret. The fixture
was corrected without changing product behavior, and the final run above passed.

Published API image tags:

- `ghcr.io/wellinglan/rebirth-api:7bbeb3e980b02416b9915d7bfc4dcdf839771f8b`
- `ghcr.io/wellinglan/rebirth-api:7bbeb3e9`
- `ghcr.io/wellinglan/rebirth-api:alpha-latest`

API digest:
`sha256:c7c15cc230945a658e573f6cd4769f599f5509b2a810f0bef1eb461aa4af97ce`

Mirrored PostgreSQL image:
`ghcr.io/wellinglan/rebirth-postgres:17-alpine`

PostgreSQL digest:
`sha256:f7b22dedcd41ec51e5a1abd50e81616ca0a1b317bdddde2722721aae53bf614e`

## Manual Gates

See `docs/manual_tests/40_authentication_protocol_and_secure_session.md`.
All new manual checks remain `NOT EXECUTED`.
