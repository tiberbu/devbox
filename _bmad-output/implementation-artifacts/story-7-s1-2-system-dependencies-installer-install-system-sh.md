# Story: S1.2: System Dependencies Installer (install-system.sh)

Status: done

## Story

As a Tiberbu engineer,
I want a `scripts/install-system.sh` Phase 1 installer,
so that all system-level apt packages are installed, MariaDB is configured with utf8mb4 and a root password, Redis is running and verified, and the script is fully idempotent — skipping safely on re-runs.

## Acceptance Criteria

### AC-1: Idempotency check
1. At script start, check all three conditions: `check_marker 1` (marker file `/var/tmp/devbox/.phase-1-complete` exists) AND `systemctl is-active mariadb` returns "active" AND `redis-cli ping` returns "PONG"
2. If all three pass: call `log_info "Phase 1 already complete, skipping"` and `exit 0`
3. If marker exists but either service check fails: call `clear_marker 1` to remove stale marker, then continue with full installation

### AC-2: apt package installation
4. Export `DEBIAN_FRONTEND=noninteractive` before any apt calls to prevent interactive prompts
5. Call `sudo apt-get update` (with 3-attempt retry via `retry 3 5 sudo apt-get update`)
6. Install all packages in a single `sudo apt-get install -y` call (with 3-attempt retry):
   - `build-essential`
   - `python3 python3-dev python3-pip python3-venv python3-setuptools`
   - `git curl wget jq`
   - `gettext-base` (provides `envsubst`)
   - `libffi-dev libssl-dev libjpeg-dev libpng-dev`
   - `libxml2-dev libxslt1-dev`
   - `libmysqlclient-dev` (falls back to `default-libmysqlclient-dev` if not available)
   - `redis-server redis-tools`
   - `mariadb-server mariadb-client`
   - `wkhtmltopdf`
   - `xvfb xfonts-base xfonts-scalable` (required for wkhtmltopdf headless operation)
   - `supervisor`
7. Log `log_info "Installing system packages..."` before the install, `log_success "All packages installed"` after

### AC-3: MariaDB configuration
8. Start MariaDB: `sudo systemctl start mariadb` and enable it: `sudo systemctl enable mariadb`
9. Create `/etc/mysql/mariadb.conf.d/99-devbox.cnf` with `sudo tee`:
   ```ini
   [mysqld]
   character-set-server  = utf8mb4
   collation-server      = utf8mb4_unicode_ci

   [client]
   default-character-set = utf8mb4
   ```
10. Set root password using `sudo mariadb -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';"` — this handles both fresh (no password) and re-run (password already set) scenarios; wrap in `|| sudo mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SELECT 1" &>/dev/null` to handle already-configured installs
11. Restart MariaDB: `sudo systemctl restart mariadb` to apply charset config
12. Verify connection: `mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SELECT 1" &>/dev/null` must exit 0; call `log_success "MariaDB connection verified"`

### AC-4: Redis verification
13. Start Redis: `sudo systemctl start redis-server` and enable: `sudo systemctl enable redis-server`
14. Verify: `redis-cli ping` outputs `PONG`; use `grep -q PONG` to check; call `log_success "Redis verified (PONG)"`

### AC-5: Completion
15. After all steps pass, call `set_marker 1` to create `/var/tmp/devbox/.phase-1-complete`
16. The marker is only set AFTER all verifications pass — never before

### Definition of Done
17. `bash -n scripts/install-system.sh` exits 0 (syntax clean)
18. ShellCheck passes with no errors: `shellcheck scripts/install-system.sh`
19. On fresh Ubuntu 24.04: all packages install without error; MariaDB and Redis are active
20. `systemctl is-active mariadb` returns "active"
21. `mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SHOW VARIABLES LIKE 'character_set_server'"` shows `utf8mb4`
22. `redis-cli ping` returns `PONG`
23. `command -v wkhtmltopdf` exits 0
24. Second run completes in < 2 seconds (idempotency check exits early)

---

## Tasks / Subtasks

- [ ] **Task 1 — Script scaffold** (AC: all)
  - [ ] 1.1 Create `scripts/install-system.sh` with shebang `#!/usr/bin/env bash` and `set -euo pipefail`
  - [ ] 1.2 Add `SCRIPT_DIR` detection: `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`
  - [ ] 1.3 Source `_common.sh`: `source "${SCRIPT_DIR}/_common.sh"`
  - [ ] 1.4 Set ERR trap: `trap 'error_handler "${BASH_SOURCE[0]}" "${LINENO}" "$?"' ERR`
  - [ ] 1.5 Define `PHASE_NUM=1` constant at top of file

