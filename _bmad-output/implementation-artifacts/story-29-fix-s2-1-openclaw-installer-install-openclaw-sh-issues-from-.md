# Story: Fix: S2.1: OpenClaw Installer (install-openclaw.sh) — issues from QA

Status: done
Task ID: mo399vdd6h62by
Task Number: #29
Workflow: quick-dev
Model: sonnet
Created: 2026-04-17T18:42:42.329Z

## Description

## Auto-generated Fix Task (from QA task #26)

### Source
QA Report: `docs/qa-report-task-26.md`
Read the QA report FIRST for full context on what failed and needs fixing.

### QA Findings Summary
ng the testing info and checking git status, then read the story file.Good - the install-openclaw.sh script is committed (commit `3cd7ae6`). The untracked files (`_bmad-output/`, `docs/`, `test-screenshots/`) are not from this feature. The modified `scripts/install-node.sh` is also not part of this task. Let me read the script and the QA story file.Let me examine the script's dependencies and look at how prior QA reports handled similar script-based tasks.Now let me run static analysis and examine the template files.Let me check a critical detail about the service template and the node version path.This is a critical finding. The service template uses `v24` as a path component, but nvm doesn't create that shortcut - only full version directories like `v24.14.1` or `v24.15.0` exist. Let me verify further and check if install-node.sh creates a symlink.Let me check the runtime state and then perform detailed testing.Interesting - port 18789 is listening but systemctl can't connect to the user bus, and the phase-4 marker doesn't exist. Let me investigate more.Now let me verify a few more details about the placeholder check and then run the Playwright-based test report.Now let me create the Playwright test scripts and generate screenshots. I'll create an HTML test report and screenshot it with Playwright.Screenshots captured successfully. Now let me write the QA report.Now let me update the story file with completion notes.Now let me run the post-task verification.

## Verification```
VERIFICATION:
✅ [QA report created]: docs/qa-report-task-25.md (11,464 bytes)
✅ [Screenshots captured]: 3 focused screenshots in test-screenshots/task-25-*.png
✅ [All 6 ACs covered]: Each AC has PASS/FAIL with evidence
✅ [P0 bug documented]: Service template v24 path issue clearly labeled with fix instructions
✅ [P2 issue documented]: Placeholder check ineffectiveness noted
✅ [Static analysis run]: bash -n and shellcheck both pass clean
✅ [Pre-check passed]: Code committed in 3cd7ae6
✅ [Playwright used]: Generated HTML report, screenshotted with chromium
✅ [Story file updated]: Status set to done with completion notes
🌐 [browser test]: 3 Playwright screenshots verify test results, P0 bug detail, and AC summary
FINAL: ✅ All requirements verified
```

---

**QA Summary:** Task #25 (install-openclaw.sh) has **1 P0 bug** and **1 P2 issue**:

- **P0:** `templates/openclaw-gateway.service` hardcodes `v24` in ExecStart and PATH, but nvm only creates full semver directories (`v24.14.1`, `v24.15.0`). The rendered path `/home/ubuntu/.nvm/versions/node/v24/bin/openclaw` does not exist. The systemd service will fail to start, blocking AC-5 and AC-6.

- **P2:** The `render_config()` placeholder check (`grep '\${'`) is ineffective because `envsubst` replaces unset vars with empty strings, not leaving `${VAR}` patterns. Missing env vars silently produce empty values.

AC-1 through AC-4 pass. The script code itself is well-structured; the P0 is in the service template's hardcoded path.

### Instructions
1. Read the QA report at `docs/qa-report-task-26.md`
2. Fix ALL P0 and P1 issues identified
3. Verify each fix with the verification commands from the report
4. Ensure the build still passes
5. Do NOT start a Vite dev server

### Done Checklist
- [ ] All P0 issues fixed
- [ ] All P1 issues fixed
- [ ] App builds without errors
- [ ] No console errors on affected pages
- [ ] git diff shows only expected files

## Acceptance Criteria

- [x] Read the QA report at `docs/qa-report-task-25.md` (report existed at task-25, not task-26)
- [x] Fix ALL P0 and P1 issues identified
- [x] Verify each fix with the verification commands from the report
- [x] Ensure the build still passes (bash -n + shellcheck clean)
- [x] Do NOT start a Vite dev server

## Tasks / Subtasks

- [x] Read the QA report at `docs/qa-report-task-25.md`
- [x] Fix ALL P0 and P1 issues identified
- [x] Verify each fix with the verification commands from the report
- [x] Ensure the build still passes
- [x] Do NOT start a Vite dev server

## Dev Notes



### References

- Task source: Claude Code Studio task #29

## Dev Agent Record

### Agent Model Used

sonnet

### Completion Notes List

- **P0 Fixed**: `templates/openclaw-gateway.service` now uses `${NODE_BIN_DIR}` in both `ExecStart` and `PATH` lines instead of the hardcoded bare `v24` path that doesn't exist in nvm.
- **P0 Fixed**: `scripts/install-openclaw.sh` `install_service()` now resolves `NODE_BIN_DIR` via `dirname "$(command -v node)"` (after `source_nvm()` has run) and exports it before calling `render_template`, yielding paths like `/home/ubuntu/.nvm/versions/node/v24.15.0/bin`.
- **P2 Fixed**: `render_config()` placeholder check replaced with explicit env var presence validation (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `DISCORD_BOT_TOKEN`). The old `grep '\${'` was ineffective since `envsubst` always replaces vars (even with empty strings).
- Static analysis clean: `bash -n` and `shellcheck --severity=style` both pass with zero warnings.

### Change Log

- `templates/openclaw-gateway.service`: Replaced `${HOME}/.nvm/versions/node/v24/bin` with `${NODE_BIN_DIR}` in `ExecStart` (line 7) and `Environment=PATH` (line 15). Fixes P0.
- `scripts/install-openclaw.sh`: In `install_service()`, added `NODE_BIN_DIR` resolution (`dirname "$(command -v node)"`) and export before `render_template` call. Fixes P0.
- `scripts/install-openclaw.sh`: In `render_config()`, replaced ineffective `grep '\${'` placeholder check with explicit required-env-var presence validation loop. Fixes P2.

### File List

**Modified:**
- `scripts/install-openclaw.sh` — Added `NODE_BIN_DIR` resolution in `install_service()`; replaced placeholder check in `render_config()`
- `templates/openclaw-gateway.service` — Replaced hardcoded `v24` nvm path with `${NODE_BIN_DIR}` variable
