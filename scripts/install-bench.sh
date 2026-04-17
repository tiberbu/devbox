#!/usr/bin/env bash
# scripts/install-bench.sh — Phase 3: Frappe Bench
#
# Installs the Frappe Bench CLI via pip3, initializes ~/frappe-bench with
# the Frappe framework (version-15 by default), creates a dev site, and
# enables developer mode.
# Idempotent: skips if .phase-3-complete marker, bench --version, and
# ~/frappe-bench/sites/${BENCH_SITE} are all healthy.
# If marker exists but checks fail: clears marker and re-runs.
#
# Usage (called by bootstrap.sh or directly):
#   bash scripts/install-bench.sh

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
readonly PHASE_NUM=3
readonly PHASE_NAME="Frappe Bench"
readonly TOTAL_PHASES=5

# Defaults — all overridable via environment variables
: "${FRAPPE_BRANCH:=version-15}"
: "${BENCH_SITE:=dev.local}"
: "${MARIADB_ROOT_PASSWORD:=tiberbu123}"
: "${HOME:=/home/ubuntu}"

readonly BENCH_DIR="${HOME}/frappe-bench"

# NVM_DIR exported so child processes can find nvm
NVM_DIR="${HOME}/.nvm"
export NVM_DIR

# ============================================================
# Internal helper — source nvm into current shell session
# ============================================================
_source_nvm() {
    # shellcheck disable=SC1090,SC1091
    [[ -s "${NVM_DIR}/nvm.sh" ]] && source "${NVM_DIR}/nvm.sh"
}

# ============================================================
# AC-1: Idempotency check
# Checks marker .phase-3-complete AND bench --version AND
# ~/frappe-bench/sites/${BENCH_SITE} exists.
# If all pass → skip and exit 0.
# If marker exists but checks fail → clear marker and re-run.
# ============================================================
check_idempotency() {
    if ! check_marker "${PHASE_NUM}"; then
        return 0   # No marker — proceed with full installation
    fi

    log_info "Marker .phase-${PHASE_NUM}-complete found — verifying bench and site"

    _source_nvm
    export PATH="${HOME}/.local/bin:${PATH}"

    local checks_ok=true

    local bench_ver
    bench_ver="$(bench --version 2>/dev/null || true)"
    if [[ -z "${bench_ver}" ]]; then
        log_warn "bench --version returned empty"
        checks_ok=false
    fi

    if [[ ! -d "${BENCH_DIR}/sites/${BENCH_SITE}" ]]; then
        log_warn "Site directory not found: ${BENCH_DIR}/sites/${BENCH_SITE}"
        checks_ok=false
    fi

    if [[ "${checks_ok}" == "true" ]]; then
        log_success "Phase ${PHASE_NUM} already complete — skipping (marker + bench ${bench_ver} + site OK)"
        exit 0
    else
        log_warn "Marker exists but checks failed — clearing marker and re-running"
        clear_marker "${PHASE_NUM}"
    fi
}

# ============================================================
# AC-2: Bench CLI installation
# Sources nvm for node, pip3 installs frappe-bench (with
# --break-system-packages fallback on Ubuntu 24.04+), verifies
# bench --version returns 5.x.x.
# ============================================================
install_bench_cli() {
    log_info "Step 1/5: Installing Frappe Bench CLI via pip3"

    # Source nvm so node/npm are available (bench needs node)
    _source_nvm
    if ! command -v node &>/dev/null; then
        log_error "node not found — ensure install-node.sh (Phase 2) ran successfully first"
        return 1
    fi
    log_info "node $(node -v) available"

    # Ensure ~/.local/bin is on PATH (pip3 user installs land here)
    export PATH="${HOME}/.local/bin:${PATH}"

    # Try plain install first; fall back to --break-system-packages on Ubuntu 24.04+
    # Note: stderr is NOT suppressed so diagnostic output is preserved on failure
    if ! pip3 install frappe-bench; then
        log_warn "pip3 install failed — retrying with --break-system-packages (Ubuntu 24.04+)"
        pip3 install frappe-bench --break-system-packages
    fi
    log_success "frappe-bench pip3 package installed"

    # Verify bench binary is accessible
    local bench_ver
    bench_ver="$(bench --version 2>/dev/null || true)"
    if [[ -z "${bench_ver}" ]]; then
        log_error "bench --version returned empty — check that ${HOME}/.local/bin is in PATH"
        return 1
    fi

    if [[ "${bench_ver}" =~ ^5\. ]]; then
        log_success "bench --version: ${bench_ver} (5.x.x confirmed)"
    else
        log_warn "bench --version: ${bench_ver} (expected 5.x.x — proceeding)"
    fi

    log_success "Step 1/5: Frappe Bench CLI installed (${bench_ver})"
}

