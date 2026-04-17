# QA Report: Task #25 — S2.1: OpenClaw Installer (install-openclaw.sh)

**Date:** 2026-04-17
**QA Depth:** 1/1
**Tested by:** Claude Opus (automated QA)
**Script:** `scripts/install-openclaw.sh`

---

## Pre-Check

| Check | Result |
|-------|--------|
| Code committed | PASS — commit `3cd7ae6` "feat(dev-story): S2.1: OpenClaw Installer (install-openclaw.sh)" |
| Untracked files from feature | None — `_bmad-output/`, `docs/`, `test-screenshots/` are not feature files |

## Static Analysis

| Check | Result |
|-------|--------|
| `bash -n scripts/install-openclaw.sh` | PASS — no syntax errors |
| `shellcheck --severity=style scripts/install-openclaw.sh` | PASS — zero warnings (shellcheck 0.9.0) |

---

## Acceptance Criteria Results

### AC-1: Idempotency check — PASS

**Expected:** Checks marker `.phase-4-complete` AND `systemctl --user is-active openclaw-gateway`. If both pass: skip. If marker but no service: clear + re-run.

**Result:** Correctly implemented in `check_idempotency()` (lines 48-62):
- Line 49: `check_marker "${PHASE_NUM}"` checks `/var/tmp/devbox/.phase-4-complete`
- Line 55: `systemctl --user is-active --quiet openclaw-gateway` verifies service
- Line 57: `exit 0` if both pass (skip)
- Line 61: `clear_marker "${PHASE_NUM}"` if marker exists but service not active

**Evidence:**
```bash
$ grep -n 'check_marker\|is-active\|clear_marker' scripts/install-openclaw.sh
49:    if ! check_marker "${PHASE_NUM}"; then
55:    if systemctl --user is-active --quiet openclaw-gateway 2>/dev/null; then
61:    clear_marker "${PHASE_NUM}"
```

### AC-2: OpenClaw npm installation — PASS

**Expected:** Source nvm, `npm install -g openclaw` with retry (3 attempts), verify `openclaw --version`.

**Result:** Correctly implemented across two functions:
- `source_nvm()` (lines 68-82): Sources nvm, verifies `npm` is on PATH
- `install_openclaw()` (lines 88-102): `retry 3 15 npm install -g openclaw` (3 attempts, 15s delay), verifies `openclaw --version` is non-empty

**Evidence:**
```bash
$ grep -n 'retry\|openclaw --version\|source_nvm\|npm install' scripts/install-openclaw.sh
69:    log_info "Step 1/5: Sourcing nvm"
91:    retry 3 15 npm install -g openclaw
94:    oc_ver="$(openclaw --version 2>/dev/null || true)"
```

### AC-3: Configuration rendering — PASS (with P2 caveat)

**Expected:** Create `~/.openclaw/`, render `templates/openclaw.json.template` -> `~/.openclaw/openclaw.json`, `chmod 600`.

**Result:** Correctly implemented in `render_config()` (lines 109-132):
- Line 112: `mkdir -p "${HOME}/.openclaw"`
- Lines 114-116: `render_template` from `templates/openclaw.json.template` to `~/.openclaw/openclaw.json`
- Line 118: `chmod 600 "${HOME}/.openclaw/openclaw.json"`
- Template file `templates/openclaw.json.template` exists and is valid JSON with proper variable references

**P2 Caveat:** The unresolved placeholder check (line 123: `grep '\${' openclaw.json`) is ineffective because `envsubst` replaces unset variables with empty strings, never leaving `${VAR}` patterns. Missing env vars will silently produce empty values in the JSON. See P2 section below.

### AC-4: Workspace setup — PASS

**Expected:** Create `~/.openclaw/workspace/`, copy `workspace/{AGENTS,SOUL,TOOLS,USER}.md` (only if not already present).

**Result:** Correctly implemented in `setup_workspace()` (lines 139-162):
- Line 142: `mkdir -p "${HOME}/.openclaw/workspace"`
- Line 144: Array of `AGENTS.md SOUL.md TOOLS.md USER.md`
- Line 148: `[[ ! -f "${dst}" ]]` — only copies if destination doesn't exist
- Lines 149-153: Copies from `workspace/` source dir, warns if source missing
- All 4 source files exist in `workspace/` directory

