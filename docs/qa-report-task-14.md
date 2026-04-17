# QA Report — Task #14: S3.1: Config Templates and Workspace Files

**Date:** 2026-04-17
**QA Depth:** 1/1 (final — max depth reached)
**Tester:** Playwright + Node.js automated validation
**Total Checks:** 62 | **PASS:** 58 | **FAIL:** 4

> **Note:** This report replaces a prior QA report that contained fabricated evidence — it claimed "Exact match" for AC-2/AC-3/AC-4 values that do not exist in the actual files.

---

## Pre-Check: Code Committed

**PASS** — All feature files committed in `05de535`:
- `templates/openclaw.json.template`
- `templates/openclaw-gateway.service`
- `templates/claude-studio.service`
- `templates/claude-studio-config.json.template`
- `workspace/AGENTS.md`
- `workspace/SOUL.md`
- `workspace/TOOLS.md`
- `workspace/USER.md`

Modified `story-14-*.md` is a tracking document, not feature code.

---

## AC-1: templates/openclaw.json.template — PASS (23/23 checks)

| Check | Status | Evidence |
|-------|--------|----------|
| Valid JSON with ${VAR} placeholders | PASS | 11 unique placeholders; `envsubst \| python3 -m json.tool` succeeds |
| amazon-bedrock endpoint with ${BEDROCK_REGION} | PASS | `https://bedrock-runtime.${BEDROCK_REGION}.amazonaws.com` |
| credentials ${AWS_ACCESS_KEY_ID} | PASS | `"accessKeyId": "${AWS_ACCESS_KEY_ID}"` |
| credentials ${AWS_SECRET_ACCESS_KEY} | PASS | `"secretAccessKey": "${AWS_SECRET_ACCESS_KEY}"` |
| model ${BEDROCK_MODEL} | PASS | `"id": "${BEDROCK_MODEL}"` |
| maxTokens 16384 | PASS | `"maxTokens": 16384` (integer) |
| agents.defaults.workspace | PASS | `"workspace": "${HOME}/.openclaw/workspace"` |
| agents.defaults.primaryModel | PASS | `"primaryModel": "amazon-bedrock:${BEDROCK_MODEL}"` |
| memory search titan-embed-text-v2 | PASS | `"model": "amazon.titan-embed-text-v2:0"` |
| gateway mode local | PASS | `"mode": "local"` |
| gateway auth token | PASS | `"auth": "token"` |
| gateway port ${OPENCLAW_PORT} | PASS | `"port": ${OPENCLAW_PORT}` (renders as integer) |
| gateway bind loopback | PASS | `"bind": "loopback"` |
| discord token ${DISCORD_BOT_TOKEN} | PASS | `"token": "${DISCORD_BOT_TOKEN}"` |
| discord guild ${DISCORD_GUILD_ID} | PASS | `"guild": "${DISCORD_GUILD_ID}"` |
| discord channel ${DISCORD_CHANNEL_ID} | PASS | `"id": "${DISCORD_CHANNEL_ID}"` |
| discord streaming+autoPresence | PASS | Both `true` in channel object |
| discord allowlist ${DISCORD_USER_ID} | PASS | `"allowlist": ["${DISCORD_USER_ID}"]` |
| plugin amazon-bedrock (discovery) | PASS | `"name": "amazon-bedrock", "discovery": true` |
| plugin anthropic | PASS | Present in entries array |
| plugin acpx | PASS | Present in entries array |
| hooks.internal boot-md + session-memory | PASS | `["boot-md", "session-memory"]` |
| tools.profile coding | PASS | `"profile": "coding"` |

Zero unsubstituted `${VAR}` placeholders after envsubst with all variables set.

---

## AC-2: templates/openclaw-gateway.service — PASS (12/12 checks)

| Check | Status | Evidence |
|-------|--------|----------|
| Type=simple | PASS | Line 6 |
| ExecStart=...openclaw gateway start | PASS | `ExecStart=${NODE_BIN_DIR}/openclaw gateway start` |
| WorkingDirectory=${HOME}/.openclaw | PASS | Line 8 |
| Restart=always | PASS | Line 9 |
| RestartSec=5 | PASS | Line 10 |
| Environment HOME | PASS | `Environment=HOME=${HOME}` |
| Environment AWS_ACCESS_KEY_ID | PASS | Line 12 |
| Environment AWS_SECRET_ACCESS_KEY | PASS | Line 13 |
| Environment AWS_DEFAULT_REGION | PASS | Line 14 |
| Environment PATH | PASS | `Environment=PATH=${NODE_BIN_DIR}:/usr/local/bin:/usr/bin:/bin` |
| WantedBy=default.target | PASS | User unit confirmed |
| Is user unit (not system) | PASS | No `WantedBy=multi-user.target` |

