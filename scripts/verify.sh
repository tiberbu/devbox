#!/usr/bin/env bash
# scripts/verify.sh — Tiberbu DevBox Verification & Smoke Test
#
# Runs 16 health checks across all installed components, prints a
# color-coded summary table, and sends a Discord notification.
#
# Usage:
#   ./scripts/verify.sh                  Run all 16 checks
#   ./scripts/verify.sh --phase N        Run only phase N checks (1–6)
#   ./scripts/verify.sh --env-file PATH  Env file path (default: ~/.tiberbu-env)
#   ./scripts/verify.sh --help           Show this help
#
# Phase groups (aligned with bootstrap.sh phases):
#   1 — System:   MariaDB running, connection, charset; Redis running, ping (5)
#   2 — Node.js:  Node.js v24.x.x, yarn 1.22.x                            (2)
#   3 — Bench:    bench CLI 5.x.x, bench site list-apps frappe             (2)
#   4 — OpenClaw: version, gateway service, port listening                 (3)
#   5 — Studio:   claude-studio service, HTTP 200                          (2)
#   6 — Auth:     git ls-remote tiberbu/devbox, Discord notification       (2)
#
# Exit codes:
#   0 — all 15 critical checks passed (check 16 / Discord is best-effort)
#   1 — one or more critical checks (1–15) failed
#
# Note: -e (exit-on-error) is intentionally omitted; individual health checks
# are expected to fail on a partially-provisioned system.
set -uo pipefail

# ============================================================
# Locate script directory and source shared library
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/_common.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_common.sh"

# ============================================================
# Argument defaults
# ============================================================
ENV_FILE="${HOME}/.tiberbu-env"
PHASE_FILTER=""

# ============================================================
# Usage / help
# ============================================================
usage() {
    cat <<'USAGE'
Usage: ./scripts/verify.sh [OPTIONS]

Runs 16 health checks across all Tiberbu DevBox components, prints a
color-coded summary table, and sends a Discord notification.

Options:
  --phase N          Run only phase N checks (1-6)
  --env-file PATH    Path to env file (default: ~/.tiberbu-env)
  --help             Show this help message

Phase groups:
  1 — System:   MariaDB running, connection, charset; Redis running, ping (5)
  2 — Node.js:  Node.js v24.x.x, yarn 1.22.x                            (2)
  3 — Bench:    bench CLI 5.x.x, bench site list-apps frappe             (2)
  4 — OpenClaw: version, gateway service, port listening                 (3)
  5 — Studio:   claude-studio service, HTTP 200                         (2)
  6 — Auth:     git ls-remote tiberbu/devbox, Discord notification      (2)

Exit codes:
  0 — all 15 critical checks passed (check 16 / Discord is best-effort)
  1 — one or more critical checks (1-15) failed
USAGE
}

# ============================================================
# Parse arguments
# ============================================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        --phase)
            if [[ -z "${2:-}" ]]; then
                printf 'Error: --phase requires an argument\n' >&2
                usage >&2
                exit 1
            fi
            PHASE_FILTER="$2"
            shift 2
            ;;
        --env-file)
            if [[ -z "${2:-}" ]]; then
                printf 'Error: --env-file requires an argument\n' >&2
                usage >&2
                exit 1
            fi
            ENV_FILE="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            printf 'Error: Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ -n "${PHASE_FILTER}" ]]; then
    if ! [[ "${PHASE_FILTER}" =~ ^[1-6]$ ]]; then
        printf 'Error: --phase must be 1–6 (got: %s)\n' "${PHASE_FILTER}" >&2
        exit 1
    fi
fi

# ============================================================
# Result tracking
# ============================================================
declare -a CHECK_NAMES=()
declare -a CHECK_STATUS=()
declare -a CHECK_DETAILS=()
PASS_COUNT=0
FAIL_COUNT=0
# Critical = checks 1–15; check 16 (Discord) is best-effort only
CRITICAL_FAIL_COUNT=0
TOTAL_CHECKS=0

