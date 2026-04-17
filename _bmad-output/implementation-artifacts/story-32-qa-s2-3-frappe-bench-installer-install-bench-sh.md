# Story: QA: S2.3: Frappe Bench Installer (install-bench.sh)

Status: done
Task ID: mo39mgi82otmsb
Task Number: #32
Workflow: playwright-qa
Model: opus
Created: 2026-04-17T18:52:29.591Z

## Description

## QA Report Task — DO NOT MODIFY CODE

### PRE-CHECK: Verify code is committed
Before testing, run `git status` and `git log --oneline -3` in the project directory.
If the dev task's changes are NOT committed (untracked/modified files from the feature), FAIL the task immediately with:
- Finding: "Code not committed — changes exist only as uncommitted files"
- Severity: P0
- This means the dev task did not properly finish its work.

**Review task #30: S2.3: Frappe Bench Installer (install-bench.sh)**
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
Read the story file for acceptance criteria: `_bmad-output/implementation-artifacts/story-30-s2-3-frappe-bench-installer-install-bench-sh.md`

### Files changed
File created: scripts/install-bench.sh exists (-rwxr-xr-x)
file updated.

### Screenshot Rules — FOCUSED SCREENSHOTS ONLY
**Do NOT screenshot login, OTP, or navigation steps.** These waste time and add no value.

Only take screenshots that directly verify acceptance criteria:
- ✅ The feature UI after it loads (the component/page being tested)
- ✅ Test results or data displayed by the feature
- ✅ Error states being verified
- ✅ Before/after comparisons for visual changes
- ❌ Login page, OTP screen, sidebar navigation, loading spinners
- ❌ Generic homepage or dashboard unless that IS the feature

Save screenshots to `test-screenshots/` with descriptive names prefixed by task number: `task-30-feature-name.png`

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
Produce `docs/qa-report-task-30.md` with:
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
- [ ] Save screenshots to `test-screenshots/` with descriptive names prefixed by task number: `task-30-feature-name.png`
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

- Task source: Claude Code Studio task #32

## Dev Agent Record

### Agent Model Used

opus

### Completion Notes List

- QA PASS: All 6 acceptance criteria verified (AC-1 through AC-6)
- Quality gates: bash -n clean, ShellCheck clean, -rwxr-xr-x permissions
- 36/36 automated checks pass via Playwright test suite
- 2x P3 minor observations (substring grep in /etc/hosts, pip3 stderr suppression) — no fix required
- Script follows project conventions and matches peer install script patterns
- No regressions in related scripts

### Change Log

- 2026-04-17: Created QA report docs/qa-report-task-30.md — ALL PASS verdict

### File List

- docs/qa-report-task-30.md (created)
- test-screenshots/task-30-ac-overview.png (created)
- test-screenshots/task-30-script-structure.png (created)
- test-screenshots/task-30-code-quality.png (created)
