# Story 3.1: Config Templates and Workspace Files

Status: ready-for-dev

**Story ID:** S7
**Epic:** E3 — Configuration & Templates
**Points:** 5
**Estimated Hours:** 2
**Priority:** P0 — Required by S4 (OpenClaw installer), S5 (Claude Studio installer), S9 (configure.sh)
**Dependencies:** None (templates are static files with placeholders; no prior phase required)

---

## Story

As a Tiberbu DevBox bootstrap system,
I want all configuration templates (with `${VAR}` placeholders) and default OpenClaw workspace files to exist in the repository,
so that the OpenClaw installer, Claude Studio installer, and configure.sh can use `envsubst` to inject credentials at runtime without any manual editing.

---

## Acceptance Criteria

### AC-1: templates/openclaw.json.template — OpenClaw config with envsubst placeholders
1. Valid JSON structure with `${VAR}` placeholders throughout (braces required for envsubst)
2. `models.providers.amazon-bedrock` section present with:
   - `endpoint`: `https://bedrock-runtime.${BEDROCK_REGION}.amazonaws.com`
   - `credentials.accessKeyId`: `${AWS_ACCESS_KEY_ID}`
   - `credentials.secretAccessKey`: `${AWS_SECRET_ACCESS_KEY}`
   - `models.primary.id`: `${BEDROCK_MODEL}`, `maxTokens`: `16384`
3. `agents.defaults` section present with:
   - `workspace`: `${HOME}/.openclaw/workspace`
   - `primaryModel`: `amazon-bedrock:${BEDROCK_MODEL}`
   - `memory.search.provider`: `amazon-bedrock`, `model`: `amazon.titan-embed-text-v2:0`
4. `gateway` section: `mode`: `local`, `auth`: `token`, `port`: `${OPENCLAW_PORT}`, `bind`: `loopback`
5. `channels.discord` section with:
   - `token`: `${DISCORD_BOT_TOKEN}`
   - `guild`: `${DISCORD_GUILD_ID}`
   - `channels[0].id`: `${DISCORD_CHANNEL_ID}`, `streaming`: `true`, `autoPresence`: `true`
   - `allowlist`: `["${DISCORD_USER_ID}"]`
6. `plugins.entries` array with: `amazon-bedrock` (discovery: true), `anthropic`, `acpx`
7. `hooks.internal` array: `["boot-md", "session-memory"]`
8. `tools.profile`: `"coding"`
9. Template renders to valid JSON when all vars exported (no unsubstituted `${VAR}` remains)

### AC-2: templates/openclaw-gateway.service — systemd user unit
1. Valid systemd INI-style unit file format
2. `[Unit]` section: `Description=OpenClaw Gateway`, `After=network.target`
3. `[Service]` section with:
   - `Type=simple`
   - `ExecStart=${HOME}/.nvm/versions/node/v24/bin/openclaw gateway start`
   - `WorkingDirectory=${HOME}/.openclaw`
   - `Restart=always`, `RestartSec=5`
   - `Environment=HOME=${HOME}`
   - `Environment=AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}`
   - `Environment=AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}`
   - `Environment=AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}`
   - `Environment=PATH=${HOME}/.nvm/versions/node/v24/bin:/usr/local/bin:/usr/bin:/bin`
4. `[Install]` section: `WantedBy=default.target`
5. Target install location is `~/.config/systemd/user/` (user service, not system)

### AC-3: templates/claude-studio.service — systemd system unit
1. Valid systemd INI-style unit file format
2. `[Unit]` section: `Description=Claude Code Studio`, `After=network.target`
3. `[Service]` section with:
   - `Type=simple`
   - `User=${USER}`
   - `WorkingDirectory=${HOME}/claude-code-studio`
   - `ExecStart=${HOME}/.nvm/versions/node/v24/bin/node dist/server.js`
   - `Restart=always`, `RestartSec=5`
   - `Environment=PORT=${CLAUDE_STUDIO_PORT}`
   - `Environment=HOME=${HOME}`
   - `Environment=PATH=${HOME}/.nvm/versions/node/v24/bin:/usr/local/bin:/usr/bin:/bin`
   - `Environment=NODE_ENV=production`
4. `[Install]` section: `WantedBy=multi-user.target`
5. Target install location is `/etc/systemd/system/` (system service)

### AC-4: templates/claude-studio-config.json.template — Claude Studio config
1. Valid JSON structure with `${VAR}` placeholders
2. `port`: `${CLAUDE_STUDIO_PORT}` (rendered as integer after envsubst)
3. `auth` section: `type`: `cookie`, `cookiePath`: `/tmp/ccs.cookie`
4. `projects` array with at least one entry: `name`: `frappe-bench`, `path`: `${HOME}/frappe-bench`
5. Renders to valid JSON with no unsubstituted placeholders when all vars exported

