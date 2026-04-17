# Story 4.1: Verification and Smoke Test (verify.sh)

Status: ready-for-dev

## Story

As a Tiberbu engineer,
I want a standalone `scripts/verify.sh` script that runs 16 health checks across all installed components, prints a color-coded summary table, and sends a Discord notification,
so that I can confirm the entire DevBox stack is operational after bootstrap and get immediate notification in Discord.

---

## Acceptance Criteria

### AC-1: 16-Point Health Check Suite

Each check must log PASS/FAIL via `log_success`/`log_error`, collect a detail string, and increment a pass/fail counter. Checks run even after a failure (no early exit).

- [ ] **Check 1 — MariaDB service running:** `systemctl is-active mariadb` → "active"
- [ ] **Check 2 — MariaDB connection:** `mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SELECT 1"` → exit 0
- [ ] **Check 3 — MariaDB charset:** `SHOW VARIABLES LIKE 'character_set_server'` → value = "utf8mb4"
- [ ] **Check 4 — Redis service running:** `systemctl is-active redis-server` → "active"
- [ ] **Check 5 — Redis PING:** `redis-cli ping` → "PONG"
- [ ] **Check 6 — Node.js version:** nvm sourced, `node -v` → matches `v24.*`
- [ ] **Check 7 — yarn version:** `yarn --version` → matches `1\.22\.`
- [ ] **Check 8 — Bench CLI:** `bench --version` → matches `5\.`
- [ ] **Check 9 — Bench site:** `cd ~/frappe-bench && bench --site ${BENCH_SITE} list-apps` → output includes "frappe"
- [ ] **Check 10 — OpenClaw version:** `openclaw --version` → exits 0, captures version string
- [ ] **Check 11 — OpenClaw gateway (systemd --user):** `systemctl --user is-active openclaw-gateway` → "active"
- [ ] **Check 12 — OpenClaw port listening:** `curl -sf --max-time 5 "http://localhost:${OPENCLAW_PORT}/health"` OR `ss -tlnp | grep -q ":${OPENCLAW_PORT}"` → success
- [ ] **Check 13 — Claude Studio service:** `systemctl is-active claude-studio` → "active"
- [ ] **Check 14 — Claude Studio HTTP:** `curl -sf --max-time 5 "http://localhost:${CLAUDE_STUDIO_PORT}"` → HTTP 200
- [ ] **Check 15 — Git auth:** `git ls-remote "https://github.com/tiberbu/devbox.git" >/dev/null 2>&1` → exit 0
- [ ] **Check 16 — Discord notification sent** (trigger at end of run, see AC-3; if sent, Check 16 = PASS)
- [ ] Each check increments `PASS_COUNT` or `FAIL_COUNT`

### AC-2: Summary Table

- [ ] After all checks, print a Unicode box-draw table to stdout:
  ```
  ╔══════════════════════════════════════════════════════╗
  ║        Tiberbu DevBox — Verification Report          ║
  ╠══════════════════╦══════════╦════════════════════════╣
  ║ Component        ║ Status   ║ Detail                 ║
  ╠══════════════════╬══════════╬════════════════════════╣
  ║ MariaDB          ║ ✓ PASS   ║ utf8mb4 :3306          ║
  ║ Redis            ║ ✓ PASS   ║ PONG :6379             ║
  ║ Node.js          ║ ✓ PASS   ║ v24.x.x                ║
  ║ yarn             ║ ✓ PASS   ║ 1.22.x                 ║
  ║ Frappe Bench     ║ ✓ PASS   ║ 5.x.x site:dev.local   ║
  ║ OpenClaw         ║ ✓ PASS   ║ 2026.x.x :18789        ║
  ║ Claude Studio    ║ ✓ PASS   ║ :3000                  ║
  ║ Git Auth         ║ ✓ PASS   ║ github.com/tiberbu     ║
  ║ Discord          ║ ✓ PASS   ║ notification sent      ║
  ╠══════════════════╬══════════╬════════════════════════╣
  ║ TOTAL            ║ 16/16    ║ ALL CHECKS PASSED      ║
  ╚══════════════════╩══════════╩════════════════════════╝
  ```
