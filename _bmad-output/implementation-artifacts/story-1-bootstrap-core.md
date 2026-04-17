# Story 1.1: bootstrap.sh Core Framework + _common.sh

Status: ready-for-dev

## Story

As a Tiberbu engineer,
I want a shared utility library (`scripts/_common.sh`) and a main orchestrator script (`bootstrap.sh`),
so that all phase scripts have consistent logging, error handling, marker-based idempotency, and the orchestrator can load credentials, validate them, and run all 5 phases sequentially with timing and dry-run support.

## Acceptance Criteria

### AC-1: scripts/_common.sh utility library
1. Logging functions implemented: `log_info()`, `log_success()`, `log_error()`, `log_warn()`, `log_phase_start()`, `log_phase_end()`
2. Stdout output uses color-coded prefixes: RED for errors (✗), GREEN for success (✓), YELLOW for warnings (!), BLUE for info (→)
3. All log functions append to `$LOG_FILE` (`/var/tmp/devbox/bootstrap.log`) in `[LEVEL] message` format; log file opened in append mode
4. Marker functions implemented: `check_marker(PHASE_NUM)`, `set_marker(PHASE_NUM)`, `clear_marker(PHASE_NUM)` using `/var/tmp/devbox/.phase-N-complete`
5. `render_template(TEMPLATE OUTPUT)` wraps `envsubst < template > output` with `log_success` on completion
6. `error_handler(LINE EXIT_CODE)` prints file, line number, exit code, tails last 20 lines of `$LOG_FILE` to stdout, then exits with the given exit code
7. `retry(COUNT DELAY CMD...)` function retries a command up to COUNT times with DELAY seconds between attempts; logs each retry attempt
8. `require_env(VAR_NAME)` checks variable is non-empty; prints error and returns 1 if not set or empty
9. `require_command(CMD_NAME)` checks command exists via `command -v`; prints error and returns 1 if not found
10. Constants exported: `MARKER_DIR=/var/tmp/devbox`, `LOG_FILE=/var/tmp/devbox/bootstrap.log`, color codes `RED`, `GREEN`, `YELLOW`, `BLUE`, `NC`
11. File is designed to be sourced (no `set -euo pipefail` inside — the sourcing script owns those flags)

### AC-2: bootstrap.sh orchestrator
12. Shebang is `#!/usr/bin/env bash`; `set -euo pipefail` at top of file
13. Sources `scripts/_common.sh` using `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` pattern
14. `trap 'error_handler $LINENO $?' ERR` set after sourcing `_common.sh`
15. Argument parsing handles: `--dry-run`, `--phase N`, `--env-file PATH`, `--help` / `-h`
16. Unknown arguments cause a `log_error` and exit 1
17. `show_help()` prints a usage summary to stdout and exits 0
18. `load_env_file(PATH)` function:
    - Exits 1 with descriptive error if the file does not exist
    - Uses `set -a; source "$env_file"; set +a` for auto-export
    - Applies defaults for all optional variables: `BEDROCK_REGION` (us-west-1), `BEDROCK_MODEL` (global.anthropic.claude-opus-4-6-v1), `FRAPPE_BRANCH` (version-15), `BENCH_SITE` (dev.local), `MARIADB_ROOT_PASSWORD` (tiberbu123), `CLAUDE_STUDIO_PORT` (3000), `OPENCLAW_PORT` (18789)
    - Exports all optional variables after defaults are applied
