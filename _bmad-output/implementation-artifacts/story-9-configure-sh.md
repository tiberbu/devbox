# Story 9: configure.sh (Credential-Only Reconfigure)

**Story ID:** S9
**Epic:** E4 — Verification & Polish
**Points:** 3
**Estimated Hours:** 1
**Priority:** P2 — Post-bootstrap polish
**Dependencies:** S1 (_common.sh, env loading, validation), S7 (templates for re-rendering)

---

## Description

Create `configure.sh` — a standalone script that re-injects credentials from `~/.tiberbu-env` into all configuration files and restarts affected services, WITHOUT reinstalling any packages or rebuilding applications. This is used for two scenarios: (1) launching an EC2 from a pre-baked AMI where packages are already installed but credentials belong to a different engineer, and (2) rotating credentials (e.g., new AWS keys or Discord bot token).

---

## Acceptance Criteria

### AC-1: Environment loading and validation
- [ ] Reads `~/.tiberbu-env` using the same `load_env_file()` function from `_common.sh`
- [ ] Validates all 8 required credentials using the same `validate_credentials()` logic
- [ ] Applies defaults for optional variables
- [ ] Exits 1 with descriptive error if env file missing or credentials incomplete

### AC-2: Template re-rendering
- [ ] Re-renders `~/.openclaw/openclaw.json` from `templates/openclaw.json.template`
- [ ] Re-renders `~/.config/systemd/user/openclaw-gateway.service` from `templates/openclaw-gateway.service`
- [ ] Re-renders `/etc/systemd/system/claude-studio.service` from `templates/claude-studio.service` (via sudo)
- [ ] Re-renders `~/claude-code-studio/config.json` from `templates/claude-studio-config.json.template`
- [ ] Sets correct permissions: `chmod 600` on openclaw.json and git-credentials

### AC-3: Git credential update
- [ ] Updates `~/.git-credentials` with new GitHub token
- [ ] Sets `chmod 600 ~/.git-credentials`
- [ ] Verifies: `git ls-remote https://github.com/tiberbu/devbox.git 2>/dev/null` succeeds (with `|| log_warn` for graceful failure)

### AC-4: Service restarts
- [ ] Reloads systemd user daemon: `systemctl --user daemon-reload`
- [ ] Restarts OpenClaw gateway: `systemctl --user restart openclaw-gateway`
- [ ] Reloads systemd system daemon: `sudo systemctl daemon-reload`
- [ ] Restarts Claude Studio: `sudo systemctl restart claude-studio`
- [ ] Waits for services to stabilize (up to 10s each)
- [ ] Does NOT restart MariaDB or Redis (credentials don't affect them)
- [ ] Does NOT touch Frappe Bench (no credential dependency)

### AC-5: Verification
- [ ] Checks `systemctl --user is-active openclaw-gateway` → "active"
- [ ] Checks `systemctl is-active claude-studio` → "active"
- [ ] Checks ports are listening (18789, 3000)
- [ ] Sends Discord notification confirming reconfigure complete

### AC-6: Performance
- [ ] Total execution time under 60 seconds
- [ ] Logs timing for each step

### AC-7: Safety
- [ ] Does NOT install any packages
- [ ] Does NOT run `bench init`, `npm install`, `npm run build`, or any build commands
- [ ] Does NOT modify MariaDB databases or Redis data
- [ ] Only touches: config files, systemd units, git credentials, service restarts

---

## Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `configure.sh` | Create | Credential-only reconfigure script |

---

## Technical Notes

- This script shares `_common.sh`, `load_env_file()`, and `validate_credentials()` with `bootstrap.sh` — no code duplication
- The script must work even if `bootstrap.sh` hasn't been run (for AMI scenarios where packages are pre-installed)
- Template paths are relative to the script's location (same as bootstrap.sh)
- The Discord notification uses the NEW credentials (the ones just injected), not any cached values
- Consider printing a "before vs after" diff for the credential variables (names only, not values) to help the engineer confirm what changed
- Script should be executable: `chmod +x configure.sh`

---

## Definition of Done

- [ ] `bash -n configure.sh` passes
- [ ] On a fully provisioned instance: `./configure.sh` completes in under 60 seconds
- [ ] After running with updated credentials:
  - `~/.openclaw/openclaw.json` contains new credential values
  - `~/.config/systemd/user/openclaw-gateway.service` contains new values
  - `/etc/systemd/system/claude-studio.service` contains new values
  - `~/.git-credentials` contains new GitHub token
- [ ] `systemctl --user is-active openclaw-gateway` → "active"
- [ ] `systemctl is-active claude-studio` → "active"
- [ ] Discord notification received in the channel specified by new credentials
- [ ] Total time < 60 seconds
- [ ] ShellCheck passes with no errors
