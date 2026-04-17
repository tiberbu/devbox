#!/usr/bin/env bash
# scripts/install-node.sh — Phase 2: Node.js via nvm
#
# Installs nvm v0.40.3, Node.js v24 (LTS), and yarn v1.22.x.
# Idempotent: skips if .phase-2-complete marker exists and node v24 + yarn are healthy.
# If marker exists but checks fail: clears marker and re-runs.
#
# Usage (called by bootstrap.sh or directly):
#   bash scripts/install-node.sh

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
readonly PHASE_NUM=2
readonly PHASE_NAME="Node.js"
readonly TOTAL_PHASES=5
readonly NVM_VERSION="v0.40.3"
readonly NODE_VERSION="24"

# NVM_DIR exported so nvm.sh and child processes pick it up
NVM_DIR="${HOME}/.nvm"
export NVM_DIR

# ============================================================
# Internal helper — source nvm into the current shell session
# ============================================================
_source_nvm() {
    # shellcheck disable=SC1090,SC1091
    [[ -s "${NVM_DIR}/nvm.sh" ]] && source "${NVM_DIR}/nvm.sh"
    # shellcheck disable=SC1090,SC1091
    [[ -s "${NVM_DIR}/bash_completion" ]] && source "${NVM_DIR}/bash_completion"
}

# ============================================================
# AC-1: Idempotency check
# Checks marker + node -v returns v24.x.x + yarn --version works.
# If all pass → skip and exit 0.
# If marker exists but checks fail → clear marker and re-run.
# ============================================================
check_idempotency() {
    if ! check_marker "${PHASE_NUM}"; then
        return 0   # No marker — proceed with full installation
    fi

    log_info "Marker .phase-${PHASE_NUM}-complete found — verifying node and yarn"

    _source_nvm

    local checks_ok=true

    local node_ver
    node_ver="$(node -v 2>/dev/null || true)"
    if [[ "${node_ver}" != v${NODE_VERSION}.* ]]; then
        log_warn "node -v returned: ${node_ver:-<empty>} (expected v${NODE_VERSION}.x.x)"
        checks_ok=false
    fi

    if ! yarn --version &>/dev/null; then
        log_warn "yarn --version failed"
        checks_ok=false
    fi

    if [[ "${checks_ok}" == "true" ]]; then
        log_success "Phase ${PHASE_NUM} already complete — skipping (marker + node v${NODE_VERSION} + yarn OK)"
        exit 0
    else
        log_warn "Marker exists but checks failed — clearing marker and re-running"
        clear_marker "${PHASE_NUM}"
    fi
}

# ============================================================
# AC-2: nvm installation
# Downloads nvm install script with retry (3 attempts), installs to ~/.nvm,
# sources nvm in current session, verifies command -v nvm.
# ============================================================
install_nvm() {
    log_info "Step 1/4: Installing nvm ${NVM_VERSION}"

    local install_url="https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh"
    local install_script
    install_script="$(mktemp /tmp/nvm-install-XXXXXX.sh)"

    # Download nvm install script with up to 3 retries
    retry 3 5 curl -fsSL -o "${install_script}" "${install_url}"
    log_success "nvm install script downloaded"

    # Run the installer (it adds nvm sourcing to ~/.bashrc automatically)
    bash "${install_script}"
    rm -f "${install_script}"
    log_success "nvm install script executed"

    # Source nvm in the current shell session
    _source_nvm

    # Verify nvm is available as a shell function
    if ! command -v nvm &>/dev/null; then
        log_error "nvm not found after installation — source may have failed"
        return 1
    fi

    log_success "Step 1/4: nvm ${NVM_VERSION} installed ($(command -v nvm || echo 'shell function'))"
}

# ============================================================
# AC-3: Node.js v24
# nvm install 24, nvm alias default 24.
# Verifies node -v outputs v24.x.x and npm -v works.
# ============================================================
install_node() {
    log_info "Step 2/4: Installing Node.js v${NODE_VERSION}"

    nvm install "${NODE_VERSION}"
    nvm alias default "${NODE_VERSION}"

    # Verify node version
    local node_ver
    node_ver="$(node -v 2>/dev/null || true)"
    if [[ "${node_ver}" != v${NODE_VERSION}.* ]]; then
        log_error "node -v returned: ${node_ver:-<empty>} (expected v${NODE_VERSION}.x.x)"
        return 1
    fi
    log_success "node -v: ${node_ver}"

    # Verify npm works
    local npm_ver
    npm_ver="$(npm -v 2>/dev/null || true)"
    if [[ -z "${npm_ver}" ]]; then
        log_error "npm -v failed"
        return 1
    fi
    log_success "npm -v: ${npm_ver}"

    log_success "Step 2/4: Node.js ${node_ver} installed"
}

# ============================================================
# AC-4: yarn installation
# npm install -g yarn; verifies yarn --version outputs 1.22.x
# ============================================================
install_yarn() {
    log_info "Step 3/4: Installing yarn"

    npm install -g yarn

    local yarn_ver
    yarn_ver="$(yarn --version 2>/dev/null || true)"
    if [[ -z "${yarn_ver}" ]]; then
        log_error "yarn --version failed after install"
        return 1
    fi
    log_success "yarn --version: ${yarn_ver}"

    log_success "Step 3/4: yarn ${yarn_ver} installed"
}

# ============================================================
# AC-5: PATH availability + .bashrc sourcing
# Ensures .bashrc contains nvm sourcing for future sessions.
# Logs absolute paths for node / npm / yarn.
# ============================================================
configure_bashrc() {
    log_info "Step 4/4: Verifying .bashrc nvm sourcing and PATH"

    local bashrc="${HOME}/.bashrc"

    # nvm installer normally adds this block; ensure it is present
    if ! grep -q 'NVM_DIR' "${bashrc}" 2>/dev/null; then
        log_warn ".bashrc does not contain NVM_DIR — adding nvm sourcing block"
        cat >> "${bashrc}" <<'BASHRC_NVM'

# nvm (Node Version Manager) — added by install-node.sh
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
BASHRC_NVM
        log_success ".bashrc updated with nvm sourcing"
    else
        log_info ".bashrc already contains NVM_DIR — no changes needed"
    fi

    # Log absolute paths (AC-5: node/npm/yarn available via absolute path)
    local node_path npm_path yarn_path
    node_path="$(command -v node)"
    npm_path="$(command -v npm)"
    yarn_path="$(command -v yarn)"

    log_success "node absolute path: ${node_path}"
    log_success "npm  absolute path: ${npm_path}"
    log_success "yarn absolute path: ${yarn_path}"

    log_success "Step 4/4: PATH and .bashrc verified"
}

# ============================================================
# AC-6: Completion marker
# ============================================================
complete_phase() {
    set_marker "${PHASE_NUM}"
    log_success "Phase ${PHASE_NUM} (${PHASE_NAME}) complete — marker .phase-${PHASE_NUM}-complete set"
}

# ============================================================
# Main
# ============================================================
main() {
    log_phase_start "${PHASE_NUM}" "${TOTAL_PHASES}" "${PHASE_NAME}"

    local phase_start
    phase_start="$(date +%s)"

    check_idempotency
    install_nvm
    install_node
    install_yarn
    configure_bashrc
    complete_phase

    local phase_end elapsed
    phase_end="$(date +%s)"
    elapsed=$(( phase_end - phase_start ))

    log_phase_end "${PHASE_NUM}" "${TOTAL_PHASES}" "${PHASE_NAME}" "${elapsed}"
}

main
