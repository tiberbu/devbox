# Story: Fix: S3.1: Config Templates and Workspace Files — issues from QA

Status: in-progress
Task ID: mo39yy14ag5ecq
Task Number: #35
Workflow: quick-dev
Model: sonnet
Created: 2026-04-17T19:02:12.161Z

## Description

## Auto-generated Fix Task (from QA task #16)

### Source
QA Report: `docs/qa-report-task-16.md`
Read the QA report FIRST for full context on what failed and needs fixing.

### QA Findings Summary


The QA report for Task #14 has already been completed. Let me verify the current state to confirm everything is in order.The QA work is already complete. All deliverables are in place:

- **QA Report:** `docs/qa-report-task-14.md` — 64/64 checks PASS, 0 failures
- **4 Screenshots:** All in `test-screenshots/task-14-*.png`
- **Feature commit:** `05de535` confirmed in git history with all 8 files
- **Story file:** Updated to `done` status with completion notes

```
VERIFICATION:
✅ Pre-check (code committed): commit 05de535 contains all 8 feature files
✅ AC-1 (openclaw.json.template): 17/17 checks PASS — valid JSON, all fields correct
✅ AC-2 (openclaw-gateway.service): 11/11 checks PASS — systemd user unit correct
✅ AC-3 (claude-studio.service): 11/11 checks PASS — systemd system unit correct
✅ AC-4 (claude-studio-config.json.template): 4/4 checks PASS — valid JSON, correct fields
✅ AC-5-8 (workspace files): 21/21 checks PASS — all 4 files exist with substantive content
✅ Envsubst: Zero unsubstituted ${VAR} placeholders in rendered output
🌐 Playwright test: 4 focused screenshots generated covering all ACs
✅ QA report: docs/qa-report-task-14.md written with all evidence
✅ Story file: story-16 updated to done with completion notes
FINAL: ✅ All requirements verified — 64/64 checks PASS, 0 P0-P3 issues
```

### Instructions
1. Read the QA report at `docs/qa-report-task-16.md`
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

- [ ] Read the QA report at `docs/qa-report-task-16.md`
- [ ] Fix ALL P0 and P1 issues identified
- [ ] Verify each fix with the verification commands from the report
- [ ] Ensure the build still passes
- [ ] Do NOT start a Vite dev server

## Tasks / Subtasks

- [ ] Read the QA report at `docs/qa-report-task-16.md`
- [ ] Fix ALL P0 and P1 issues identified
- [ ] Verify each fix with the verification commands from the report
- [ ] Ensure the build still passes
- [ ] Do NOT start a Vite dev server

## Dev Notes



### References

- Task source: Claude Code Studio task #35

## Dev Agent Record

### Agent Model Used

sonnet

### Completion Notes List

_(Updated by agent on completion)_

### Change Log

_(Updated by agent during implementation)_

### File List

_(Updated by agent — list all files created or modified)_
