#!/usr/bin/env bash
# scripts/install-openclaw.sh — Phase 4: OpenClaw + Discord gateway
#
# Installs openclaw globally via npm, renders configuration from templates,
# copies default workspace files, and installs/starts a systemd user service.
# Idempotent: skips if .phase-4-complete marker exists and openclaw-gateway is active.
# If marker exists but service is not active: clears marker and re-runs.
#
# Usage (called by bootstrap.sh or directly):
#   bash scripts/install-openclaw.sh

set -euo pipefail

# ============================================================
# Locate and source shared library
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVBOX_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/_common.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_common.sh"

trap 'error_handler "${BASH_SOURCE[0]}" "${LINENO}" "$?"' ERR

# ============================================================
# Constants
# ============================================================
readonly PHASE_NUM=4
readonly PHASE_NAME="OpenClaw + Discord"
readonly TOTAL_PHASES=5

# Defensive defaults for optional/system variables
: "${OPENCLAW_PORT:=18789}"
: "${HOME:=/home/ubuntu}"

# Ensure XDG_RUNTIME_DIR is set so systemctl --user can reach the user bus
# (required in non-interactive scripts on Ubuntu 24.04)
XDG_RUNTIME_DIR="/run/user/$(id -u)"
export XDG_RUNTIME_DIR

# ============================================================
# AC-1: Idempotency check
# Checks marker .phase-4-complete AND systemctl --user is-active openclaw-gateway.
# If both pass: skip and exit 0.
# If marker exists but service not active: clear marker and re-run.
# ============================================================
check_idempotency() {
    if ! check_marker "${PHASE_NUM}"; then
        return 0   # No marker — proceed with full installation
    fi

    log_info "Marker .phase-${PHASE_NUM}-complete found — verifying openclaw-gateway"

    if systemctl --user is-active --quiet openclaw-gateway 2>/dev/null; then
        log_success "Phase ${PHASE_NUM} already complete — skipping (marker + service active)"
        exit 0
    fi

    log_warn "Marker exists but openclaw-gateway not active — clearing marker and re-running"
    clear_marker "${PHASE_NUM}"
}

# ============================================================
# AC-2: nvm/npm sourcing
# Sources nvm into the current session so npm/openclaw are on PATH.
# ============================================================
source_nvm() {
    log_info "Step 1/5: Sourcing nvm"

    export NVM_DIR="${HOME}/.nvm"
    # shellcheck disable=SC1090,SC1091
    [[ -s "${NVM_DIR}/nvm.sh" ]] && \. "${NVM_DIR}/nvm.sh"

    if ! command -v npm &>/dev/null; then
        log_error "npm not found — ensure install-node.sh (Phase 2) ran successfully first"
        exit 1
    fi

    log_info "npm $(npm -v) available"
    log_success "Step 1/5: nvm sourced — npm available"
}

# ============================================================
# AC-2: OpenClaw npm installation
# npm install -g openclaw with 3 retries; verifies openclaw --version.
# ============================================================
install_openclaw() {
    log_info "Step 2/5: Installing openclaw globally via npm"

    retry 3 15 npm install -g openclaw

    local oc_ver
    oc_ver="$(openclaw --version 2>/dev/null || true)"
    if [[ -z "${oc_ver}" ]]; then
        log_error "openclaw --version returned empty — installation may have failed"
        return 1
    fi

    log_success "openclaw ${oc_ver} installed"
    log_success "Step 2/5: openclaw installed"
}