- [ ] **Task 2 — Idempotency check function** (AC: 1–3)
  - [ ] 2.1 Implement `check_completed()` function that checks marker file, `systemctl is-active mariadb`, and `redis-cli ping | grep -q PONG`
  - [ ] 2.2 If all three pass: `log_info "Phase 1 already complete, skipping"` then `exit 0`
  - [ ] 2.3 If marker exists but checks fail: call `clear_marker "$PHASE_NUM"` and fall through
  - [ ] 2.4 Call `check_completed` immediately after sourcing _common.sh

- [ ] **Task 3 — apt installation** (AC: 4–7)
  - [ ] 3.1 Export `DEBIAN_FRONTEND=noninteractive`
  - [ ] 3.2 Run `retry 3 5 sudo apt-get update` with `log_info` before and `log_success` after
  - [ ] 3.3 Build the package list as a bash array or inline in the install command
  - [ ] 3.4 Run `retry 3 5 sudo apt-get install -y <packages>` with all 26 packages
  - [ ] 3.5 Log success after install completes

- [ ] **Task 4 — MariaDB configuration** (AC: 8–12)
  - [ ] 4.1 `sudo systemctl start mariadb && sudo systemctl enable mariadb`
  - [ ] 4.2 Write `/etc/mysql/mariadb.conf.d/99-devbox.cnf` via heredoc + `sudo tee`
  - [ ] 4.3 Implement root password set logic: try without password first; if that fails, verify existing password works; log_warn if already set
  - [ ] 4.4 `sudo systemctl restart mariadb`
  - [ ] 4.5 Verify with `mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SELECT 1" &>/dev/null`
  - [ ] 4.6 `log_success "MariaDB configured and verified"`

- [ ] **Task 5 — Redis verification** (AC: 13–14)
  - [ ] 5.1 `sudo systemctl start redis-server && sudo systemctl enable redis-server`
  - [ ] 5.2 Verify `redis-cli ping | grep -q PONG`
  - [ ] 5.3 `log_success "Redis verified (PONG)"`

- [ ] **Task 6 — Completion marker** (AC: 15–16)
  - [ ] 6.1 Call `set_marker "$PHASE_NUM"` as the last step in the main flow
  - [ ] 6.2 Confirm marker is only set after all verifications succeed

- [ ] **Task 7 — Quality gates** (AC: 17–24)
  - [ ] 7.1 Run `bash -n scripts/install-system.sh` — must exit 0
  - [ ] 7.2 Run `shellcheck scripts/install-system.sh` — must produce no errors
  - [ ] 7.3 On a fresh system: verify all packages listed under AC-2 are installed
  - [ ] 7.4 Verify `systemctl is-active mariadb` → "active"
  - [ ] 7.5 Verify `mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SHOW VARIABLES LIKE 'character_set_server'"` → utf8mb4
  - [ ] 7.6 Verify `redis-cli ping` → `PONG`
  - [ ] 7.7 Verify `command -v wkhtmltopdf` → exits 0
  - [ ] 7.8 Run script a second time and confirm it exits in < 2 seconds

---

## Dev Notes

### Architecture Patterns

