# Story: S4.1: Verification and Smoke Test (verify.sh)

Status: in-progress
Task ID: mo3a7hdjixujw5
Task Number: #37
Workflow: dev-story
Model: sonnet
Created: 2026-04-17T19:08:50.479Z

## Description

## Story S8 — Verification and Smoke Test
**Epic:** E4 — Verification & Polish | **Points:** 5 | **Priority:** P1

### Acceptance Criteria

#### AC-1: 16-point health check suite
- [ ] Check 1: MariaDB running (systemctl is-active mariadb)
- [ ] Check 2: MariaDB connection (SELECT 1 with root password)
- [ ] Check 3: MariaDB charset (character_set_server = utf8mb4)
- [ ] Check 4: Redis running (systemctl is-active redis-server)
- [ ] Check 5: Redis PING (redis-cli ping = PONG)
- [ ] Check 6: Node.js version (v24.x.x)
- [ ] Check 7: yarn version (1.22.x)
- [ ] Check 8: Bench CLI (bench --version = 5.x.x)
- [ ] Check 9: Bench site (list-apps shows frappe)
- [ ] Check 10: OpenClaw version
- [ ] Check 11: OpenClaw gateway active (systemctl --user)
- [ ] Check 12: OpenClaw port listening (curl/ss)
- [ ] Check 13: Claude Studio service active
- [ ] Check 14: Claude Studio port (HTTP 200)
- [ ] Check 15: Git auth (git ls-remote tiberbu/devbox)
- [ ] Check 16: Discord notification sent
- [ ] Each check logs PASS/FAIL, tracks count

#### AC-2: Summary table
- [ ] Formatted table with Component, Status, Detail columns
- [ ] Color-coded PASS (green) / FAIL (red)
- [ ] Summary line: N/16 passed

#### AC-3: Discord notification
- [ ] POST to Discord API channels/${DISCORD_CHANNEL_ID}/messages
- [ ] Auth: Bot ${DISCORD_BOT_TOKEN}
- [ ] Embed with hostname, service count, URLs, timestamp
- [ ] Failure does NOT fail script (|| true)

#### AC-4: Exit code
- [ ] Exit 0 if all 16 pass (Discord best-effort)
- [ ] Exit 1 if any critical check fails

#### AC-5: Standalone execution
- [ ] Can run as ./scripts/verify.sh
- [ ] Sources _common.sh, reads env
- [ ] Supports --phase N for single-phase verification

### Files to Create
- scripts/verify.sh

### Definition of Done
- bash -n + ShellCheck clean
- All 16 checks pass on fully provisioned instance
- Summary table printed, Discord notification received
- Exit 0 on success, exit 1 on failure

Story file created by task #12. Read the stor

## Acceptance Criteria

- [ ] #### AC-1: 16-point health check suite
- [ ] [ ] Check 1: MariaDB running (systemctl is-active mariadb)
- [ ] [ ] Check 2: MariaDB connection (SELECT 1 with root password)
- [ ] [ ] Check 3: MariaDB charset (character_set_server = utf8mb4)
- [ ] [ ] Check 4: Redis running (systemctl is-active redis-server)
- [ ] [ ] Check 5: Redis PING (redis-cli ping = PONG)
- [ ] [ ] Check 6: Node.js version (v24.x.x)
- [ ] [ ] Check 7: yarn version (1.22.x)
- [ ] [ ] Check 8: Bench CLI (bench --version = 5.x.x)
- [ ] [ ] Check 9: Bench site (list-apps shows frappe)
- [ ] [ ] Check 10: OpenClaw version
- [ ] [ ] Check 11: OpenClaw gateway active (systemctl --user)
- [ ] [ ] Check 12: OpenClaw port listening (curl/ss)
- [ ] [ ] Check 13: Claude Studio service active
- [ ] [ ] Check 14: Claude Studio port (HTTP 200)
- [ ] [ ] Check 15: Git auth (git ls-remote tiberbu/devbox)
- [ ] [ ] Check 16: Discord notification sent
- [ ] [ ] Each check logs PASS/FAIL, tracks count

## Tasks / Subtasks

- [ ] Implement changes
- [ ] Verify build passes

## Dev Notes



### References

- Task source: Claude Code Studio task #37

## Dev Agent Record

### Agent Model Used

sonnet

### Completion Notes List

_(Updated by agent on completion)_

### Change Log

_(Updated by agent during implementation)_

### File List

_(Updated by agent — list all files created or modified)_
