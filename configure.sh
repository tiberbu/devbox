#!/usr/bin/env bash
# configure.sh — Tiberbu DevBox credential-only reconfigure
#
# Re-renders all configuration files from templates, updates git credentials,
# and restarts openclaw-gateway and claude-studio services.
#
# Does NOT install packages, rebuild apps, or touch Frappe Bench, MariaDB,
# or Redis.
#
# Usage: ./configure.sh [OPTIONS]
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

trap 'error_handler "${BASH_SOURCE[0]}" "${LINENO}" "$?"' ERR

# ============================================================
# Argument defaults
# ============================================================
ENV_FILE="${HOME}/.tiberbu-env"

# ============================================================
# Usage / help
# ============================================================
usage() {
    cat <<'EOF'
Usage: ./configure.sh [OPTIONS]

Re-renders all configuration files from templates, updates git credentials,
and restarts openclaw-gateway and claude-studio services.

Does NOT install packages, rebuild apps, or touch Frappe Bench, MariaDB,
or Redis.

Options:
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
    CLAUDE_STUDIO_PORT      Claude Studio HTTP port   (default: 3000)
    OPENCLAW_PORT           OpenClaw gateway port     (default: 18789)

Files updated:
  ~/.openclaw/openclaw.json
  ~/.config/systemd/user/openclaw-gateway.service
  /etc/systemd/system/claude-studio.service  (via sudo)
  ~/claude-code-studio/config.json
  ~/.git-credentials

Services restarted:
  openclaw-gateway  (systemctl --user restart)
  claude-studio     (sudo systemctl restart)

Log file: /var/tmp/devbox/bootstrap.log
EOF
}