- **Script scaffold (from S1.1):** Every phase script follows the exact same pattern established in `bootstrap.sh`:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "${SCRIPT_DIR}/_common.sh"

  PHASE_NUM=1
  trap 'error_handler "${BASH_SOURCE[0]}" "${LINENO}" "$?"' ERR
  ```
  Note: `_common.sh` already has 3 parameters in `error_handler` (SCRIPT LINE EXIT_CODE), so the trap must pass `"${BASH_SOURCE[0]}"` as the first argument — see `scripts/_common.sh` line 138.

- **`check_completed()` pattern (from architecture § 7):** The hybrid idempotency strategy requires checking BOTH the marker file AND live service status. This prevents re-running after a reboot that cleared `/var/tmp/` (marker gone but services up) from erroneously re-installing:
  ```bash
  check_completed() {
      if check_marker "$PHASE_NUM" \
          && systemctl is-active --quiet mariadb \
          && redis-cli ping 2>/dev/null | grep -q "PONG"; then
          log_info "Phase 1 already complete, skipping"
          exit 0
      fi
      # If marker exists but checks failed, clear the stale marker
      if check_marker "$PHASE_NUM"; then
          clear_marker "$PHASE_NUM"
      fi
  }
  ```

- **`retry()` usage (from architecture § 8):** The `retry` function in `_common.sh` takes `COUNT DELAY CMD...`. Use it for apt operations which can fail due to transient mirrors or lock contention:
  ```bash
  retry 3 5 sudo apt-get update
  retry 3 5 sudo apt-get install -y "${PACKAGES[@]}"
  ```

- **MariaDB root password handling:** Ubuntu 24.04's MariaDB 10.11 uses unix_socket auth by default for root. The password set command must use `sudo` to access the socket-authenticated root session, then set a password. For idempotent re-runs where the password is already set, the `sudo` path will succeed silently. Pattern:
  ```bash
  # Try setting via socket auth (fresh install)
  sudo mariadb -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${MARIADB_ROOT_PASSWORD}'); FLUSH PRIVILEGES;" 2>/dev/null \
      || log_warn "root password already set or using alternative auth"
  # Verify the password works
  mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SELECT 1;" &>/dev/null
  ```

- **`wkhtmltopdf` availability note (from PRD risk register):** The `wkhtmltopdf` in Ubuntu 24.04 apt repos is version 0.12.6. If the install fails (package not available), fall back to downloading the .deb directly:
  ```bash
  # Fallback: download from GitHub releases (add only if apt fails)
  # curl -L "https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_amd64.deb" -o /tmp/wkhtmltopdf.deb
  # sudo apt-get install -y /tmp/wkhtmltopdf.deb
  ```
  The primary path should attempt from apt first. Only add the fallback if testing shows the apt package is unavailable.

- **DEBIAN_FRONTEND:** Must be exported (not just set) so child processes (apt subprocess) inherit it:
  ```bash
  export DEBIAN_FRONTEND=noninteractive
  ```

### MariaDB utf8mb4 Config File

The config file goes to `/etc/mysql/mariadb.conf.d/99-devbox.cnf` (99- prefix ensures it's loaded last, overriding defaults). Use `sudo tee` to write as root:

```bash
sudo tee /etc/mysql/mariadb.conf.d/99-devbox.cnf > /dev/null << 'EOF'
[mysqld]
character-set-server  = utf8mb4
collation-server      = utf8mb4_unicode_ci
bind-address          = 127.0.0.1

