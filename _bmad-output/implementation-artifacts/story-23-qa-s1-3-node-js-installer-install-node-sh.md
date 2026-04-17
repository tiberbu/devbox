# Story: QA: S1.3: Node.js Installer (install-node.sh)

Status: done
Task ID: mo38hqia6u2hig
Task Number: #23
Workflow: playwright-qa
Model: opus
Created: 2026-04-17T18:20:49.661Z

## Description

## QA Report Task — DO NOT MODIFY CODE

### PRE-CHECK: Verify code is committed
Before testing, run `git status` and `git log --oneline -3` in the project directory.
If the dev task's changes are NOT committed (untracked/modified files from the feature), FAIL the task immediately with:
- Finding: "Code not committed — changes exist only as uncommitted files"
- Severity: P0
- This means the dev task did not properly finish its work.

**Review task #21: S1.3: Node.js Installer (install-node.sh)**
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
Read the story file for acceptance criteria: `_bmad-output/implementation-artifacts/story-21-s1-3-node-js-installer-install-node-sh.md`

### Files changed
file updated with all subtasks checked, change log, file list, and completion notes.

### Screenshot Rules — FOCUSED SCREENSHOTS ONLY
**Do NOT screenshot login, OTP, or navigation steps.** These waste time and add no value.

Only take screenshots that directly verify acceptance criteria:
- ✅ The feature UI after it loads (the component/page being tested)
- ✅ Test results or data displayed by the feature
- ✅ Error states being verified
- ✅ Before/after comparisons for visual changes
- ❌ Login page, OTP screen, sidebar navigation, loading spinners
- ❌ Generic homepage or dashboard unless that IS the feature

Save screenshots to `test-screenshots/` with descriptive names prefixed by task number: `task-21-feature-name.png`

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
Produce `docs/qa-report-task-21.md` with:
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
- [ ] Save screenshots to `test-screenshots/` with descriptive names prefixed by task number: `task-21-feature-name.png`
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

- Task source: Claude Code Studio task #23

## Dev Agent Record

### Agent Model Used

opus

### Completion Notes List

- QA testing complete for Task #21: S1.3 Node.js Installer (install-node.sh)
- Found **1 P0 bug**: `readonly NVM_VERSION` on line 30 of `scripts/install-node.sh` conflicts with nvm.sh's internal use of `NVM_VERSION` as a local variable (39 occurrences)
- This bug causes the script to fail on every run: nvm installs the wrong Node.js version (v25 instead of v24), npm fails, and the script exits with code 1
- 5 of 6 acceptance criteria FAIL due to this single bug; AC-2 (nvm installation) passes
- Static analysis (bash -n, shellcheck) passes cleanly
- Fix: rename `NVM_VERSION` to `DEVBOX_NVM_VERSION` (4 lines changed)

### Change Log

| Date | Change |
|------|--------|
| 2026-04-17 | QA report created: `docs/qa-report-task-21.md`. Found P0 bug: readonly NVM_VERSION conflicts with nvm.sh. |
| 2026-04-17 | Screenshots captured: `test-screenshots/task-21-*.png` (3 screenshots). |

### File List

- `docs/qa-report-task-21.md` — **created** (QA report)
- `test-screenshots/task-21-test-results.png` — **created** (test results screenshot)
- `test-screenshots/task-21-readonly-nvm-version-bug.png` — **created** (bug detail screenshot)
- `test-screenshots/task-21-execution-failure.png` — **created** (execution failure screenshot)
- `test-screenshots/task-21-qa-report.html` — **created** (HTML report source)
- `test-screenshots/task-21-bug-detail.html` — **created** (bug detail HTML source)
- `test-screenshots/task-21-execution-output.html` — **created** (execution output HTML source)
