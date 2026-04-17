# Story 2: System Dependencies Installer

**Story ID:** S2
**Epic:** E1 — Bootstrap Core Framework
**Points:** 5
**Estimated Hours:** 2
**Priority:** P0 — Phase 1 of bootstrap
**Dependencies:** S1 (bootstrap.sh core framework, _common.sh)

---

## Description

Create `scripts/install-system.sh` — the Phase 1 installer that provisions all system-level packages via apt, configures MariaDB with utf8mb4 and a root password, ensures Redis is running, and installs wkhtmltopdf for Frappe PDF generation.

---

## Acceptance Criteria

### AC-1: Idempotency check
- [ ] Checks marker file `.phase-1-complete` AND `systemctl is-active mariadb` AND `redis-cli ping | grep PONG`
- [ ] If all pass: logs "Phase 1 already complete, skipping" and exits 0
- [ ] If marker exists but service check fails: clears marker and re-runs

### AC-2: apt package installation
- [ ] Runs `apt-get update` before installing
- [ ] Installs all required packages in a single `apt-get install -y` command:
  - build-essential
  - python3, python3-dev, python3-pip, python3-venv, python3-setuptools
  - git, curl, wget, jq
  - gettext-base (for envsubst)
  - libffi-dev, libssl-dev, libjpeg-dev, libpng-dev
  - libxml2-dev, libxslt1-dev
  - libmysqlclient-dev (or default-libmysqlclient-dev)
  - redis-server, redis-tools
  - mariadb-server, mariadb-client
  - wkhtmltopdf
  - xvfb, xfonts-base, xfonts-scalable (for wkhtmltopdf headless)
  - supervisor
- [ ] Uses `DEBIAN_FRONTEND=noninteractive` to prevent interactive prompts
- [ ] Uses retry logic (3 attempts) for `apt-get update` and `apt-get install`
- [ ] Logs each major step with `log_info` / `log_success`

### AC-3: MariaDB configuration
- [ ] Ensures MariaDB service is started and enabled
- [ ] Sets character set to utf8mb4 via config file:
  - Creates `/etc/mysql/mariadb.conf.d/99-devbox.cnf`
  - Sets `[mysqld]` section: `character-set-server = utf8mb4`, `collation-server = utf8mb4_unicode_ci`
  - Sets `[client]` section: `default-character-set = utf8mb4`
- [ ] Sets root password from `$MARIADB_ROOT_PASSWORD` using `mariadb -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';"` (handles both fresh and existing installs)
- [ ] Restarts MariaDB after config changes
- [ ] Verifies: `mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SELECT 1"` succeeds

### AC-4: Redis verification
- [ ] Ensures Redis service is started and enabled
- [ ] Verifies: `redis-cli ping` returns `PONG`

### AC-5: Completion
- [ ] Sets marker file `.phase-1-complete` after all checks pass
- [ ] Total execution time logged

---

## Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `scripts/install-system.sh` | Create | Phase 1 installer |

---

## Technical Notes

- Script sources `_common.sh` from the same directory: `source "${SCRIPT_DIR}/_common.sh"`
- Uses `sudo` for all apt and systemctl commands (bootstrap runs as ubuntu user)
- The wkhtmltopdf in Ubuntu 24.04 repos should be 0.12.6; if not available, fall back to direct .deb download from the wkhtmltopdf GitHub releases
- MariaDB root password change must handle both initial (no password) and subsequent (password already set) states
- `DEBIAN_FRONTEND=noninteractive` prevents any apt dialog boxes

---

## Definition of Done

- [ ] `bash -n scripts/install-system.sh` passes
- [ ] On fresh Ubuntu 24.04: script installs all packages without error
- [ ] `systemctl is-active mariadb` returns "active"
- [ ] `mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SELECT 1"` returns 1
- [ ] `mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SHOW VARIABLES LIKE 'character_set_server'"` shows utf8mb4
- [ ] `redis-cli ping` returns "PONG"
- [ ] `command -v wkhtmltopdf` succeeds
- [ ] Second run skips (exits 0 in < 2 seconds)
- [ ] ShellCheck passes with no errors