[client]
default-character-set = utf8mb4
EOF
```

The `bind-address = 127.0.0.1` enforces architecture requirement: MariaDB bound to localhost only (architecture § 8 security).

### Package List (complete)

```bash
PACKAGES=(
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
```

**Note on `libmysqlclient-dev`:** On Ubuntu 24.04, this package may be named `default-libmysqlclient-dev`. If `libmysqlclient-dev` causes apt errors, substitute `default-libmysqlclient-dev`. The package provides `mysqlclient` headers needed by Frappe.

### Logging Conventions (from `_common.sh`)

Use the exact `_common.sh` function signatures (no indentation prefix needed — `_common.sh` adds `  ` indent automatically via printf):

```bash
log_info "Updating apt package index..."
log_success "apt update complete"
log_info "Installing system packages (this may take 60–90 seconds)..."
log_success "All packages installed"
log_info "Configuring MariaDB..."
log_success "MariaDB configured and verified"
log_info "Verifying Redis..."
log_success "Redis verified (PONG)"
```

### Required Environment Variables

This script uses only **one** env var from `.tiberbu-env`:
- `MARIADB_ROOT_PASSWORD` — default `tiberbu123`, applied by `bootstrap.sh` via `load_env_file` before calling this script

The script does NOT call `require_env` for this variable because it has a default. However, if running standalone (not via `bootstrap.sh`), the caller must ensure `MARIADB_ROOT_PASSWORD` is exported. You can add a guard:
```bash
: "${MARIADB_ROOT_PASSWORD:=tiberbu123}"
```
This provides a safe default even in standalone execution.

### Standalone Execution Pattern

The script must work both when called by `bootstrap.sh` (where `_common.sh` is already loaded via bootstrap's own source) AND when called directly (`./scripts/install-system.sh`). The `source "${SCRIPT_DIR}/_common.sh"` at the top handles both cases — re-sourcing is safe since `_common.sh` only defines functions and constants.

### ShellCheck Notes

- Use `# shellcheck source=scripts/_common.sh` directive above the `source` line to suppress SC1091
- Avoid `sudo` inside arrays — use string expansion instead
- Quote all variable references: `"${MARIADB_ROOT_PASSWORD}"` not `$MARIADB_ROOT_PASSWORD`
- The `retry` function receives the command as arguments, so: `retry 3 5 sudo apt-get install -y "${PACKAGES[@]}"` is valid

### Project Structure Notes

**Files to Create:**
```
devbox/
└── scripts/
    ├── _common.sh        ← Already exists (from S1.1)
    └── install-system.sh ← CREATE THIS (Phase 1 installer)
```

**This story does NOT create:**
- `scripts/install-node.sh` (S1.3 story)
- `scripts/install-bench.sh` (S2.3 story)
- `scripts/install-openclaw.sh` (S2.1 story)
- `scripts/install-studio.sh` (S2.2 story)
- `scripts/verify.sh` (S4.1 story)

**Pre-existing dependencies:**
- `scripts/_common.sh` — MUST exist before this script runs (created in S1.1 / task #15)
- Verify it exists: `ls scripts/_common.sh`

### Performance Target

From architecture § 10: Phase 1 target is **< 90 seconds** on t3.xlarge. The bottleneck is apt package download. The script should NOT add unnecessary sleeps or delays beyond the `retry` backoff.

### Security Notes (architecture § 8)

- `MARIADB_ROOT_PASSWORD` value must NEVER be logged. Only log that it was set, not what it is.
- MariaDB must be bound to 127.0.0.1 (enforced via `bind-address = 127.0.0.1` in the cnf file)
- Redis binds to localhost by default in Ubuntu's redis package — no additional config needed

### Verification Commands (from PRD testing table)

Run these to confirm DoD criteria met:
```bash
# AC-3: MariaDB active
systemctl is-active mariadb

# AC-3: MariaDB connection works
mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SELECT 1;"

# AC-3: utf8mb4 charset
mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SHOW VARIABLES LIKE 'character_set_server';"
# Expected: utf8mb4

# AC-4: Redis PONG
redis-cli ping
# Expected: PONG

# AC-2: wkhtmltopdf available
command -v wkhtmltopdf && wkhtmltopdf --version

# AC-1: Idempotency (second run < 2s)
time bash scripts/install-system.sh
# Expected: "Phase 1 already complete, skipping" in < 2 seconds
```

### References

- Architecture § 3.1 — Phase 1 dependencies [Source: _bmad-output/planning-artifacts/architecture.md#31-installation-order-phase-dependencies]
- Architecture § 4.1 — Repository Structure [Source: _bmad-output/planning-artifacts/architecture.md#41-repository-structure]
- Architecture § 4.2 — Installed Paths [Source: _bmad-output/planning-artifacts/architecture.md#42-installed-paths-on-target-ec2]
- Architecture § 5 — `_common.sh` API Surface [Source: _bmad-output/planning-artifacts/architecture.md#5-shared-utility-library]
- Architecture § 7 — Idempotency Strategy [Source: _bmad-output/planning-artifacts/architecture.md#7-idempotency-strategy]
- Architecture § 8 — Error Handling & Security [Source: _bmad-output/planning-artifacts/architecture.md#8-error-handling--security]
- Architecture § 9 — Technology Versions [Source: _bmad-output/planning-artifacts/architecture.md#9-technology-versions]
- Architecture § 10 — Performance Budget [Source: _bmad-output/planning-artifacts/architecture.md#10-performance-budget]
- Architecture ADR-3 — Hybrid Idempotency [Source: _bmad-output/planning-artifacts/architecture.md#adr-3-hybrid-idempotency--marker-files--service-checks]
- Architecture ADR-5 — Error Handling [Source: _bmad-output/planning-artifacts/architecture.md#adr-5-error-handling--fail-fast-with-context]
- PRD FR-3 — Phase 1 System Dependencies [Source: _bmad-output/planning-artifacts/prd.md#fr-3-phase-1--system-dependencies]
- PRD FR-11 — Idempotent Re-Run [Source: _bmad-output/planning-artifacts/prd.md#fr-11-idempotent-re-run]
- PRD NFR-1 — Performance (< 90s) [Source: _bmad-output/planning-artifacts/prd.md#nfr-1-performance]
- PRD NFR-2 — Reliability / Retries [Source: _bmad-output/planning-artifacts/prd.md#nfr-2-reliability]
- PRD NFR-4 — Security [Source: _bmad-output/planning-artifacts/prd.md#nfr-4-security]
- PRD Appendix B — Port Allocation [Source: _bmad-output/planning-artifacts/prd.md#appendix-b-port-allocation]
- PRD Risk Register — wkhtmltopdf fallback [Source: _bmad-output/planning-artifacts/prd.md#risk-register]
- Existing _common.sh — error_handler signature (3 args: SCRIPT LINE EXIT_CODE) [Source: scripts/_common.sh#138]

---

## Dev Agent Record

### Agent Model Used

_to be filled by dev agent_

### Debug Log References

_to be filled by dev agent_

### Completion Notes List

_to be filled by dev agent_

### File List

- `scripts/install-system.sh`
