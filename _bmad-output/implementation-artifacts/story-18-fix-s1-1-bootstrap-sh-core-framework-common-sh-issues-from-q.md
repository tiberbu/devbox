# Story: Fix: S1.1: bootstrap.sh Core Framework + _common.sh — issues from QA

Status: done
Task ID: mo37ybvytsnkd3
Task Number: #18
Workflow: quick-dev
Model: sonnet
Created: 2026-04-17T18:05:44.231Z

## Description

## Auto-generated Fix Task (from QA task #17)

### Source
QA Report: `docs/qa-report-task-17.md`
Read the QA report FIRST for full context on what failed and needs fixing.

### QA Findings Summary
I'll start by reading the testing info and story file, then check git status.Let me check what's actually committed vs what's modified.The core feature files are committed (in commit 05de535). There's a 1-line uncommitted change (shellcheck disable comment). Let me now read the QA story file and the actual source files.Now I have a clear picture. This is a shell script project — `bootstrap.sh` and `scripts/_common.sh`. Let me run comprehensive tests.Let me run comprehensive shell tests for AC-1 and the Definition of Done checks in parallel.The AC-1 test script failed early due to `set -euo pipefail`. Let me fix and re-run it without the strict mode since we're intentionally testing failure cases.All 33 AC-1 tests pass. Now let me test AC-2, AC-3, and AC-4.One test showed 6/8 vars. Let me investigate — some env vars may already be set in the environment.The "6 of 8" was a test environment artifact — `AWS_DEFAULT_REGION` and `GITHUB_TOKEN` were leaked from earlier test steps. With a clean environment, all 8 required vars are correctly validated. The feature works correctly.Now let me create the Playwright test that captures the shell script test results and generates screenshots.All screenshots look great. Now let me write the QA report.Now let me update the story file and run the final verification.Now running the mandatory post-task verification.---

```
VERIFICATION:
✅ Pre-check: code committed (05de535 contains bootstrap.sh + scripts/_common.sh)
✅ AC-1: _common.sh utility library — 33/33 tests pass (all functions, constants, logging, markers, template, retry, validators, error_handler)
✅ AC-2: bootstrap.sh orchestrator — all sub-criteria pass (pipefail, source, args, env, creds, phases, mkdir, elapsed, executable)
✅ AC-3: Dry-run mode — exits 0, prints plan, validates creds, prevents execution
✅ AC-4: Error handling — set -euo pipefail + ERR trap with BASH_SOURCE/LINENO/$? context
✅ Definition of Done — 6/6 (bash -n, shellcheck, --help, --dry-run, executable)
🌐 Playwright: HTML test report generated, 4 screenshots captured to test-screenshots/
✅ QA report: docs/qa-report-task-15.md written with all ACs, evidence, and severity ratings
FINAL: ✅ All requirements verified — 64 tests pass, no P0/P1 issues
```

### Instructions
1. Read the QA report at `docs/qa-report-task-17.md`
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

- [x] Read the QA report at `docs/qa-report-task-17.md`
- [x] Fix ALL P0 and P1 issues identified
- [x] Verify each fix with the verification commands from the report
- [x] Ensure the build still passes
- [x] Do NOT start a Vite dev server

## Tasks / Subtasks

- [x] Read the QA report at `docs/qa-report-task-17.md`
- [x] Fix ALL P0 and P1 issues identified
- [x] Verify each fix with the verification commands from the report
- [x] Ensure the build still passes
- [x] Do NOT start a Vite dev server

## Dev Notes



### References

- Task source: Claude Code Studio task #18

## Dev Agent Record

### Agent Model Used

sonnet

### Completion Notes List

- QA report `docs/qa-report-task-17.md` was not found at the referenced path; the equivalent report was `docs/qa-report-task-15.md`, which covered the same files (bootstrap.sh + scripts/_common.sh).
- The QA report found **zero P0 or P1 issues**. The only finding was a P3 (cosmetic, non-blocking): an uncommitted `# shellcheck disable=SC1091` comment in bootstrap.sh.
- The P3 fix has been committed in `feefe2a`. All verification checks pass: bash -n (both files), shellcheck (both files), --help (exit 0), --dry-run (exit 0), git status (clean working tree).

### Change Log

- `bootstrap.sh` — committed the pending `# shellcheck disable=SC1091` directive above the `source` call (line 21) to suppress ShellCheck SC1091 for dynamic source paths. This was the sole open finding from the QA report. Committed as `feefe2a`.

### File List

- `bootstrap.sh` — modified (added `# shellcheck disable=SC1091`)