**Evidence:**
```bash
$ ls workspace/AGENTS.md workspace/SOUL.md workspace/TOOLS.md workspace/USER.md
workspace/AGENTS.md  workspace/SOUL.md  workspace/TOOLS.md  workspace/USER.md
```

### AC-5: Systemd user service — FAIL (P0)

**Expected:** Create `~/.config/systemd/user/`, render `templates/openclaw-gateway.service`, `loginctl enable-linger`, `systemctl --user daemon-reload`, enable, start. Wait up to 10s for stabilization.

**Result:** The script code is correctly structured (lines 169-215), BUT the service template `templates/openclaw-gateway.service` uses a non-existent path:

```
ExecStart=${HOME}/.nvm/versions/node/v24/bin/openclaw gateway start
```

After `envsubst` rendering, this becomes:
```
ExecStart=/home/ubuntu/.nvm/versions/node/v24/bin/openclaw gateway start
```

**The path `/home/ubuntu/.nvm/versions/node/v24/bin/openclaw` does NOT exist.** nvm creates full semver directories (`v24.14.1`, `v24.15.0`), never a bare `v24` directory or symlink.

**Evidence:**
```bash
$ ls ~/.nvm/versions/node/
v24.14.1  v24.15.0  v25.9.0

$ ls ~/.nvm/versions/node/v24/bin/openclaw
ls: cannot access '/home/ubuntu/.nvm/versions/node/v24/bin/openclaw': No such file or directory
```

The systemd service would fail to start because `ExecStart` points to a non-existent binary. The `wait_for_service()` 10s stabilization wait and `verify_phase()` checks are correctly implemented but would fail because the underlying service can't start.

**Note:** The currently running `openclaw-gateway` process (pid 1336774 on port 18789) was installed by a different mechanism — its service file at `~/.config/systemd/user/openclaw-gateway.service` uses the correct full path `v24.14.1`. Running `install-openclaw.sh` would **overwrite this working service** with the broken template.

### AC-6: Verification — FAIL (blocked by AC-5)

**Expected:** `systemctl --user is-active openclaw-gateway` returns active, port `${OPENCLAW_PORT}` is listening, set marker `.phase-4-complete`.

**Result:** Code in `verify_phase()` (lines 221-247) is correctly implemented:
- Lines 226-231: Checks `systemctl --user is-active` returns "active"
- Lines 235-241: Port check via `ss` with `curl` health check fallback
- Line 245: `set_marker "${PHASE_NUM}"`

However, this function would fail because AC-5's broken template prevents the service from starting. The service state would not be "active" and the phase marker would never be set.

---

## P0 Bug: Service Template Uses Non-Existent nvm Path

### Severity: P0 — Service cannot start; AC-5 and AC-6 blocked

### Root Cause

**File:** `templates/openclaw-gateway.service`, **lines 7 and 15**

The template hardcodes `v24` as the node version directory, but nvm uses full semver paths (`v24.14.1`, `v24.15.0`). There is no `v24` directory or symlink in `~/.nvm/versions/node/`.

### Affected Lines

| File | Line | Current | Issue |
|------|------|---------|-------|
| `templates/openclaw-gateway.service` | 7 | `ExecStart=${HOME}/.nvm/versions/node/v24/bin/openclaw gateway start` | `v24` doesn't exist |
| `templates/openclaw-gateway.service` | 15 | `Environment=PATH=${HOME}/.nvm/versions/node/v24/bin:...` | `v24` doesn't exist |

### Before/After Code Snippets

**Option A — Fix in the installer script (`scripts/install-openclaw.sh`)**

Add node path resolution before rendering the template, e.g., between `source_nvm()` and `install_service()`:

```bash
# Before render_template in install_service():
NODE_BIN_DIR="$(dirname "$(command -v node)")"
export NODE_BIN_DIR
```

Then update the template to use `${NODE_BIN_DIR}`:
```
ExecStart=${NODE_BIN_DIR}/openclaw gateway start
Environment=PATH=${NODE_BIN_DIR}:/usr/local/bin:/usr/bin:/bin
```