# ============================================================
# record_check NAME STATUS DETAIL [CRITICAL]
#   STATUS  : "PASS" or "FAIL"
#   CRITICAL: "true" (default) — affects exit code; "false" = best-effort
# ============================================================
record_check() {
    local name="$1"
    local status="$2"
    local detail="$3"
    local critical="${4:-true}"

    TOTAL_CHECKS=$(( TOTAL_CHECKS + 1 ))
    CHECK_NAMES+=("${name}")
    CHECK_STATUS+=("${status}")
    CHECK_DETAILS+=("${detail}")

    local label
    label="[${TOTAL_CHECKS}] ${name}: ${detail}"

    if [[ "${status}" == "PASS" ]]; then
        PASS_COUNT=$(( PASS_COUNT + 1 ))
        log_success "${label}"
    else
        FAIL_COUNT=$(( FAIL_COUNT + 1 ))
        if [[ "${critical}" == "true" ]]; then
            CRITICAL_FAIL_COUNT=$(( CRITICAL_FAIL_COUNT + 1 ))
        fi
        log_error "${label}"
    fi
}

# ============================================================
# Environment loading
# ============================================================
load_env() {
    if [[ -f "${ENV_FILE}" ]]; then
        set -a
        # shellcheck disable=SC1090
        source "${ENV_FILE}"
        set +a
        log_info "Loaded env file: ${ENV_FILE}"
    else
        log_warn "Env file not found: ${ENV_FILE} — using environment variables"
    fi

    # Apply defaults for optional variables (no-op if already set)
    : "${MARIADB_ROOT_PASSWORD:=tiberbu123}"
    : "${BENCH_SITE:=dev.local}"
    : "${OPENCLAW_PORT:=18789}"
    : "${CLAUDE_STUDIO_PORT:=3000}"
}

# ============================================================
# NVM helper — sourced silently; node checks handle missing node
# ============================================================
_source_nvm() {
    local nvm_dir="${HOME}/.nvm"
    # shellcheck disable=SC1090,SC1091
    if [[ -s "${nvm_dir}/nvm.sh" ]]; then
        source "${nvm_dir}/nvm.sh" 2>/dev/null || true
    fi
}

# ============================================================
# Phase 1: System — Checks 1–5
# ============================================================

check_01_mariadb_running() {
    local state
    state="$(systemctl is-active mariadb 2>/dev/null || true)"
    if [[ "${state}" == "active" ]]; then
        record_check "MariaDB running" "PASS" "systemctl: active"
    else
        record_check "MariaDB running" "FAIL" "systemctl: ${state:-unknown}"
    fi
}

check_02_mariadb_connection() {
    if mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SELECT 1;" \
            >/dev/null 2>&1; then
        record_check "MariaDB connection" "PASS" "SELECT 1 succeeded"
    else
        record_check "MariaDB connection" "FAIL" \
            "cannot connect as root (check MARIADB_ROOT_PASSWORD)"
    fi
}

check_03_mariadb_charset() {
    local charset
    charset="$(mysql -u root -p"${MARIADB_ROOT_PASSWORD}" \
        -sNe "SHOW VARIABLES LIKE 'character_set_server';" 2>/dev/null \
        | awk '{print $2}' || true)"
    if [[ "${charset}" == "utf8mb4" ]]; then
        record_check "MariaDB charset" "PASS" "character_set_server=utf8mb4"
    else
        record_check "MariaDB charset" "FAIL" \
            "character_set_server=${charset:-unknown} (expected utf8mb4)"
    fi
}

check_04_redis_running() {
    local state
    state="$(systemctl is-active redis-server 2>/dev/null || true)"
    if [[ "${state}" == "active" ]]; then
        record_check "Redis running" "PASS" "systemctl: active"
    else
        record_check "Redis running" "FAIL" "systemctl: ${state:-unknown}"
    fi
}

check_05_redis_ping() {
    local pong
    pong="$(redis-cli ping 2>/dev/null || true)"
    if [[ "${pong}" == "PONG" ]]; then
        record_check "Redis PING" "PASS" "redis-cli ping → PONG"
    else
        record_check "Redis PING" "FAIL" \
            "got: ${pong:-<empty>} (expected PONG)"
    fi
}

# ============================================================
# Phase 2: Node.js — Checks 6–7
# ============================================================

check_06_nodejs_version() {
    local node_ver
    node_ver="$(node -v 2>/dev/null || true)"
    if [[ "${node_ver}" =~ ^v24\. ]]; then
        record_check "Node.js version" "PASS" "${node_ver}"
    else
        record_check "Node.js version" "FAIL" \
            "${node_ver:-not found} (expected v24.x.x)"
    fi
}

