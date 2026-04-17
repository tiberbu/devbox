# Story: Fix: S1.3: Node.js Installer (install-node.sh) — issues from QA

Status: done
Task ID: mo38qlibbngcqf
Task Number: #24
Workflow: quick-dev
Model: sonnet
Created: 2026-04-17T18:27:43.070Z

## Description

## Auto-generated Fix Task (from QA task #23)

### Source
QA Report: `docs/qa-report-task-23.md`
Read the QA report FIRST for full context on what failed and needs fixing.

### QA Findings Summary
Paths are correct under `~/.nvm/versions/node/v24.x.x/bin/`

Now let me also check another potential issue - the AC-4 checks that yarn version is 1.22.x, but the script only checks if `yarn --version` is non-empty (doesn't verify the 1.22.x part).The yarn version check is lenient (only checks non-empty, not `1.22.x`) - this is a minor concern (P3) since `npm install -g yarn` will always install 1.22.x (classic yarn).

Now let me also check the idempotency logic and test the second run, and verify the .bashrc sourcing.Good, .bashrc is properly configured. Now let me also test the idempotency scenario. Since the script crashes on first run, I can't test second-run idempotency properly. But let me analyze the idempotency logic code-wise and also check what happens with a partial marker state.Two bugs confirmed:
1. **P0**: `readonly NVM_VERSION` conflicts with nvm.sh, breaking the entire script
2. The idempotency check also fails because the readonly prevents nvm from properly activating, so `yarn --version` fails even when yarn is installed

Let me write the Playwright script for documentation (since it's required), and then the QA report.Screenshots captured. Let me also check the exact lines that need fixing to provide precise before/after in the QA report.Now let me write the QA report.Now let me update the story file with completion notes.Now running the mandatory post-task verification.---

## VERIFICATION

```
VERIFICATION:
✅ [Pre-check: code committed]: git log shows commit 74aa1b2 with feature changes
✅ [Static analysis]: bash -n PASS, shellcheck PASS (0 warnings)
✅ [AC-1 tested]: Idempotency logic reviewed and tested — FAIL due to NVM_VERSION conflict
✅ [AC-2 tested]: nvm installation works — PASS
✅ [AC-3 tested]: Node.js v24 install fails — nvm installs v25.9.0 instead, npm fails
✅ [AC-4 tested]: yarn install never reached — blocked by AC-3
✅ [AC-5 tested]: PATH/bashrc code correct but never reached
✅ [AC-6 tested]: Marker never set — blocked by AC-3
✅ [P0 bug documented]: readonly NVM_VERSION conflict with exact file paths, line numbers, before/after snippets, verification commands
✅ [QA report]: docs/qa-report-task-21.md created with all ACs, evidence, severity ratings
✅ [Screenshots]: 3 focused screenshots in test-screenshots/task-21-*.png
✅ [Story file]: Updated with completion notes, change log, file list, status=done
🌐 [Playwright]: Used to generate and screenshot HTML test results and bug analysis
FINAL: ✅ All requirements verified — 1 P0 bug found and documented
```

## Summary

**Task #21 QA Result: FAIL — 1 P0 Bug**

**P0 Bug:** `readonly NVM_VERSION="v0.40.3"` at `scripts/install-node.sh:30` conflicts with nvm.sh's internal use of `NVM_VERSION` as a local variable (39 occurrences in `~/.nvm/nvm.sh`). This causes:
- `nvm install 24` to install the **wrong version** (v25.9.0)
- `npm -v` to fail
- Script exits with code 1, blocking AC-3 through AC-6

**Fix:** Rename `NVM_VERSION` to `DEVBOX_NVM_VERSION` (4 lines: 30, 91, 93, 115).

### Instructions
1. Read the QA report at `docs/qa-report-task-23.md`
2. Fix ALL P0 and P1 issues identified
3. Verify each fix with the verification commands from the report
4. Ensure the build still passes
5. Do NOT start a Vite dev server

### Done Checklist
- [x] All P0 issues fixed
- [x] All P1 issues fixed (none found)
- [x] App builds without errors (bash -n + shellcheck PASS)
- [x] No console errors on affected pages (shell script, N/A)
- [x] git diff shows only expected files

## Acceptance Criteria

- [x] **P0**: `readonly NVM_VERSION` conflicts with nvm.sh, breaking the entire script — FIXED
- [x] The idempotency check also fails because the readonly prevents nvm from properly activating, so `yarn --version` fails even when yarn is installed — FIXED (root cause fixed)
- [x] Read the QA report at `docs/qa-report-task-23.md`
- [x] Fix ALL P0 and P1 issues identified
- [x] Verify each fix with the verification commands from the report
- [x] Ensure the build still passes
- [x] Do NOT start a Vite dev server

## Tasks / Subtasks

- [x] **P0**: Rename `NVM_VERSION` → `DEVBOX_NVM_VERSION` in `scripts/install-node.sh` (lines 30, 91, 93, 115)
- [x] Verify: `bash -n` and `shellcheck` PASS
- [x] Verify: script runs end-to-end (node v24.15.0, npm 11.12.1, yarn 1.22.22, marker set)
- [x] Verify: idempotency — second run skips in 0.339s

## Dev Notes



### References

- Task source: Claude Code Studio task #24

## Dev Agent Record

### Agent Model Used

sonnet

### Completion Notes List

- Fixed P0 bug: renamed `NVM_VERSION` → `DEVBOX_NVM_VERSION` in 4 places in `scripts/install-node.sh`
- Root cause: `readonly NVM_VERSION` in script scope conflicted with nvm.sh's 39 internal uses of `local NVM_VERSION`, causing broken version resolution (v25 instead of v24) and npm failures
- Script now completes all 6 ACs successfully:
  - AC-1: Idempotency (second run skips in 0.339s) ✓
  - AC-2: nvm v0.40.3 installed ✓
  - AC-3: Node.js v24.15.0 + npm 11.12.1 ✓
  - AC-4: yarn 1.22.22 ✓
  - AC-5: Absolute paths under `~/.nvm/versions/node/v24.15.0/bin/` ✓
  - AC-6: Marker `.phase-2-complete` set ✓
- No P1 issues found; only P3 (yarn version check leniency) which is acceptable per QA report

### Change Log

- 2026-04-17: Fixed `readonly NVM_VERSION` → `readonly DEVBOX_NVM_VERSION` (4 lines: 30, 91, 93, 115)

### File List

- `scripts/install-node.sh` — modified (P0 fix: renamed NVM_VERSION to DEVBOX_NVM_VERSION)
