# Story 5: Claude Code Studio Installer

**Story ID:** S5
**Epic:** E2 — Application Stack
**Points:** 3
**Estimated Hours:** 1.5
**Priority:** P1 — Phase 5 of bootstrap
**Dependencies:** S1 (_common.sh), S3 (Node.js/npm available), S7 (templates/claude-studio.service, templates/claude-studio-config.json.template)

---

## Description

Create `scripts/install-studio.sh` — the Phase 5 installer that clones Claude Code Studio from GitHub using token authentication, runs `npm install` and `npm run build`, renders systemd service and config templates, and starts the service.

---

## Acceptance Criteria

### AC-1: Idempotency check
- [ ] Checks marker file `.phase-5-complete` AND `systemctl is-active claude-studio`
- [ ] If both pass: logs "Phase 5 already complete, skipping" and exits 0
- [ ] If marker exists but service not active: clears marker and re-runs

### AC-2: Git clone
- [ ] Sources nvm to get node/npm on PATH
- [ ] Configures git credential helper: `git config --global credential.helper store`
- [ ] Writes GitHub credentials: `echo "https://${GITHUB_TOKEN}@github.com" > ~/.git-credentials && chmod 600 ~/.git-credentials`
- [ ] Clones repository: `git clone https://github.com/Mwogi/claude-code-studio.git ~/claude-code-studio`
- [ ] Uses retry logic (3 attempts with 5s delay)
- [ ] If `~/claude-code-studio` already exists, runs `git pull` instead of clone

### AC-3: Build from source
- [ ] Changes to `~/claude-code-studio` directory
- [ ] Runs `npm install` with retry logic (3 attempts)
- [ ] Runs `npm run build`
- [ ] Verifies: `dist/server.js` exists after build

### AC-4: Configuration rendering
- [ ] Uses `render_template` to render `templates/claude-studio-config.json.template` → `~/claude-code-studio/config.json`
- [ ] Config includes project paths (frappe-bench)

### AC-5: Systemd system service
- [ ] Uses `render_template` to render `templates/claude-studio.service` → a temp file
- [ ] Copies rendered service to `/etc/systemd/system/claude-studio.service` via `sudo cp`
- [ ] Reloads systemd daemon: `sudo systemctl daemon-reload`
- [ ] Enables the service: `sudo systemctl enable claude-studio`
- [ ] Starts the service: `sudo systemctl start claude-studio`
- [ ] Waits up to 15 seconds for the service to stabilize

### AC-6: Verification
- [ ] `systemctl is-active claude-studio` returns "active"
- [ ] HTTP check: `curl -sf http://localhost:${CLAUDE_STUDIO_PORT}` returns HTTP 200
- [ ] Sets marker file `.phase-5-complete`

---

## Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `scripts/install-studio.sh` | Create | Phase 5 installer |

---

## Technical Notes

- This is a **system** systemd service (not user) — requires `sudo` for systemctl and file placement
- The service runs as the `ubuntu` user (specified in `User=` directive in the unit file)
- Git credential setup here also benefits Phase 3 (bench can use GitHub for apps later)
- The build step (`npm run build`) compiles TypeScript to `dist/server.js`
- The service uses absolute path to node binary: `${HOME}/.nvm/versions/node/v24/bin/node`
- Claude Studio listens on 0.0.0.0 (not just localhost) — access controlled by EC2 security group

---

## Definition of Done

- [ ] `bash -n scripts/install-studio.sh` passes
- [ ] On provisioned instance (after Phases 1-2): script clones, builds, and starts Claude Studio without error
- [ ] `~/claude-code-studio/dist/server.js` exists
- [ ] `~/claude-code-studio/config.json` exists with rendered values
- [ ] `systemctl is-active claude-studio` returns "active"
- [ ] `curl -s -o /dev/null -w "%{http_code}" http://localhost:${CLAUDE_STUDIO_PORT}` returns "200"
- [ ] Second run skips (exits 0 in < 2 seconds)
- [ ] ShellCheck passes with no errors