check_07_yarn_version() {
    local yarn_ver
    yarn_ver="$(yarn --version 2>/dev/null || true)"
    if [[ "${yarn_ver}" =~ ^1\.22\. ]]; then
        record_check "yarn version" "PASS" "${yarn_ver}"
    else
        record_check "yarn version" "FAIL" \
            "${yarn_ver:-not found} (expected 1.22.x)"
    fi
}

# ============================================================
# Phase 3: Bench — Checks 8–9
# ============================================================

check_08_bench_cli() {
    local bench_ver
    bench_ver="$(bench --version 2>/dev/null || true)"
    if [[ "${bench_ver}" =~ ^5\. ]]; then
        record_check "Bench CLI" "PASS" "bench ${bench_ver}"
    else
        record_check "Bench CLI" "FAIL" \
            "${bench_ver:-not found} (expected 5.x.x)"
    fi
}

check_09_bench_site() {
    local bench_dir="${HOME}/frappe-bench"
    local apps=""
    if cd "${bench_dir}" 2>/dev/null; then
        apps="$(bench --site "${BENCH_SITE}" list-apps 2>/dev/null || true)"
    fi
    if printf '%s\n' "${apps}" | grep -q "frappe"; then
        record_check "Bench site (frappe)" "PASS" \
            "frappe in list-apps on ${BENCH_SITE}"
    else
        record_check "Bench site (frappe)" "FAIL" \
            "frappe not in list-apps (site: ${BENCH_SITE})"
    fi
}

# ============================================================
# Phase 4: OpenClaw — Checks 10–12
# ============================================================

check_10_openclaw_version() {
    local oc_ver
    oc_ver="$(openclaw --version 2>/dev/null || true)"
    if [[ -n "${oc_ver}" ]]; then
        record_check "OpenClaw version" "PASS" "${oc_ver}"
    else
        record_check "OpenClaw version" "FAIL" \
            "openclaw --version returned empty (not installed?)"
    fi
}

check_11_openclaw_service() {
    local state
    state="$(systemctl --user is-active openclaw-gateway 2>/dev/null || true)"
    if [[ "${state}" == "active" ]]; then
        record_check "OpenClaw gateway" "PASS" "systemctl --user: active"
    else
        record_check "OpenClaw gateway" "FAIL" \
            "systemctl --user: ${state:-unknown}"
    fi
}

check_12_openclaw_port() {
    local port="${OPENCLAW_PORT}"
    if ss -tlnp 2>/dev/null | grep -q ":${port}"; then
        record_check "OpenClaw port" "PASS" "port ${port} listening (ss)"
    elif curl -sf "http://localhost:${port}/health" >/dev/null 2>&1; then
        record_check "OpenClaw port" "PASS" \
            "HTTP health check passed on port ${port}"
    else
        record_check "OpenClaw port" "FAIL" "port ${port} not listening"
    fi
}

# ============================================================
# Phase 5: Claude Studio — Checks 13–14
# ============================================================

check_13_studio_service() {
    local state
    state="$(systemctl is-active claude-studio 2>/dev/null || true)"
    if [[ "${state}" == "active" ]]; then
        record_check "Claude Studio service" "PASS" "systemctl: active"
    else
        record_check "Claude Studio service" "FAIL" \
            "systemctl: ${state:-unknown}"
    fi
}

check_14_studio_port() {
    local port="${CLAUDE_STUDIO_PORT}"
    local http_code
    http_code="$(curl -sL -o /dev/null -w '%{http_code}' \
        "http://localhost:${port}" 2>/dev/null || true)"
    if [[ "${http_code}" == "200" ]]; then
        record_check "Claude Studio HTTP" "PASS" "HTTP 200 on port ${port}"
    else
        record_check "Claude Studio HTTP" "FAIL" \
            "HTTP ${http_code:-no response} on port ${port}"
    fi
}

# ============================================================
# Phase 6: Auth + Notifications — Checks 15–16
# ============================================================

check_15_git_auth() {
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        record_check "Git auth (tiberbu/devbox)" "FAIL" \
            "GITHUB_TOKEN not set"
        return 0
    fi
    local result
    result="$(GIT_TERMINAL_PROMPT=0 \
        git ls-remote \
        "https://${GITHUB_TOKEN}@github.com/tiberbu/devbox.git" HEAD \
        2>/dev/null | head -1 || true)"
    if [[ -n "${result}" ]]; then
        record_check "Git auth (tiberbu/devbox)" "PASS" \
            "ls-remote HEAD succeeded"
    else
        record_check "Git auth (tiberbu/devbox)" "FAIL" \
            "ls-remote returned empty (token invalid?)"
    fi
}