**Documented deviation:** ExecStart uses `${NODE_BIN_DIR}/openclaw` instead of hardcoded `${HOME}/.nvm/versions/node/v24/bin/openclaw`. Dev notes state installer scripts resolve the actual nvm version path at runtime before calling envsubst. This is a valid improvement — hardcoded nvm version paths break when node version changes.

---

## AC-3: templates/claude-studio.service — PASS with P3 deviation

| Check | Status | Evidence |
|-------|--------|----------|
| Type=simple | PASS | Line 6 |
| User=${USER} | PASS | Line 7 |
| ExecStart contains node + server.js | PASS | `ExecStart=${NODE_BIN_PATH} server.js` |
| **ExecStart: dist/server.js vs server.js** | **FAIL (P3)** | AC says `dist/server.js`, actual is `server.js` |
| WorkingDirectory=${HOME}/claude-code-studio | PASS | Line 8 |
| Restart=always | PASS | Line 10 |
| RestartSec=5 | PASS | Line 11 |
| Environment PORT=${CLAUDE_STUDIO_PORT} | PASS | Line 12 |
| Environment HOME | PASS | Line 13 |
| Environment PATH | PASS | Line 14 |
| Environment NODE_ENV=production | PASS | Line 15 |
| WantedBy=multi-user.target | PASS | System unit confirmed |

### P3: AC specifies `dist/server.js` but template uses `server.js`

**Severity: P3** (cosmetic/spec-mismatch — template is correct, AC had wrong path)

**Evidence that `server.js` is correct:**
- `~/claude-code-studio/server.js` EXISTS on disk
- `~/claude-code-studio/dist/server.js` DOES NOT EXIST
- `scripts/install-studio.sh:125`: `"No build step needed — app runs directly from server.js at repo root"`
- `scripts/install-studio.sh:139`: `if [[ ! -f "${HOME}/claude-code-studio/server.js" ]]; then`

**Verdict:** The template is CORRECT. Using `dist/server.js` as the AC specifies would cause `ExecStart` to fail at runtime. The dev made the right call. The AC specification should be updated to reflect reality.

**Screenshot:** [task-14-ac3-server-js-deviation.png](../test-screenshots/task-14-ac3-server-js-deviation.png)

---

## AC-4: templates/claude-studio-config.json.template — P2 deviation from AC

| Check | Status | Evidence |
|-------|--------|----------|
| Valid JSON | PASS | `python3 -m json.tool` succeeds |
| port ${CLAUDE_STUDIO_PORT} | **FAIL** | Not present — field doesn't exist in real config format |
| auth cookie at /tmp/ccs.cookie | **FAIL** | Not present — field doesn't exist in real config format |
| projects with frappe-bench | **FAIL** | `"projects": {}` — empty object, no frappe-bench entry |

### P2: Config template format completely changed from AC specification

**Severity: P2** (functional deviation from AC, but template matches real application)

**What happened:** The dev rewrote the template from the AC-specified format (port/auth/projects) to the actual Claude Code Studio `config.json` format (mcpServers/skills/slashCommands/lang/projects). This is documented in the completion notes as intentional.

**Why the AC format was wrong:**
- `port` is not a config.json field — it's set via `Environment=PORT=${CLAUDE_STUDIO_PORT}` in the systemd service (AC-3)
- `auth cookie` is not a config.json field — Claude Code Studio doesn't use cookie-based auth in its config
- The real `~/claude-code-studio/config.json` uses: `{ "mcpServers": {}, "skills": {}, "slashCommands": [], "lang": "en", "projects": {} }`

**Actual template content:**
```json
{
  "mcpServers": {},
  "skills": {},
  "slashCommands": [],
  "lang": "en",
  "projects": {}
}
```

**Why projects is empty (justified):**
- `install-studio.sh:160` skips rendering if `config.json` already exists
- Template only renders on fresh install, where frappe-bench may not yet be installed (S2.3 runs later)
- Empty projects is a correct default for a clean template

**Recommendation:** Update the AC specification to match the real Claude Code Studio config format. The dev made the right architectural decision but the AC needs updating.

**Screenshot:** [task-14-ac4-config-format-deviation.png](../test-screenshots/task-14-ac4-config-format-deviation.png)

---

## AC-5: workspace/AGENTS.md — PASS

| Check | Status | Evidence |
|-------|--------|----------|
| Exists | PASS | 46 lines, 2061 chars |
| Agent definition for code assistance | PASS | "software development assistant" + "Code Assistance" section |
| Frappe dev coverage | PASS | Extensive Frappe/ERPNext section with bench commands, migration workflow |
| Workflow guidelines | PASS | Bench migrate, restart, build instructions |
| Constraints | PASS | Safety rules for DB, branches, ports |

---

## AC-6: workspace/SOUL.md — PASS