- [ ] PASS rows: green `✓ PASS`, FAIL rows: red `✗ FAIL`
- [ ] Summary line: `N/16 passed` — green if 16/16, red otherwise
- [ ] Table uses `printf` or `echo -e` with color codes from `_common.sh`

### AC-3: Discord Notification

- [ ] POST to `https://discord.com/api/v10/channels/${DISCORD_CHANNEL_ID}/messages`
- [ ] Auth header: `Authorization: Bot ${DISCORD_BOT_TOKEN}`
- [ ] Content-Type: `application/json`
- [ ] Body is a Discord embed JSON payload containing:
  - `title`: "✅ DevBox Setup Complete" (or "⚠️ DevBox Setup — Issues Found" if failures)
  - `color`: `65280` (green) or `16711680` (red)
  - `fields`: hostname, services count (`N/16 checks passed`), URLs (Claude Studio, Frappe Bench)
  - `timestamp`: ISO 8601 from `date -u +%Y-%m-%dT%H:%M:%SZ`
- [ ] Discord failure uses `|| true` — does NOT fail the script
- [ ] Discord success/failure is logged via `log_success` or `log_warn`
- [ ] Check 16 is set to PASS if the curl command exits 0, FAIL (warning only) if it fails

### AC-4: Exit Code

- [ ] Exit 0 if all 16 checks pass (Discord notification failure is best-effort; a Discord failure sets Check 16 = FAIL but still exits 1)
- [ ] Exit 1 if **any** of Checks 1–15 fail (critical infrastructure)
- [ ] Discord notification failure (Check 16) causes FAIL in the table/count but does NOT by itself cause an exit 1 — use `|| true` for curl; track separately

> **Clarification:** Exit code is driven by Checks 1–15. If all 1–15 pass but Discord fails, still exit 0 (best-effort). Table shows 15/16 + Discord warning.

### AC-5: Standalone Execution

- [ ] Script starts with `#!/usr/bin/env bash` and `set -euo pipefail`
- [ ] `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`
- [ ] Sources `${SCRIPT_DIR}/_common.sh` for logging and color constants
- [ ] Loads `~/.tiberbu-env` via `set -a; source "${HOME}/.tiberbu-env"; set +a` (with graceful handling if missing)
- [ ] Applies defaults: `MARIADB_ROOT_PASSWORD`, `BENCH_SITE`, `OPENCLAW_PORT`, `CLAUDE_STUDIO_PORT`
- [ ] Sources nvm: `. "${HOME}/.nvm/nvm.sh"` (required for node/yarn/openclaw/bench)
- [ ] Supports `--phase N` flag to run only the checks for that phase's components:
  - `--phase 1`: Checks 1–5 (MariaDB + Redis)
  - `--phase 2`: Checks 6–7 (Node.js + yarn)
  - `--phase 3`: Checks 8–9 (Frappe Bench)
  - `--phase 4`: Checks 10–12 (OpenClaw)
  - `--phase 5`: Checks 13–14 (Claude Studio)
  - No `--phase`: run all 16

---

## Tasks / Subtasks

- [ ] Task 1: Script skeleton and env setup (AC-5)
  - [ ] 1.1 Shebang, `set -euo pipefail`, ERR trap
  - [ ] 1.2 SCRIPT_DIR + source `_common.sh`
  - [ ] 1.3 Load `~/.tiberbu-env` (graceful if absent — checks may still partially run)
  - [ ] 1.4 Set defaults for all optional vars (MARIADB_ROOT_PASSWORD, BENCH_SITE, OPENCLAW_PORT, CLAUDE_STUDIO_PORT)
  - [ ] 1.5 Source nvm
  - [ ] 1.6 Parse `--phase N` argument; set PHASE_FILTER variable

- [ ] Task 2: Implement helper function `run_check` (AC-1)
  - [ ] 2.1 Signature: `run_check LABEL CMD_BLOCK DETAIL_VAR`
  - [ ] 2.2 Runs command block, captures output for detail
  - [ ] 2.3 On success: `log_success`, increments PASS_COUNT, appends row to TABLE_ROWS
  - [ ] 2.4 On failure: `log_error`, increments FAIL_COUNT, appends FAIL row to TABLE_ROWS
  - [ ] 2.5 Does NOT abort script on individual check failure (use `|| true` inside run_check or `if/else`)

