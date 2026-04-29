#!/usr/bin/env bash
# bootstrap.sh — Tiberbu DevBox orchestrator
#
# Provisions the full Tiberbu development environment on a fresh Ubuntu 24.04 EC2 instance.
# Runs five installation phases sequentially with idempotency, timing, and structured logging.
#
# Usage: ./bootstrap.sh [OPTIONS]
#   --dry-run          Validate environment and print plan; do not install anything
#   --phase N          Run only phase N (1-5)
#   --env-file PATH    Path to env file (default: ~/.tiberbu-env)
#   --help             Show this help message

set -euo pipefail

# ============================================================
# Script directory + source shared library
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/_common.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/scripts/_common.sh"

# ERR trap — passes script path, line number, and exit code to error_handler
trap 'error_handler "${BASH_SOURCE[0]}" "${LINENO}" "$?"' ERR

# ============================================================
# Argument defaults
# ============================================================
DRY_RUN=false
PHASE_FILTER=""
ENV_FILE="${HOME}/.tiberbu-env"

# ============================================================
# Usage / help
# ============================================================
usage() {
    cat <<'EOF'
Usage: ./bootstrap.sh [OPTIONS]

Provisions the full Tiberbu development environment on a fresh Ubuntu 24.04 EC2
instance. Runs five installation phases sequentially with idempotency, timing,
and structured logging.

Options:
  --dry-run          Validate environment and print plan; do not install anything
  --phase N          Run only phase N (1-5)
  --env-file PATH    Path to env file (default: ~/.tiberbu-env)
  --help             Show this help message

Environment file (~/.tiberbu-env)
  REQUIRED:
    AWS_ACCESS_KEY_ID       AWS access key
    AWS_SECRET_ACCESS_KEY   AWS secret key
    AWS_DEFAULT_REGION      AWS region (e.g. us-west-1)
    DISCORD_BOT_TOKEN       Discord bot token
    DISCORD_GUILD_ID        Discord guild/server ID
    DISCORD_CHANNEL_ID      Discord channel ID (bot's home channel)
    DISCORD_USER_ID         Discord user ID
    GITHUB_TOKEN            GitHub personal access token

  OPTIONAL (defaults shown):
    BEDROCK_REGION          AWS Bedrock region        (default: us-west-1)
    BEDROCK_MODEL           Bedrock model ID          (default: global.anthropic.claude-opus-4-6-v1)
    FRAPPE_BRANCH           Frappe framework branch   (default: version-15)
    BENCH_SITE              Frappe site name          (default: dev.local)
    MARIADB_ROOT_PASSWORD   MariaDB root password     (default: tiberbu123)
    CLAUDE_STUDIO_PORT      Claude Studio HTTP port   (default: 3000)
    OPENCLAW_PORT           OpenClaw gateway port     (default: 18789)

Phases:
  1 — System dependencies (apt, MariaDB, Redis, wkhtmltopdf)
  2 — Node.js via nvm (Node v24, yarn)
  3 — Frappe Bench (bench init, new-site)
  4 — OpenClaw + Discord (npm, config, systemd)
  5 — Claude Code Studio (git clone, build, systemd)

Log file: /var/tmp/devbox/bootstrap.log

Examples:
  ./bootstrap.sh                      Full installation
  ./bootstrap.sh --dry-run            Validate credentials and print plan
  ./bootstrap.sh --phase 1            Run only Phase 1
  ./bootstrap.sh --env-file ~/my.env  Use a custom env file
EOF
}

# ============================================================
# Argument parsing
# ============================================================
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
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

# Validate --phase value (must be 1-5)
if [[ -n "${PHASE_FILTER}" ]]; then
    if ! [[ "${PHASE_FILTER}" =~ ^[1-5]$ ]]; then
        printf 'Error: --phase must be a number between 1 and 5 (got: %s)\n' "${PHASE_FILTER}" >&2
        exit 1
    fi
fi

# ============================================================
# Ensure runtime directory exists and is writable by the real user
# (Phase 1 runs as root, Phases 2-5 run as the regular user —
# both need to write log files and marker files here)
# ============================================================
mkdir -p "${MARKER_DIR}"
chmod 1777 "${MARKER_DIR}" 2>/dev/null || true
# Make existing files writable if re-running after a root-owned Phase 1
chmod a+rw "${MARKER_DIR}"/* 2>/dev/null || true

# ============================================================
# Privilege handling
# Phase 1 (system deps) needs root for apt/MariaDB/systemd.
# Phases 2-5 MUST run as a regular user (nvm, bench, pip, systemd --user).
#
# If invoked via sudo, detect the real user from SUDO_USER and re-exec
# phases 2-5 with `su - $REAL_USER`.
# ============================================================
REAL_USER="${SUDO_USER:-$(whoami)}"
REAL_HOME="$(eval echo "~${REAL_USER}")"

# Override HOME for template rendering when running as root via sudo
if [[ "$(id -u)" -eq 0 && -n "${SUDO_USER:-}" ]]; then
    export HOME="${REAL_HOME}"
    log_info "Running as root (via sudo) — real user: ${REAL_USER}, HOME: ${HOME}"
fi

# ============================================================
# Phase definitions (functions to avoid associative arrays)
# ============================================================

# phase_name N — prints the human-readable name for phase N
phase_name() {
    case "$1" in
        1) printf 'System Dependencies' ;;
        2) printf 'Node.js via nvm' ;;
        3) printf 'Frappe Bench' ;;
        4) printf 'OpenClaw + Discord Gateway' ;;
        5) printf 'Claude Code Studio' ;;
        *) printf 'Unknown Phase' ;;
    esac
}

# phase_script N — prints the path to the phase script for phase N
phase_script() {
    case "$1" in
        1) printf '%s/scripts/install-system.sh' "${SCRIPT_DIR}" ;;
        2) printf '%s/scripts/install-node.sh' "${SCRIPT_DIR}" ;;
        3) printf '%s/scripts/install-bench.sh' "${SCRIPT_DIR}" ;;
        4) printf '%s/scripts/install-openclaw.sh' "${SCRIPT_DIR}" ;;
        5) printf '%s/scripts/install-studio.sh' "${SCRIPT_DIR}" ;;
        *) printf '' ;;
    esac
}

readonly TOTAL_PHASES=5

# ============================================================
# Progress spinner — shows activity while a phase runs
# ============================================================
SPINNER_PID=""

# start_spinner "message"
start_spinner() {
    local msg="${1:-Running}"
    (
        local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
        local i=0
        local elapsed=0
        while true; do
            printf '\r  %s %s (%ds elapsed)   ' "${frames[$i]}" "${msg}" "${elapsed}"
            i=$(( (i + 1) % ${#frames[@]} ))
            sleep 1
            elapsed=$(( elapsed + 1 ))
        done
    ) &
    SPINNER_PID=$!
    disown "${SPINNER_PID}" 2>/dev/null || true
}

# stop_spinner [exit_code]
stop_spinner() {
    local exit_code="${1:-0}"
    if [[ -n "${SPINNER_PID}" ]]; then
        kill "${SPINNER_PID}" 2>/dev/null || true
        wait "${SPINNER_PID}" 2>/dev/null || true
        SPINNER_PID=""
    fi
    printf '\r%*s\r' 80 ""  # Clear spinner line
}

# ============================================================
# Phase results tracking (for final summary)
# ============================================================
declare -a PHASE_RESULTS=()
declare -a PHASE_TIMES=()

# ============================================================
# Phase runner
# ============================================================

# run_phase PHASE_NUM
# Executes a single phase with timing, progress spinner, and clear status.
run_phase() {
    local phase_num="$1"
    local pname
    local pscript
    pname="$(phase_name "${phase_num}")"
    pscript="$(phase_script "${phase_num}")"

    local phase_start
    phase_start="$(date +%s)"

    # Clear phase banner
    printf '\n'
    printf '%s╔══════════════════════════════════════════════════╗%s\n' "${BLUE}" "${NC}"
    printf '%s║  [%s/%s] %-42s  ║%s\n' "${BLUE}" "${phase_num}" "${TOTAL_PHASES}" "${pname}" "${NC}"
    printf '%s╚══════════════════════════════════════════════════╝%s\n' "${BLUE}" "${NC}"
    printf '%s [PHASE] ===== Phase %s/%s: %s =====\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "${phase_num}" "${TOTAL_PHASES}" "${pname}" >> "${LOG_FILE}"

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would execute: ${pscript}"
        PHASE_RESULTS+=("SKIP")
        PHASE_TIMES+=("0")
        return 0
    fi

    if [[ ! -f "${pscript}" ]]; then
        log_error "Phase script not found: ${pscript}"
        PHASE_RESULTS+=("FAIL")
        PHASE_TIMES+=("0")
        return 1
    fi

    # Start progress spinner
    start_spinner "Phase ${phase_num}: ${pname}"

    # Run the phase script, capturing exit code without letting set -e kill us
    local phase_exit=0
    if [[ "${phase_num}" -eq 1 ]]; then
        # Phase 1 needs root (apt, MariaDB, Redis, wkhtmltopdf)
        if [[ "$(id -u)" -ne 0 ]]; then
            log_info "Phase 1 requires root — re-running with sudo"
            sudo -E bash "${pscript}" >> "${LOG_FILE}" 2>&1 || phase_exit=$?
        else
            bash "${pscript}" >> "${LOG_FILE}" 2>&1 || phase_exit=$?
        fi
        # After Phase 1 (root), fix permissions so the regular user can
        # write to the shared log file and marker directory
        chmod a+rw "${MARKER_DIR}" 2>/dev/null || true
        chmod a+rw "${MARKER_DIR}"/* 2>/dev/null || true
        chmod a+rw "${LOG_FILE}" 2>/dev/null || true
    else
        # Phases 2-5 must run as regular user (nvm, pip, bench, systemd --user)
        if [[ "$(id -u)" -eq 0 && -n "${SUDO_USER:-}" ]]; then
            log_info "Dropping privileges to ${REAL_USER} for phase ${phase_num}"
            su - "${REAL_USER}" -c "
                set -a
                source '${ENV_FILE}' 2>/dev/null || true
                set +a
                export ENV_FILE='${ENV_FILE}'
                cd '${SCRIPT_DIR}' && bash '${pscript}'
            " >> "${LOG_FILE}" 2>&1 || phase_exit=$?
        else
            bash "${pscript}" >> "${LOG_FILE}" 2>&1 || phase_exit=$?
        fi
    fi

    # Stop spinner
    stop_spinner "${phase_exit}"

    # Calculate elapsed time
    local phase_end
    local elapsed
    phase_end="$(date +%s)"
    elapsed=$(( phase_end - phase_start ))

    PHASE_TIMES+=("${elapsed}")

    # Print result
    if [[ "${phase_exit}" -eq 0 ]]; then
        printf '%s╔══════════════════════════════════════════════════╗%s\n' "${GREEN}" "${NC}"
        printf '%s║  ✓ [%s/%s] %-38s    ║%s\n' "${GREEN}" "${phase_num}" "${TOTAL_PHASES}" "${pname} — DONE (${elapsed}s)" "${NC}"
        printf '%s╚══════════════════════════════════════════════════╝%s\n' "${GREEN}" "${NC}"
        PHASE_RESULTS+=("OK")
        printf '%s [PHASE] ===== Phase %s/%s: %s complete (%ss) =====\n' \
            "$(date '+%Y-%m-%d %H:%M:%S')" "${phase_num}" "${TOTAL_PHASES}" "${pname}" "${elapsed}" >> "${LOG_FILE}"
    else
        printf '%s╔══════════════════════════════════════════════════╗%s\n' "${RED}" "${NC}"
        printf '%s║  ✗ [%s/%s] %-38s    ║%s\n' "${RED}" "${phase_num}" "${TOTAL_PHASES}" "${pname} — FAILED (exit ${phase_exit})" "${NC}"
        printf '%s╚══════════════════════════════════════════════════╝%s\n' "${RED}" "${NC}"
        printf '\n'
        printf '%s  Last 30 lines from log:%s\n' "${YELLOW}" "${NC}"
        printf '%s  ─────────────────────────────────────────────%s\n' "${YELLOW}" "${NC}"
        tail -30 "${LOG_FILE}" | sed 's/^/  /'
        printf '%s  ─────────────────────────────────────────────%s\n' "${YELLOW}" "${NC}"
        printf '  Full log: %s\n' "${LOG_FILE}"
        PHASE_RESULTS+=("FAIL")
        printf '%s [PHASE] ===== Phase %s/%s: %s FAILED (exit %s, %ss) =====\n' \
            "$(date '+%Y-%m-%d %H:%M:%S')" "${phase_num}" "${TOTAL_PHASES}" "${pname}" "${phase_exit}" "${elapsed}" >> "${LOG_FILE}"
        return "${phase_exit}"
    fi
}

# ============================================================
# Final summary table
# ============================================================
print_summary() {
    local total_elapsed="$1"
    local i pname status elapsed color

    printf '\n'
    printf '%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n' "${BLUE}" "${NC}"
    printf '%s  BOOTSTRAP SUMMARY                                     %s\n' "${BLUE}" "${NC}"
    printf '%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n' "${BLUE}" "${NC}"
    printf '\n'
    printf '  %-4s %-30s %-10s %s\n' "#" "Phase" "Status" "Time"
    printf '  %-4s %-30s %-10s %s\n' "──" "──────────────────────────────" "────────" "────"

    for i in $(seq 1 "${#PHASE_RESULTS[@]}"); do
        local idx=$(( i - 1 ))
        pname="$(phase_name "${i}")"
        status="${PHASE_RESULTS[$idx]}"
        elapsed="${PHASE_TIMES[$idx]}"

        case "${status}" in
            OK)   color="${GREEN}"; status="✓ Done" ;;
            FAIL) color="${RED}";   status="✗ Failed" ;;
            SKIP) color="${YELLOW}"; status="⊘ Skipped" ;;
            *)    color="${NC}";    status="? Unknown" ;;
        esac

        printf '  %-4s %-30s %s%-10s%s %ss\n' "${i}" "${pname}" "${color}" "${status}" "${NC}" "${elapsed}"
    done

    printf '\n'
    printf '  Total elapsed: %ss\n' "${total_elapsed}"
    printf '  Full log: %s\n' "${LOG_FILE}"
    printf '\n'
    printf '%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n' "${BLUE}" "${NC}"
}

# ============================================================
# Main entry point
# ============================================================
main() {
    local bootstrap_start
    bootstrap_start="$(date +%s)"

    printf '\n'
    printf '%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n' "${BLUE}" "${NC}"
    printf '%s  Tiberbu DevBox Bootstrap                              %s\n' "${BLUE}" "${NC}"
    printf '%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n' "${BLUE}" "${NC}"
    printf '\n'
    log_info "Script directory : ${SCRIPT_DIR}"
    log_info "Runtime directory: ${MARKER_DIR}"
    log_info "Log file         : ${LOG_FILE}"
    log_info "Env file         : ${ENV_FILE}"

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_warn "DRY-RUN mode active — no changes will be made to this system"
    fi

    if [[ -n "${PHASE_FILTER}" ]]; then
        log_info "Phase filter     : ${PHASE_FILTER} only"
    fi

    # Step 1: Load environment
    load_env_file "${ENV_FILE}"

    # Step 2: Validate credentials (always, including dry-run)
    validate_credentials "${ENV_FILE}"

    # Step 3: Execute phases
    local failed=false
    if [[ "${DRY_RUN}" == "true" ]]; then
        # Print plan
        local i pname pscript
        printf '\n'
        log_info "=== Dry-run plan ==="
        printf '\n'
        for i in $(seq 1 "${TOTAL_PHASES}"); do
            if [[ -z "${PHASE_FILTER}" || "${PHASE_FILTER}" == "${i}" ]]; then
                pname="$(phase_name "${i}")"
                pscript="$(phase_script "${i}")"
                printf '  %s[Phase %s]%s %s\n' "${BLUE}" "${i}" "${NC}" "${pname}"
                printf '    Script : %s\n' "${pscript}"
                if check_marker "${i}"; then
                    printf '    Status : %salready complete (marker exists)%s\n' "${GREEN}" "${NC}"
                else
                    printf '    Status : %spending%s\n' "${YELLOW}" "${NC}"
                fi
                printf '\n'
            fi
        done
        log_success "Dry-run complete — all credentials valid, plan printed above"
    elif [[ -n "${PHASE_FILTER}" ]]; then
        log_info "Running single phase: ${PHASE_FILTER}"
        run_phase "${PHASE_FILTER}" || failed=true
    else
        local i
        for i in $(seq 1 "${TOTAL_PHASES}"); do
            if ! run_phase "${i}"; then
                failed=true
                log_error "Phase ${i} failed — stopping bootstrap"
                break
            fi
        done
    fi

    # Print total elapsed time + summary
    local bootstrap_end
    local elapsed
    bootstrap_end="$(date +%s)"
    elapsed=$(( bootstrap_end - bootstrap_start ))

    print_summary "${elapsed}"

    if [[ "${failed}" == "true" ]]; then
        printf '%s  ✗ Bootstrap FAILED — review log above and re-run%s\n\n' "${RED}" "${NC}"
        exit 1
    else
        printf '%s  ✓ Bootstrap COMPLETE — all phases successful%s\n\n' "${GREEN}" "${NC}"
    fi
}

main
