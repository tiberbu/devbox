#!/usr/bin/env bash
# scripts/_common.sh — Shared utility library for Tiberbu DevBox
#
# SOURCE this file; do NOT execute it directly.
# Provides: logging, markers, template rendering, error handling, retry, validators.
#
# Usage in caller scripts:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/_common.sh"   # (from scripts/)
#   source "${SCRIPT_DIR}/scripts/_common.sh"  # (from project root)

# ============================================================
# Constants
# ============================================================
export MARKER_DIR="/var/tmp/devbox"
export LOG_FILE="/var/tmp/devbox/bootstrap.log"

# Color codes (actual ESC sequences via $'...' syntax)
export RED=$'\033[0;31m'
export GREEN=$'\033[0;32m'
export YELLOW=$'\033[1;33m'
export BLUE=$'\033[0;34m'
export NC=$'\033[0m'

# ============================================================
# Internal helper — ensure log directory exists
# ============================================================
_ensure_log_dir() {
    mkdir -p "${MARKER_DIR}" 2>/dev/null || true
}

# ============================================================
# Logging functions
# All functions:
#   - Print color-coded line to stdout (or stderr for errors)
#   - Append plain timestamped line to $LOG_FILE
# ============================================================

log_info() {
    _ensure_log_dir
    printf '%s→%s %s\n' "${BLUE}" "${NC}" "$*"
    printf '%s [INFO]  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "${LOG_FILE}"
}

log_success() {
    _ensure_log_dir
    printf '%s✓%s %s\n' "${GREEN}" "${NC}" "$*"
    printf '%s [OK]    %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "${LOG_FILE}"
}

log_error() {
    _ensure_log_dir
    printf '%s✗%s %s\n' "${RED}" "${NC}" "$*" >&2
    printf '%s [ERROR] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "${LOG_FILE}"
}

log_warn() {
    _ensure_log_dir
    printf '%s!%s %s\n' "${YELLOW}" "${NC}" "$*"
    printf '%s [WARN]  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "${LOG_FILE}"
}

# log_phase_start NUM TOTAL "Phase Name"
log_phase_start() {
    local num="$1"
    local total="$2"
    local name="$3"
    _ensure_log_dir
    printf '\n'
    printf '%s════════════════════════════════════════════════%s\n' "${BLUE}" "${NC}"
    printf '%s  Phase %s/%s: %s%s\n' "${BLUE}" "${num}" "${total}" "${name}" "${NC}"
    printf '%s════════════════════════════════════════════════%s\n' "${BLUE}" "${NC}"
    printf '%s [PHASE] ===== Phase %s/%s: %s =====\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "${num}" "${total}" "${name}" >> "${LOG_FILE}"
}

# log_phase_end NUM TOTAL "Phase Name" ELAPSED
log_phase_end() {
    local num="$1"
    local total="$2"
    local name="$3"
    local elapsed="$4"
    _ensure_log_dir
    printf '%s════════════════════════════════════════════════%s\n' "${GREEN}" "${NC}"
    printf '%s  Phase %s/%s: %s — done in %ss%s\n' \
        "${GREEN}" "${num}" "${total}" "${name}" "${elapsed}" "${NC}"
    printf '%s════════════════════════════════════════════════%s\n\n' "${GREEN}" "${NC}"
    printf '%s [PHASE] ===== Phase %s/%s: %s complete (%ss) =====\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "${num}" "${total}" "${name}" "${elapsed}" >> "${LOG_FILE}"
}

# ============================================================
# Marker functions
# Marker files live at: $MARKER_DIR/.phase-N-complete
# ============================================================

# check_marker PHASE_NUM — returns 0 if marker exists, 1 otherwise
check_marker() {
    local phase_num="$1"
    [[ -f "${MARKER_DIR}/.phase-${phase_num}-complete" ]]
}

# set_marker PHASE_NUM — creates the marker file
set_marker() {
    local phase_num="$1"
    _ensure_log_dir
    touch "${MARKER_DIR}/.phase-${phase_num}-complete"
    log_success "Marker set: .phase-${phase_num}-complete"
}

# clear_marker PHASE_NUM — removes the marker file
clear_marker() {
    local phase_num="$1"
    rm -f "${MARKER_DIR}/.phase-${phase_num}-complete"
    log_warn "Marker cleared: .phase-${phase_num}-complete"
}

# ============================================================
# Template rendering
# ============================================================

# render_template TEMPLATE OUTPUT
# Renders $TEMPLATE through envsubst into $OUTPUT
render_template() {
    local template="$1"
    local output="$2"
    envsubst < "${template}" > "${output}"
    log_success "Rendered template: ${template} → ${output}"
}

# ============================================================
# Error handler (for ERR trap)
# ============================================================

# error_handler SCRIPT LINE EXIT_CODE
# Intended usage in calling script:
#   trap 'error_handler "${BASH_SOURCE[0]}" "${LINENO}" "$?"' ERR
error_handler() {
    local script="${1:-unknown}"
    local line="${2:-0}"
    local exit_code="${3:-1}"
    _ensure_log_dir
    log_error "Error in ${script} at line ${line} (exit code: ${exit_code})"
    if [[ -f "${LOG_FILE}" ]]; then
        printf '%s--- Last 20 lines of %s ---%s\n' "${RED}" "${LOG_FILE}" "${NC}" >&2
        tail -20 "${LOG_FILE}" >&2
        printf '%s--- Full log: %s ---%s\n' "${RED}" "${LOG_FILE}" "${NC}" >&2
    fi
    exit "${exit_code}"
}

# ============================================================
# Retry
# ============================================================

# retry COUNT DELAY CMD [ARGS...]
# Runs CMD up to COUNT times, sleeping DELAY seconds between attempts.
# Returns 0 on success, 1 if all attempts fail.
retry() {
    local count="$1"
    local delay="$2"
    shift 2
    local attempt=1
    until "$@"; do
        if (( attempt >= count )); then
            log_error "Command failed after ${count} attempt(s): $*"
            return 1
        fi
        log_warn "Attempt ${attempt}/${count} failed for: $* — retrying in ${delay}s"
        (( attempt++ ))
        sleep "${delay}"
    done
    return 0
}

# ============================================================
# Validators
# ============================================================

# require_env VAR_NAME — exits 1 if the named variable is unset or empty
require_env() {
    local var_name="$1"
    local val="${!var_name:-}"
    if [[ -z "${val}" ]]; then
        log_error "Required environment variable is not set: ${var_name}"
        return 1
    fi
}

# require_command CMD_NAME — exits 1 if the command is not on PATH
require_command() {
    local cmd="$1"
    if ! command -v "${cmd}" &>/dev/null; then
        log_error "Required command not found: ${cmd}"
        return 1
    fi
}