# ============================================================
# Discord notification builder
# Outputs "sent (HTTP NNN)", "skipped (no credentials)", or error string.
# Called from check_16_discord_notification.
# ============================================================
_build_discord_payload() {
    local color="$1"
    local hostname="$2"
    local pass_count="$3"
    local studio_url="$4"
    local openclaw_url="$5"
    local timestamp="$6"

    if command -v jq &>/dev/null; then
        jq -n \
            --argjson color "${color}" \
            --arg desc "${pass_count}/16 checks passed on ${hostname}" \
            --arg hostname "${hostname}" \
            --arg services "${pass_count}/16 healthy" \
            --arg studio "${studio_url}" \
            --arg openclaw "${openclaw_url}" \
            --arg ts "${timestamp}" \
            '{
                embeds: [{
                    title: "Tiberbu DevBox Health Check",
                    color: $color,
                    description: $desc,
                    fields: [
                        {name: "Hostname",      value: $hostname, inline: true},
                        {name: "Services",      value: $services, inline: true},
                        {name: "Claude Studio", value: $studio,   inline: false},
                        {name: "OpenClaw",      value: $openclaw, inline: false}
                    ],
                    timestamp: $ts
                }]
            }'
    else
        # Fallback: hand-built JSON (safe for typical hostname / URL values)
        printf \
            '{"embeds":[{"title":"Tiberbu DevBox Health Check","color":%d,'\
'"description":"%d/16 checks passed on %s",'\
'"fields":[{"name":"Hostname","value":"%s","inline":true},'\
'{"name":"Services","value":"%d/16 healthy","inline":true},'\
'{"name":"Claude Studio","value":"%s","inline":false},'\
'{"name":"OpenClaw","value":"%s","inline":false}],'\
'"timestamp":"%s"}]}' \
            "${color}" "${pass_count}" "${hostname}" \
            "${hostname}" "${pass_count}" \
            "${studio_url}" "${openclaw_url}" \
            "${timestamp}"
    fi
}

_send_discord_notification() {
    if [[ -z "${DISCORD_BOT_TOKEN:-}" || -z "${DISCORD_CHANNEL_ID:-}" ]]; then
        printf 'skipped (DISCORD_BOT_TOKEN or DISCORD_CHANNEL_ID not set)'
        return 0
    fi

    local hostname
    hostname="$(hostname -f 2>/dev/null \
        || hostname 2>/dev/null \
        || printf 'unknown')"

    # Embed color: green when all critical checks pass, red otherwise
    local color=15158332  # red
    if [[ "${CRITICAL_FAIL_COUNT}" -eq 0 ]]; then
        color=3066993     # green
    fi

    local timestamp
    timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    local studio_url="http://${hostname}:${CLAUDE_STUDIO_PORT}"
    local openclaw_url="http://${hostname}:${OPENCLAW_PORT}"

    local payload
    payload="$(_build_discord_payload \
        "${color}" "${hostname}" "${PASS_COUNT}" \
        "${studio_url}" "${openclaw_url}" "${timestamp}")" || true

    if [[ -z "${payload}" ]]; then
        printf 'send failed (could not build JSON payload)'
        return 0
    fi

    local http_code
    http_code="$(curl -sf \
        -o /dev/null \
        -w '%{http_code}' \
        -X POST \
        -H "Authorization: Bot ${DISCORD_BOT_TOKEN}" \
        -H 'Content-Type: application/json' \
        -d "${payload}" \
        "https://discord.com/api/v10/channels/${DISCORD_CHANNEL_ID}/messages" \
        2>/dev/null)" || true

    if [[ "${http_code:-000}" =~ ^2 ]]; then
        printf 'sent (HTTP %s)' "${http_code}"
    else
        printf 'send failed (HTTP %s)' "${http_code:-000}"
    fi
}

check_16_discord_notification() {
    local result
    result="$(_send_discord_notification)" || true
    # Check 16 is always non-critical (best-effort — never affects exit code)
    if [[ "${result}" == sent* ]]; then
        record_check "Discord notification" "PASS" "${result}" "false"
    else
        record_check "Discord notification" "FAIL" "${result}" "false"
    fi
}

