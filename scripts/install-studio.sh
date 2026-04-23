#!/usr/bin/env bash
# scripts/install-studio.sh — Phase 5: Claude Code Studio
#
# Clones, builds, configures, and daemonizes Claude Code Studio as a systemd
# system service. On success http://localhost:${CLAUDE_STUDIO_PORT} (default 3000)
# serves the web IDE.
# Idempotent: skips if .phase-5-complete marker exists and claude-studio is active.
# If marker exists but service is not active: clears marker and re-runs.
#
# Usage (called by bootstrap.sh or directly):
#   bash scripts/install-studio.sh

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
readonly PHASE_NUM=5
readonly PHASE_NAME="Claude Code Studio"
readonly TOTAL_PHASES=5
readonly TOTAL_STEPS=8

# Defensive defaults for optional/system variables
: "${CLAUDE_STUDIO_PORT:=3000}"
: "${HOME:=/home/ubuntu}"

# Export variables needed by render_template (envsubst)
export USER HOME CLAUDE_STUDIO_PORT

# ============================================================
# AC-1: Idempotency check
# Checks marker .phase-5-complete AND systemctl is-active claude-studio.
# If both pass: skip and exit 0.
# If marker exists but service not active: clear marker and re-run.
# ============================================================
check_idempotency() {
    if ! check_marker "${PHASE_NUM}"; then
        return 0   # No marker — proceed with full installation
    fi

    log_info "Marker .phase-${PHASE_NUM}-complete found — verifying claude-studio"

    if systemctl is-active --quiet claude-studio 2>/dev/null; then
        log_success "Phase ${PHASE_NUM} already complete — skipping (marker + service active)"
        exit 0
    fi

    log_warn "Marker exists but claude-studio not active — clearing marker and re-running"
    clear_marker "${PHASE_NUM}"
}

# ============================================================
# AC-2: nvm/npm sourcing
# Sources nvm into the current session so node/npm are on PATH
# in non-interactive (script) context where ~/.bashrc is not sourced.
# ============================================================
source_nvm() {
    log_info "Step 1/8: Sourcing nvm"

    export NVM_DIR="${HOME}/.nvm"
    # shellcheck disable=SC1090,SC1091
    [[ -s "${NVM_DIR}/nvm.sh" ]] && \. "${NVM_DIR}/nvm.sh"

    if ! command -v npm &>/dev/null; then
        log_error "npm not found — ensure install-node.sh (Phase 2) ran successfully first"
        exit 1
    fi

    log_info "npm $(npm -v) available"
    log_success "Step 1/8: nvm sourced — npm available"
}

# ============================================================
# AC-2: Git credential setup
# Configures credential helper and writes the GitHub token to
# ~/.git-credentials (mode 600) so git clone/pull can authenticate
# against the private repository without an interactive prompt.
# ============================================================
setup_git_credentials() {
    log_info "Step 2/8: Configuring git credentials"

    git config --global credential.helper store

    # Write token — overwrite on every run in case the token has rotated
    printf 'https://%s@github.com\n' "${GITHUB_TOKEN}" > "${HOME}/.git-credentials"
    chmod 600 "${HOME}/.git-credentials"

    log_success "Step 2/8: Git credentials configured (~/.git-credentials mode 600)"
}

# ============================================================
# AC-2: Clone or pull
# Checks for an existing .git directory to distinguish a complete
# clone from a stale/partial directory before deciding clone vs pull.
# ============================================================
clone_or_pull() {
    log_info "Step 3/8: Cloning or updating claude-code-studio repository"

    if [[ -d "${HOME}/claude-code-studio/.git" ]]; then
        log_info "Repository already cloned — running git pull"
        git -C "${HOME}/claude-code-studio" pull
    else
        retry 3 5 git clone \
            https://github.com/Mwogi/claude-code-studio.git \
            "${HOME}/claude-code-studio"
    fi

    log_success "Step 3/8: Repository ready at ${HOME}/claude-code-studio"
}

# ============================================================
# AC-3: Install npm dependencies
# npm install (with retry for network flakiness).
# No build step needed — app runs directly from server.js at repo root.
# Asserts server.js exists after npm install completes.
# ============================================================
build_studio() {
    log_info "Step 4/8: Installing Claude Code Studio dependencies"

    cd "${HOME}/claude-code-studio"

    retry 3 15 npm install
    log_info "npm install complete"

    # No build step required — app runs from server.js at repository root
    log_info "No build step required — app runs from server.js"

    if [[ ! -f "${HOME}/claude-code-studio/server.js" ]]; then
        log_error "Installation failed — server.js not found in claude-code-studio"
        return 1
    fi

    log_success "server.js present — app entry point verified"
    log_success "Step 4/8: Dependencies installed"
}

