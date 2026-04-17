# QA Report: Task #21 — S1.3: Node.js Installer (install-node.sh)

**Date:** 2026-04-17
**QA Depth:** 1/1
**Tested by:** Claude Opus (automated QA)
**Script:** `scripts/install-node.sh`

---

## Pre-Check

| Check | Result |
|-------|--------|
| Code committed | PASS — commit `74aa1b2` "feat(dev-story): S1.3: Node.js Installer (install-node.sh)" |
| Untracked files from feature | None — only `_bmad-output/`, `docs/`, `test-screenshots/` are untracked (not feature files) |

## Static Analysis

| Check | Result |
|-------|--------|
| `bash -n scripts/install-node.sh` | PASS — no syntax errors |
| `shellcheck scripts/install-node.sh` | PASS — zero warnings (shellcheck 0.9.0) |
| `shellcheck scripts/_common.sh` | PASS — zero warnings |

---

## Acceptance Criteria Results

### AC-1: Idempotency check — FAIL (P0)

**Expected:** Checks marker `.phase-2-complete` AND `node -v` returns v24 AND `yarn --version` succeeds. If all pass: logs skip and exits 0. If marker exists but checks fail: clears marker and re-runs.

**Result:** The idempotency logic is correctly implemented in code (lines 53-83), but it **fails at runtime** because:
1. The `readonly NVM_VERSION` conflict (see P0 bug below) prevents nvm from properly activating the default node version
2. `yarn --version` fails even when yarn IS installed, because nvm can't resolve the PATH to the nvm-managed node's bin directory
3. The check always falls through to "marker exists but checks failed" path, clears the marker, then the full re-run also fails

**Evidence:** Script output shows:
```
→ Marker .phase-2-complete found — verifying node and yarn
! yarn --version failed
! Marker exists but checks failed — clearing marker and re-running
```

**Code review:** The idempotency logic itself is well-structured:
- `check_marker` correctly checks for `/var/tmp/devbox/.phase-2-complete`
- `_source_nvm` correctly loads nvm into the session
- Version checks and marker clearing are properly implemented
- Would work correctly if the `NVM_VERSION` naming conflict were fixed

### AC-2: nvm installation — PASS (with caveat)

**Expected:** Downloads nvm v0.40.3 install script with retry (3 attempts), installs to `~/.nvm`, sources nvm in current session, verifies `command -v nvm`.

**Result:** nvm installation code is correct. The download URL, retry logic (3 attempts with 5s delay), temp file handling, sourcing, and verification all work properly. nvm IS successfully installed and sourced.

**Evidence:**
```
✓ nvm install script downloaded
✓ nvm install script executed
✓ Step 1/4: nvm v0.40.3 installed (nvm)
```

**Caveat:** The `readonly NVM_VERSION` on line 30 causes nvm.sh errors in later steps. The nvm installation itself succeeds, but subsequent nvm operations break.

### AC-3: Node.js v24 — FAIL (P0)

**Expected:** `nvm install 24`, `nvm alias default 24`. Verifies `node -v` outputs v24.x.x and `npm -v` works.

**Result:** Due to the `readonly NVM_VERSION` conflict:
1. `nvm install 24` installs **v25.9.0** instead of v24 (broken version resolution)
2. nvm falls back to system node (v24.14.1)
3. `npm -v` fails, causing the script to exit with code 1

**Evidence:**
```
/home/ubuntu/.nvm/nvm.sh: line 930: local: NVM_VERSION: readonly variable
/home/ubuntu/.nvm/nvm.sh: line 931: NVM_VERSION: readonly variable
Downloading and installing node v25.9.0...    ← WRONG VERSION
Now using system version of node: v24.14.1
✓ node -v: v24.14.1     ← System node, not nvm-managed
✗ npm -v failed          ← FATAL
```

**Without the bug (verified manually):** `nvm install 24` correctly installs v24.15.0, `npm -v` returns 11.12.1.

### AC-4: yarn installation — FAIL (P0, blocked by AC-3)

**Expected:** `npm install -g yarn`, verifies `yarn --version` outputs 1.22.x.

**Result:** Never reached — script exits at AC-3 (`npm -v` failure).

**Code review:** The install_yarn function (lines 154-168) is correctly implemented but doesn't validate yarn version matches `1.22.x` pattern — it only checks the version string is non-empty. This is a minor concern (P3) since `npm install -g yarn` always installs classic yarn 1.22.x.

**Without the bug (verified manually):** yarn 1.22.22 installs correctly.

### AC-5: PATH availability — FAIL (P0, blocked by AC-3)

**Expected:** `node/npm/yarn` available via absolute path `~/.nvm/versions/node/v24.x.x/bin/`. `.bashrc` sources nvm for future sessions.

**Result:** Never reached — script exits at AC-3.

**Code review:** The configure_bashrc function (lines 175-206) is correctly implemented. `.bashrc` already contains the NVM_DIR block (added by nvm installer). PATH logging is correct.

**Without the bug (verified manually):**
```
which node → /home/ubuntu/.nvm/versions/node/v24.15.0/bin/node
which yarn → /home/ubuntu/.nvm/versions/node/v24.15.0/bin/yarn
```

### AC-6: Completion — FAIL (P0, blocked by AC-3)

**Expected:** Set marker `.phase-2-complete`.