# ============================================================
# AC-3: Configuration rendering
# Creates ~/.openclaw/, renders openclaw.json.template, chmod 600,
# and asserts no unresolved placeholders remain.
# ============================================================
render_config() {
    log_info "Step 3/5: Rendering openclaw configuration"

    mkdir -p "${HOME}/.openclaw"

    render_template \
        "${DEVBOX_DIR}/templates/openclaw.json.template" \
        "${HOME}/.openclaw/openclaw.json"

    chmod 600 "${HOME}/.openclaw/openclaw.json"

    # Verify required env var fields are not empty in the rendered config.
    # envsubst replaces unset variables with empty strings, never leaving ${VAR}
    # patterns, so grepping for literal '${' is ineffective. Instead we check
    # that each critical JSON string field contains a non-empty value.
    local required_env_vars=(
        AWS_ACCESS_KEY_ID
        AWS_SECRET_ACCESS_KEY
        DISCORD_BOT_TOKEN
    )
    local missing=()
    for var in "${required_env_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing+=("${var}")
        fi
    done
    if (( ${#missing[@]} > 0 )); then
        log_error "Required env vars are unset or empty; openclaw.json may be invalid:"
        for var in "${missing[@]}"; do
            log_error "  ${var} is not set"
        done
        return 1
    fi

    log_success "openclaw.json rendered at ${HOME}/.openclaw/openclaw.json (mode 600)"
    log_success "Step 3/5: Configuration rendered"
}

# ============================================================
# AC-4: Workspace setup
# Creates ~/.openclaw/workspace/ and copies workspace/*.md files
# only if they do not already exist (preserves user customizations).
# ============================================================
setup_workspace() {
    log_info "Step 4/5: Setting up workspace files"

    mkdir -p "${HOME}/.openclaw/workspace"

    local workspace_files=( AGENTS.md SOUL.md TOOLS.md USER.md )
    for f in "${workspace_files[@]}"; do
        local src="${DEVBOX_DIR}/workspace/${f}"
        local dst="${HOME}/.openclaw/workspace/${f}"
        if [[ ! -f "${dst}" ]]; then
            if [[ -f "${src}" ]]; then
                cp "${src}" "${dst}"
                log_info "Copied workspace/${f}"
            else
                log_warn "Source workspace/${f} not found in ${DEVBOX_DIR}/workspace/ — skipping"
            fi
        else
            log_info "workspace/${f} already exists — preserving user customization"
        fi
    done

    log_success "Workspace files in place at ${HOME}/.openclaw/workspace/"
    log_success "Step 4/5: Workspace setup complete"
}

# ============================================================
# AC-5: Systemd user service
# Creates ~/.config/systemd/user/, renders the service unit,
# enables linger, reloads the daemon, enables and starts the service.
# ============================================================
install_service() {
    log_info "Step 5/5: Installing openclaw-gateway systemd user service"

    mkdir -p "${HOME}/.config/systemd/user"

    # Resolve the actual nvm-versioned node binary directory
    # (e.g. /home/ubuntu/.nvm/versions/node/v24.15.0/bin)
    # nvm never creates a bare v24 alias directory, only full semver paths.
    local node_bin_dir
    node_bin_dir="$(dirname "$(command -v node)")"
    export NODE_BIN_DIR="${node_bin_dir}"
    log_info "Resolved node binary directory: ${NODE_BIN_DIR}"

    render_template \
        "${DEVBOX_DIR}/templates/openclaw-gateway.service" \
        "${HOME}/.config/systemd/user/openclaw-gateway.service"

    # Enable linger so user services persist across sessions / reboots
    loginctl enable-linger "${USER}" \
        || log_warn "loginctl enable-linger failed (may need sudo or already enabled)"

    systemctl --user daemon-reload
    log_info "systemctl --user daemon-reload complete"

    systemctl --user enable openclaw-gateway
    log_info "openclaw-gateway service enabled"

    systemctl --user start openclaw-gateway
    log_info "openclaw-gateway service started"

    log_success "Step 5/5: Service installed and started"
}

# ============================================================
# AC-5 (continued): Wait for service stabilization
# Polls systemctl --user is-active for up to 10 seconds.
# ============================================================
wait_for_service() {
    local max_attempts=10
    local attempt=0
    log_info "Waiting for openclaw-gateway to stabilize (up to ${max_attempts}s)..."

    while (( attempt < max_attempts )); do
        if systemctl --user is-active --quiet openclaw-gateway 2>/dev/null; then
            log_success "openclaw-gateway is active (attempt $((attempt + 1))/${max_attempts})"
            return 0
        fi
        attempt=$(( attempt + 1 ))
        sleep 1
    done

    log_error "openclaw-gateway did not become active within ${max_attempts} seconds"
    systemctl --user status openclaw-gateway --no-pager 2>&1 | tail -20 || true
    return 1
}

# ============================================================
# AC-6: Verification and marker
# Asserts service is active, port is listening, then sets marker.
# ============================================================
verify_phase() {
    log_info "Verifying Phase ${PHASE_NUM} completion"

    # Assert service is active
    local svc_state
    svc_state="$(systemctl --user is-active openclaw-gateway 2>/dev/null || true)"
    if [[ "${svc_state}" != "active" ]]; then
        log_error "openclaw-gateway is not active (state: ${svc_state:-unknown})"
        systemctl --user status openclaw-gateway --no-pager 2>&1 | tail -20 || true
        return 1
    fi
    log_success "openclaw-gateway service is active"

    # Assert port is listening (prefer ss; fallback to curl health check)
    if ss -tlnp 2>/dev/null | grep -q ":${OPENCLAW_PORT}"; then
        log_success "Port ${OPENCLAW_PORT} is listening"
    elif curl -sf "http://localhost:${OPENCLAW_PORT}/health" &>/dev/null; then
        log_success "OpenClaw gateway health check passed on port ${OPENCLAW_PORT}"
    else
        log_error "Port ${OPENCLAW_PORT} not listening — openclaw-gateway may have failed to start"
        return 1
    fi

    # Set completion marker
    set_marker "${PHASE_NUM}"
    log_success "Phase ${PHASE_NUM} complete — OpenClaw gateway active on port ${OPENCLAW_PORT}"
}

# ============================================================
# Main
# ============================================================
main() {
    log_phase_start "${PHASE_NUM}" "${TOTAL_PHASES}" "${PHASE_NAME}"

    local phase_start
    phase_start="$(date +%s)"

    check_idempotency
    source_nvm
    install_openclaw
    render_config
    setup_workspace
    install_service
    wait_for_service
    verify_phase

    local phase_end elapsed
    phase_end="$(date +%s)"
    elapsed=$(( phase_end - phase_start ))

    log_phase_end "${PHASE_NUM}" "${TOTAL_PHASES}" "${PHASE_NAME}" "${elapsed}"
}

main