19. `validate_credentials()` function:
    - Checks all 8 required variables: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`, `DISCORD_BOT_TOKEN`, `DISCORD_GUILD_ID`, `DISCORD_CHANNEL_ID`, `DISCORD_USER_ID`, `GITHUB_TOKEN`
    - Collects ALL missing variables into an array before reporting — does not fail on first missing var
    - Exits 1 and prints each missing variable name if any are absent
    - Calls `log_success "All required credentials present"` on pass
20. `run_phase(PHASE_NUM PHASE_NAME PHASE_SCRIPT)` function:
    - Calls `log_phase_start` before and `log_phase_end` with elapsed seconds after
    - Captures elapsed time using `$SECONDS` bash builtin
    - In dry-run mode prints `[DRY RUN] Would execute: $phase_script` instead of running
    - Executes phase script via `bash "${SCRIPT_DIR}/${phase_script}"`
21. When `--phase N` is provided, runs only that single phase (prerequisite marker check is a stretch goal)
22. When no `--phase` provided, runs all 5 phases sequentially via `run_phase`
23. After phases complete (non-dry-run), invokes `scripts/verify.sh`
24. Prints total elapsed time at the end: "Bootstrap completed in Xs"
25. Creates `/var/tmp/devbox/` directory at startup with `mkdir -p`
26. File has executable bit set (`chmod +x`)

### AC-3: Dry-run mode
27. `--dry-run` prevents any phase script from executing
28. Dry-run still calls `load_env_file` and `validate_credentials`
29. Prints the plan — what each phase would do — using `log_info "[DRY RUN] Would execute: ..."`
30. Exits 0 if all validations pass (env file exists, all credentials present)

### AC-4: Error handling
31. Any command failure triggers `ERR` trap → `error_handler` which shows file/line/exit-code context
32. Access to an undefined variable triggers an error (enforced by `set -u`)
33. Failures inside pipes are caught (enforced by `set -o pipefail`)
34. `error_handler` prints the path to the full log file for post-mortem debugging

### Definition of Done
35. `bash -n scripts/_common.sh` exits 0 (no syntax errors)
36. `bash -n bootstrap.sh` exits 0 (no syntax errors)
37. `./bootstrap.sh --help` prints usage and exits 0
38. `./bootstrap.sh --dry-run --env-file <valid-env>` exits 0 and prints phase plan
39. `./bootstrap.sh --dry-run` without env file exits 1 with descriptive error
40. ShellCheck passes with no errors on both files (`shellcheck scripts/_common.sh bootstrap.sh`)

---

## Tasks / Subtasks

- [ ] **Task 1 — Create `scripts/_common.sh`** (AC: 1–11)
  - [ ] 1.1 Create `scripts/` directory if it does not exist
  - [ ] 1.2 Add color code constants: `RED`, `GREEN`, `YELLOW`, `BLUE`, `NC` and export them (AC: 2, 10)
  - [ ] 1.3 Add `MARKER_DIR` and `LOG_FILE` constants and export (AC: 10)
  - [ ] 1.4 Implement `log_info()` — blue arrow prefix to stdout + append `[INFO]` to log file (AC: 1, 3)
  - [ ] 1.5 Implement `log_success()` — green checkmark prefix to stdout + append `[OK]` to log file (AC: 1, 3)
  - [ ] 1.6 Implement `log_error()` — red X prefix to stdout + append `[ERR]` to log file (AC: 1, 3)
  - [ ] 1.7 Implement `log_warn()` — yellow bang prefix to stdout + append `[WARN]` to log file (AC: 1, 3)
  - [ ] 1.8 Implement `log_phase_start(NUM TOTAL NAME)` — prints phase header to stdout and log (AC: 1, 3)
  - [ ] 1.9 Implement `log_phase_end(NUM TOTAL NAME ELAPSED)` — prints phase completion with timing (AC: 1, 3)
  - [ ] 1.10 Implement `check_marker(PHASE_NUM)` — returns 0 if `/var/tmp/devbox/.phase-N-complete` exists (AC: 4)
  - [ ] 1.11 Implement `set_marker(PHASE_NUM)` — `touch` the marker file (AC: 4)
  - [ ] 1.12 Implement `clear_marker(PHASE_NUM)` — `rm -f` the marker file (AC: 4)
  - [ ] 1.13 Implement `render_template(TEMPLATE OUTPUT)` — `envsubst < "$1" > "$2"` with success log (AC: 5)
  - [ ] 1.14 Implement `error_handler(LINE EXIT_CODE)` — log error context, tail last 20 lines of log, exit (AC: 6)
  - [ ] 1.15 Implement `retry(COUNT DELAY CMD...)` — loop with sleep, log each retry (AC: 7)
  - [ ] 1.16 Implement `require_env(VAR_NAME)` — check via `${!VAR_NAME}` indirect expansion (AC: 8)
  - [ ] 1.17 Implement `require_command(CMD_NAME)` — check via `command -v` (AC: 9)
  - [ ] 1.18 Verify no `set -euo pipefail` inside the file (AC: 11)

- [ ] **Task 2 — Create `bootstrap.sh`** (AC: 12–26)
  - [ ] 2.1 Add shebang `#!/usr/bin/env bash` and `set -euo pipefail` (AC: 12)
  - [ ] 2.2 Implement `SCRIPT_DIR` detection using `BASH_SOURCE[0]` pattern (AC: 13)
  - [ ] 2.3 Source `${SCRIPT_DIR}/scripts/_common.sh` (AC: 13)
  - [ ] 2.4 Set `trap 'error_handler $LINENO $?' ERR` (AC: 14)
  - [ ] 2.5 Initialize defaults: `DRY_RUN=false`, `SINGLE_PHASE=""`, `ENV_FILE="${HOME}/.tiberbu-env"` (AC: 15)
  - [ ] 2.6 Implement argument parser `while [[ $# -gt 0 ]]` loop with case statement for all 4 flags (AC: 15, 16)
  - [ ] 2.7 Implement `show_help()` with usage examples and flag descriptions (AC: 17)
  - [ ] 2.8 Implement `load_env_file(PATH)` with existence check, `set -a/+a` source, and 7 defaults (AC: 18)
  - [ ] 2.9 Implement `validate_credentials()` with array-collection pattern for missing vars (AC: 19)
  - [ ] 2.10 Implement `run_phase(NUM NAME SCRIPT)` with timing, dry-run branch, and `bash` execution (AC: 20)
  - [ ] 2.11 Add `mkdir -p /var/tmp/devbox` at startup (AC: 25)
  - [ ] 2.12 Call `load_env_file "$ENV_FILE"` and `validate_credentials` in main flow (AC: 18, 19)
  - [ ] 2.13 Add `--phase N` single-phase execution branch (AC: 21)
  - [ ] 2.14 Add default full 5-phase sequential execution block (AC: 22)
  - [ ] 2.15 Add `scripts/verify.sh` invocation after phases (guard: skip in dry-run, skip if `--phase`) (AC: 23)
  - [ ] 2.16 Print total elapsed time using `$SECONDS` (AC: 24)
  - [ ] 2.17 Set executable bit: `chmod +x bootstrap.sh` (AC: 26)

