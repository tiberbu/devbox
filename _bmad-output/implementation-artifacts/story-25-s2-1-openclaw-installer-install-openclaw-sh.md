# Story: S2.1: OpenClaw Installer (install-openclaw.sh)

Status: done
Task ID: mo38xvcau5z1rx
Task Number: #25
Workflow: dev-story
Model: sonnet
Created: 2026-04-17T18:33:22.404Z

## Description

## Story S4 — OpenClaw Installer
**Epic:** E2 — Application Stack | **Points:** 3 | **Priority:** P1

### Acceptance Criteria

#### AC-1: Idempotency check
- [ ] Checks marker .phase-4-complete AND systemctl --user is-active openclaw-gateway
- [ ] If both pass: skip. If marker but no service: clear + re-run

#### AC-2: OpenClaw npm installation
- [ ] Source nvm, npm install -g openclaw with retry (3 attempts)
- [ ] Verify openclaw --version

#### AC-3: Configuration rendering
- [ ] Create ~/.openclaw/ directory
- [ ] render_template templates/openclaw.json.template -> ~/.openclaw/openclaw.json
- [ ] chmod 600 ~/.openclaw/openclaw.json

#### AC-4: Workspace setup
- [ ] Create ~/.openclaw/workspace/
- [ ] Copy workspace/{AGENTS,SOUL,TOOLS,USER}.md (only if not already present)

#### AC-5: Systemd user service
- [ ] Create ~/.config/systemd/user/
- [ ] render_template templates/openclaw-gateway.service
- [ ] loginctl enable-linger $USER
- [ ] systemctl --user daemon-reload, enable, start
- [ ] Wait up to 10s for stabilization

#### AC-6: Verification
- [ ] systemctl --user is-active openclaw-gateway returns active
- [ ] Port ${OPENCLAW_PORT} is listening
- [ ] Set marker .phase-4-complete

### Files to Create
- scripts/install-openclaw.sh

### Definition of Done
- bash -n + ShellCheck clean
- openclaw --version works, config at ~/.openclaw/openclaw.json with mode 600
- Workspace files present, gateway active on port 18789
- Second run skips in < 2 seconds

Story file created by task #9. Read the story from _bmad-output/implementation-artifacts/ and implement all acceptance criteria.

## Acceptance Criteria

- [ ] #### AC-1: Idempotency check
- [ ] [ ] Checks marker .phase-4-complete AND systemctl --user is-active openclaw-gateway
- [ ] [ ] If both pass: skip. If marker but no service: clear + re-run

## Tasks / Subtasks

- [ ] Implement changes
- [ ] Verify build passes

## Dev Notes



### References

- Task source: Claude Code Studio task #25

## Dev Agent Record

### Agent Model Used

sonnet

### Completion Notes List

- Implemented `scripts/install-openclaw.sh` as Phase 4 installer following the established pattern from `install-node.sh` and `install-system.sh`.
- All 6 acceptance criteria implemented: idempotency check (AC-1), npm install with retry (AC-2), config rendering to `~/.openclaw/openclaw.json` with mode 600 and placeholder verification (AC-3), workspace file copy-if-missing (AC-4), systemd user service with linger + daemon-reload + enable + start + 10s stabilization wait (AC-5), service active + port listening verification + marker set (AC-6).
- `bash -n` syntax check: PASS. ShellCheck 0.9.0: PASS (no errors).
- Three ShellCheck issues fixed: SC2155 (separate declare/assign for XDG_RUNTIME_DIR), SC2016 (added disable comments for intentional single-quoted grep patterns).
- Script exports `XDG_RUNTIME_DIR` before any `systemctl --user` call for compatibility with non-interactive sessions on Ubuntu 24.04.

### Change Log

- 2026-04-17: Created `scripts/install-openclaw.sh` — Phase 4 OpenClaw + Discord gateway installer.

### File List

- `scripts/install-openclaw.sh` (created)
