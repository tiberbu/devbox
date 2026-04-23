#!/usr/bin/env bash
# scripts/install-system.sh — Phase 1: System Dependencies
#
# Installs all required apt packages, configures MariaDB (utf8mb4 charset),
# and verifies Redis is active.  Idempotent: skips if .phase-1-complete
# marker exists and both MariaDB and Redis are healthy.
#
# Usage (called by bootstrap.sh or directly):
#   sudo bash scripts/install-system.sh

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
readonly PHASE_NUM=1
readonly PHASE_NAME="System Dependencies"
readonly TOTAL_PHASES=5
readonly MARIADB_CNF="/etc/mysql/mariadb.conf.d/99-devbox.cnf"

APT_PACKAGES=(
    build-essential
    python3
    python3-dev
    python3-pip
    python3-venv
    python3-setuptools
    git
    curl
    wget
    jq
    cron
    gettext-base
    libffi-dev
    libssl-dev
    libjpeg-dev
    libpng-dev
    libxml2-dev
    libxslt1-dev
    libmysqlclient-dev
    redis-server
    redis-tools
    mariadb-server
    mariadb-client
    wkhtmltopdf
    xvfb
    xfonts-base
    xfonts-scalable
    supervisor
)

# ============================================================
# AC-1: Idempotency check
# Checks marker + systemctl is-active mariadb + redis-cli ping.
# If all pass → skip and exit 0.
# If marker exists but a service fails → clear marker and re-run.
# ============================================================
check_idempotency() {
    if ! check_marker "${PHASE_NUM}"; then
        return 0   # No marker — proceed with full installation
    fi

    log_info "Marker .phase-${PHASE_NUM}-complete found — verifying services"

    local services_ok=true

    if ! systemctl is-active --quiet mariadb; then
        log_warn "mariadb is not active"
        services_ok=false
    fi

    local pong
    pong="$(redis-cli ping 2>/dev/null || true)"
    if [[ "${pong}" != "PONG" ]]; then
        log_warn "redis-cli ping returned: ${pong:-<empty>} (expected PONG)"
        services_ok=false
    fi

    if [[ "${services_ok}" == "true" ]]; then
        log_success "Phase ${PHASE_NUM} already complete — skipping (marker + services OK)"
        exit 0
    else
        log_warn "Marker exists but services are not healthy — clearing marker and re-running"
        clear_marker "${PHASE_NUM}"
    fi
}

# ============================================================
# AC-2: apt package installation (with 3-attempt retry)
# ============================================================
install_packages() {
    log_info "Step 1/4: Installing apt packages"
    export DEBIAN_FRONTEND=noninteractive

    retry 3 10 apt-get update

    retry 3 10 apt-get install -y "${APT_PACKAGES[@]}"

    log_success "Step 1/4: All apt packages installed"
}

# ============================================================
# AC-3: MariaDB configuration
# ============================================================
configure_mariadb() {
    log_info "Step 2/4: Configuring MariaDB"

    # Apply default if the variable is not set
    : "${MARIADB_ROOT_PASSWORD:=tiberbu123}"

    # Start and enable
    systemctl start mariadb
    systemctl enable mariadb
    log_success "MariaDB started and enabled"

    # Write utf8mb4 config
    cat > "${MARIADB_CNF}" <<'MARIADBCNF'
[client]
default-character-set = utf8mb4

[mysqld]
character-set-server  = utf8mb4
collation-server      = utf8mb4_unicode_ci
init_connect          = 'SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci'

[mysql]
default-character-set = utf8mb4
MARIADBCNF
    log_success "MariaDB utf8mb4 config written: ${MARIADB_CNF}"

    # Set root password (idempotent: try new password first, then fresh-install path)
    if mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SELECT 1;" &>/dev/null; then
        log_info "MariaDB root password already configured"
    else
        log_info "Setting MariaDB root password"
        # Fresh install: root is accessible via unix socket with no password
        mysql -u root <<MYSQL_INIT
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
MYSQL_INIT
        log_success "MariaDB root password set"
    fi

    # Restart to apply charset config
    systemctl restart mariadb
    log_success "MariaDB restarted with utf8mb4 config"

    # Verify connection with new password
    if mysql -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SELECT 1;" &>/dev/null; then
        log_success "Step 2/4: MariaDB connection verified"
    else
        log_error "MariaDB connection verification failed"
        return 1
    fi
}

# ============================================================
# AC-4: Redis verification
# ============================================================
configure_redis() {
    log_info "Step 3/4: Configuring Redis"

    systemctl start redis-server
    systemctl enable redis-server
    log_success "Redis started and enabled"

    local pong
    pong="$(redis-cli ping 2>/dev/null || true)"
    if [[ "${pong}" == "PONG" ]]; then
        log_success "Step 3/4: Redis ping returned PONG"
    else
        log_error "Redis ping failed (got: ${pong:-<empty>})"
        return 1
    fi
}

# ============================================================
# AC-5: Completion marker
# ============================================================
complete_phase() {
    log_info "Step 4/4: Setting completion marker"
    set_marker "${PHASE_NUM}"
    log_success "Phase ${PHASE_NUM} (${PHASE_NAME}) complete"
}

# ============================================================
# Main
# ============================================================
main() {
    log_phase_start "${PHASE_NUM}" "${TOTAL_PHASES}" "${PHASE_NAME}"

    local phase_start
    phase_start="$(date +%s)"

    check_idempotency
    install_packages
    configure_mariadb
    configure_redis
    complete_phase

    local phase_end elapsed
    phase_end="$(date +%s)"
    elapsed=$(( phase_end - phase_start ))

    log_phase_end "${PHASE_NUM}" "${TOTAL_PHASES}" "${PHASE_NAME}" "${elapsed}"
}

main