# ============================================================
# Argument parsing
# ============================================================
while [[ $# -gt 0 ]]; do
    case "$1" in
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

# ============================================================
# Ensure runtime directory exists
# ============================================================
mkdir -p "${MARKER_DIR}"

# ============================================================
# NVM sourcing helper
# Sources nvm silently so node binary paths can be resolved.
# ============================================================
_source_nvm() {
    export NVM_DIR="${HOME}/.nvm"
    # shellcheck disable=SC1090,SC1091
    if [[ -s "${NVM_DIR}/nvm.sh" ]]; then
        \. "${NVM_DIR}/nvm.sh" 2>/dev/null || true
    fi
}

# ============================================================
# Discord notification — reconfigure complete
# Best-effort; warns on failure, never exits non-zero.
# ============================================================
_send_discord_reconfigure_notification() {
    if [[ -z "${DISCORD_BOT_TOKEN:-}" || -z "${DISCORD_CHANNEL_ID:-}" ]]; then
        log_warn "Discord credentials not set — skipping notification"
        return 0
    fi

    local hostname
    hostname="$(hostname -f 2>/dev/null || hostname 2>/dev/null || printf 'unknown')"

    local timestamp
    timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    local payload
    if command -v jq &>/dev/null; then
        payload="$(jq -n \
            --arg hostname "${hostname}" \
            --arg ts "${timestamp}" \
            '{
                embeds: [{
                    title: "Tiberbu DevBox — Reconfigure Complete",
                    color: 3066993,
                    description: ("Credentials updated and services restarted on " + $hostname),
                    fields: [
                        {name: "Host",   value: $hostname, inline: true},
                        {name: "Status", value: "✅ Active", inline: true}
                    ],
                    timestamp: $ts
                }]
            }')" || true
    else
        # Fallback: hand-built JSON (safe for typical hostname values)
        payload="$(printf \
            '{"embeds":[{"title":"Tiberbu DevBox \u2014 Reconfigure Complete","color":3066993,"description":"Credentials updated and services restarted on %s","fields":[{"name":"Host","value":"%s","inline":true},{"name":"Status","value":"Active","inline":true}],"timestamp":"%s"}]}' \
            "${hostname}" "${hostname}" "${timestamp}")"
    fi

    if [[ -z "${payload:-}" ]]; then
        log_warn "Could not build Discord payload — skipping notification"
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
        log_success "Discord notification sent (HTTP ${http_code})"
    else
        log_warn "Discord notification failed (HTTP ${http_code:-000}) — non-fatal"
    fi
}

# ============================================================
# Service stabilization helper
# _wait_for_service NAME SCOPE [MAX_SECS]
#   SCOPE: "user" or "system"
#   MAX_SECS: default 10
# ============================================================
_wait_for_service() {
    local svc_name="$1"
    local scope="$2"
    local max_secs="${3:-10}"
    local attempt=0

    log_info "Waiting for ${svc_name} (${scope}) to stabilize (up to ${max_secs}s)..."

    while (( attempt < max_secs )); do
        if [[ "${scope}" == "user" ]]; then
            if systemctl --user is-active --quiet "${svc_name}" 2>/dev/null; then
                log_success "${svc_name} is active (attempt $((attempt + 1))/${max_secs})"
                return 0
            fi
        else
            if systemctl is-active --quiet "${svc_name}" 2>/dev/null; then
                log_success "${svc_name} is active (attempt $((attempt + 1))/${max_secs})"
                return 0
            fi
        fi
        attempt=$(( attempt + 1 ))
        sleep 1
    done

    log_error "${svc_name} (${scope}) did not become active within ${max_secs} seconds"
    if [[ "${scope}" == "user" ]]; then
        systemctl --user status "${svc_name}" --no-pager 2>&1 | tail -20 || true
    else
        sudo systemctl status "${svc_name}" --no-pager 2>&1 | tail -20 || true
    fi
    return 1
}

# ============================================================
# STEP 1 — Environment loading and validation (AC-1)
# ============================================================
step_load_env() {
    local step_start
    step_start="$(date +%s)"
    log_phase_start 1 5 "Environment loading and validation"

    # Require env file to exist (configure.sh needs the file, unlike bootstrap.sh
    # which can fall back to environment variables)
    if [[ ! -f "${ENV_FILE}" ]]; then
        log_error "Env file not found: ${ENV_FILE}"
        log_error "Create ${ENV_FILE} with the required credentials and re-run configure.sh"
        exit 1
    fi

    load_env_file "${ENV_FILE}"
    validate_credentials "${ENV_FILE}"

    local step_end elapsed
    step_end="$(date +%s)"
    elapsed=$(( step_end - step_start ))
    log_phase_end 1 5 "Environment loading and validation" "${elapsed}"
}

# ============================================================
# STEP 2 — Template re-rendering (AC-2)
# ============================================================
step_render_templates() {
    local step_start
    step_start="$(date +%s)"
    log_phase_start 2 5 "Template re-rendering"

    # Source nvm so node binary paths are available for template substitution
    _source_nvm

    # Resolve node binary paths used in service unit templates
    if command -v node &>/dev/null; then
        NODE_BIN_PATH="$(command -v node)"
        NODE_BIN_DIR="$(dirname "${NODE_BIN_PATH}")"
        export NODE_BIN_PATH NODE_BIN_DIR
        log_info "Resolved node binary: ${NODE_BIN_PATH}"
    else
        log_warn "node not found in PATH — NODE_BIN_PATH/NODE_BIN_DIR will be empty in service templates"
        NODE_BIN_PATH=""
        NODE_BIN_DIR=""
        export NODE_BIN_PATH NODE_BIN_DIR
    fi

    # Export variables consumed by envsubst in all templates
    export USER HOME

    # 2a. ~/.openclaw/openclaw.json
    mkdir -p "${HOME}/.openclaw"
    render_template \
        "${SCRIPT_DIR}/templates/openclaw.json.template" \
        "${HOME}/.openclaw/openclaw.json"
    chmod 600 "${HOME}/.openclaw/openclaw.json"
    log_success "openclaw.json re-rendered and secured (mode 600)"

    # 2b. ~/.config/systemd/user/openclaw-gateway.service
    mkdir -p "${HOME}/.config/systemd/user"
    render_template \
        "${SCRIPT_DIR}/templates/openclaw-gateway.service" \
        "${HOME}/.config/systemd/user/openclaw-gateway.service"
    log_success "openclaw-gateway.service re-rendered"

    # 2c. /etc/systemd/system/claude-studio.service (via sudo)
    local tmp_svc="/tmp/claude-studio.service.rendered"
    render_template "${SCRIPT_DIR}/templates/claude-studio.service" "${tmp_svc}"
    sudo cp "${tmp_svc}" /etc/systemd/system/claude-studio.service
    rm -f "${tmp_svc}"
    log_success "claude-studio.service re-rendered (system, via sudo)"

    # 2d. ~/claude-code-studio/config.json
    if [[ -d "${HOME}/claude-code-studio" ]]; then
        render_template \
            "${SCRIPT_DIR}/templates/claude-studio-config.json.template" \
            "${HOME}/claude-code-studio/config.json"
        log_success "claude-code-studio/config.json re-rendered"
    else
        log_warn "Directory ${HOME}/claude-code-studio not found — skipping config.json render"
    fi

    local step_end elapsed
    step_end="$(date +%s)"
    elapsed=$(( step_end - step_start ))
    log_phase_end 2 5 "Template re-rendering" "${elapsed}"
}

# ============================================================
# STEP 3 — Git credential update (AC-3)
# ============================================================
step_update_git_creds() {
    local step_start
    step_start="$(date +%s)"
    log_phase_start 3 5 "Git credential update"

    # Write new token (overwrite to pick up rotated credentials)
    printf 'https://%s@github.com\n' "${GITHUB_TOKEN}" > "${HOME}/.git-credentials"
    chmod 600 "${HOME}/.git-credentials"
    log_success "${HOME}/.git-credentials updated (mode 600)"

    # Ensure credential helper is set to store
    git config --global credential.helper store

    # Verify GitHub token — graceful failure only (log_warn, do not exit)
    log_info "Verifying GitHub token via git ls-remote..."
    local result
    result="$(GIT_TERMINAL_PROMPT=0 \
        git ls-remote \
        "https://${GITHUB_TOKEN}@github.com/tiberbu/devbox.git" HEAD \
        2>/dev/null | head -1 || true)"

    if [[ -n "${result}" ]]; then
        log_success "git ls-remote succeeded — GitHub token is valid"
    else
        log_warn "git ls-remote returned empty — token may be invalid or network unavailable"
    fi

    local step_end elapsed
    step_end="$(date +%s)"
    elapsed=$(( step_end - step_start ))
    log_phase_end 3 5 "Git credential update" "${elapsed}"
}