- [ ] Task 3: Implement all 16 checks (AC-1)
  - [ ] 3.1 Check 1: MariaDB systemctl active
  - [ ] 3.2 Check 2: MariaDB SELECT 1 via mariadb CLI (use `-p${MARIADB_ROOT_PASSWORD}` without space)
  - [ ] 3.3 Check 3: MariaDB charset — parse `SHOW VARIABLES LIKE 'character_set_server'`
  - [ ] 3.4 Check 4: Redis systemctl active
  - [ ] 3.5 Check 5: `redis-cli ping` returns PONG
  - [ ] 3.6 Check 6: `node -v` matches `v24`
  - [ ] 3.7 Check 7: `yarn --version` matches `1.22`
  - [ ] 3.8 Check 8: `bench --version` matches `5.`
  - [ ] 3.9 Check 9: `bench --site ${BENCH_SITE} list-apps` from ~/frappe-bench includes "frappe"
  - [ ] 3.10 Check 10: `openclaw --version` exits 0; capture version for detail
  - [ ] 3.11 Check 11: `systemctl --user is-active openclaw-gateway` returns "active"
  - [ ] 3.12 Check 12: Port listening — try curl first, fall back to ss; use `--max-time 5`
  - [ ] 3.13 Check 13: `systemctl is-active claude-studio` returns "active"
  - [ ] 3.14 Check 14: `curl -sf --max-time 10` to Claude Studio port → HTTP 200
  - [ ] 3.15 Check 15: `git ls-remote` to tiberbu/devbox → exit 0
  - [ ] 3.16 Check 16: Discord notification (see Task 4); record result as PASS/FAIL in table

- [ ] Task 4: Discord notification function (AC-3)
  - [ ] 4.1 Build JSON embed payload as heredoc variable
  - [ ] 4.2 Set `color` based on FAIL_COUNT > 0
  - [ ] 4.3 Include fields: Hostname (`hostname`), Checks (`N/16 passed`), Claude Studio URL, Frappe Bench URL, Timestamp
  - [ ] 4.4 Use `curl -sf -X POST` with Bot auth header; wrap entire call with `|| true`
  - [ ] 4.5 Capture exit code to set Check 16 result BEFORE printing table

- [ ] Task 5: Summary table and exit (AC-2, AC-4)
  - [ ] 5.1 Print box-draw header
  - [ ] 5.2 Print each row (stored in array or built string) with color: green for PASS, red for FAIL
  - [ ] 5.3 Print separator + total row: `N/16 passed`
  - [ ] 5.4 Exit 0 if FAIL_COUNT == 0 (excluding Discord-only failures), else exit 1
  - [ ] 5.5 (Discord failure: increment FAIL_COUNT but exit logic checks only Checks 1–15)

- [ ] Task 6: ShellCheck and syntax validation (Definition of Done)
  - [ ] 6.1 `bash -n scripts/verify.sh` → clean
  - [ ] 6.2 `shellcheck scripts/verify.sh` → zero errors, zero warnings
  - [ ] 6.3 Verify `--phase 1` runs only MariaDB/Redis checks and exits correctly

---

## Dev Notes

### Script Structure Pattern

All phase scripts in this project follow this pattern (verify.sh adapts it):

```bash
#!/usr/bin/env bash
set -euo pipefail
trap 'error_handler "${BASH_SOURCE[0]}" "${LINENO}" "$?"' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

# Load env
ENV_FILE="${HOME}/.tiberbu-env"
if [[ -f "${ENV_FILE}" ]]; then
    set -a; source "${ENV_FILE}"; set +a
fi

# Defaults
: "${MARIADB_ROOT_PASSWORD:=tiberbu123}"
: "${BENCH_SITE:=dev.local}"
: "${OPENCLAW_PORT:=18789}"
: "${CLAUDE_STUDIO_PORT:=3000}"

# Source nvm (required for node, yarn, bench, openclaw)
export NVM_DIR="${HOME}/.nvm"
[[ -s "${NVM_DIR}/nvm.sh" ]] && . "${NVM_DIR}/nvm.sh"
```

### Check Implementation Pattern

Use a helper that captures success/failure without aborting the script:

```bash
PASS_COUNT=0
FAIL_COUNT=0
declare -a TABLE_ROWS=()

# run_check LABEL DETAIL_IF_PASS DETAIL_IF_FAIL COMMAND [ARGS...]
run_check() {
    local label="$1"
    local detail_pass="$2"
    local detail_fail="$3"
    shift 3
    if "$@" >/dev/null 2>&1; then
        PASS_COUNT=$(( PASS_COUNT + 1 ))
        TABLE_ROWS+=("PASS|${label}|${detail_pass}")
        log_success "[CHECK] ${label}: PASS"
    else
        FAIL_COUNT=$(( FAIL_COUNT + 1 ))
        TABLE_ROWS+=("FAIL|${label}|${detail_fail}")
        log_error "[CHECK] ${label}: FAIL"
    fi
}
```

For checks that need output capture for details:

```bash
# Check 3: MariaDB charset
_check_mariadb_charset() {
    local result
    result=$(mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" -sse \
        "SHOW VARIABLES LIKE 'character_set_server';" 2>/dev/null | awk '{print $2}')
    [[ "${result}" == "utf8mb4" ]]
}
run_check "MariaDB charset" "utf8mb4" "not utf8mb4" _check_mariadb_charset
```

### Discord API Payload

```bash
send_discord_notification() {
    local pass_count="$1"
    local total_count="$2"
    local color
    color=$(( pass_count == total_count ? 65280 : 16711680 ))
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local hostname
    hostname=$(hostname)

    local payload
    payload=$(cat <<DISCORD_EOF
{
  "embeds": [{
    "title": "$([ "${pass_count}" -eq "${total_count}" ] && echo "✅ DevBox Setup Complete" || echo "⚠️ DevBox Setup — Issues Found")",
    "color": ${color},
    "fields": [
      {"name": "Hostname", "value": "${hostname}", "inline": true},
      {"name": "Checks", "value": "${pass_count}/${total_count} passed", "inline": true},
      {"name": "Claude Studio", "value": "http://${hostname}:${CLAUDE_STUDIO_PORT}", "inline": false},
      {"name": "Frappe Bench", "value": "http://${hostname}:8000", "inline": false}
    ],
    "timestamp": "${timestamp}"
  }]
}
DISCORD_EOF
)

    curl -sf -X POST \
        -H "Authorization: Bot ${DISCORD_BOT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${payload}" \
        "https://discord.com/api/v10/channels/${DISCORD_CHANNEL_ID}/messages" \
        >/dev/null 2>&1
}
```

### --phase Flag Implementation

```bash
PHASE_FILTER=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --phase) PHASE_FILTER="$2"; shift 2 ;;
        *) log_warn "Unknown arg: $1"; shift ;;
    esac
done

run_phase_checks() {
    local phase="$1"
    case "${phase}" in
        1) run_checks_mariadb_redis ;;
        2) run_checks_node ;;
        3) run_checks_bench ;;
        4) run_checks_openclaw ;;
        5) run_checks_studio ;;
        *) log_error "Unknown phase: ${phase}"; exit 1 ;;
    esac
}

if [[ -n "${PHASE_FILTER}" ]]; then
    run_phase_checks "${PHASE_FILTER}"
else
    run_checks_mariadb_redis   # Checks 1-5
    run_checks_node            # Checks 6-7
    run_checks_bench           # Checks 8-9
    run_checks_openclaw        # Checks 10-12
    run_checks_studio          # Checks 13-14
    run_checks_git             # Check 15
    run_discord_and_check16    # Check 16
fi
```

### Summary Table Rendering

Use `printf` for alignment. The table uses Unicode box-draw characters. Test that your terminal supports them (Ubuntu 24.04 does by default).