### AC-5: workspace/AGENTS.md — default agent definition
1. Provides a default agent definition for the OpenClaw workspace context
2. Instructs the AI agent to focus on code assistance and Frappe/ERPNext development
3. Includes guidance on using available tools (shell execution, file I/O, git, bench CLI)
4. Mentions the Frappe Bench environment at `~/frappe-bench`

### AC-6: workspace/SOUL.md — agent personality
1. Defines personality traits: professional, concise, technical, solution-oriented
2. Sets communication style appropriate for a developer assistant (no corporate jargon)
3. Specifies response format preferences (code blocks, short explanations)

### AC-7: workspace/TOOLS.md — available tools reference
1. Lists the tools available to the agent: shell execution, file read/write, git operations, bench CLI commands
2. Provides usage guidance and safety constraints for each tool category
3. Notes bench-specific commands (`bench start`, `bench migrate`, `bench --site doctor`, etc.)

### AC-8: workspace/USER.md — user context template
1. Structured template for engineer-specific context (name, project, preferences)
2. Contains placeholder sections the engineer fills in at first use
3. Includes a section for current project focus within `~/frappe-bench`

---

## Tasks / Subtasks

- [ ] Task 1: Create `templates/openclaw.json.template` (AC: 1)
  - [ ] 1.1 Create `templates/` directory if it doesn't exist
  - [ ] 1.2 Write the full JSON template with all `${VAR}` placeholders per AC-1
  - [ ] 1.3 Validate it is valid JSON when placeholders are replaced with literal strings
  - [ ] 1.4 Verify all 10 required variables from the Template Variable Matrix are present

- [ ] Task 2: Create `templates/openclaw-gateway.service` (AC: 2)
  - [ ] 2.1 Write the systemd user unit file with all `[Unit]`, `[Service]`, `[Install]` sections
  - [ ] 2.2 Confirm all 5 required environment variables (HOME, AWS keys, REGION, PATH) are present
  - [ ] 2.3 Verify `WantedBy=default.target` (user service pattern)

- [ ] Task 3: Create `templates/claude-studio.service` (AC: 3)
  - [ ] 3.1 Write the systemd system unit file with User, WorkingDirectory, ExecStart per AC-3
  - [ ] 3.2 Confirm all environment variables (PORT, HOME, PATH, NODE_ENV) are present
  - [ ] 3.3 Verify `WantedBy=multi-user.target` (system service pattern)

- [ ] Task 4: Create `templates/claude-studio-config.json.template` (AC: 4)
  - [ ] 4.1 Write the JSON config template with port, auth, and projects sections
  - [ ] 4.2 Verify renders to valid JSON when vars are substituted

- [ ] Task 5: Create `workspace/AGENTS.md` (AC: 5)
  - [ ] 5.1 Create `workspace/` directory if it doesn't exist
  - [ ] 5.2 Write agent definition with Frappe development focus
  - [ ] 5.3 Include tool usage guidance

- [ ] Task 6: Create `workspace/SOUL.md` (AC: 6)
  - [ ] 6.1 Write personality definition (professional, technical, concise)
  - [ ] 6.2 Include communication style and response format preferences

- [ ] Task 7: Create `workspace/TOOLS.md` (AC: 7)
  - [ ] 7.1 List available tool categories: shell, file, git, bench CLI
  - [ ] 7.2 Add usage notes and safety constraints per tool

- [ ] Task 8: Create `workspace/USER.md` (AC: 8)
  - [ ] 8.1 Write template with placeholder sections for engineer to fill in
  - [ ] 8.2 Include section for Frappe project context

- [ ] Task 9: Smoke-test envsubst rendering (AC: 1, 4)
  - [ ] 9.1 Export all required variables with dummy values
  - [ ] 9.2 Run `envsubst < templates/openclaw.json.template | python3 -m json.tool` — must pass
  - [ ] 9.3 Run `envsubst < templates/claude-studio-config.json.template | python3 -m json.tool` — must pass
  - [ ] 9.4 Confirm no literal `${` remains in rendered output

---

## Dev Notes

### Template Rendering Pattern
All templates use `${VARIABLE}` syntax (curly braces required). The `render_template()` function from `scripts/_common.sh` invokes:
```bash
envsubst < "$template" > "$output"
```
Variables must be exported before `envsubst` is called. The `bootstrap.sh` orchestrator exports all variables via `set -a; source ~/.tiberbu-env; set +a`.

### Template Variable Matrix (from architecture.md §6)
| Variable | openclaw.json | gw.service | studio.service | studio-config |
|---|---|---|---|---|
| `AWS_ACCESS_KEY_ID` | ✓ | ✓ | | |
| `AWS_SECRET_ACCESS_KEY` | ✓ | ✓ | | |
| `AWS_DEFAULT_REGION` | | ✓ | | |
| `BEDROCK_REGION` | ✓ | | | |
| `BEDROCK_MODEL` | ✓ | | | |
| `DISCORD_BOT_TOKEN` | ✓ | | | |
| `DISCORD_GUILD_ID` | ✓ | | | |
| `DISCORD_CHANNEL_ID` | ✓ | | | |
| `DISCORD_USER_ID` | ✓ | | | |
| `OPENCLAW_PORT` | ✓ | | | |
| `HOME` | ✓ | ✓ | ✓ | ✓ |
| `USER` | | | ✓ | |
| `CLAUDE_STUDIO_PORT` | | | ✓ | ✓ |

