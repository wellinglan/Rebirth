# Sprint 13A.2 Public Login Automated Evidence

> Automated evidence does not convert manual matrix rows to PASS.

## Baseline

- Sprint 13A.1 manual acceptance commit:
  `5402613917be09bb8691965f8ff074b60a92b8ec`
- Sprint 13A.2 actual baseline:
  `5402613917be09bb8691965f8ff074b60a92b8ec`
- Sprint 13A.1 manual result: 67 PASS / 0 FAIL / 12 NOT EXECUTED

## Automated Coverage

Coverage added for production fail-closed configuration, Alpha Developer Login
enablement, public input rules, privacy-safe error mapping, controller
single-flight, Account Boundary, secure-store failure cleanup, absolute session
expiry, Router gates, production deep-link denial, responsive Material 3 pages,
and credential-free architecture boundaries.

## Local Verification

| Check | Result |
|---|---|
| `flutter analyze` | PASS, no issues |
| `flutter test` | PASS, 1096 passed / 2 skipped |
| Server pytest | PASS, 188 passed / 11 skipped |
| Flutter schemaVersion | 9, unchanged |
| API Version | 1, unchanged |
| Sync Protocol | 2, unchanged |
| Server runtime code | unchanged |
| PostgreSQL schema | unchanged |
| Alembic revisions | unchanged |

The skipped cases are existing opt-in/environment cases and are not converted
to PASS.

## Build And CI Evidence

Build and GitHub results are recorded only after they finish:

| Check | Result |
|---|---|
| Alpha Windows release | PASS |
| Production Windows release | PASS |
| Alpha Android split release | PASS, three ABI artifacts |
| Production Android split release | PASS, three ABI artifacts |
| Windows startup smoke | PASS, Alpha and Production |
| GitHub Quality | PENDING |
| Publish Alpha Images | Expected NOT RUN |

Build artifacts were separated under ignored `build/verified/sprint13a2/`
environment directories. Alpha and Production `app.so` and arm64 APK SHA-256
values differ, confirming that evidence did not reuse one environment artifact.
No APK or Windows build output is committed.

## Manual Gate

`manual_tests/41_public_username_password_login.md` starts at 0 PASS, 0 FAIL,
and 114 NOT EXECUTED. Public Login Experience, Authentication Protocol,
Password Credential Security, and Secure Client Storage remain open for real
Windows and Android acceptance.
