# QA Report — Task #19: S1.2: System Dependencies Installer (install-system.sh)

**QA Date:** 2026-04-17
**QA Depth:** 1/1 (max depth reached)
**Script Under Test:** `scripts/install-system.sh`
**Supporting Library:** `scripts/_common.sh`
**Commit:** `794f22c` — feat(dev-story): S1.2: System Dependencies Installer

## Pre-Check

| Check | Result |
|-------|--------|
| Code committed | PASS — commit `794f22c` on `main` |
| Untracked files | Only task-tracking docs (`_bmad-output/`, `docs/`, `test-screenshots/`) — no uncommitted feature code |

## Static Analysis

| Tool | Result |
|------|--------|
| `bash -n` | PASS — no syntax errors |
| ShellCheck 0.9.0 (all levels) | PASS — 0 warnings |

## Acceptance Criteria Results

### AC-1: Idempotency Check — PASS

| Sub-criterion | Result | Evidence |
|--------------|--------|----------|
| Checks marker `.phase-1-complete` | PASS | Line 69: `check_marker "${PHASE_NUM}"` (PHASE_NUM=1) |
| Checks `systemctl is-active mariadb` | PASS | Line 77: `systemctl is-active --quiet mariadb` |
| Checks `redis-cli ping` returns PONG | PASS | Lines 83-84: captures output, compares to `"PONG"` |
| If all pass: logs skip and exits 0 | PASS | Line 90-91: `log_success "Phase 1 already complete — skipping"` then `exit 0` |
| If marker exists but service fails: clears marker and re-runs | PASS | Lines 93-94: `log_warn` + `clear_marker "${PHASE_NUM}"`, then function returns (falls through to full install) |

### AC-2: apt Package Installation — PASS

| Sub-criterion | Result | Evidence |
|--------------|--------|----------|
| `DEBIAN_FRONTEND=noninteractive` | PASS | Line 103: `export DEBIAN_FRONTEND=noninteractive` |
| `apt-get update` | PASS | Line 105: `retry 3 10 apt-get update` |
| `apt-get install -y` | PASS | Line 107: `retry 3 10 apt-get install -y "${APT_PACKAGES[@]}"` |
| All 27 required packages | PASS | Lines 32-60: all 27 packages verified present (automated comparison) |
| Retry logic (3 attempts) | PASS | Uses `retry 3 10` wrapper from `_common.sh` for both update and install |

**Package list verified (27/27):** build-essential, python3, python3-dev, python3-pip, python3-venv, python3-setuptools, git, curl, wget, jq, gettext-base, libffi-dev, libssl-dev, libjpeg-dev, libpng-dev, libxml2-dev, libxslt1-dev, libmysqlclient-dev, redis-server, redis-tools, mariadb-server, mariadb-client, wkhtmltopdf, xvfb, xfonts-base, xfonts-scalable, supervisor

### AC-3: MariaDB Configuration — PASS

| Sub-criterion | Result | Evidence |
|--------------|--------|----------|
| Start and enable mariadb | PASS | Lines 122-123: `systemctl start mariadb` + `systemctl enable mariadb` |
| Create `/etc/mysql/mariadb.conf.d/99-devbox.cnf` | PASS | Line 30 (constant) + Lines 127-138 (heredoc writes config) |
| utf8mb4 charset + collation | PASS | `character-set-server = utf8mb4`, `collation-server = utf8mb4_unicode_ci`, `init_connect = SET NAMES utf8mb4` |
| Set root password from `$MARIADB_ROOT_PASSWORD` | PASS | Line 119: defaults to `tiberbu123`; Lines 142-150: idempotent password set via `ALTER USER` |
| Restart MariaDB | PASS | Line 155: `systemctl restart mariadb` |
| Verify connection | PASS | Lines 159-164: `mysql -u root -p"..." -e "SELECT 1;"` after restart |

### AC-4: Redis Verification — PASS

| Sub-criterion | Result | Evidence |
|--------------|--------|----------|
| Start and enable redis-server | PASS | Lines 173-174: `systemctl start redis-server` + `systemctl enable redis-server` |
| Verify redis-cli ping returns PONG | PASS | Lines 178-184: captures `redis-cli ping`, compares to `"PONG"`, returns 1 on failure |

### AC-5: Completion — PASS

| Sub-criterion | Result | Evidence |
|--------------|--------|----------|
| Set marker `.phase-1-complete` | PASS | Line 192: `set_marker "${PHASE_NUM}"` — creates `/var/tmp/devbox/.phase-1-complete` |

## Definition of Done

| Criterion | Result | Evidence |
|-----------|--------|----------|
| `bash -n` passes | PASS | Exit code 0 |
| ShellCheck clean | PASS | 0 warnings at all severity levels |
| All packages installed (code path) | PASS | 27/27 packages in `APT_PACKAGES` array |
| MariaDB active with utf8mb4 (code path) | PASS | Config written, service started/restarted, connection verified |
| Redis active with PONG (code path) | PASS | Service started, ping verified |
| Second run skips (code path) | PASS | `check_idempotency()` checks marker + services, exits 0 if healthy |

## Code Quality Notes

| Aspect | Assessment |
|--------|-----------|
| Strict mode | `set -euo pipefail` — good |
| Error handling | ERR trap with `error_handler` — good |
| Execution order | `check_idempotency → install_packages → configure_mariadb → configure_redis → complete_phase` — correct |
| Timing | Phase start/end timing tracked — good |
| Logging | Uses structured logging from `_common.sh` — good |
| Default password | `MARIADB_ROOT_PASSWORD` defaults to `tiberbu123` if unset (line 119) — acceptable for dev environment |

## Observations (P3 — Informational, No Action Required)

1. **SQL in unquoted heredoc** (line 147-150): `MARIADB_ROOT_PASSWORD` is interpolated inside an unquoted heredoc. If the password contains single quotes or special SQL characters, the `ALTER USER` statement could break. This is a P3 since it's a local dev setup and the default password is simple.

2. **No `--quiet` on idempotency redis check**: The idempotency check at line 77 uses `--quiet` for mariadb but the redis check (line 83) uses `2>/dev/null || true` — consistent behavior but different mechanisms. Functionally correct.

## Screenshots

| Screenshot | Description |
|-----------|-------------|
| `test-screenshots/task-19-validation-report.png` | Playwright-rendered validation report showing 21/21 tests passing across all ACs |
| `test-screenshots/task-19-script-source.png` | Full source code of `install-system.sh` with line numbers |

## Console Errors

N/A — This is a shell script, not a web application. No browser console involved.

## Summary

| AC | Result |
|----|--------|
| AC-1: Idempotency check | **PASS** |
| AC-2: apt package installation | **PASS** |
| AC-3: MariaDB configuration | **PASS** |
| AC-4: Redis verification | **PASS** |
| AC-5: Completion | **PASS** |
| Definition of Done | **PASS** |

**Overall: ALL PASS** — No P0/P1/P2 issues found. Script is well-structured, idempotent, and implements all acceptance criteria correctly.
