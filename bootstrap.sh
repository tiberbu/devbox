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
    DISCORD_CHANNEL_ID      Discord channel ID
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
# Ensure runtime directory exists
# ============================================================
mkdir -p "${MARKER_DIR}"

# ============================================================
# Environment loading
# ============================================================

# load_env_file — sources ENV_FILE and applies defaults for optional variables
load_env_file() {
    if [[ -f "${ENV_FILE}" ]]; then
        log_info "Loading env file: ${ENV_FILE}"
        # Export all variables defined in the file
        set -a
        # shellcheck disable=SC1090
        source "${ENV_FILE}"
        set +a
    else
        log_warn "Env file not found: ${ENV_FILE} — expecting variables already in environment"
    fi

    # Apply defaults for optional variables (no-op if already set)
    : "${BEDROCK_REGION:=us-west-1}"
    : "${BEDROCK_MODEL:=global.anthropic.claude-opus-4-6-v1}"
    : "${FRAPPE_BRANCH:=version-15}"
    : "${BENCH_SITE:=dev.local}"
    : "${MARIADB_ROOT_PASSWORD:=tiberbu123}"
    : "${CLAUDE_STUDIO_PORT:=3000}"
    : "${OPENCLAW_PORT:=18789}"

    export BEDROCK_REGION BEDROCK_MODEL FRAPPE_BRANCH BENCH_SITE
    export MARIADB_ROOT_PASSWORD CLAUDE_STUDIO_PORT OPENCLAW_PORT

    log_success "Env file loaded; optional defaults applied"
}

# ============================================================
# Credential validation
# ============================================================
readonly REQUIRED_VARS=(
    AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY
    AWS_DEFAULT_REGION
    DISCORD_BOT_TOKEN
    DISCORD_GUILD_ID
    DISCORD_CHANNEL_ID
    DISCORD_USER_ID
    GITHUB_TOKEN
)

# validate_credentials — checks all required vars and reports ALL missing ones
validate_credentials() {
    local missing=()
    local var val
    for var in "${REQUIRED_VARS[@]}"; do
        val="${!var:-}"
        if [[ -z "${val}" ]]; then
            missing+=("${var}")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required environment variables (${#missing[@]}):"
        for var in "${missing[@]}"; do
            log_error "  • ${var}"
        done
        log_error "Add the above variables to ${ENV_FILE} and re-run."
        return 1
    fi

    log_success "All ${#REQUIRED_VARS[@]} required credentials are present"
}

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
# Phase runner
# ============================================================

# run_phase PHASE_NUM
# Executes a single phase with timing and dry-run support.
run_phase() {
    local phase_num="$1"
    local pname
    local pscript
    pname="$(phase_name "${phase_num}")"
    pscript="$(phase_script "${phase_num}")"

    local phase_start
    phase_start="$(date +%s)"

    log_phase_start "${phase_num}" "${TOTAL_PHASES}" "${pname}"

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] Would execute: ${pscript}"
        log_phase_end "${phase_num}" "${TOTAL_PHASES}" "${pname}" "0 (dry-run)"
        return 0
    fi

    if [[ ! -f "${pscript}" ]]; then
        log_error "Phase script not found: ${pscript}"
        return 1
    fi

    bash "${pscript}"

    local phase_end
    local elapsed
    phase_end="$(date +%s)"
    elapsed=$(( phase_end - phase_start ))

    log_phase_end "${phase_num}" "${TOTAL_PHASES}" "${pname}" "${elapsed}"
}

# ============================================================
# Main entry point
# ============================================================
main() {
    local bootstrap_start
    bootstrap_start="$(date +%s)"

    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "  Tiberbu DevBox Bootstrap"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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
    load_env_file

    # Step 2: Validate credentials (always, including dry-run)
    validate_credentials

    # Step 3: Execute phases
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
        run_phase "${PHASE_FILTER}"
    else
        local i
        for i in $(seq 1 "${TOTAL_PHASES}"); do
            run_phase "${i}"
        done
    fi

    # Print total elapsed time
    local bootstrap_end
    local elapsed
    bootstrap_end="$(date +%s)"
    elapsed=$(( bootstrap_end - bootstrap_start ))
    printf '\n'
    log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "  Bootstrap complete — total elapsed time: ${elapsed}s"
    log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

main