# ============================================================
# Phase runners
# ============================================================

run_phase_1() {
    log_phase_start 1 6 "System (MariaDB + Redis)"
    check_01_mariadb_running
    check_02_mariadb_connection
    check_03_mariadb_charset
    check_04_redis_running
    check_05_redis_ping
}

run_phase_2() {
    log_phase_start 2 6 "Node.js"
    check_06_nodejs_version
    check_07_yarn_version
}

run_phase_3() {
    log_phase_start 3 6 "Frappe Bench"
    check_08_bench_cli
    check_09_bench_site
}

run_phase_4() {
    log_phase_start 4 6 "OpenClaw"
    check_10_openclaw_version
    check_11_openclaw_service
    check_12_openclaw_port
}

run_phase_5() {
    log_phase_start 5 6 "Claude Studio"
    check_13_studio_service
    check_14_studio_port
}

run_phase_6() {
    log_phase_start 6 6 "Auth + Notifications"
    check_15_git_auth
    check_16_discord_notification
}

# ============================================================
# Summary table
# ============================================================
print_summary() {
    # Separator line (72 chars)
    local line="════════════════════════════════════════════════════════════════════════"

    printf '\n'
    printf '%s%s%s\n' "${BLUE}" "${line}" "${NC}"
    printf '%s  %-3s  %-30s  %-4s  %s%s\n' \
        "${BLUE}" '#' 'Component' 'Status' 'Detail' "${NC}"
    printf '%s%s%s\n' "${BLUE}" "${line}" "${NC}"

    local i
    for i in "${!CHECK_NAMES[@]}"; do
        local num=$(( i + 1 ))
        local name="${CHECK_NAMES[$i]}"
        local status="${CHECK_STATUS[$i]}"
        local detail="${CHECK_DETAILS[$i]}"
        local sc
        if [[ "${status}" == "PASS" ]]; then
            sc="${GREEN}"
        else
            sc="${RED}"
        fi
        printf '  %3d  %-30s  %s%-4s%s  %s\n' \
            "${num}" "${name}" "${sc}" "${status}" "${NC}" "${detail}"
    done

    printf '%s%s%s\n' "${BLUE}" "${line}" "${NC}"
    printf '\n'

    if [[ "${CRITICAL_FAIL_COUNT}" -eq 0 ]]; then
        printf '%s  ✓ %d/%d checks passed — system fully provisioned%s\n' \
            "${GREEN}" "${PASS_COUNT}" "${TOTAL_CHECKS}" "${NC}"
    else
        printf '%s  ✗ %d/%d checks passed — %d critical failure(s)%s\n' \
            "${RED}" "${PASS_COUNT}" "${TOTAL_CHECKS}" \
            "${CRITICAL_FAIL_COUNT}" "${NC}"
    fi
    printf '\n'
}

# ============================================================
# Main
# ============================================================
main() {
    printf '\n'
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "  Tiberbu DevBox — Verification & Smoke Test"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Load environment variables and apply defaults
    load_env

    # Source nvm silently — node/yarn/openclaw checks handle missing binaries
    _source_nvm

    # Add ~/.local/bin to PATH for bench and other pip-installed tools
    export PATH="${HOME}/.local/bin:${PATH}"

    # Set XDG_RUNTIME_DIR so systemctl --user can reach the session bus
    # (needed on Ubuntu 24.04 in non-interactive / script contexts)
    if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
        XDG_RUNTIME_DIR="/run/user/$(id -u)"
        export XDG_RUNTIME_DIR
    fi

    if [[ -n "${PHASE_FILTER}" ]]; then
        log_info "Running phase ${PHASE_FILTER} checks only"
        "run_phase_${PHASE_FILTER}"
    else
        run_phase_1
        run_phase_2
        run_phase_3
        run_phase_4
        run_phase_5
        run_phase_6
    fi

    print_summary

    if [[ "${CRITICAL_FAIL_COUNT}" -gt 0 ]]; then
        log_error "Verification FAILED: ${CRITICAL_FAIL_COUNT} critical check(s) failed"
        exit 1
    fi

    log_success "Verification PASSED: all critical checks passed"
    exit 0
}

main
