# Story: Fix: S2.3: Frappe Bench Installer (install-bench.sh) — issues from QA

Status: done
Task ID: mo39v8f8awzqk4
Task Number: #33
Workflow: quick-dev
Model: sonnet
Created: 2026-04-17T18:59:19.018Z

## Description

## Auto-generated Fix Task (from QA task #32)

### Source
QA Report: `docs/qa-report-task-32.md`
Read the QA report FIRST for full context on what failed and needs fixing.

### QA Findings Summary
I'll start by reading the testing info and story file, and checking git status.`docs/testing-info.md` doesn't exist. Let me check what's in `docs/` and verify the committed script.Critical finding: the commit `29a86b4` only changed `sprint-status.yaml`, not `install-bench.sh`. Let me verify if the script is actually committed.The script is committed. Now let me do thorough testing. Let me read the QA story file and the shared library, run static analysis, and check file permissions.Good: bash -n and ShellCheck both pass clean. Let me now do deeper analysis - check peer scripts, look for a running Frappe instance, and verify logic.Let me check the runtime environment and compare with peer scripts for potential issues.Let me check Playwright availability and run comprehensive tests.Good, Playwright is ready. Now let me write a comprehensive test script that verifies all acceptance criteria through both static analysis and runtime validation, generating an HTML report for Playwright to screenshot.Template literal issue with `${BENCH_SITE}`. Let me fix and re-run just the quality screenshot.Let me verify the screenshots were captured.Let me verify the screenshots visually.All screenshots captured clearly. All 36 checks pass. Now let me write the QA report.Now let me write the QA report.Now update the story file.Now the mandatory post-task verification.```
VERIFICATION:
✅ [Pre-check: code committed]: git log shows install-bench.sh committed in b0103dd, working tree clean
✅ [Quality gates]: bash -n exit 0, shellcheck exit 0, permissions -rwxr-xr-x
✅ [AC-1 Idempotency]: check_marker + bench --version + site dir check, exit 0 or clear+re-run
✅ [AC-2 Bench CLI]: nvm sourced, pip3 install with --break-system-packages fallback, version 5.x verify
✅ [AC-3 Bench init]: bench init --frappe-branch version-15, verifies apps/frappe env sites Procfile, no ERPNext
✅ [AC-4 Site creation]: bench new-site dev.local + /etc/hosts + bench use
✅ [AC-5 Dev mode]: 3x bench set-config -g (developer_mode, dev_server, serve_default_site)
✅ [AC-6 Verification]: site dir + list-apps grep frappe + set_marker 3
✅ [Playwright tests]: 36/36 checks pass, 3 screenshots captured
✅ [QA report]: docs/qa-report-task-30.md created (7332 bytes)
✅ [Story file]: Status updated to "done" with completion notes
🌐 [browser test]: Playwright rendered HTML test reports, screenshots in test-screenshots/task-30-*.png
FINAL: ✅ All requirements verified — PASS verdict, no P0/P1 issues
```

### Instructions
1. Read the QA report at `docs/qa-report-task-32.md`
2. Fix ALL P0 and P1 issues identified
3. Verify each fix with the verification commands from the report
4. Ensure the build still passes
5. Do NOT start a Vite dev server

### Done Checklist
- [x] All P0 issues fixed (none found — QA verdict was PASS)
- [x] All P1 issues fixed (none found — QA verdict was PASS)
- [x] App builds without errors (bash -n: PASS, shellcheck: PASS)
- [x] No console errors on affected pages (shell script, no web UI)
- [x] git diff shows only expected files (only scripts/install-bench.sh)

## Acceptance Criteria

- [x] Read the QA report at `docs/qa-report-task-32.md` (saved as `docs/qa-report-task-30.md` by QA agent — naming error)
- [x] Fix ALL P0 and P1 issues identified (none found; improved 2x P3 observations instead)
- [x] Verify each fix with the verification commands from the report
- [x] Ensure the build still passes (bash -n + shellcheck both exit 0)
- [x] Do NOT start a Vite dev server

## Tasks / Subtasks

- [x] Read the QA report at `docs/qa-report-task-32.md` (found as `docs/qa-report-task-30.md`)
- [x] Fix ALL P0 and P1 issues identified (none — QA was PASS; improved P3 items)
- [x] Verify each fix with verification commands
- [x] Ensure the build still passes (bash -n + shellcheck exit 0)
- [x] Do NOT start a Vite dev server

## Dev Notes



### References

- Task source: Claude Code Studio task #33

## Dev Agent Record

### Agent Model Used

sonnet

### Completion Notes List

- QA task #32 report was saved as `docs/qa-report-task-30.md` (naming error by QA agent — should have been `qa-report-task-32.md`)
- QA verdict was PASS with no P0/P1 issues; only 2x P3 minor observations
- Improved P3-1: `/etc/hosts` grep changed from `grep -qF "${BENCH_SITE}"` to `grep -qF " ${BENCH_SITE}"` to use space-prefix match and avoid false positives from substring hostnames (e.g. "mydev.local" wrongly matching search for "dev.local")
- Improved P3-2: Removed `2>/dev/null` from first `pip3 install frappe-bench` attempt so stderr is preserved for diagnostics on failure
- All quality gates pass: `bash -n` exit 0, `shellcheck` exit 0, permissions `-rwxr-xr-x`

### Change Log

- 2026-04-17: Fix P3-1 — `/etc/hosts` grep: `grep -qF "${BENCH_SITE}"` → `grep -qF " ${BENCH_SITE}"` (line 207)
- 2026-04-17: Fix P3-2 — pip3 stderr: removed `2>/dev/null` from first install attempt (line 115)

### File List

- `scripts/install-bench.sh` (modified — 2x P3 improvements)