**Result:** Never reached — script exits at AC-3. Marker is NOT set.

**Evidence:**
```
$ ls /var/tmp/devbox/.phase-2-complete
ls: cannot access '/var/tmp/devbox/.phase-2-complete': No such file or directory
```

---

## P0 Bug: `readonly NVM_VERSION` conflicts with nvm.sh internals

### Severity: P0 — Script completely broken, cannot complete any run

### Root Cause

**File:** `scripts/install-node.sh`, **line 30**

```bash
readonly NVM_VERSION="v0.40.3"
```

The variable name `NVM_VERSION` conflicts with nvm.sh's internal use of the same name. nvm.sh uses `local NVM_VERSION` in **39 functions** (e.g., `nvm_ensure_version_prefix()` at line 930). Bash's `readonly` attribute prevents any subsequent `local` declaration of the same variable, causing:

1. `nvm.sh: line 930: local: NVM_VERSION: readonly variable` errors
2. Broken version resolution — `nvm install 24` installs v25.9.0 instead of v24
3. `npm -v` fails → script exits with code 1
4. yarn never installed, marker never set, no steps after AC-2 complete

### Affected Lines

| Line | Current | Fixed |
|------|---------|-------|
| 30 | `readonly NVM_VERSION="v0.40.3"` | `readonly DEVBOX_NVM_VERSION="v0.40.3"` |
| 91 | `log_info "Step 1/4: Installing nvm ${NVM_VERSION}"` | `log_info "Step 1/4: Installing nvm ${DEVBOX_NVM_VERSION}"` |
| 93 | `local install_url="https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh"` | `local install_url="https://raw.githubusercontent.com/nvm-sh/nvm/${DEVBOX_NVM_VERSION}/install.sh"` |
| 115 | `log_success "Step 1/4: nvm ${NVM_VERSION} installed ..."` | `log_success "Step 1/4: nvm ${DEVBOX_NVM_VERSION} installed ..."` |

### Before/After Code Snippets

**Line 30 — Before:**
```bash
readonly NVM_VERSION="v0.40.3"
```

**Line 30 — After:**
```bash
readonly DEVBOX_NVM_VERSION="v0.40.3"
```

**Line 91 — Before:**
```bash
log_info "Step 1/4: Installing nvm ${NVM_VERSION}"
```

**Line 91 — After:**
```bash
log_info "Step 1/4: Installing nvm ${DEVBOX_NVM_VERSION}"
```

**Line 93 — Before:**
```bash
local install_url="https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh"
```

**Line 93 — After:**
```bash
local install_url="https://raw.githubusercontent.com/nvm-sh/nvm/${DEVBOX_NVM_VERSION}/install.sh"
```

**Line 115 — Before:**
```bash
log_success "Step 1/4: nvm ${NVM_VERSION} installed ($(command -v nvm || echo 'shell function'))"
```

**Line 115 — After:**
```bash
log_success "Step 1/4: nvm ${DEVBOX_NVM_VERSION} installed ($(command -v nvm || echo 'shell function'))"
```

### Verification Command

```bash
# After fix, run the script and verify:
bash scripts/install-node.sh
# Should complete without errors. Then verify:
node -v           # Should output v24.x.x
npm -v            # Should output a version
yarn --version    # Should output 1.22.x
ls /var/tmp/devbox/.phase-2-complete   # Should exist
# Second run should skip in <2s:
time bash scripts/install-node.sh
```

---

## Screenshots

| Screenshot | Description |
|-----------|-------------|
| [task-21-test-results.png](../test-screenshots/task-21-test-results.png) | Full test results table showing PASS/FAIL for each check |
| [task-21-readonly-nvm-version-bug.png](../test-screenshots/task-21-readonly-nvm-version-bug.png) | Detailed bug analysis showing the conflict between script and nvm.sh |
| [task-21-execution-failure.png](../test-screenshots/task-21-execution-failure.png) | Script execution output showing the failure cascade |

---

## Console Errors Captured

```
/home/ubuntu/.nvm/nvm.sh: line 930: local: NVM_VERSION: readonly variable
/home/ubuntu/.nvm/nvm.sh: line 931: NVM_VERSION: readonly variable
(repeated for every nvm function call involving NVM_VERSION)
```

---

## Summary

| AC | Status | Severity | Notes |
|----|--------|----------|-------|
| AC-1: Idempotency check | FAIL | P0 | Logic correct, but readonly NVM_VERSION breaks nvm PATH activation |
| AC-2: nvm installation | PASS | — | nvm installs correctly; the bug affects later nvm operations |
| AC-3: Node.js v24 | FAIL | P0 | nvm installs wrong version (v25 instead of v24), npm fails |
| AC-4: yarn installation | FAIL | P0 | Never reached due to AC-3 failure |
| AC-5: PATH availability | FAIL | P0 | Never reached; .bashrc config code is correct |
| AC-6: Completion marker | FAIL | P0 | Never reached |
| bash -n | PASS | — | Clean syntax |
| shellcheck | PASS | — | Zero warnings |

**Overall: FAIL — 1 P0 bug blocks 5 of 6 acceptance criteria.**

The fix is straightforward: rename `NVM_VERSION` to `DEVBOX_NVM_VERSION` (4 lines changed). All other code is well-structured and would pass if this naming conflict is resolved.
