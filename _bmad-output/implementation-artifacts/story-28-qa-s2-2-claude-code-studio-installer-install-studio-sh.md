# Story: QA: S2.2: Claude Code Studio Installer (install-studio.sh)

Status: done
Task ID: mo399oskp8mowz
Task Number: #28
Workflow: playwright-qa
Model: opus
Created: 2026-04-17T18:42:42.322Z

## Description

## QA Report Task — DO NOT MODIFY CODE

### PRE-CHECK: Verify code is committed
Before testing, run `git status` and `git log --oneline -3` in the project directory.
If the dev task's changes are NOT committed (untracked/modified files from the feature), FAIL the task immediately with:
- Finding: "Code not committed — changes exist only as uncommitted files"
- Severity: P0
- This means the dev task did not properly finish its work.

**Review task #27: S2.2: Claude Code Studio Installer (install-studio.sh)**
**QA Depth: 1/1** (max depth reached = no further QA cycles)

### MANDATORY: Use Playwright via Bash scripts for ALL browser testing
You MUST write and execute Playwright scripts using the Bash tool. MCP tools are NOT available.

Example pattern:
```
cat > /tmp/qa-test.mjs << 'SCRIPT'
import { chromium } from "playwright";
const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();
// ... test code ...
await browser.close();
SCRIPT
node /tmp/qa-test.mjs
```

**If you skip Playwright testing, the task will be FAILED by the server automatically.**

Start by reading docs/testing-info.md for the correct test URL and credentials.

### What to verify
Read the story file for acceptance criteria: `_bmad-output/implementation-artifacts/story-27-s2-2-claude-code-studio-installer-install-studio-sh.md`

### Files changed
file updated: status=done, all ACs and subtasks checked, Change Log + Completion Notes added

### Screenshot Rules — FOCUSED SCREENSHOTS ONLY
**Do NOT screenshot login, OTP, or navigation steps.** These waste time and add no value.

Only take screenshots that directly verify acceptance criteria:
- ✅ The feature UI after it loads (the component/page being tested)
- ✅ Test results or data displayed by the feature
- ✅ Error states being verified
- ✅ Before/after comparisons for visual changes
- ❌ Login page, OTP screen, sidebar navigation, loading spinners
- ❌ Generic homepage or dashboard unless that IS the feature

Save screenshots to `test-screenshots/` with descriptive names prefixed by task number: `task-27-feature-name.png`

Aim for 2-5 focused screenshots per QA task, not 10+ routine ones.

### Test steps
1. Read docs/testing-info.md for the correct test URL and credentials
2. Write a Playwright script that logs in (no screenshot needed for login)
3. Navigate to the relevant pages for this feature
4. Test each acceptance criterion from the story file
5. Take FOCUSED screenshots only for AC verification (see rules above)
6. Check for console errors
7. Check for regressions in related functionality

### Deliverable
Produce `docs/qa-report-task-27.md` with:
- Each AC: PASS/FAIL with evidence
- Screenshots referenced (use task-prefixed naming)
- Console errors captured
- Severity ratings (P0-P3) for any failures

### Creating fix tasks (HANDLED AUTOMATICALLY BY SERVER)
If you find P0 or P1 failures, clearly document them in your QA report with:
1. **Severity level** (P0/P1) clearly labeled in headings
2. **Exact file paths + line numbers** for every issue
3. **Before/after code snippets** showing exactly what to change
4. **Verification command** for each fix

The server will automatically create a fix task from your QA report when P0/P1 issues are detected.
You do NOT need to create fix tasks via curl anymore — just write a thorough QA report.

**CRITICAL: Clearly label P0/P1 issues in your report. Do NOT mark ALL PASS if there are P0/P1 issues.**

## Acceptance Criteria

- [ ] ✅ The feature UI after it loads (the component/page being tested)
- [ ] ✅ Test results or data displayed by the feature
- [ ] ✅ Error states being verified
- [ ] ✅ Before/after comparisons for visual changes
- [ ] ❌ Login page, OTP screen, sidebar navigation, loading spinners
- [ ] ❌ Generic homepage or dashboard unless that IS the feature
- [ ] Save screenshots to `test-screenshots/` with descriptive names prefixed by task number: `task-27-feature-name.png`
- [ ] Aim for 2-5 focused screenshots per QA task, not 10+ routine ones.

## Tasks / Subtasks

- [x] Read docs/testing-info.md for the correct test URL and credentials
- [x] Write a Playwright script that logs in (no screenshot needed for login)
- [x] Navigate to the relevant pages for this feature
- [x] Test each acceptance criterion from the story file
- [x] Take FOCUSED screenshots only for AC verification (see rules above)
- [x] Check for console errors
- [x] Check for regressions in related functionality
- [x] **Severity level** (P0/P1) clearly labeled in headings
- [x] **Exact file paths + line numbers** for every issue
- [x] **Before/after code snippets** showing exactly what to change
- [x] **Verification command** for each fix

## Dev Notes



### References

- Task source: Claude Code Studio task #28

## Dev Agent Record

### Agent Model Used

opus

### Completion Notes List

- QA FAIL: 3x P0, 2x P1 issues found — script cannot run successfully
- P0-1: `npm run build` fails (no build script in upstream package.json)
- P0-2: `dist/server.js` assertion incorrect (app entry is `server.js` at root)
- P0-3: Node path `v24` in systemd template does not exist (only `v24.14.1`, `v24.15.0`)
- P1-1: HTTP check expects 200 but app returns 302 (redirect to /login)
- P1-2: Config template schema doesn't match actual app configuration
- Static quality gates pass: bash -n and shellcheck both exit 0
- AC-1 (idempotency) and AC-2 (git clone/pull) are structurally correct

### Change Log

| Date | Author | Change |
|------|--------|--------|
| 2026-04-17 | qa-agent (opus) | Created QA report `docs/qa-report-task-27.md` with 3x P0 + 2x P1 findings |

### File List

- `docs/qa-report-task-27.md` (created)
- `test-screenshots/task-27-studio-running-state.png` (created)
- `test-screenshots/task-27-studio-http-response.png` (created)
- `test-screenshots/task-27-critical-findings.png` (created)