### JSON Template Escaping
JSON templates containing `${VAR}` for integer fields (e.g., `"port": ${CLAUDE_STUDIO_PORT}`) are valid template syntax but result in a number after substitution. Do NOT quote integer placeholders in JSON templates.

### Systemd Node Path Convention
The path `${HOME}/.nvm/versions/node/v24/bin/` assumes nvm creates a `v24` symlink or uses the major-version directory. If nvm uses the full version path (e.g., `v24.14.1`), the installer script (S4, S5) must resolve this and either create the symlink or update the ExecStart path post-render. See architecture.md §4.2 and S4/S5 technical notes.

### Workspace Files Consumed By
- `install-openclaw.sh` (S4) copies all 4 workspace files to `~/.openclaw/workspace/`
- Files are NOT templates (no `${VAR}` placeholders) — they are static markdown
- Engineers are expected to customize them after bootstrap completes

### Security Note
`openclaw.json` contains AWS credentials and Discord tokens. After rendering:
- `install-openclaw.sh` must `chmod 600 ~/.openclaw/openclaw.json`
- This is enforced in S4, not in this story

### Default Values Reference (from bootstrap.sh load_env_file)
| Variable | Default |
|---|---|
| `BEDROCK_REGION` | `us-west-1` |
| `BEDROCK_MODEL` | `global.anthropic.claude-opus-4-6-v1` |
| `OPENCLAW_PORT` | `18789` |
| `CLAUDE_STUDIO_PORT` | `3000` |

### Project Structure Notes

**Files to create (this story owns all 8):**
```
devbox/
├── templates/
│   ├── openclaw.json.template             # New — AC-1
│   ├── openclaw-gateway.service           # New — AC-2
│   ├── claude-studio.service              # New — AC-3
│   └── claude-studio-config.json.template # New — AC-4
└── workspace/
    ├── AGENTS.md                          # New — AC-5
    ├── SOUL.md                            # New — AC-6
    ├── TOOLS.md                           # New — AC-7
    └── USER.md                            # New — AC-8
```

**Alignment with architecture.md §4.1 (Repository Structure):**
- `templates/` directory maps exactly to architecture spec
- `workspace/` directory maps exactly to architecture spec
- No conflicts with other stories — this story creates new files only

**Downstream consumers (do NOT modify in this story):**
- `scripts/install-openclaw.sh` (S4): reads `templates/openclaw.json.template`, `templates/openclaw-gateway.service`, copies `workspace/` files
- `scripts/install-studio.sh` (S5): reads `templates/claude-studio.service`, `templates/claude-studio-config.json.template`
- `configure.sh` (S9): re-renders all 4 templates with new credentials

### References

- Template variable matrix: [Source: _bmad-output/planning-artifacts/architecture.md#6-template-variable-matrix]
- Template content examples: [Source: _bmad-output/planning-artifacts/prd.md#template-design]
- Installed paths for rendered configs: [Source: _bmad-output/planning-artifacts/architecture.md#4-2-installed-paths-on-target-ec2]
- render_template() API: [Source: _bmad-output/planning-artifacts/architecture.md#5-1-api-surface]
- E3 epic goal: [Source: _bmad-output/planning-artifacts/epics.md#epic-3-configuration-templates]
- FR-6 (OpenClaw config): [Source: _bmad-output/planning-artifacts/prd.md#fr-6-phase-4-openclaw-configuration]
- FR-7 (Claude Studio config): [Source: _bmad-output/planning-artifacts/prd.md#fr-7-phase-5-claude-code-studio]

---

## Definition of Done

- [ ] All 4 template files exist in `templates/`
- [ ] All 4 workspace files exist in `workspace/`
- [ ] `envsubst` with all required variables exported renders `openclaw.json.template` to valid JSON (`python3 -m json.tool` passes)
- [ ] `envsubst` renders `claude-studio-config.json.template` to valid JSON
- [ ] `envsubst` renders both `.service` files with no unsubstituted `${VAR}` placeholders
- [ ] Workspace files contain meaningful, non-trivial default content
- [ ] No file contains raw shell credentials or real tokens

---

## Dev Agent Record

### Agent Model Used

_to be filled by dev agent_

### Debug Log References

_to be filled by dev agent_

### Completion Notes List

_to be filled by dev agent_

### File List

- `templates/openclaw.json.template`
- `templates/openclaw-gateway.service`
- `templates/claude-studio.service`
- `templates/claude-studio-config.json.template`
- `workspace/AGENTS.md`
- `workspace/SOUL.md`
- `workspace/TOOLS.md`
- `workspace/USER.md`
