# Story: Fix: S3.1: Config Templates and Workspace Files — issues from QA

Status: in-progress
Task ID: mo3a65kyqaavy2
Task Number: #36
Workflow: quick-dev
Model: sonnet
Created: 2026-04-17T19:07:48.539Z

## Description

## Auto-generated Fix Task (from QA task #34)

### Source
QA Report: `docs/qa-report-task-34.md`
Read the QA report FIRST for full context on what failed and needs fixing.

### QA Findings Summary
for QA criteria.The S3.1 feature was committed in `05de535`. The modified `story-14` file is just the tracking doc, not the feature files themselves. Let me verify the actual template/workspace files are committed, then validate each AC.Good - all 8 files are committed and present. Now let me read all the template and workspace files to verify against ACs.Now let me validate the JSON templates and run envsubst tests.Good. Now let me validate the systemd unit files and run a comprehensive Playwright-based test script.Let me verify the `dist/server.js` vs `server.js` question by checking the actual Claude Code Studio structure, and check if there was a prior QA report for this task.The previous QA report (`docs/qa-report-task-14.md`) is **fabricated** — it claims exact matches for values that don't exist in the files. Let me verify the actual config format and check if `dist/server.js` is a real issue.Now I have the full picture. The real Claude Code Studio uses `server.js` (not `dist/server.js`), and its config format is `mcpServers/skills/projects` (not `port/auth/cookie`). The dev's deviations were justified. Let me take focused screenshots and write the report.Now let me verify the screenshots and write the QA report.Good. Now let me write the QA report.Now let me update the story tracking file.Now let me run the post-task verification.

## Verification

```
VERIFICATION:
✅ [Pre-check: code committed]: git log confirms 05de535 with all 8 feature files
✅ [AC-1: openclaw.json.template]: 23/23 checks PASS — valid JSON, all fields, envsubst clean
✅ [AC-2: openclaw-gateway.service]: 12/12 checks PASS — systemd user unit, all Environment vars
✅ [AC-3: claude-studio.service]: 11/12 checks — server.js correct (P3: AC spec had wrong path dist/server.js)
⚠️ [AC-4: claude-studio-config.json.template]: P2 — format matches real app but deviates from AC spec
✅ [AC-5: AGENTS.md]: Agent definition with Frappe dev + code assistance
✅ [AC-6: SOUL.md]: Dev assistant personality defined
✅ [AC-7: TOOLS.md]: 160 lines covering 6 tool categories
✅ [AC-8: USER.md]: Template with placeholder sections
🌐 [Browser test]: Playwright used for automated 62-check validation + 4 screenshots
✅ [QA report]: docs/qa-report-task-14.md written with per-AC PASS/FAIL, evidence, screenshots
✅ [Screenshots]: 4 focused screenshots in test-screenshots/ with task-14 prefix
✅ [Console errors]: N/A (file-based task, no web UI)
✅ [Regression]: No existing files modified, no regression risk
FINAL: ✅ All requirements verified — 0 P0/P1 issues, 1 P2 (AC spec mismatch), 1 P3
```

**QA Summary:**
- **62 automated checks** across 8 acceptance criteria
- **58 PASS, 4 FAIL** (all failures are AC spec issues, not code bugs)
- **P2 (AC-4):** Config template format correctly matches real application but deviates from AC text
- **P3 (AC-3):** Template correctly uses `server.js` — AC's `dist/server.js` doesn't exist on disk
- **No P0/P1 issues** — no fix task needed
- Report: `docs/qa-report-task-14.md`

### Instructions
1. Read the QA report at `docs/qa-report-task-34.md`
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

- [ ] **58 PASS, 4 FAIL** (all failures are AC spec issues, not code bugs)
- [ ] **P2 (AC-4):** Config template format correctly matches real application but deviates from AC text
- [ ] **P3 (AC-3):** Template correctly uses `server.js` — AC's `dist/server.js` doesn't exist on disk
- [ ] **No P0/P1 issues** — no fix task needed
- [ ] Report: `docs/qa-report-task-14.md`

## Tasks / Subtasks

- [ ] Read the QA report at `docs/qa-report-task-34.md`
- [ ] Fix ALL P0 and P1 issues identified
- [ ] Verify each fix with the verification commands from the report
- [ ] Ensure the build still passes
- [ ] Do NOT start a Vite dev server

## Dev Notes



### References

- Task source: Claude Code Studio task #36

## Dev Agent Record

### Agent Model Used

sonnet

### Completion Notes List

_(Updated by agent on completion)_

### Change Log

_(Updated by agent during implementation)_

### File List

_(Updated by agent — list all files created or modified)_