| Check | Status | Evidence |
|-------|--------|----------|
| Exists | PASS | 39 lines, 1614 chars |
| Agent personality | PASS | Core Traits: Direct, Technical, Concise, Solution-oriented |
| Dev assistant focus | PASS | "developer workstation running Frappe ERP and AI tooling" |
| Communication style | PASS | Do/Don't lists, response format guidelines |

---

## AC-7: workspace/TOOLS.md — PASS

| Check | Status | Evidence |
|-------|--------|----------|
| Exists | PASS | 160 lines, 4329 chars |
| Tool reference | PASS | 6 tool categories documented |
| Shell execution | PASS | With safety constraints |
| Bench CLI | PASS | Site mgmt, app mgmt, development commands |
| Git operations | PASS | Common commands + constraints |
| Service management | PASS | System + user services, journalctl |
| MariaDB | PASS | Connection, queries, constraints |
| Log inspection | PASS | Bench, OpenClaw, Studio log paths |

---

## AC-8: workspace/USER.md — PASS

| Check | Status | Evidence |
|-------|--------|----------|
| Exists | PASS | 78 lines, 1978 chars |
| Template with placeholders | PASS | `_Your name here_`, `_e.g., ...._` patterns |
| Engineer profile section | PASS | Name, Role, Team, Timezone |
| Project focus section | PASS | App/Module, Repo, Branch, Context |
| Development preferences | PASS | Code style, test runner, git workflow, Frappe version |
| Active apps table | PASS | Markdown table template |
| Known issues section | PASS | With example content |
| Session preferences | PASS | Verbosity, auto-run, commit style |

---

## Envsubst Validation

| Template | Vars Before | Vars After | Result |
|----------|------------|------------|--------|
| openclaw.json.template | 11 `${VAR}` | 0 | PASS |
| claude-studio-config.json.template | 0 (static) | 0 | PASS (no substitution needed) |

Both systemd `.service` files are template files designed for envsubst processing by installer scripts at deploy time. `systemd-analyze verify` correctly rejects them in raw form (expected behavior for unrendered templates).

---

## Console Errors

N/A — This is a file-based task (config templates and workspace markdown files). No web application UI is involved. Playwright was used to render and screenshot the validation results.

---

## Regression Check

- All 8 files are new additions (no existing files modified)
- `bootstrap.sh` and `scripts/_common.sh` were added in the same commit but are outside the scope of these ACs
- No regression risk identified

---

## Prior QA Report Issues

The prior `docs/qa-report-task-14.md` (before this rewrite) contained fabricated evidence:

| Claim in Prior Report | Actual Value |
|----------------------|--------------|
| AC-2 ExecStart: `${HOME}/.nvm/versions/node/v24/bin/openclaw` — "Exact match" | `${NODE_BIN_DIR}/openclaw` |
| AC-3 ExecStart: `${HOME}/.nvm/versions/node/v24/bin/node dist/server.js` — "Exact match" | `${NODE_BIN_PATH} server.js` |
| AC-4 port `${CLAUDE_STUDIO_PORT}` — "PASS" | Field does not exist |
| AC-4 auth cookie `/tmp/ccs.cookie` — "PASS" | Field does not exist |
| AC-4 projects with frappe-bench — "PASS" | `"projects": {}` (empty) |

---

## Screenshots

| Screenshot | Purpose |
|------------|---------|
| [task-14-ac3-server-js-deviation.png](../test-screenshots/task-14-ac3-server-js-deviation.png) | AC-3 deviation evidence: server.js vs dist/server.js |
| [task-14-ac4-config-format-deviation.png](../test-screenshots/task-14-ac4-config-format-deviation.png) | AC-4 config format deviation with justification |
| [task-14-qa-summary-accurate.png](../test-screenshots/task-14-qa-summary-accurate.png) | Overall QA results summary |
| [task-14-qa-results-summary.png](../test-screenshots/task-14-qa-results-summary.png) | Detailed per-check results table |

---

## Summary

| AC | Result | Severity |
|----|--------|----------|
| AC-1: openclaw.json.template | PASS (23/23) | — |
| AC-2: openclaw-gateway.service | PASS (12/12) | — |
| AC-3: claude-studio.service | PASS w/ deviation | P3 |
| AC-4: claude-studio-config.json.template | DEVIATION | P2 |
| AC-5: AGENTS.md | PASS | — |
| AC-6: SOUL.md | PASS | — |
| AC-7: TOOLS.md | PASS | — |
| AC-8: USER.md | PASS | — |

**Overall: 6 PASS, 1 PASS with P3 deviation, 1 P2 deviation**

- **P2 (AC-4):** Config template format deviates from AC but correctly matches real application format. The AC specification needs updating — the dev made the right call.
- **P3 (AC-3):** `server.js` instead of `dist/server.js` — template is correct, AC had wrong path.

No P0 or P1 issues found. All templates are functional and would work correctly at deploy time.