# ============================================================
# AC-4b: Claude Code CLI Bedrock configuration
# Renders ~/.claude/settings.json so Claude Code CLI uses Bedrock
# instead of requiring an Anthropic API key.
# Skips if settings.json already exists (preserves manual config).
# ============================================================
render_claude_code_config() {
    log_info "Step 7/8: Configuring Claude Code CLI for Bedrock"

    local claude_dir="${HOME}/.claude"
    local settings_path="${claude_dir}/settings.json"

    mkdir -p "${claude_dir}"

    if [[ -f "${settings_path}" ]]; then
        log_info "~/.claude/settings.json already exists — preserving existing config"
        log_success "Step 7/8: Claude Code CLI config present"
        return 0
    fi

    render_template \
        "${DEVBOX_DIR}/templates/claude-settings.json.template" \
        "${settings_path}"

    chmod 600 "${settings_path}"

    log_success "~/.claude/settings.json rendered (Bedrock enabled, region: ${BEDROCK_REGION:-us-west-1})"
    log_success "Step 7/8: Claude Code CLI configured for Bedrock"
}

# ============================================================
# Renders claude-studio-config.json.template into config.json only if
# config.json does not already exist (preserves manual configuration).
# Asserts that no unresolved ${VAR} placeholders remain after rendering.
# ============================================================
render_config() {
    log_info "Step 5/8: Rendering Claude Studio configuration"

    local config_path="${HOME}/claude-code-studio/config.json"

    # Skip rendering if config.json already exists — preserve manual/existing config
    if [[ -f "${config_path}" ]]; then
        log_info "config.json already exists — skipping template render (preserving existing config)"
        log_success "Step 5/8: Configuration present at ${config_path}"
        return 0
    fi

    render_template \
        "${DEVBOX_DIR}/templates/claude-studio-config.json.template" \
        "${config_path}"

    # Verify no unresolved ${VAR} placeholders remain
    # SC2016: single quotes intentional — grep for literal string ${
    # shellcheck disable=SC2016
    if grep -q '\${' "${config_path}"; then
        log_error "Unresolved placeholders in config.json — check required env vars:"
        # shellcheck disable=SC2016
        grep '\${' "${config_path}" >&2
        return 1
    fi

    log_success "config.json rendered at ${config_path}"
    log_success "Step 5/8: Configuration rendered"
}

# ============================================================
# AC-4c: Claude Studio .env file
# Creates ~/claude-code-studio/.env with OpenClaw webhook integration
# and Discord notification channel. Reads the hooks token generated
# by Phase 4 (install-openclaw.sh).
# Skips if .env already exists (preserves manual config).
# ============================================================
render_studio_env() {
    log_info "Step 6/8: Creating Claude Studio .env for OpenClaw integration"

    local env_path="${HOME}/claude-code-studio/.env"

    if [[ -f "${env_path}" ]]; then
        log_info ".env already exists — preserving existing config"
        log_success "Step 6/8: Claude Studio .env present"
        return 0
    fi

    # Read the hooks token generated by Phase 4
    local hooks_token_file="${HOME}/.openclaw/.hooks-token"
    if [[ -f "${hooks_token_file}" ]]; then
        OPENCLAW_HOOKS_TOKEN="$(cat "${hooks_token_file}")"
        export OPENCLAW_HOOKS_TOKEN
        log_info "Read OpenClaw hooks token from ${hooks_token_file}"
    else
        # Fallback: try to extract from openclaw.json
        OPENCLAW_HOOKS_TOKEN="$(python3 -c "import json; print(json.load(open('${HOME}/.openclaw/openclaw.json'))['hooks']['token'])" 2>/dev/null || true)"
        export OPENCLAW_HOOKS_TOKEN
        if [[ -n "${OPENCLAW_HOOKS_TOKEN}" ]]; then
            log_info "Extracted hooks token from openclaw.json"
        else
            log_warn "No hooks token found — Studio webhook notifications won't work until configured"
            OPENCLAW_HOOKS_TOKEN="REPLACE_ME"
            export OPENCLAW_HOOKS_TOKEN
        fi
    fi

    render_template \
        "${DEVBOX_DIR}/templates/claude-studio.env.template" \
        "${env_path}"

    chmod 600 "${env_path}"

    log_success ".env rendered at ${env_path} (OpenClaw integration configured)"
    log_success "Step 6/8: Claude Studio .env created"
}