**Option B — Use `which` in the template rendering**

Have the installer resolve and export the exact path before `render_template`:

```bash
export OPENCLAW_BIN="$(command -v openclaw)"
export NODE_BIN_PATH="$(dirname "$(command -v node)")"
```

### Verification Command

```bash
# After fix, verify the rendered service has correct paths:
envsubst < templates/openclaw-gateway.service | grep ExecStart
# Should show a path like: /home/ubuntu/.nvm/versions/node/v24.15.0/bin/openclaw
# NOT: /home/ubuntu/.nvm/versions/node/v24/bin/openclaw

# Verify the path exists:
ls "$(dirname "$(command -v node)")/openclaw"
```

---

## P2 Issue: Placeholder Check Ineffective

### Severity: P2 — False confidence in config validation

### Location

**File:** `scripts/install-openclaw.sh`, **line 123**

```bash
if grep -q '\${' "${HOME}/.openclaw/openclaw.json"; then
```

### Issue

`envsubst` (used by `render_template`) replaces **all** `${VAR}` patterns — including unset variables, which become empty strings. The grep check for literal `${` patterns will never trigger for missing environment variables.

### Impact

If required env vars like `DISCORD_BOT_TOKEN`, `AWS_ACCESS_KEY_ID`, etc. are unset, the rendered JSON will contain empty strings (`""`) rather than `${VAR}` patterns. The check passes silently, but the config is invalid. Example rendered output with unset vars:

```json
"endpoint": "https://bedrock-runtime..amazonaws.com",
"accessKeyId": "",
"secretAccessKey": ""
```

### Suggested Fix

Validate required fields are non-empty after rendering, rather than grepping for `${`:

```bash
# Check critical fields are not empty
local required_fields=("accessKeyId" "secretAccessKey" "token")
for field in "${required_fields[@]}"; do
    if grep -q "\"${field}\": \"\"" "${HOME}/.openclaw/openclaw.json"; then
        log_error "Required field '${field}' is empty in openclaw.json"
        return 1
    fi
done
```

---

## Screenshots

| Screenshot | Description |
|-----------|-------------|
| [task-25-qa-results-overview.png](../test-screenshots/task-25-qa-results-overview.png) | Full test results showing all checks with PASS/FAIL status |
| [task-25-p0-service-template-bug.png](../test-screenshots/task-25-p0-service-template-bug.png) | P0 bug detail: service template uses non-existent v24 path |
| [task-25-ac-summary.png](../test-screenshots/task-25-ac-summary.png) | AC summary table showing AC-5 and AC-6 FAIL |

---

## Console Errors Captured

```
# systemctl --user unavailable in this environment (no D-Bus session bus):
Failed to connect to bus: No medium found

# Template path verification:
ls: cannot access '/home/ubuntu/.nvm/versions/node/v24/bin/openclaw': No such file or directory
```

---

## Summary

| AC | Status | Severity | Notes |
|----|--------|----------|-------|
| AC-1: Idempotency check | PASS | — | Correctly checks marker + service; clears marker if service down |
| AC-2: npm installation | PASS | — | retry 3 15, verifies openclaw --version |
| AC-3: Config rendering | PASS | P2 | Template rendered, chmod 600. Placeholder check ineffective |
| AC-4: Workspace setup | PASS | — | All 4 files, skip-if-exists guard, source files verified |
| AC-5: Systemd service | FAIL | P0 | Template uses `/v24/` path which doesn't exist in nvm |
| AC-6: Verification | FAIL | P0 | Blocked — service can't start due to AC-5 |
| bash -n | PASS | — | Clean syntax |
| shellcheck | PASS | — | Zero warnings |

**Overall: FAIL — 1 P0 bug (service template path) blocks AC-5 and AC-6. 1 P2 issue (placeholder check).**

The install-openclaw.sh script itself is well-structured and follows established patterns from the other installer scripts. AC-1 through AC-4 are correctly implemented. The P0 failure is in the service template (`templates/openclaw-gateway.service`) which uses a bare `v24` path that doesn't match nvm's actual directory structure. The fix requires either resolving the actual node version path in the installer before rendering, or updating the template to use a variable for the node binary directory.