# ============================================================
# AC-3: Bench initialization
# bench init ~/frappe-bench --frappe-branch ${FRAPPE_BRANCH}
# Verifies apps/frappe/, env/, sites/, Procfile exist after init.
# Expected duration: 3-5 minutes.
# ============================================================
init_bench() {
    log_info "Step 2/5: Initializing frappe-bench (branch: ${FRAPPE_BRANCH})"
    log_info "  Expected duration: 3-5 minutes — cloning Frappe and creating virtualenv"

    if [[ -d "${BENCH_DIR}/apps/frappe" ]]; then
        log_info "apps/frappe already exists — skipping bench init"
    else
        # Remove stale/partial directory before re-initialising
        if [[ -d "${BENCH_DIR}" ]]; then
            log_warn "Removing stale bench directory before re-init: ${BENCH_DIR}"
            rm -rf "${BENCH_DIR}"
        fi

        bench init "${BENCH_DIR}" --frappe-branch "${FRAPPE_BRANCH}"
        log_success "bench init complete"
    fi

    # Verify expected structure (AC-3)
    local -a required_paths=(
        "${BENCH_DIR}/apps/frappe"
        "${BENCH_DIR}/env"
        "${BENCH_DIR}/sites"
        "${BENCH_DIR}/Procfile"
    )
    local -a missing=()
    for path in "${required_paths[@]}"; do
        [[ -e "${path}" ]] || missing+=("${path}")
    done

    if (( ${#missing[@]} > 0 )); then
        log_error "bench init verification failed — missing paths:"
        for p in "${missing[@]}"; do
            log_error "  ${p}"
        done
        return 1
    fi

    log_success "bench structure verified: apps/frappe, env, sites, Procfile"
    log_success "Step 2/5: Bench initialized at ${BENCH_DIR}"
}

# ============================================================
# AC-4: Site creation
# bench new-site with MariaDB root credentials.
# Adds BENCH_SITE → 127.0.0.1 in /etc/hosts if absent.
# Sets default site via bench use.
# ============================================================
create_site() {
    log_info "Step 3/5: Creating site ${BENCH_SITE}"

    cd "${BENCH_DIR}"

    if [[ -d "${BENCH_DIR}/sites/${BENCH_SITE}" ]]; then
        log_info "Site ${BENCH_SITE} already exists — skipping bench new-site"
    else
        bench new-site "${BENCH_SITE}" \
            --mariadb-root-password "${MARIADB_ROOT_PASSWORD}" \
            --admin-password "${MARIADB_ROOT_PASSWORD}"
        log_success "Site ${BENCH_SITE} created"
    fi

    # Add BENCH_SITE to /etc/hosts (AC-4: 127.0.0.1) if not already present
    # Use space-prefix match to avoid false positives from substring hostnames
    # (e.g. "dev.local" must not match "mydev.local")
    if ! grep -qF " ${BENCH_SITE}" /etc/hosts 2>/dev/null; then
        log_info "Adding ${BENCH_SITE} → 127.0.0.1 in /etc/hosts"
        printf '127.0.0.1  %s\n' "${BENCH_SITE}" | sudo tee -a /etc/hosts >/dev/null
        log_success "${BENCH_SITE} added to /etc/hosts"
    else
        log_info "${BENCH_SITE} already present in /etc/hosts — no change"
    fi

    # Set default site (AC-4: bench use)
    bench use "${BENCH_SITE}"
    log_success "bench use ${BENCH_SITE} — default site configured"

    log_success "Step 3/5: Site ${BENCH_SITE} ready"
}

# ============================================================
# AC-5: Development mode configuration
# Sets developer_mode, dev_server, and serve_default_site
# in sites/common_site_config.json via bench set-config -g.
# ============================================================
configure_dev_mode() {
    log_info "Step 4/5: Configuring development mode"

    cd "${BENCH_DIR}"

    bench set-config -g developer_mode 1
    log_success "developer_mode = 1 (common_site_config.json)"

    bench set-config -g dev_server 1
    log_success "dev_server = 1 (common_site_config.json)"

    bench set-config -g serve_default_site 1
    log_success "serve_default_site = 1 (common_site_config.json)"

    log_success "Step 4/5: Development mode configured"
}

# ============================================================
# AC-6: Verification and marker
# Checks site directory exists, frappe appears in list-apps,
# then sets .phase-3-complete marker.
# ============================================================
verify_phase() {
    log_info "Step 5/5: Verifying Phase ${PHASE_NUM} completion"

    cd "${BENCH_DIR}"

    # Assert site directory exists (AC-6)
    if [[ ! -d "${BENCH_DIR}/sites/${BENCH_SITE}" ]]; then
        log_error "Site directory not found: ${BENCH_DIR}/sites/${BENCH_SITE}"
        return 1
    fi
    log_success "Site directory confirmed: ${BENCH_DIR}/sites/${BENCH_SITE}"

    # Assert frappe appears in list-apps (AC-6)
    local apps
    apps="$(bench --site "${BENCH_SITE}" list-apps 2>/dev/null || true)"
    if printf '%s\n' "${apps}" | grep -q "frappe"; then
        log_success "bench list-apps confirms: frappe installed on ${BENCH_SITE}"
    else
        log_error "frappe not found in bench --site ${BENCH_SITE} list-apps output: ${apps}"
        return 1
    fi

    # Set completion marker (AC-6)
    set_marker "${PHASE_NUM}"
    log_success "Step 5/5: Phase ${PHASE_NUM} (${PHASE_NAME}) verified — marker set"
}

# ============================================================
# Main
# ============================================================
main() {
    log_phase_start "${PHASE_NUM}" "${TOTAL_PHASES}" "${PHASE_NAME}"

    local phase_start
    phase_start="$(date +%s)"

    check_idempotency
    install_bench_cli
    init_bench
    create_site
    configure_dev_mode
    verify_phase

    local phase_end elapsed
    phase_end="$(date +%s)"
    elapsed=$(( phase_end - phase_start ))

    log_phase_end "${PHASE_NUM}" "${TOTAL_PHASES}" "${PHASE_NAME}" "${elapsed}"
}

main
