#!/usr/bin/env bash
# scripts/install-vscode.sh — Phase 6: VS Code (code-server)
#
# Installs code-server (VS Code in the browser) and configures it as a
# systemd service accessible on the configured port.
# Idempotent: skips if .phase-6-complete marker exists and code-server is healthy.
#
# Usage (called by bootstrap.sh or directly):
#   bash scripts/install-vscode.sh

set -euo pipefail

# ============================================================
# Locate and source shared library
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/_common.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_common.sh"

trap 'error_handler "${BASH_SOURCE[0]}" "${LINENO}" "$?"' ERR

# ============================================================
# Constants
# ============================================================
readonly PHASE_NUM=6
readonly PHASE_NAME="VS Code (code-server)"
readonly TOTAL_PHASES=6

# Defaults — all overridable via environment variables
: "${VSCODE_PORT:=8443}"
: "${VSCODE_PASSWORD:=changeme}"
: "${HOME:=/home/ubuntu}"

readonly CONFIG_DIR="${HOME}/.config/code-server"
readonly CONFIG_FILE="${CONFIG_DIR}/config.yaml"
readonly SERVICE_NAME="code-server@$(whoami)"

# ============================================================
# AC-1: Idempotency check
# ============================================================
check_idempotency() {
    if ! check_marker "${PHASE_NUM}"; then
        return 0   # No marker — proceed with full installation
    fi

    log_info "Marker .phase-${PHASE_NUM}-complete found — verifying code-server"

    local checks_ok=true

    # Check code-server binary exists
    if ! command -v code-server &>/dev/null; then
        log_warn "code-server binary not found"
        checks_ok=false
    fi

    # Check systemd service is active
    if ! systemctl is-active --quiet "${SERVICE_NAME}" 2>/dev/null; then
        log_warn "code-server service is not active"
        checks_ok=false
    fi

    # Check HTTP response on configured port
    local http_code
    http_code="$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${VSCODE_PORT}" 2>/dev/null || true)"
    if [[ "${http_code}" != "302" && "${http_code}" != "200" ]]; then
        log_warn "code-server HTTP check failed (got ${http_code:-timeout})"
        checks_ok=false
    fi

    if [[ "${checks_ok}" == "true" ]]; then
        log_success "Phase ${PHASE_NUM} already complete — skipping (marker + code-server healthy)"
        exit 0
    else
        log_warn "Marker exists but checks failed — clearing marker and re-running"
        clear_marker "${PHASE_NUM}"
    fi
}

# ============================================================
# Installation
# ============================================================
install_code_server() {
    log_info "Installing code-server via official installer..."

    # Use the official install script (handles deb/rpm detection)
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone 2>&1 || {
        # Fallback: try system package method
        log_warn "Standalone install failed — trying system package method"
        curl -fsSL https://code-server.dev/install.sh | sh 2>&1
    }

    if ! command -v code-server &>/dev/null; then
        log_error "code-server installation failed — binary not found on PATH"
        return 1
    fi

    local version
    version="$(code-server --version 2>/dev/null | head -1)"
    log_success "code-server installed: ${version}"
}

# ============================================================
# Configuration
# ============================================================
configure_code_server() {
    log_info "Configuring code-server (port ${VSCODE_PORT})..."

    mkdir -p "${CONFIG_DIR}"

    cat > "${CONFIG_FILE}" << EOF
bind-addr: 0.0.0.0:${VSCODE_PORT}
auth: password
password: ${VSCODE_PASSWORD}
cert: false
EOF

    log_success "Config written to ${CONFIG_FILE}"
}

# ============================================================
# Systemd service setup
# ============================================================
setup_service() {
    log_info "Enabling code-server systemd service..."

    # code-server ships a template unit: code-server@.service
    # Enable for the current user
    sudo systemctl daemon-reload 2>/dev/null || true
    sudo systemctl enable --now "${SERVICE_NAME}" 2>&1

    # Wait for service to become active
    local attempts=0
    while [[ ${attempts} -lt 10 ]]; do
        if systemctl is-active --quiet "${SERVICE_NAME}"; then
            log_success "code-server service is active"
            return 0
        fi
        sleep 1
        attempts=$(( attempts + 1 ))
    done

    log_error "code-server service failed to start within 10s"
    sudo systemctl status "${SERVICE_NAME}" --no-pager 2>&1 || true
    return 1
}

# ============================================================
# Install useful extensions
# ============================================================
install_extensions() {
    log_info "Installing VS Code extensions..."

    local extensions=(
        "ms-python.python"
        "dbaeumer.vscode-eslint"
        "esbenp.prettier-vscode"
        "eamodio.gitlens"
        "bradlc.vscode-tailwindcss"
    )

    for ext in "${extensions[@]}"; do
        code-server --install-extension "${ext}" --force 2>/dev/null || {
            log_warn "Failed to install extension: ${ext} (non-fatal)"
        }
    done

    log_success "Extensions installed"
}

# ============================================================
# Main
# ============================================================
main() {
    log_phase_start "${PHASE_NUM}" "${TOTAL_PHASES}" "${PHASE_NAME}"

    check_idempotency

    install_code_server
    configure_code_server
    setup_service
    install_extensions

    # Set marker
    set_marker "${PHASE_NUM}"

    log_phase_end "${PHASE_NUM}" "${TOTAL_PHASES}" "${PHASE_NAME}" "complete"
    log_success "VS Code available at: http://<server-ip>:${VSCODE_PORT}"
    log_success "Password: (from VSCODE_PASSWORD in .tiberbu-env)"
}

main
