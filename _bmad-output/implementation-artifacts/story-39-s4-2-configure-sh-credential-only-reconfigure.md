# Story: S4.2: configure.sh Credential-Only Reconfigure

Status: done
Task ID: mo3anoqqf8k38o
Task Number: #39
Workflow: dev-story
Model: sonnet
Created: 2026-04-17T19:21:26.523Z

## Description

## Story S9 — configure.sh (Credential-Only Reconfigure)
**Epic:** E4 — Verification & Polish | **Points:** 3 | **Priority:** P2

### Acceptance Criteria

#### AC-1: Environment loading and validation
- [ ] Reads ~/.tiberbu-env via shared load_env_file() from _common.sh
- [ ] Validates 8 required credentials via validate_credentials()
- [ ] Applies defaults for optional vars
- [ ] Exits 1 if env file missing or credentials incomplete

#### AC-2: Template re-rendering
- [ ] Re-renders ~/.openclaw/openclaw.json from templates/openclaw.json.template
- [ ] Re-renders ~/.config/systemd/user/openclaw-gateway.service
- [ ] Re-renders /etc/systemd/system/claude-studio.service (via sudo)
- [ ] Re-renders ~/claude-code-studio/config.json
- [ ] chmod 600 on openclaw.json and git-credentials

#### AC-3: Git credential update
- [ ] Updates ~/.git-credentials with new GITHUB_TOKEN
- [ ] chmod 600
- [ ] Verifies git ls-remote (|| log_warn for graceful failure)

#### AC-4: Service restarts
- [ ] systemctl --user daemon-reload + restart openclaw-gateway
- [ ] sudo systemctl daemon-reload + restart claude-studio
- [ ] Wait for stabilization (up to 10s each)
- [ ] Does NOT restart MariaDB, Redis, or touch Frappe Bench

#### AC-5: Verification
- [ ] openclaw-gateway active, claude-studio active
- [ ] Ports 18789 and 3000 listening
- [ ] Discord notification confirming reconfigure complete

#### AC-6: Performance
- [ ] Total time < 60 seconds

#### AC-7: Safety
- [ ] NO package installs, NO bench init, NO npm install/build
- [ ] Only touches: config files, systemd units, git creds, service restarts

### Files to Create
- configure.sh

### Definition of Done
- bash -n + ShellCheck clean
- Completes in < 60 seconds on provisioned instance
- All configs re-rendered with new credentials
- Services restarted and active
- Discord notification received

Story file created by task #13. Read the story from _bmad-output/implementation-artifacts/ and implement all acceptance criteria.

## Acceptance Criteria

- [ ] #### AC-1: Environment loading and validation
- [ ] [ ] Reads ~/.tiberbu-env via shared load_env_file() from _common.sh
- [ ] [ ] Validates 8 required credentials via validate_credentials()
- [ ] [ ] Applies defaults for optional vars
- [ ] [ ] Exits 1 if env file missing or credentials incomplete

## Tasks / Subtasks

- [x] Implement changes
- [x] Verify build passes

## Dev Notes



### References

- Task source: Claude Code Studio task #39

## Dev Agent Record

### Agent Model Used

sonnet

### Completion Notes List

- Implemented `configure.sh` (481 lines) with 5 structured steps matching all 7 ACs.
- Moved `load_env_file()`, `validate_credentials()`, and `REQUIRED_VARS` from `bootstrap.sh` into `scripts/_common.sh` so both scripts share the same implementation.
- `bootstrap.sh` updated to remove duplicated definitions and pass `${ENV_FILE}` explicitly to the shared functions.
- All three files pass `bash -n` syntax check and `shellcheck` (version 0.9.0) with zero warnings.
- `configure.sh` is designed to complete in well under 60 seconds: only re-renders 4 config files, updates git credentials, restarts 2 services, and sends one Discord notification.
- Safety: no package installs, no npm/bench operations, no MariaDB/Redis touches.

### Change Log

- `scripts/_common.sh`: Added `REQUIRED_VARS` array, `load_env_file()`, and `validate_credentials()` shared functions at end of file.
- `bootstrap.sh`: Removed the now-duplicate `REQUIRED_VARS`, `load_env_file()`, and `validate_credentials()` definitions; updated calls in `main()` to pass `"${ENV_FILE}"` explicitly.
- `configure.sh`: New file — credential-only reconfigure script implementing ACs 1–7.

### File List

- `configure.sh` — **CREATED** — credential-only reconfigure script
- `scripts/_common.sh` — **MODIFIED** — added REQUIRED_VARS, load_env_file(), validate_credentials()
- `bootstrap.sh` — **MODIFIED** — removed duplicated functions, updated calls to use shared versions