- [ ] **Task 3 — Dry-run mode validation** (AC: 27–30)
  - [ ] 3.1 Confirm `--dry-run` sets `DRY_RUN=true` and `run_phase` prints plan instead of executing (AC: 27, 29)
  - [ ] 3.2 Confirm `load_env_file` and `validate_credentials` still run in dry-run mode (AC: 28)
  - [ ] 3.3 Confirm exit code is 0 when env is valid in dry-run (AC: 30)
  - [ ] 3.4 Confirm exit code is 1 when env file missing in dry-run (AC: 30)

- [ ] **Task 4 — Error handling verification** (AC: 31–34)
  - [ ] 4.1 Verify `set -euo pipefail` + `trap ERR` are in place (AC: 31, 32, 33)
  - [ ] 4.2 Verify `error_handler` output includes log file path (AC: 34)

- [ ] **Task 5 — Quality gates** (AC: 35–40)
  - [ ] 5.1 Run `bash -n scripts/_common.sh` — must exit 0 (AC: 35)
  - [ ] 5.2 Run `bash -n bootstrap.sh` — must exit 0 (AC: 36)
  - [ ] 5.3 Run `./bootstrap.sh --help` — must print usage and exit 0 (AC: 37)
  - [ ] 5.4 Create a minimal valid `.tiberbu-env` test file and run `./bootstrap.sh --dry-run --env-file <path>` — must exit 0 (AC: 38)
  - [ ] 5.5 Run `./bootstrap.sh --dry-run` with no env file — must exit 1 with descriptive message (AC: 39)
  - [ ] 5.6 Run `shellcheck scripts/_common.sh bootstrap.sh` — must produce no errors (AC: 40)

---

## Dev Notes

### Architecture Patterns

