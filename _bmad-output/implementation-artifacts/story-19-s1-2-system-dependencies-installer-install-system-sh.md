# Story: S1.2: System Dependencies Installer (install-system.sh)

Status: done
Task ID: mo38531e16iqu5
Task Number: #19
Workflow: dev-story
Model: sonnet
Created: 2026-04-17T18:10:59.300Z

## Description

## Story S2 — System Dependencies Installer
**Epic:** E1 — Bootstrap Core Framework | **Points:** 5 | **Priority:** P0

### Acceptance Criteria

#### AC-1: Idempotency check
- [ ] Checks marker .phase-1-complete AND systemctl is-active mariadb AND redis-cli ping returns PONG
- [ ] If all pass: logs skip and exits 0
- [ ] If marker exists but service fails: clears marker and re-runs

#### AC-2: apt package installation
- [ ] DEBIAN_FRONTEND=noninteractive apt-get update + apt-get install -y
- [ ] Packages: build-essential, python3, python3-dev, python3-pip, python3-venv, python3-setuptools, git, curl, wget, jq, gettext-base, libffi-dev, libssl-dev, libjpeg-dev, libpng-dev, libxml2-dev, libxslt1-dev, libmysqlclient-dev, redis-server, redis-tools, mariadb-server, mariadb-client, wkhtmltopdf, xvfb, xfonts-base, xfonts-scalable, supervisor
- [ ] Retry logic (3 attempts) for apt-get

#### AC-3: MariaDB configuration
- [ ] Start and enable mariadb
- [ ] Create /etc/mysql/mariadb.conf.d/99-devbox.cnf: utf8mb4 charset + collation
- [ ] Set root password from $MARIADB_ROOT_PASSWORD
- [ ] Restart MariaDB, verify connection

#### AC-4: Redis verification
- [ ] Start and enable redis-server
- [ ] Verify redis-cli ping returns PONG

#### AC-5: Completion
- [ ] Set marker .phase-1-complete

### Files to Create
- scripts/install-system.sh

### Definition of Done
- bash -n passes, ShellCheck clean
- All packages installed, MariaDB active with utf8mb4, Redis active with PONG
- Second run skips in < 2 seconds

Story file created by task #7. Read the story from _bmad-output/implementation-artifacts/ and implement all acceptance criteria.

## Acceptance Criteria

- [x] #### AC-1: Idempotency check
- [x] Checks marker .phase-1-complete AND systemctl is-active mariadb AND redis-cli ping returns PONG
- [x] If all pass: logs skip and exits 0
- [x] If marker exists but service fails: clears marker and re-runs

## Tasks / Subtasks

- [x] Implement changes
- [x] Verify build passes

## Dev Notes



### References

- Task source: Claude Code Studio task #19

## Dev Agent Record

### Agent Model Used

sonnet

### Completion Notes List

- Implemented `scripts/install-system.sh` with all 5 acceptance criteria.
- AC-1 (Idempotency): checks `.phase-1-complete` marker + `systemctl is-active mariadb` + `redis-cli ping PONG`; exits 0 if all pass; clears marker and re-runs if services are down.
- AC-2 (apt): `DEBIAN_FRONTEND=noninteractive` apt-get update + install of all 26 packages; wrapped in `retry 3 10` from `_common.sh`.
- AC-3 (MariaDB): start+enable, write `/etc/mysql/mariadb.conf.d/99-devbox.cnf` (utf8mb4), idempotent root password via `ALTER USER`, restart, verify connection.
- AC-4 (Redis): start+enable, verify `redis-cli ping` returns `PONG`.
- AC-5 (Marker): `set_marker 1` creates `.phase-1-complete`.
- `bash -n` passes; ShellCheck 0.9.0 reports zero warnings.

### Change Log

- 2026-04-17: Created `scripts/install-system.sh` — implements Phase 1 (System Dependencies) with idempotency, apt install, MariaDB utf8mb4 config, Redis verification, and completion marker.

### File List

- `scripts/install-system.sh` — created (Phase 1 installer)
