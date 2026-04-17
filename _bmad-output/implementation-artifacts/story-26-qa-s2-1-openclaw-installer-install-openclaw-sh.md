# Story: QA: S2.1: OpenClaw Installer (install-openclaw.sh)

Status: done
Task ID: mo3920v8wlk2i1
Task Number: #26
Workflow: playwright-qa
Model: opus
Created: 2026-04-17T18:36:36.218Z

## Description

## QA Report Task — DO NOT MODIFY CODE

### PRE-CHECK: Verify code is committed
Before testing, run `git status` and `git log --oneline -3` in the project directory.
If the dev task's changes are NOT committed (untracked/modified files from the feature), FAIL the task immediately with:
- Finding: "Code not committed — changes exist only as uncommitted files"
- Severity: P0
- This means the dev task did not properly finish its work.

**Review task #25: S2.1: OpenClaw Installer (install-openclaw.sh)**
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
Read the story file for acceptance criteria: `_bmad-output/implementation-artifacts/story-25-s2-1-openclaw-installer-install-openclaw-sh.md`

### Files changed
File created]: ls scripts/install-openclaw.sh → -rw-r--r-- 1 ubuntu ubuntu 9967 Apr 17 18:35 scripts/install-openclaw.sh
file updated]: Status → done; Completion Notes, Change Log, File List populated
file updated to `done`.

### Screenshot Rules — FOCUSED SCREENSHOTS ONLY
**Do NOT screenshot login, OTP, or navigation steps.** These waste time and add no value.

Only take screenshots that directly verify acceptance criteria:
- ✅ The feature UI after it loads (the component/page being tested)
- ✅ Test results or data displayed by the feature
- ✅ Error states being verified
- ✅ Before/after comparisons for visual changes
- ❌ Login page, OTP screen, sidebar navigation, loading spinners
- ❌ Generic homepage or dashboard unless that IS the feature

Save screenshots to `test-screenshots/` with descriptive names prefixed by task number: `task-25-feature-name.png`

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
Produce `docs/qa-report-task-25.md` with:
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
- [ ] Save screenshots to `test-screenshots/` with descriptive names prefixed by task number: `task-25-feature-name.png`
- [ ] Aim for 2-5 focused screenshots per QA task, not 10+ routine ones.

## Tasks / Subtasks

- [ ] Read docs/testing-info.md for the correct test URL and credentials
- [ ] Write a Playwright script that logs in (no screenshot needed for login)
- [ ] Navigate to the relevant pages for this feature
- [ ] Test each acceptance criterion from the story file
- [ ] Take FOCUSED screenshots only for AC verification (see rules above)
- [ ] Check for console errors
- [ ] Check for regressions in related functionality
- [ ] **Severity level** (P0/P1) clearly labeled in headings
- [ ] **Exact file paths + line numbers** for every issue
- [ ] **Before/after code snippets** showing exactly what to change
- [ ] **Verification command** for each fix

## Dev Notes



### References

- Task source: Claude Code Studio task #26

## Dev Agent Record

### Agent Model Used

opus

### Completion Notes List

- QA completed for task #25 (S2.1: OpenClaw Installer). Found 1 P0 bug and 1 P2 issue.
- P0: `templates/openclaw-gateway.service` uses `v24` in ExecStart/PATH, but nvm creates full semver dirs (`v24.14.1`, `v24.15.0`). The rendered service path doesn't exist, so systemd service fails to start. AC-5 and AC-6 blocked.
- P2: Placeholder check in `render_config()` (line 123) greps for `${` after envsubst, but envsubst replaces unset vars with empty strings — the check never fires.
- AC-1 through AC-4 pass. Static analysis (bash -n, shellcheck) clean.
- 3 focused screenshots captured for evidence.

### Change Log

- 2026-04-17: Created `docs/qa-report-task-25.md` with full QA findings.
- 2026-04-17: Captured 3 screenshots to `test-screenshots/task-25-*.png`.

### File List

- `docs/qa-report-task-25.md` (created)
- `test-screenshots/task-25-qa-results-overview.png` (created)
- `test-screenshots/task-25-p0-service-template-bug.png` (created)
- `test-screenshots/task-25-ac-summary.png` (created)