- **SCRIPT_DIR pattern:** All scripts use `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` for portable relative sourcing. This works whether the script is called directly, via `bash ./script.sh`, or through `curl | bash`.
- **Auto-export with `set -a`:** The `load_env_file` function uses `set -a; source "$env_file"; set +a` so all variables in `.tiberbu-env` are automatically exported without requiring `export VAR=val` syntax in the file.
- **Collect-all validation:** `validate_credentials` must NOT fail on first missing variable. It collects all missing vars into a bash array `missing=()` and reports them all at once. This is the pattern from the PRD (FR-2).
- **$SECONDS builtin:** Use bash's built-in `$SECONDS` variable (integer seconds since shell started or reset) for phase timing. Reset with `local start=$SECONDS` at phase start; compute `elapsed=$(( SECONDS - start ))`.
- **Marker file idempotency:** Marker files live at `/var/tmp/devbox/.phase-N-complete`. The hybrid strategy (marker + service check) is used in individual phase scripts; `_common.sh` provides the primitives only.
- **No credentials in logs:** The `log_*` functions must never echo variable values that could contain credentials. They log the message string only.
- **Graceful degradation:** `scripts/verify.sh` and any Discord notification steps should use `|| true` so they don't abort the bootstrap if they fail.

### Logging Format

```
stdout:
  ℹ [Phase 1/5] Installing system dependencies...   ← log_phase_start (BLUE)
    → apt update                                     ← log_info (BLUE →)
    ✓ build-essential installed                      ← log_success (GREEN ✓)
    ! wkhtmltopdf using fallback URL                 ← log_warn (YELLOW !)
    ✗ Command failed at line 42                      ← log_error (RED ✗)
  ✓ [Phase 1/5] Complete (14s)                       ← log_phase_end (GREEN)

/var/tmp/devbox/bootstrap.log:
  [INFO] apt update
  [OK]   build-essential installed
  [WARN] wkhtmltopdf using fallback URL
  [ERR]  Command failed at line 42
  === Phase 1/5: Installing system dependencies ===
  === Phase 1/5: Complete (14s) ===
```

### Color Code Reference

```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'   # No Color (reset)
```

### `_common.sh` Function Signatures

| Function | Signature | Notes |
|---|---|---|
| `log_info` | `log_info "message"` | Blue `→` |
| `log_success` | `log_success "message"` | Green `✓` |
| `log_error` | `log_error "message"` | Red `✗` |
| `log_warn` | `log_warn "message"` | Yellow `!` |
| `log_phase_start` | `log_phase_start NUM TOTAL "name"` | Phase header |
| `log_phase_end` | `log_phase_end NUM TOTAL "name" ELAPSED` | Phase footer |
| `check_marker` | `check_marker PHASE_NUM` | 0=exists |
| `set_marker` | `set_marker PHASE_NUM` | touch file |
| `clear_marker` | `clear_marker PHASE_NUM` | rm -f file |
| `render_template` | `render_template TEMPLATE OUTPUT` | envsubst wrapper |
| `error_handler` | `error_handler LINE EXIT_CODE` | ERR trap handler |
| `retry` | `retry COUNT DELAY CMD...` | Retry with sleep |
| `require_env` | `require_env VAR_NAME` | Non-empty check |
| `require_command` | `require_command CMD_NAME` | command -v check |

### bootstrap.sh Required Variables After `load_env_file`

**Required (no default):** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`, `DISCORD_BOT_TOKEN`, `DISCORD_GUILD_ID`, `DISCORD_CHANNEL_ID`, `DISCORD_USER_ID`, `GITHUB_TOKEN`

**Optional (with defaults):**

| Variable | Default |
|---|---|
| `BEDROCK_REGION` | `us-west-1` |
| `BEDROCK_MODEL` | `global.anthropic.claude-opus-4-6-v1` |
| `FRAPPE_BRANCH` | `version-15` |
| `BENCH_SITE` | `dev.local` |
| `MARIADB_ROOT_PASSWORD` | `tiberbu123` |
| `CLAUDE_STUDIO_PORT` | `3000` |
| `OPENCLAW_PORT` | `18789` |

### Phase Execution Map

```bash
run_phase 1 "System dependencies"  "scripts/install-system.sh"
run_phase 2 "Node.js via nvm"      "scripts/install-node.sh"
run_phase 3 "Frappe Bench"         "scripts/install-bench.sh"
run_phase 4 "OpenClaw + Discord"   "scripts/install-openclaw.sh"
run_phase 5 "Claude Code Studio"   "scripts/install-studio.sh"
```

### Downstream Consumers of `_common.sh`

Every phase script will source `_common.sh` from its own directory:
```bash
# From scripts/install-system.sh:
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"
```

This means `_common.sh` must be in `scripts/` and must work when sourced from a sub-directory context.

### Security Notes

- Never log variable values — only log variable names when reporting missing credentials
- `~/.tiberbu-env` should be set to mode 600 by the user; the script does not need to chmod it (it's created by the engineer before running)
- `MARIADB_ROOT_PASSWORD` default is intentionally weak — engineers can override in their `.tiberbu-env`

### Project Structure Notes

**Files to Create:**

```
devbox/
├── bootstrap.sh          ← Main orchestrator (chmod +x)
└── scripts/
    └── _common.sh        ← Shared utility library (sourced, not executed)
