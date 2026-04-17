# Story: S2.3: Frappe Bench Installer (install-bench.sh)

Status: done
Task ID: mo39dc8eidr9fl
Task Number: #30
Workflow: dev-story
Model: sonnet
Created: 2026-04-17T18:45:24.135Z

## Description

## Story S6 — Frappe Bench Installer
**Epic:** E2 — Application Stack | **Points:** 5 | **Priority:** P1

### Acceptance Criteria

#### AC-1: Idempotency check
- [ ] Checks marker .phase-3-complete AND bench --version AND ~/frappe-bench/sites/${BENCH_SITE} exists
- [ ] If all pass: skip. If marker but checks fail: clear + re-run

#### AC-2: Bench CLI installation
- [ ] Source nvm for node
- [ ] pip3 install frappe-bench (use --break-system-packages on Ubuntu 24.04 if needed)
- [ ] Verify bench --version returns 5.x.x

#### AC-3: Bench initialization
- [ ] bench init ~/frappe-bench --frappe-branch ${FRAPPE_BRANCH} (default: version-15)
- [ ] Creates apps/frappe/, env/, sites/, Procfile
- [ ] Log progress (3-5 min expected)
- [ ] Only frappe app, NO ERPNext

#### AC-4: Site creation
- [ ] bench new-site ${BENCH_SITE} --mariadb-root-password ${MARIADB_ROOT_PASSWORD} --admin-password ${MARIADB_ROOT_PASSWORD}
- [ ] Default site: dev.local
- [ ] Add ${BENCH_SITE} to /etc/hosts -> 127.0.0.1 (if not present)
- [ ] bench use ${BENCH_SITE}

#### AC-5: Development mode
- [ ] bench set-config developer_mode 1
- [ ] bench set-config dev_server 1
- [ ] serve_default_site 1 in common_site_config.json

#### AC-6: Verification
- [ ] ~/frappe-bench/sites/${BENCH_SITE} exists
- [ ] bench --site ${BENCH_SITE} list-apps shows frappe
- [ ] Set marker .phase-3-complete

### Files to Create
- scripts/install-bench.sh

### Definition of Done
- bash -n + ShellCheck clean
- bench 5.x.x installed, site created with frappe app
- /etc/hosts has ${BENCH_SITE} entry
- Total time < 5 min on t3.xlarge
- Second run skips in < 2 seconds

Story file created by task #11. Read the story from _bmad-output/implementation-artifacts/ and implement all acceptance criteria.

## Acceptance Criteria

- [x] #### AC-1: Idempotency check
- [x] Checks marker .phase-3-complete AND bench --version AND ~/frappe-bench/sites/${BENCH_SITE} exists
- [x] If all pass: skip. If marker but checks fail: clear + re-run
- [x] #### AC-2: Bench CLI installation
- [x] Source nvm for node
- [x] pip3 install frappe-bench (use --break-system-packages on Ubuntu 24.04 if needed)
- [x] Verify bench --version returns 5.x.x
- [x] #### AC-3: Bench initialization
- [x] bench init ~/frappe-bench --frappe-branch ${FRAPPE_BRANCH} (default: version-15)
- [x] Creates apps/frappe/, env/, sites/, Procfile
- [x] Log progress (3-5 min expected)
- [x] Only frappe app, NO ERPNext
- [x] #### AC-4: Site creation
- [x] bench new-site ${BENCH_SITE} --mariadb-root-password ... --admin-password ...
- [x] Default site: dev.local
- [x] Add ${BENCH_SITE} to /etc/hosts -> 127.0.0.1 (if not present)
- [x] bench use ${BENCH_SITE}
- [x] #### AC-5: Development mode
- [x] bench set-config developer_mode 1
- [x] bench set-config dev_server 1
- [x] serve_default_site 1 in common_site_config.json
- [x] #### AC-6: Verification
- [x] ~/frappe-bench/sites/${BENCH_SITE} exists
- [x] bench --site ${BENCH_SITE} list-apps shows frappe
- [x] Set marker .phase-3-complete

## Tasks / Subtasks

- [x] Implement changes
- [x] Verify build passes (bash -n + ShellCheck clean)

## Dev Notes



### References

- Task source: Claude Code Studio task #30

## Dev Agent Record

### Agent Model Used

sonnet

### Completion Notes List

- Implemented `scripts/install-bench.sh` (Phase 3: Frappe Bench) following the same
  patterns as install-node.sh, install-system.sh, install-openclaw.sh, and install-studio.sh.
- All 6 acceptance criteria implemented: idempotency check, bench CLI install, bench init,
  site creation, dev mode config, and verification.
- Script is bash -n clean and ShellCheck 0.9.0 clean (zero warnings).
- Defaults: FRAPPE_BRANCH=version-15, BENCH_SITE=dev.local, MARIADB_ROOT_PASSWORD=tiberbu123.
- Uses --break-system-packages fallback for Ubuntu 24.04 pip3 install.
- Uses `bench set-config -g` for all three dev mode settings to write to common_site_config.json.
- Idempotency second run: exits in <2 seconds via check_idempotency() + exit 0.

### Change Log

- 2026-04-17: Created scripts/install-bench.sh — full implementation of S2.3 (all 6 ACs)

### File List

- scripts/install-bench.sh (created)