# ============================================================
# STEP 4 — Service restarts (AC-4)
# NOTE: Does NOT restart MariaDB, Redis, or touch Frappe Bench.
# ============================================================
step_restart_services() {
    local step_start
    step_start="$(date +%s)"
    log_phase_start 4 5 "Service restarts"

    # Ensure XDG_RUNTIME_DIR is set so systemctl --user can reach the session bus
    # (required in non-interactive / script contexts on Ubuntu 24.04)
    if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
        XDG_RUNTIME_DIR="/run/user/$(id -u)"
        export XDG_RUNTIME_DIR
    fi

    # 4a. openclaw-gateway (user service)
    log_info "Reloading user daemon and restarting openclaw-gateway..."
    systemctl --user daemon-reload
    systemctl --user restart openclaw-gateway
    _wait_for_service "openclaw-gateway" "user" 10

    # 4b. claude-studio (system service)
    log_info "Reloading system daemon and restarting claude-studio..."
    sudo systemctl daemon-reload
    sudo systemctl restart claude-studio
    _wait_for_service "claude-studio" "system" 10

    local step_end elapsed
    step_end="$(date +%s)"
    elapsed=$(( step_end - step_start ))
    log_phase_end 4 5 "Service restarts" "${elapsed}"
}

# ============================================================
# STEP 5 — Verification + Discord notification (AC-5)
# ============================================================
step_verify() {
    local step_start
    step_start="$(date +%s)"
    log_phase_start 5 5 "Verification"

    local all_pass=true

    # 5a. openclaw-gateway active?
    local oc_state
    oc_state="$(systemctl --user is-active openclaw-gateway 2>/dev/null || true)"
    if [[ "${oc_state}" == "active" ]]; then
        log_success "openclaw-gateway: active"
    else
        log_error "openclaw-gateway: ${oc_state:-unknown}"
        all_pass=false
    fi

    # 5b. claude-studio active?
    local cs_state
    cs_state="$(systemctl is-active claude-studio 2>/dev/null || true)"
    if [[ "${cs_state}" == "active" ]]; then
        log_success "claude-studio: active"
    else
        log_error "claude-studio: ${cs_state:-unknown}"
        all_pass=false
    fi

    # 5c. Port 18789 (openclaw) listening?
    if ss -tlnp 2>/dev/null | grep -q ":${OPENCLAW_PORT}"; then
        log_success "Port ${OPENCLAW_PORT} (openclaw) is listening"
    elif curl -sf "http://localhost:${OPENCLAW_PORT}/health" &>/dev/null; then
        log_success "Port ${OPENCLAW_PORT} (openclaw) health check passed"
    else
        log_warn "Port ${OPENCLAW_PORT} (openclaw) not yet listening — service may still be starting"
    fi

    # 5d. Port 3000 (claude-studio) listening?
    local http_code
    http_code="$(curl -sL -o /dev/null -w '%{http_code}' \
        "http://localhost:${CLAUDE_STUDIO_PORT}" 2>/dev/null || true)"
    if [[ "${http_code}" == "200" ]]; then
        log_success "Port ${CLAUDE_STUDIO_PORT} (claude-studio) HTTP 200"
    elif ss -tlnp 2>/dev/null | grep -q ":${CLAUDE_STUDIO_PORT}"; then
        log_success "Port ${CLAUDE_STUDIO_PORT} (claude-studio) is listening"
    else
        log_warn "Port ${CLAUDE_STUDIO_PORT} (claude-studio) HTTP ${http_code:-no response} — service may still be starting"
    fi

    # 5e. Discord notification (best-effort — never affects exit code)
    _send_discord_reconfigure_notification

    local step_end elapsed
    step_end="$(date +%s)"
    elapsed=$(( step_end - step_start ))
    log_phase_end 5 5 "Verification" "${elapsed}"

    if [[ "${all_pass}" == "false" ]]; then
        log_error "One or more services are not active after reconfigure — review logs"
        return 1
    fi
}

# ============================================================
# Main entry point
# ============================================================
main() {
    local start_time
    start_time="$(date +%s)"

    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "  Tiberbu DevBox — Credential Reconfigure"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Script directory : ${SCRIPT_DIR}"
    log_info "Env file         : ${ENV_FILE}"
    log_info "Log file         : ${LOG_FILE}"

    step_load_env
    step_render_templates
    step_update_git_creds
    step_restart_services
    step_verify

    local end_time elapsed
    end_time="$(date +%s)"
    elapsed=$(( end_time - start_time ))

    printf '\n'
    log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "  Reconfigure complete — elapsed time: ${elapsed}s"
    log_success "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

main