# ============================================================
# AC-5: Systemd system service
# Renders the unit to a temp file (avoids privileged envsubst),
# copies to /etc/systemd/system/, reloads daemon, enables, starts.
# NODE_BIN_PATH and NODE_BIN_DIR are resolved from the active nvm node
# so the service file references the exact versioned binary path.
# ============================================================
install_service() {
    log_info "Step 8/8: Installing claude-studio systemd system service"

    # Resolve node binary path from the currently active nvm node
    NODE_BIN_PATH="$(command -v node)"
    NODE_BIN_DIR="$(dirname "${NODE_BIN_PATH}")"
    export NODE_BIN_PATH NODE_BIN_DIR
    log_info "node binary: ${NODE_BIN_PATH}"

    local tmp_svc="/tmp/claude-studio.service.rendered"

    render_template "${DEVBOX_DIR}/templates/claude-studio.service" "${tmp_svc}"
    sudo cp "${tmp_svc}" /etc/systemd/system/claude-studio.service
    rm -f "${tmp_svc}"

    sudo systemctl daemon-reload
    log_info "systemctl daemon-reload complete"

    sudo systemctl enable claude-studio
    log_info "claude-studio service enabled"

    sudo systemctl start claude-studio
    log_info "claude-studio service started"

    log_success "Step 8/8: Service installed and started"
}

# ============================================================
# AC-5 (continued): Wait for service stabilization
# Polls systemctl is-active for up to 15 seconds; dumps status on timeout.
# ============================================================
wait_for_service() {
    local max_attempts=15
    local attempt=0
    log_info "Waiting for claude-studio to stabilize (up to ${max_attempts}s)..."

    while (( attempt < max_attempts )); do
        if systemctl is-active --quiet claude-studio 2>/dev/null; then
            log_success "claude-studio is active (attempt $((attempt + 1))/${max_attempts})"
            return 0
        fi
        attempt=$(( attempt + 1 ))
        sleep 1
    done

    log_error "claude-studio did not become active within ${max_attempts} seconds"
    sudo systemctl status claude-studio --no-pager 2>&1 | tail -20 || true
    return 1
}

# ============================================================
# AC-6: Verification and marker
# Asserts service is active, HTTP 200 on port, then sets marker.
# ============================================================
verify_phase() {
    log_info "Verifying Phase ${PHASE_NUM} completion"

    # Assert service is active
    local svc_state
    svc_state="$(systemctl is-active claude-studio 2>/dev/null || true)"
    if [[ "${svc_state}" != "active" ]]; then
        log_error "claude-studio is not active (state: ${svc_state:-unknown})"
        sudo systemctl status claude-studio --no-pager 2>&1 | tail -20 || true
        return 1
    fi
    log_success "claude-studio service is active"

    # Assert HTTP 200 on the configured port (follow redirects — app redirects / to /login)
    # Retry a few times since Node apps may take a moment to bind the port after systemd reports active
    local http_code
    local http_attempt=0
    local http_max=6
    while (( http_attempt < http_max )); do
        http_code="$(curl -sL -o /dev/null -w "%{http_code}" \
            "http://localhost:${CLAUDE_STUDIO_PORT}" 2>/dev/null || true)"
        if [[ "${http_code}" == "200" ]]; then
            log_success "Claude Studio HTTP 200 on port ${CLAUDE_STUDIO_PORT}"
            break
        fi
        http_attempt=$(( http_attempt + 1 ))
        if (( http_attempt < http_max )); then
            log_info "HTTP check returned ${http_code:-000} — retrying in 5s (${http_attempt}/${http_max})"
            sleep 5
        fi
    done
    if [[ "${http_code}" != "200" ]]; then
        log_error "Claude Studio HTTP check failed (code: ${http_code:-no response}) on port ${CLAUDE_STUDIO_PORT}"
        return 1
    fi

    # Set completion marker
    set_marker "${PHASE_NUM}"
    log_success "Phase ${PHASE_NUM} complete — Claude Code Studio active on port ${CLAUDE_STUDIO_PORT}"
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
    setup_git_credentials
    clone_or_pull
    build_studio
    render_config
    render_studio_env
    render_claude_code_config
    install_service
    wait_for_service
    verify_phase

    local phase_end elapsed
    phase_end="$(date +%s)"
    elapsed=$(( phase_end - phase_start ))

    log_phase_end "${PHASE_NUM}" "${TOTAL_PHASES}" "${PHASE_NAME}" "${elapsed}"
}

main
