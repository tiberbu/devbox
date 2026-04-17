# Story 4: OpenClaw Installer

**Story ID:** S4
**Epic:** E2 — Application Stack
**Points:** 3
**Estimated Hours:** 1.5
**Priority:** P1 — Phase 4 of bootstrap
**Dependencies:** S1 (_common.sh), S3 (Node.js/npm available), S7 (templates/openclaw.json.template, templates/openclaw-gateway.service)

---

## Description

Create `scripts/install-openclaw.sh` — the Phase 4 installer that installs OpenClaw globally via npm, renders the configuration from template, copies default workspace files, creates a systemd user service for the gateway, and starts it.

---

## Acceptance Criteria

### AC-1: Idempotency check
- [ ] Checks marker file `.phase-4-complete` AND `systemctl --user is-active openclaw-gateway`
- [ ] If both pass: logs "Phase 4 already complete, skipping" and exits 0
- [ ] If marker exists but service not active: clears marker and re-runs

### AC-2: OpenClaw npm installation
- [ ] Sources nvm to get node/npm on PATH
- [ ] Runs `npm install -g openclaw` with retry logic (3 attempts)
- [ ] Verifies: `openclaw --version` returns a valid version string

### AC-3: Configuration rendering
- [ ] Creates directory `~/.openclaw/` if it doesn't exist
- [ ] Uses `render_template` to render `templates/openclaw.json.template` → `~/.openclaw/openclaw.json`
- [ ] Sets permissions: `chmod 600 ~/.openclaw/openclaw.json`
- [ ] All template variables are populated from the exported environment

### AC-4: Workspace setup
- [ ] Creates directory `~/.openclaw/workspace/` if it doesn't exist
- [ ] Copies `workspace/AGENTS.md`, `workspace/SOUL.md`, `workspace/TOOLS.md`, `workspace/USER.md` from the devbox repo to `~/.openclaw/workspace/`
- [ ] Only copies if files don't already exist (preserves user customizations)

### AC-5: Systemd user service
- [ ] Creates directory `~/.config/systemd/user/` if it doesn't exist
- [ ] Uses `render_template` to render `templates/openclaw-gateway.service` → `~/.config/systemd/user/openclaw-gateway.service`
- [ ] Enables user linger: `loginctl enable-linger $USER` (required for user services to persist)
- [ ] Reloads systemd user daemon: `systemctl --user daemon-reload`
- [ ] Enables the service: `systemctl --user enable openclaw-gateway`
- [ ] Starts the service: `systemctl --user start openclaw-gateway`
- [ ] Waits up to 10 seconds for the service to stabilize

### AC-6: Verification
- [ ] `systemctl --user is-active openclaw-gateway` returns "active"
- [ ] Gateway is listening on configured port: `curl -sf http://localhost:${OPENCLAW_PORT}/health` or `ss -tlnp | grep ${OPENCLAW_PORT}` succeeds
- [ ] Sets marker file `.phase-4-complete`

---

## Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `scripts/install-openclaw.sh` | Create | Phase 4 installer |

---

## Technical Notes

- This is a **user** systemd service (not system), so all systemctl commands use `--user` flag
- User linger is required for the service to run when the user is not logged in
- The service ExecStart uses absolute path to the openclaw binary in nvm's bin directory
- The openclaw.json template must have all `${VAR}` placeholders substituted — envsubst handles this
- Workspace files are default starters; engineers will customize AGENTS.md etc. via Discord over time
- The gateway may take a few seconds to fully start and register with Discord

---

## Definition of Done

- [ ] `bash -n scripts/install-openclaw.sh` passes
- [ ] On provisioned instance (after Phases 1-2): script installs openclaw without error
- [ ] `openclaw --version` returns valid version
- [ ] `~/.openclaw/openclaw.json` exists with mode 600 and contains rendered credentials (no `${VAR}` placeholders remaining)
- [ ] `~/.openclaw/workspace/` contains AGENTS.md, SOUL.md, TOOLS.md, USER.md
- [ ] `systemctl --user is-active openclaw-gateway` returns "active"
- [ ] Port 18789 (or configured port) is listening
- [ ] Second run skips (exits 0 in < 2 seconds)
- [ ] ShellCheck passes with no errors
