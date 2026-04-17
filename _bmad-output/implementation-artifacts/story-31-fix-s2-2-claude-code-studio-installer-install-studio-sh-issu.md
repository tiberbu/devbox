# Story: Fix: S2.2: Claude Code Studio Installer (install-studio.sh) — issues from QA

Status: done
Task ID: mo39h14ptdppk8
Task Number: #31
Workflow: quick-dev
Model: sonnet
Created: 2026-04-17T18:48:16.370Z

## Description

## Auto-generated Fix Task (from QA task #28)

### Source
QA Report: `docs/qa-report-task-28.md`
Read the QA report FIRST for full context on what failed and needs fixing.

### QA Findings Summary
ht test to verify the HTTP behavior and capture evidence, then check a few more things.Playwright follows redirects by default. Let me verify the exact curl behavior the script uses, and run more checks.Now let me capture a focused screenshot of the actual running Studio for evidence, and verify one more template detail.Let me view the screenshots to confirm they captured properly.Screenshots confirmed. Now let me capture one final piece of evidence and write the QA report.Evidence captured clearly. Now let me write the QA report.Now let me update the story file with completion notes.Now let me run the mandatory post-task verification.

## Post-Task Verification

### Step 1 — Requirements Audit

1. Pre-check: verify code is committed
2. Read story file for acceptance criteria
3. Test each AC (AC-1 through AC-6) from the story
4. Use Playwright for browser testing
5. Take focused screenshots (2-5, task-prefixed)
6. Check console errors
7. Check regressions
8. Produce `docs/qa-report-task-27.md` with PASS/FAIL per AC, screenshots, severity ratings
9. Clearly label P0/P1 issues with file paths, line numbers, before/after snippets, verification commands

### Step 2 — Proof of Completion```
VERIFICATION:
✅ Pre-check (code committed): git log shows 510ec0c commit with install-studio.sh
✅ Story file read: AC-1 through AC-6 reviewed from story-27
✅ All 6 ACs tested: AC-1 PASS, AC-2 PASS, AC-3 FAIL (P0), AC-4 FAIL (P1), AC-5 FAIL (P0), AC-6 FAIL (P1)
✅ Playwright browser testing: 3 test scripts executed, HTTP behavior verified
✅ Screenshots: 4 focused screenshots in test-screenshots/task-27-*.png
✅ Console errors: None detected
✅ Regression check: No regressions in other scripts
✅ QA report: docs/qa-report-task-27.md (298 lines) with PASS/FAIL per AC
✅ P0/P1 labeling: 3x P0, 2x P1 clearly labeled with file:line, before/after, verification commands
🌐 Browser test: localhost:3000 serves Claude Code Studio login page (302 redirect, verified via Playwright + curl)
FINAL: ✅ All QA requirements verified — FAIL verdict with 5 actionable findings documented
```

## Summary

**QA Verdict: FAIL** — `install-studio.sh` has 3 P0 and 2 P1 issues that prevent successful execution:

| Sev | Issue | Root Cause |
|-----|-------|-----------|
| **P0** | `npm run build` fails | Upstream project has no `build` script |
| **P0** | `dist/server.js` assertion always fails | App entry point is `server.js` at root |
| **P0** | Node path `v24` doesn't exist in nvm | nvm uses full versions like `v24.14.1` |
| **P1** | HTTP check gets 302, expects 200 | App redirects `/` to `/login` |
| **P1** | Config template schema mismatch | Template has `{port, auth}`, app needs `{mcpServers, skills, ...}` |

The script passes static analysis (`bash -n`, `shellcheck`) and AC-1/AC-2 are structurally sound, but AC-3 through AC-6 all have runtime failures. The currently running Claude Studio was configured manually, not by this script. Full details with fix snippets in `docs/qa-report-task-27.md`.

### Instructions
1. Read the QA report at `docs/qa-report-task-28.md`
2. Fix ALL P0 and P1 issues identified
3. Verify each fix with the verification commands from the report
4. Ensure the build still passes
5. Do NOT start a Vite dev server

### Done Checklist
- [x] All P0 issues fixed
- [x] All P1 issues fixed
- [x] App builds without errors
- [x] No console errors on affected pages
- [x] git diff shows only expected files

## Acceptance Criteria

- [ ] Test each AC (AC-1 through AC-6) from the story
- [ ] Use Playwright for browser testing
- [ ] Take focused screenshots (2-5, task-prefixed)
- [ ] Check console errors
- [ ] Check regressions
- [ ] Produce `docs/qa-report-task-27.md` with PASS/FAIL per AC, screenshots, severity ratings
- [ ] Clearly label P0/P1 issues with file paths, line numbers, before/after snippets, verification commands

## Tasks / Subtasks

- [ ] Pre-check: verify code is committed
- [ ] Read story file for acceptance criteria
- [ ] Test each AC (AC-1 through AC-6) from the story
- [ ] Use Playwright for browser testing
- [ ] Take focused screenshots (2-5, task-prefixed)
- [ ] Check console errors
- [ ] Check regressions
- [ ] Produce `docs/qa-report-task-27.md` with PASS/FAIL per AC, screenshots, severity ratings
- [ ] Clearly label P0/P1 issues with file paths, line numbers, before/after snippets, verification commands
- [ ] Read the QA report at `docs/qa-report-task-28.md`
- [ ] Fix ALL P0 and P1 issues identified
- [ ] Verify each fix with the verification commands from the report
- [ ] Ensure the build still passes
- [ ] Do NOT start a Vite dev server

## Dev Notes



### References

- Task source: Claude Code Studio task #31

## Dev Agent Record

### Agent Model Used

sonnet

### Completion Notes List

All 5 QA findings (3x P0, 2x P1) from qa-report-task-27.md fixed:
- P0-1: Removed `npm run build` — no build script in upstream package.json
- P0-2: Changed `dist/server.js` assertion to `server.js` at repo root
- P0-3: Fixed hardcoded `v24` node path — now resolved dynamically via `command -v node` → `NODE_BIN_PATH`/`NODE_BIN_DIR` exported before `render_template` call
- P1-1: Added `-L` to curl HTTP check so 302→/login redirect follows to 200
- P1-2: Updated config template schema to match actual app (`mcpServers`, `skills`, `slashCommands`, `lang`, `projects`); added skip-if-exists guard to preserve manual config

All fixes pass `bash -n`, `shellcheck`, and runtime verification.

### Change Log

- 2026-04-17: Fixed P0-1 — removed `npm run build` from `build_studio()`, updated comment
- 2026-04-17: Fixed P0-2 — changed `dist/server.js` assertion to `server.js` in `build_studio()`
- 2026-04-17: Fixed P0-3 — added `NODE_BIN_PATH`/`NODE_BIN_DIR` resolution in `install_service()`, updated service template to use `${NODE_BIN_PATH}` and `${NODE_BIN_DIR}`
- 2026-04-17: Fixed P1-1 — changed `curl -s` to `curl -sL` in `verify_phase()` to follow 302 redirect
- 2026-04-17: Fixed P1-2 — updated config template to correct schema (`mcpServers`, `skills`, `slashCommands`, `lang`, `projects`); added skip-if-exists guard in `render_config()`

### File List

- `scripts/install-studio.sh` — modified: P0-1/P0-2 (`build_studio`), P0-3 (`install_service`), P1-1 (`verify_phase`), P1-2 (`render_config`)
- `templates/claude-studio.service` — modified: P0-3 (`ExecStart`, `PATH` env)
- `templates/claude-studio-config.json.template` — modified: P1-2 (schema corrected)