```bash
print_summary_table() {
    local total=$(( PASS_COUNT + FAIL_COUNT ))
    printf '\n'
    printf '╔══════════════════════════════════════════════════════╗\n'
    printf '║        Tiberbu DevBox — Verification Report          ║\n'
    printf '╠══════════════════╦══════════╦════════════════════════╣\n'
    printf '║ %-16s ║ %-8s ║ %-22s ║\n' "Component" "Status" "Detail"
    printf '╠══════════════════╬══════════╬════════════════════════╣\n'

    for row in "${TABLE_ROWS[@]}"; do
        IFS='|' read -r status label detail <<< "${row}"
        if [[ "${status}" == "PASS" ]]; then
            status_str="${GREEN}✓ PASS${NC}"
        else
            status_str="${RED}✗ FAIL${NC}"
        fi
        printf "║ %-16s ║ ${status_str}%-$((8 - 7))s ║ %-22s ║\n" \
            "${label}" "" "${detail}"
    done

    printf '╠══════════════════╬══════════╬════════════════════════╣\n'
    if [[ ${FAIL_COUNT} -eq 0 ]]; then
        printf '║ %-16s ║ %-8s ║ %-22s ║\n' "TOTAL" "${PASS_COUNT}/${total}" "ALL CHECKS PASSED"
    else
        printf '║ %-16s ║ %-8s ║ %-22s ║\n' "TOTAL" "${PASS_COUNT}/${total}" "${FAIL_COUNT} FAILED"
    fi
    printf '╚══════════════════╩══════════╩════════════════════════╝\n'
    printf '\n'
}
```

> **Note:** Printf color codes inside table rows need careful padding math. An alternative simpler approach: build each row as a string with `printf "| %-16s |" "${label}"` and echo color separately. Choose whichever ShellCheck passes without complaints.

### Important: bench and openclaw PATH

`bench` requires the Python virtualenv that Frappe Bench activates. The `bench` CLI is typically at `~/.local/bin/bench` after `pip install frappe-bench`. nvm must be sourced for `openclaw`, `node`, `yarn`. Do not assume these are on PATH without sourcing nvm first.

```bash
# Add ~/.local/bin to PATH for bench CLI
export PATH="${HOME}/.local/bin:${PATH}"
```

### MariaDB CLI Note

On Ubuntu 24.04, the `mariadb` command is preferred over `mysql`. Both accept the same flags. Use `mariadb` for consistency with the installation scripts.

Password with no space: `-p"${MARIADB_ROOT_PASSWORD}"` (no space between `-p` and the value).

### Git Auth Check

```bash
_check_git_auth() {
    git ls-remote "https://github.com/tiberbu/devbox.git" >/dev/null 2>&1
}
```

This requires the git credential store to be configured (done by install-studio.sh). If the credential store is not set up, this will fail.

### Exit Code Logic

```bash
# After all checks and table print:
# Discord failure (Check 16) is best-effort — only critical checks 1-15 drive exit code
CRITICAL_FAIL_COUNT=$(( FAIL_COUNT - DISCORD_FAIL ))  # DISCORD_FAIL is 0 or 1
if [[ ${CRITICAL_FAIL_COUNT} -gt 0 ]]; then
    exit 1
fi
exit 0
```

---

### Project Structure Notes

- **File to create:** `scripts/verify.sh` — one new file
- **Files read:** `scripts/_common.sh` (sourced), `~/.tiberbu-env` (loaded)
- **No files modified:** verify.sh does not write to disk beyond logging
- **Executable bit:** `chmod +x scripts/verify.sh`
- **Log output:** All check results also written to `$LOG_FILE` (`/var/tmp/devbox/bootstrap.log`) via `_common.sh` log functions

The script must work when called from bootstrap.sh as `bash "${SCRIPT_DIR}/scripts/verify.sh"` and also directly as `./scripts/verify.sh`.

### References

- Architecture file: [Source: _bmad-output/planning-artifacts/architecture.md — §8 Verification Checklist]
- PRD: [Source: _bmad-output/planning-artifacts/prd.md — FR-9: Post-Install Verification, FR-10: Discord Notification]
- Epics: [Source: _bmad-output/planning-artifacts/epics.md — Epic 4: Verification & Polish]
- Common utilities: [Source: scripts/_common.sh — log_info, log_success, log_error, log_warn, error_handler]
- Service ports: [Source: _bmad-output/planning-artifacts/architecture.md — §1.2 Service Architecture]: MariaDB :3306, Redis :6379, Frappe :8000, Claude Studio :3000, OpenClaw :18789
- Discord API: `POST https://discord.com/api/v10/channels/{channel.id}/messages` with `Authorization: Bot TOKEN`
- Existing story for reference patterns: [Source: _bmad-output/implementation-artifacts/story-30-s2-3-frappe-bench-installer-install-bench-sh.md]

---

## Dev Agent Record

### Agent Model Used

sonnet

### Debug Log References

### Completion Notes List

### File List

- scripts/verify.sh (to create)
