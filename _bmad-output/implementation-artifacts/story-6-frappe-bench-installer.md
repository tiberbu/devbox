# Story 6: Frappe Bench Installer

**Story ID:** S6
**Epic:** E2 — Application Stack
**Points:** 5
**Estimated Hours:** 2
**Priority:** P1 — Phase 3 of bootstrap (longest-running phase)
**Dependencies:** S1 (_common.sh), S2 (MariaDB + Redis running), S3 (Node.js for bench assets)

---

## Description

Create `scripts/install-bench.sh` — the Phase 3 installer that installs the Frappe Bench CLI via pip, initializes a bench directory with Frappe framework (version-15), creates a development site with MariaDB, and configures bench for development mode. This is the longest-running phase (~4 minutes) due to `bench init`.

---

## Acceptance Criteria

### AC-1: Idempotency check
- [ ] Checks marker file `.phase-3-complete` AND `bench --version 2>/dev/null` AND `[[ -d ~/frappe-bench/sites/${BENCH_SITE} ]]`
- [ ] If all pass: logs "Phase 3 already complete, skipping" and exits 0
- [ ] If marker exists but checks fail: clears marker and re-runs

### AC-2: Frappe Bench CLI installation
- [ ] Sources nvm to get node/npm on PATH (required for bench assets build)
- [ ] Installs frappe-bench: `pip3 install frappe-bench` (uses system pip; bench manages its own venv internally)
- [ ] Verifies: `bench --version` returns `5.x.x`

### AC-3: Bench initialization
- [ ] Runs: `bench init ~/frappe-bench --frappe-branch ${FRAPPE_BRANCH}` (default: version-15)
- [ ] This creates the bench directory with:
  - `apps/frappe/` — Frappe framework source
  - `env/` — Python virtual environment
  - `sites/` — Sites directory
  - `Procfile` — Process definitions
- [ ] Logs progress ("This may take 3-5 minutes...")
- [ ] Only frappe app installed (no ERPNext, healthcare, etc.)

### AC-4: Site creation
- [ ] Creates site: `bench new-site ${BENCH_SITE} --mariadb-root-password ${MARIADB_ROOT_PASSWORD} --admin-password ${MARIADB_ROOT_PASSWORD}`
- [ ] Default site name: `dev.local` (from `$BENCH_SITE`)
- [ ] Adds `${BENCH_SITE}` to `/etc/hosts` mapping to `127.0.0.1` if not already present
- [ ] Sets as default site: `bench use ${BENCH_SITE}`

### AC-5: Development mode configuration
- [ ] Enables developer mode: `bench set-config developer_mode 1`
- [ ] Enables dev mode: `bench set-config dev_server 1` (optional, for hot-reload)
- [ ] Sets `serve_default_site 1` in common_site_config.json

### AC-6: Verification
- [ ] Directory `~/frappe-bench/sites/${BENCH_SITE}` exists
- [ ] `cd ~/frappe-bench && bench --site ${BENCH_SITE} list-apps` shows `frappe`
- [ ] Sets marker file `.phase-3-complete`

---

## Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `scripts/install-bench.sh` | Create | Phase 3 installer |

---

## Technical Notes

- `bench init` is the primary bottleneck (~4 minutes) — it clones frappe, sets up a Python venv, runs pip install, and builds node assets
- `bench init` requires: git, python3, pip, node, yarn, MariaDB, Redis — all from Phases 1 & 2
- The bench commands must be run from within `~/frappe-bench` directory
- `bench new-site` connects to MariaDB to create the database — requires MariaDB root password
- The `/etc/hosts` entry for the site name avoids DNS resolution delays (domain research noted 10s+ delay)
- Frappe bench runs in development mode (not production) — suitable for a dev environment
- Do NOT install ERPNext or any other apps — the PRD specifies "frappe only"
- pip install should use `--break-system-packages` flag on Ubuntu 24.04 if not using a venv externally, OR use `pipx` for bench CLI

---

## Definition of Done

- [ ] `bash -n scripts/install-bench.sh` passes
- [ ] On provisioned instance (after Phases 1-2): script installs bench, initializes, and creates site without error
- [ ] `bench --version` returns `5.x.x`
- [ ] `~/frappe-bench/apps/frappe/` exists
- [ ] `~/frappe-bench/sites/${BENCH_SITE}/` exists
- [ ] `cd ~/frappe-bench && bench --site ${BENCH_SITE} list-apps` shows only `frappe`
- [ ] `/etc/hosts` contains entry for `${BENCH_SITE}`
- [ ] Second run skips (exits 0 in < 2 seconds)
- [ ] Total time under 5 minutes on t3.xlarge
- [ ] ShellCheck passes with no errors