```

**This story does NOT create:**
- `scripts/install-*.sh` (S1.2, S1.3 stories)
- `scripts/verify.sh` (S4.1 story)
- `configure.sh` (S4.2 story)
- `templates/` directory (S3.1 story)
- `workspace/` directory (S3.1 story)

**File that `bootstrap.sh` references but doesn't require to exist yet:** `scripts/verify.sh` — bootstrap.sh should invoke it but it's acceptable to guard with `[[ -f "${SCRIPT_DIR}/scripts/verify.sh" ]] && bash ...` so the orchestrator works before verify.sh exists.

### Testing a Minimal `.tiberbu-env` for DoD Verification

```bash
# /tmp/test-env
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_DEFAULT_REGION=us-east-1
DISCORD_BOT_TOKEN=test-bot-token
DISCORD_GUILD_ID=123456789
DISCORD_CHANNEL_ID=987654321
DISCORD_USER_ID=111222333
GITHUB_TOKEN=ghp_testtoken
```

Then: `./bootstrap.sh --dry-run --env-file /tmp/test-env` → should exit 0 and print the 5-phase plan.

### References

- Architecture § 5 — `_common.sh` API Surface [Source: _bmad-output/planning-artifacts/architecture.md#5-shared-utility-library]
- Architecture § 4.1 — Repository Structure [Source: _bmad-output/planning-artifacts/architecture.md#41-repository-structure]
- Architecture § 4.2 — Installed Paths [Source: _bmad-output/planning-artifacts/architecture.md#42-installed-paths-on-target-ec2]
- Architecture § 7 — Idempotency Strategy [Source: _bmad-output/planning-artifacts/architecture.md#7-idempotency-strategy]
- Architecture § 8 — Error Handling [Source: _bmad-output/planning-artifacts/architecture.md#8-error-handling--security]
- Architecture ADR-4 — Structured Logging [Source: _bmad-output/planning-artifacts/architecture.md#adr-4-structured-logging-with-phases-and-timing]
- Architecture ADR-5 — Error Handling [Source: _bmad-output/planning-artifacts/architecture.md#adr-5-error-handling--fail-fast-with-context]
- PRD FR-1 — Environment File Parsing [Source: _bmad-output/planning-artifacts/prd.md#fr-1-environment-file-parsing]
- PRD FR-2 — Credential Validation [Source: _bmad-output/planning-artifacts/prd.md#fr-2-credential-validation]
- PRD FR-13 — Dry-Run Mode [Source: _bmad-output/planning-artifacts/prd.md#fr-13-dry-run-mode]
- PRD NFR-2 — Reliability / Retries [Source: _bmad-output/planning-artifacts/prd.md#nfr-2-reliability]
- PRD NFR-4 — Security [Source: _bmad-output/planning-artifacts/prd.md#nfr-4-security]
- PRD Appendix A — Environment Variable Reference [Source: _bmad-output/planning-artifacts/prd.md#appendix-a-environment-variable-reference]

---

## Dev Agent Record

### Agent Model Used

_to be filled by dev agent_

### Debug Log References

_to be filled by dev agent_

### Completion Notes List

_to be filled by dev agent_

### File List

- `scripts/_common.sh`
- `bootstrap.sh`
