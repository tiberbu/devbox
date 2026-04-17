# QA Report — Task #27: S2.2: Claude Code Studio Installer (install-studio.sh)

**Date:** 2026-04-17
**QA Depth:** 1/1 (max depth)
**Tester:** QA Agent (opus)
**Verdict:** FAIL — 3x P0, 2x P1 issues found

---

## Pre-Check: Code Committed

**PASS** — Feature commit `510ec0c` exists:
```
510ec0c feat(dev-story): S2.2: Claude Code Studio Installer (install-studio.sh)
```
File `scripts/install-studio.sh` (280 lines, 1 file) is committed to main.
Note: `scripts/install-node.sh` has unrelated uncommitted changes (NVM_VERSION rename) — not part of this feature.

## Quality Gates

| Check | Result |
|-------|--------|
| `bash -n scripts/install-studio.sh` | PASS (exit 0) |
| `shellcheck scripts/install-studio.sh` | PASS (exit 0, zero warnings) |

---

## Acceptance Criteria Results

### AC-1: Idempotency check — PASS

**Evidence:** `scripts/install-studio.sh` lines 47-61

- [x] Checks marker via `check_marker 5` (maps to `/var/tmp/devbox/.phase-5-complete`) — line 48
- [x] Checks `systemctl is-active --quiet claude-studio` — line 54
- [x] If both pass: logs and `exit 0` — lines 55-56
- [x] If marker exists but service not active: `clear_marker 5` and proceeds — lines 59-60

Logic matches the dual-check pattern from the dev notes. Structurally correct.

---

### AC-2: Git clone / pull with token auth — PASS

**Evidence:** `scripts/install-studio.sh` lines 68-120

- [x] Sources nvm (`${HOME}/.nvm/nvm.sh`) — line 73
- [x] Verifies `npm` on PATH with clear error message — lines 75-78
- [x] `git config --global credential.helper store` — line 93
- [x] Writes `https://${GITHUB_TOKEN}@github.com` to `~/.git-credentials` via `printf` — line 96
- [x] `chmod 600 ~/.git-credentials` — line 97
- [x] Clone/pull branch on `[[ -d ~/claude-code-studio/.git ]]` — line 110
- [x] Clone uses `retry 3 5` — line 114

---

### AC-3: Build from source — FAIL (P0)

**Evidence:** `scripts/install-studio.sh` lines 127-144

- [x] `cd ~/claude-code-studio` — line 130
- [x] `retry 3 15 npm install` — line 132
- [ ] **`npm run build`** — line 135 — **WILL FAIL**
- [ ] **Assert `dist/server.js` exists** — line 137 — **WILL ALWAYS FAIL**

#### P0-1: `npm run build` fails — no build script in package.json

The upstream `claude-code-studio` project has NO `build` script:

```json
// ~/claude-code-studio/package.json .scripts
{
  "start": "node server.js",
  "dev": "node --watch server.js",
  "postinstall": "node scripts/install-hooks.js",
  "release": "node scripts/release.js"
}
```

`npm run build` will exit non-zero, triggering `set -e` and aborting the script.

**File:** `scripts/install-studio.sh`, line 135
**Before:**
```bash
npm run build
```
**After:**
```bash
# No build step needed — app runs directly from server.js
log_info "No build step required — app runs from server.js"
```

#### P0-2: `dist/server.js` assertion incorrect — app entry is `server.js`

The app's entry point is `server.js` at the repository root (confirmed by `package.json` main field `auth.js` and start script `node server.js`). There is no `dist/` directory and never will be.

**File:** `scripts/install-studio.sh`, line 137
**Before:**
```bash
if [[ ! -f "${HOME}/claude-code-studio/dist/server.js" ]]; then
    log_error "Build failed — dist/server.js not found after npm run build"
    return 1
fi
```
**After:**
```bash
if [[ ! -f "${HOME}/claude-code-studio/server.js" ]]; then
    log_error "Installation failed — server.js not found in claude-code-studio"
    return 1
fi
```

**Verification:**
```bash
ls ~/claude-code-studio/server.js  # Should exist
ls ~/claude-code-studio/dist/server.js  # Does NOT exist
```

---

### AC-4: Configuration rendering — FAIL (P1)

**Evidence:** `scripts/install-studio.sh` lines 151-170

- [x] `render_template` called correctly — lines 154-156
- [x] Grep for unresolved `${` placeholders — lines 161-165
- [x] Template variables `${HOME}` and `${CLAUDE_STUDIO_PORT}` exported — line 39

#### P1-2: Config template does not match actual app configuration schema

The template `templates/claude-studio-config.json.template` renders:
```json
{
  "port": 3000,
  "auth": { "type": "cookie", "cookiePath": "/tmp/ccs.cookie" },
  "projects": [{ "name": "frappe-bench", "path": "/home/ubuntu/frappe-bench" }]
}
```

The actual running app uses a completely different config schema with `mcpServers`, `skills`, `slashCommands`, `projects` (different structure), and `lang` fields. Rendering this template would **overwrite the working configuration** and likely cause the app to malfunction or lose all MCP server integrations.

**File:** `templates/claude-studio-config.json.template`
**Fix:** Update the template to match the actual config schema expected by claude-code-studio, or skip config rendering if a config.json already exists.

**Verification:**
```bash
cat ~/claude-code-studio/config.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(list(d.keys()))"
# Actual: ['mcpServers', 'skills', 'slashCommands', 'lang', 'projects']
```

---

### AC-5: Systemd system service — FAIL (P0)

**Evidence:** `scripts/install-studio.sh` lines 177-219, `templates/claude-studio.service`

- [x] Renders to temp file `/tmp/claude-studio.service.rendered` — line 180-182
- [x] `sudo cp` to `/etc/systemd/system/` — line 183
- [x] `sudo systemctl daemon-reload` — line 186
- [x] `sudo systemctl enable` — line 189
- [x] `sudo systemctl start` — line 192
- [x] 15-iteration poll with 1s sleep — lines 202-219
- [x] Status dump on timeout — line 217

#### P0-3: Node binary path `v24` does not exist — service will fail to start

The template `templates/claude-studio.service` line 9:
```
ExecStart=${HOME}/.nvm/versions/node/v24/bin/node dist/server.js
```

Two problems:
1. **Path `v24` does not exist** — nvm installs to versioned directories like `v24.14.1` or `v24.15.0`, not a bare `v24`:
   ```
   $ ls ~/.nvm/versions/node/
   v24.14.1/  v24.15.0/  v25.9.0/
   
   $ ls ~/.nvm/versions/node/v24/bin/node
   No such file or directory
   ```
2. **Entry point is `server.js`, not `dist/server.js`** (same as P0-2)

The rendered service file would reference a non-existent node binary, causing `systemctl start` to fail immediately.

**File:** `templates/claude-studio.service`, line 9
**Before:**
```
ExecStart=${HOME}/.nvm/versions/node/v24/bin/node dist/server.js
```
**After (option A — resolve nvm path dynamically in the install script):**
```
ExecStart=${NODE_BIN_PATH} server.js
```
And in `install-studio.sh`, before `render_template`:
```bash
NODE_BIN_PATH="$(command -v node)"
export NODE_BIN_PATH
```

**Also fix line 14** (same `v24` issue in PATH):
```
Environment=PATH=${HOME}/.nvm/versions/node/v24/bin:/usr/local/bin:/usr/bin:/bin
```

**Verification:**
```bash
ls ~/.nvm/versions/node/v24/bin/node  # FAILS — does not exist
command -v node  # Returns actual path like ~/.nvm/versions/node/v24.15.0/bin/node
```

The currently installed service file (configured manually) correctly uses `v24.14.1`:
```
ExecStart=/home/ubuntu/.nvm/versions/node/v24.14.1/bin/node server.js
```

---

### AC-6: Verification and marker — FAIL (P1)

**Evidence:** `scripts/install-studio.sh` lines 225-252

- [x] `systemctl is-active claude-studio` check — lines 229-235
- [ ] **HTTP 200 check** — lines 239-246 — **WILL FAIL (gets 302)**
- [x] `set_marker 5` — line 250

#### P1-1: HTTP check expects 200 but app returns 302

```bash
$ curl -s -o /dev/null -w "%{http_code}" http://localhost:3000
302
```

The root URL redirects to `/login` (HTTP 302). The script checks for exactly `200`:
```bash
if [[ "${http_code}" == "200" ]]; then
```

This will always fail, preventing the marker from being set.

**File:** `scripts/install-studio.sh`, lines 240-242
**Before:**
```bash
http_code="$(curl -s -o /dev/null -w "%{http_code}" \
    "http://localhost:${CLAUDE_STUDIO_PORT}" 2>/dev/null || true)"
if [[ "${http_code}" == "200" ]]; then
```
**After (option A — follow redirects):**
```bash
http_code="$(curl -sL -o /dev/null -w "%{http_code}" \
    "http://localhost:${CLAUDE_STUDIO_PORT}" 2>/dev/null || true)"
if [[ "${http_code}" == "200" ]]; then
```
**After (option B — accept 2xx/3xx):**
```bash
http_code="$(curl -s -o /dev/null -w "%{http_code}" \
    "http://localhost:${CLAUDE_STUDIO_PORT}" 2>/dev/null || true)"
if [[ "${http_code}" =~ ^[23] ]]; then
```

**Verification:**
```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000       # Returns 302
curl -sL -o /dev/null -w "%{http_code}" http://localhost:3000      # Returns 200
```

---

## Screenshots

| Screenshot | Description |
|-----------|-------------|
| `test-screenshots/task-27-studio-running-state.png` | Claude Code Studio login page at localhost:3000 (service is active) |
| `test-screenshots/task-27-studio-http-response.png` | HTTP response behavior (302 redirect to /login) |
| `test-screenshots/task-27-critical-findings.png` | Summary of all P0/P1 findings with evidence |

## Console Errors

No browser console errors detected during Playwright testing.

---

## Summary of Issues

| ID | Severity | AC | Issue | File:Line |
|----|----------|----|-------|-----------|
| P0-1 | **P0** | AC-3 | `npm run build` fails — no build script in package.json | `scripts/install-studio.sh:135` |
| P0-2 | **P0** | AC-3 | `dist/server.js` assertion incorrect — app entry is `server.js` | `scripts/install-studio.sh:137` |
| P0-3 | **P0** | AC-5 | Node path `v24` does not exist — service will not start | `templates/claude-studio.service:9,14` |
| P1-1 | **P1** | AC-6 | HTTP check expects 200, app returns 302 | `scripts/install-studio.sh:242` |
| P1-2 | **P1** | AC-4 | Config template schema doesn't match actual app config | `templates/claude-studio-config.json.template` |

**The script has never been successfully executed.** The currently running Claude Studio service was configured manually with correct paths (`v24.14.1`, `server.js`). The install script as committed would fail at AC-3 (`npm run build`) and never reach AC-4, AC-5, or AC-6.

---

## Regression Check

No regressions in other scripts. The `install-openclaw.sh` (Phase 4) structure was correctly used as a reference template, but the Claude Studio-specific values (build step, entry point, node path) do not match the actual upstream project.
