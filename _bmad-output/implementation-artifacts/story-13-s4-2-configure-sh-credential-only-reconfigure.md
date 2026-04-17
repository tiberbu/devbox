# Story S4.2: configure.sh (Credential-Only Reconfigure)

Status: done

## Story

As a Tiberbu engineer,
I want a standalone `configure.sh` script that reads `~/.tiberbu-env`, re-renders all configuration templates with fresh credentials, updates the git credential store, restarts the affected services, and sends a Discord confirmation,
so that I can rotate credentials or launch an instance from a pre-baked AMI and be fully operational in under 60 seconds without reinstalling any packages.

---

## Acceptance Criteria

### AC-1: Environment Loading and Validation

- [ ] Reads `~/.tiberbu-env` via the shared `load_env_file()` function from `scripts/_common.sh` (same function used by bootstrap.sh)
- [ ] Validates all 8 required credentials via `validate_credentials()` from `scripts/_common.sh`:
  - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`
  - `DISCORD_BOT_TOKEN`, `DISCORD_GUILD_ID`, `DISCORD_CHANNEL_ID`, `DISCORD_USER_ID`
  - `GITHUB_TOKEN`
- [ ] Applies defaults for optional variables:
  - `BEDROCK_REGION` → `us-west-1`
  - `BEDROCK_MODEL` → `global.anthropic.claude-opus-4-6-v1`
  - `CLAUDE_STUDIO_PORT` → `3000`
  - `OPENCLAW_PORT` → `18789`
- [ ] Exits with code 1 and a descriptive error message listing ALL missing variables if env file is missing or any required credential is empty

### AC-2: Template Re-Rendering

- [ ] Re-renders `~/.openclaw/openclaw.json` from `templates/openclaw.json.template` using `render_template()` from `_common.sh`
- [ ] Re-renders `~/.config/systemd/user/openclaw-gateway.service` from `templates/openclaw-gateway.service`
- [ ] Re-renders `/etc/systemd/system/claude-studio.service` from `templates/claude-studio.service` (rendered to tmp then copied via `sudo cp`)
- [ ] Re-renders `~/claude-code-studio/config.json` from `templates/claude-studio-config.json.template`
- [ ] Sets `chmod 600 ~/.openclaw/openclaw.json` after rendering
- [ ] Sets `chmod 600 ~/.git-credentials` after git credential update

### AC-3: Git Credential Update

- [ ] Writes `~/.git-credentials` with the new `GITHUB_TOKEN` in the format:
  `https://x-access-token:${GITHUB_TOKEN}@github.com`
- [ ] Sets `chmod 600 ~/.git-credentials`
- [ ] Verifies git auth: `git ls-remote https://github.com/tiberbu/devbox.git >/dev/null 2>&1` — on failure uses `|| log_warn` for graceful degradation (does NOT exit the script)

### AC-4: Service Restarts

- [ ] Reloads systemd user daemon: `systemctl --user daemon-reload`
- [ ] Restarts OpenClaw gateway: `systemctl --user restart openclaw-gateway`
- [ ] Reloads systemd system daemon: `sudo systemctl daemon-reload`
- [ ] Restarts Claude Studio: `sudo systemctl restart claude-studio`
- [ ] Waits for each service to stabilize (polls `is-active`, up to 10 seconds each)
- [ ] Does NOT restart MariaDB, Redis, or touch Frappe Bench (credentials do not affect them)
- [ ] Logs elapsed time for each service restart step

### AC-5: Verification

- [ ] Checks `systemctl --user is-active openclaw-gateway` → "active"
- [ ] Checks `systemctl is-active claude-studio` → "active"
- [ ] Checks OpenClaw port 18789 is listening (`ss -tlnp | grep -q ":${OPENCLAW_PORT}"`)
- [ ] Checks Claude Studio port 3000 is listening (`ss -tlnp | grep -q ":${CLAUDE_STUDIO_PORT}"`)
- [ ] Sends Discord notification confirming reconfigure complete using the **new** credentials (new `DISCORD_BOT_TOKEN` and `DISCORD_CHANNEL_ID`)
- [ ] Discord notification failure does NOT fail the script (wrapped with `|| log_warn`)

### AC-6: Performance

- [ ] Total wall-clock execution time under 60 seconds
- [ ] Logs timing for each major step (render templates, update git creds, restart services)
- [ ] Overall elapsed time printed at completion

### AC-7: Safety (Hard Constraints)

- [ ] Does NOT run `apt`, `apt-get`, or install any packages
- [ ] Does NOT run `bench init`, `bench new-site`, or any bench commands
- [ ] Does NOT run `npm install`, `npm run build`, `yarn install`, `yarn build`, or any build commands
- [ ] Does NOT run `git clone` or `nvm install`
- [ ] Does NOT modify MariaDB databases or Redis data
- [ ] Only touches: 4 config files, 1 git credential file, 2 systemd unit reloads/restarts
- [ ] Script is idempotent — safe to run multiple times; re-renders and restarts are non-destructive

---

## Tasks / Subtasks

- [ ] Task 1: Script skeleton and environment setup (AC-1)
  - [ ] 1.1 Shebang `#!/usr/bin/env bash`, `set -euo pipefail`, ERR trap using `error_handler`
  - [ ] 1.2 `SCRIPT_DIR` detection: `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`
  - [ ] 1.3 Source `${SCRIPT_DIR}/scripts/_common.sh`
  - [ ] 1.4 Call `load_env_file "${HOME}/.tiberbu-env"` (handles missing file with exit 1)
  - [ ] 1.5 Call `validate_credentials` (validates all 8 required vars, lists all missing)
  - [ ] 1.6 Export defaults for optional vars: BEDROCK_REGION, BEDROCK_MODEL, CLAUDE_STUDIO_PORT, OPENCLAW_PORT
  - [ ] 1.7 Record START_TIME using `$SECONDS` for overall elapsed reporting

- [ ] Task 2: Template re-rendering (AC-2)
  - [ ] 2.1 Ensure `~/.openclaw/` directory exists (`mkdir -p`)
  - [ ] 2.2 Render openclaw.json: `render_template "${SCRIPT_DIR}/templates/openclaw.json.template" "${HOME}/.openclaw/openclaw.json"`
  - [ ] 2.3 `chmod 600 "${HOME}/.openclaw/openclaw.json"`
  - [ ] 2.4 Ensure `~/.config/systemd/user/` directory exists (`mkdir -p`)
  - [ ] 2.5 Render openclaw-gateway.service: `render_template "${SCRIPT_DIR}/templates/openclaw-gateway.service" "${HOME}/.config/systemd/user/openclaw-gateway.service"`
  - [ ] 2.6 Render claude-studio.service to `/tmp/claude-studio.service.tmp`, then `sudo cp /tmp/claude-studio.service.tmp /etc/systemd/system/claude-studio.service && rm -f /tmp/claude-studio.service.tmp`
  - [ ] 2.7 Render claude-studio config: `render_template "${SCRIPT_DIR}/templates/claude-studio-config.json.template" "${HOME}/claude-code-studio/config.json"` (only if `~/claude-code-studio/` exists)
  - [ ] 2.8 Log timing for template rendering step

- [ ] Task 3: Git credential update (AC-3)
  - [ ] 3.1 Write `~/.git-credentials`: `printf 'https://x-access-token:%s@github.com\n' "${GITHUB_TOKEN}" > "${HOME}/.git-credentials"`
  - [ ] 3.2 `chmod 600 "${HOME}/.git-credentials"`
  - [ ] 3.3 Ensure git credential helper is set: `git config --global credential.helper store`
  - [ ] 3.4 Verify: `git ls-remote https://github.com/tiberbu/devbox.git >/dev/null 2>&1 || log_warn "Git auth check failed — token may not have repo access"`

- [ ] Task 4: Service restarts with stabilization wait (AC-4)
  - [ ] 4.1 `systemctl --user daemon-reload`
  - [ ] 4.2 `systemctl --user restart openclaw-gateway`
  - [ ] 4.3 Poll `systemctl --user is-active openclaw-gateway` in a loop, up to 10s, 1s intervals; `log_warn` if not active after 10s
  - [ ] 4.4 `sudo systemctl daemon-reload`
  - [ ] 4.5 `sudo systemctl restart claude-studio`
  - [ ] 4.6 Poll `systemctl is-active claude-studio` in a loop, up to 10s, 1s intervals; `log_warn` if not active after 10s
  - [ ] 4.7 Log elapsed time for service restart step

- [ ] Task 5: Post-restart verification (AC-5)
  - [ ] 5.1 Check `systemctl --user is-active openclaw-gateway` → log_success or log_error
  - [ ] 5.2 Check `systemctl is-active claude-studio` → log_success or log_error
  - [ ] 5.3 Check OpenClaw port: `ss -tlnp | grep -q ":${OPENCLAW_PORT}"` → log_success or log_warn
  - [ ] 5.4 Check Claude Studio port: `ss -tlnp | grep -q ":${CLAUDE_STUDIO_PORT}"` → log_success or log_warn
  - [ ] 5.5 Implement `send_discord_notification` function using new credentials (see Dev Notes)
  - [ ] 5.6 Call `send_discord_notification` with `|| log_warn` (graceful failure)

- [ ] Task 6: Performance reporting and completion (AC-6)
  - [ ] 6.1 Calculate total elapsed: `$(( SECONDS - START_TIME ))`
  - [ ] 6.2 Print final summary: services active status, total elapsed time
  - [ ] 6.3 Exit 0 on success (verification failures produce warnings but do not block completion)

- [ ] Task 7: ShellCheck and safety validation (AC-7)
  - [ ] 7.1 `bash -n configure.sh` → exit 0
  - [ ] 7.2 `shellcheck configure.sh` → zero errors, zero warnings
  - [ ] 7.3 Grep for prohibited commands (`apt`, `bench init`, `npm install`, `yarn install`) → confirm absent
  - [ ] 7.4 `chmod +x configure.sh`

---

## Dev Notes

### Script Location and Sourcing

`configure.sh` lives in the project root alongside `bootstrap.sh`. It sources `scripts/_common.sh` using its own `SCRIPT_DIR`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/_common.sh"

START_TIME="${SECONDS}"

log_info "=== configure.sh: Credential-Only Reconfigure ==="

# 1. Load and validate environment
load_env_file "${HOME}/.tiberbu-env"
validate_credentials

# Apply defaults for optional vars
: "${BEDROCK_REGION:=us-west-1}"
: "${BEDROCK_MODEL:=global.anthropic.claude-opus-4-6-v1}"
: "${CLAUDE_STUDIO_PORT:=3000}"
: "${OPENCLAW_PORT:=18789}"
export BEDROCK_REGION BEDROCK_MODEL CLAUDE_STUDIO_PORT OPENCLAW_PORT
```

### load_env_file() and validate_credentials() from _common.sh

These functions are already defined in `scripts/_common.sh` (implemented in S1.1). `configure.sh` must NOT redefine them — just call them. This is the key architectural decision: zero code duplication with `bootstrap.sh`.

Reference from architecture §5.1 API Surface:
- `load_env_file ENV_FILE` — sources env file with `set -a`, applies defaults, exits 1 if missing
- `validate_credentials` — checks all 8 required vars, lists all missing, exits 1 if any absent
- `render_template TEMPLATE OUTPUT` — `envsubst < "$template" > "$output"` wrapper with logging
- `log_info / log_success / log_error / log_warn` — colored output + log file

### Template Paths (relative to SCRIPT_DIR)

All 4 templates live in `${SCRIPT_DIR}/templates/`:

| Template | Destination |
|----------|-------------|
| `templates/openclaw.json.template` | `~/.openclaw/openclaw.json` |
| `templates/openclaw-gateway.service` | `~/.config/systemd/user/openclaw-gateway.service` |
| `templates/claude-studio.service` | `/etc/systemd/system/claude-studio.service` (needs sudo) |
| `templates/claude-studio-config.json.template` | `~/claude-code-studio/config.json` |

The `render_template` function uses `envsubst` — all env vars must already be exported (ensured by `load_env_file` with `set -a`).

### Sudo-Required System Service Rendering

The claude-studio systemd unit requires root write access. Pattern:

```bash
# Render to tmp, then sudo copy
local TMP_STUDIO_SERVICE
TMP_STUDIO_SERVICE="$(mktemp /tmp/claude-studio.service.XXXXXX)"
render_template "${SCRIPT_DIR}/templates/claude-studio.service" "${TMP_STUDIO_SERVICE}"
sudo cp "${TMP_STUDIO_SERVICE}" /etc/systemd/system/claude-studio.service
rm -f "${TMP_STUDIO_SERVICE}"
log_success "Rendered /etc/systemd/system/claude-studio.service"
```

### Git Credential Update

The credential store format used by `git credential-store` is one URL per line:

```bash
update_git_credentials() {
    log_info "Updating git credentials..."
    printf 'https://x-access-token:%s@github.com\n' "${GITHUB_TOKEN}" \
        > "${HOME}/.git-credentials"
    chmod 600 "${HOME}/.git-credentials"
    git config --global credential.helper store
    log_success "Git credentials updated"

    # Verify — graceful on failure
    if git ls-remote "https://github.com/tiberbu/devbox.git" >/dev/null 2>&1; then
        log_success "Git auth verified: github.com access confirmed"
    else
        log_warn "Git auth check failed — GITHUB_TOKEN may lack repo access (non-fatal)"
    fi
}
```

### Service Stabilization Wait Pattern

```bash
wait_for_service() {
    local service="$1"
    local scope="$2"   # "--user" or ""
    local max_wait=10
    local elapsed=0
    local systemctl_cmd

    if [[ "${scope}" == "--user" ]]; then
        systemctl_cmd="systemctl --user"
    else
        systemctl_cmd="sudo systemctl"
    fi

    while [[ ${elapsed} -lt ${max_wait} ]]; do
        if ${systemctl_cmd} is-active --quiet "${service}"; then
            log_success "${service} is active (${elapsed}s)"
            return 0
        fi
        sleep 1
        elapsed=$(( elapsed + 1 ))
    done
    log_warn "${service} not active after ${max_wait}s — check journalctl"
    return 1
}
```

### Discord Notification (New Credentials)

The notification must use the credentials that were JUST injected (they are already in env from `load_env_file`):

```bash
send_discord_notification() {
    local elapsed="$1"
    local hostname
    hostname=$(hostname)
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    local payload
    payload=$(printf '{
  "embeds": [{
    "title": "🔄 DevBox Reconfigured",
    "color": 3447003,
    "description": "Credentials updated and services restarted successfully.",
    "fields": [
      {"name": "Hostname", "value": "%s", "inline": true},
      {"name": "Elapsed", "value": "%ss", "inline": true},
      {"name": "OpenClaw Gateway", "value": "Restarted ✓", "inline": true},
      {"name": "Claude Studio", "value": "Restarted ✓", "inline": true}
    ],
    "timestamp": "%s"
  }]
}' "${hostname}" "${elapsed}" "${timestamp}")

    curl -sf -X POST \
        -H "Authorization: Bot ${DISCORD_BOT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${payload}" \
        "https://discord.com/api/v10/channels/${DISCORD_CHANNEL_ID}/messages" \
        >/dev/null 2>&1 \
    && log_success "Discord notification sent" \
    || log_warn "Discord notification failed (non-fatal)"
}
```

> Note: `3447003` is Discord blue (0x3498DB). Use green `65280` if you want success-colored embeds.

### Safety: No Build Commands

`configure.sh` must never trigger package installation or compilation. Add this comment at the top:

```bash
# SAFETY: This script ONLY touches config files and restarts services.
# It MUST NOT install packages, compile code, or modify databases.
# Prohibited: apt, npm install, yarn, bench init, bench new-site, git clone, nvm install
```

ShellCheck will flag any obvious violations; a final grep check in Task 7 confirms safety.

### Handling Missing claude-code-studio Directory

If the instance was not provisioned via bootstrap.sh (e.g., a fresh AMI that pre-installs claude-code-studio), the directory should exist. Guard the config render:

```bash
if [[ -d "${HOME}/claude-code-studio" ]]; then
    render_template \
        "${SCRIPT_DIR}/templates/claude-studio-config.json.template" \
        "${HOME}/claude-code-studio/config.json"
else
    log_warn "~/claude-code-studio not found — skipping config render"
fi
```

### envsubst Variable Scoping

`render_template` uses `envsubst` which substitutes ALL `$VAR` and `${VAR}` in the template. Ensure all variables referenced in templates are exported before calling render. The `load_env_file()` function uses `set -a` to auto-export everything from `~/.tiberbu-env`, and we manually export the defaults above. Also ensure `HOME`, `USER` are exported (they are in any standard shell environment).

From the Template Variable Matrix (architecture §6):
- `openclaw.json.template` uses: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `BEDROCK_REGION`, `BEDROCK_MODEL`, `DISCORD_BOT_TOKEN`, `DISCORD_GUILD_ID`, `DISCORD_CHANNEL_ID`, `DISCORD_USER_ID`, `OPENCLAW_PORT`, `HOME`
- `openclaw-gateway.service` uses: `HOME`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`
- `claude-studio.service` uses: `USER`, `HOME`, `CLAUDE_STUDIO_PORT`
- `claude-studio-config.json.template` uses: `HOME`, `CLAUDE_STUDIO_PORT`

### Overall Script Flow

```
configure.sh
 │
 ├─ 1. source _common.sh
 ├─ 2. load_env_file ~/.tiberbu-env          (exit 1 if missing/incomplete)
 ├─ 3. validate_credentials                  (exit 1 if any of 8 missing)
 ├─ 4. Apply optional defaults
 │
 ├─ 5. Render templates [AC-2]
 │     ├─ openclaw.json              chmod 600
 │     ├─ openclaw-gateway.service
 │     ├─ claude-studio.service      (via sudo cp)
 │     └─ claude-studio config.json
 │
 ├─ 6. Update git credentials [AC-3]
 │     ├─ write ~/.git-credentials   chmod 600
 │     └─ verify git ls-remote       (|| log_warn)
 │
 ├─ 7. Restart services [AC-4]
 │     ├─ systemctl --user daemon-reload
 │     ├─ systemctl --user restart openclaw-gateway  → wait up to 10s
 │     ├─ sudo systemctl daemon-reload
 │     └─ sudo systemctl restart claude-studio       → wait up to 10s
 │
 ├─ 8. Verify services [AC-5]
 │     ├─ is-active openclaw-gateway
 │     ├─ is-active claude-studio
 │     ├─ port 18789 listening
 │     └─ port 3000 listening
 │
 ├─ 9. Send Discord notification     (|| log_warn)
 │
 └─ 10. Print summary + elapsed time → exit 0
```

---

## Project Structure Notes

- **File to create:** `configure.sh` (project root, same level as `bootstrap.sh`)
- **Files sourced (read-only):** `scripts/_common.sh`
- **Templates read (read-only):**
  - `templates/openclaw.json.template`
  - `templates/openclaw-gateway.service`
  - `templates/claude-studio.service`
  - `templates/claude-studio-config.json.template`
- **Files written (output):**
  - `~/.openclaw/openclaw.json` (mode 600)
  - `~/.config/systemd/user/openclaw-gateway.service`
  - `/etc/systemd/system/claude-studio.service` (via sudo)
  - `~/claude-code-studio/config.json` (conditional)
  - `~/.git-credentials` (mode 600)
- **Services restarted:** `openclaw-gateway` (user), `claude-studio` (system)
- **Services NOT touched:** `mariadb`, `redis-server`, `frappe bench`
- **Executable bit:** `chmod +x configure.sh`
- **Log output:** All steps logged via `_common.sh` functions to `/var/tmp/devbox/bootstrap.log`

---

### References

- Architecture: [`_bmad-output/planning-artifacts/architecture.md`] — §2.2 Credential Flow (configure.sh), §4.1 Repository Structure, §4.2 Installed Paths, §5.1 _common.sh API Surface, §6 Template Variable Matrix
- PRD: [`_bmad-output/planning-artifacts/prd.md`] — FR-12: Credential Reconfigure (configure.sh), ADR-6: configure.sh as Credential-Only Reconfigure, UJ-3: AMI Credential Reconfigure, UJ-4: Credential Update, SC-6: AMI reconfigure time < 60s
- Epics: [`_bmad-output/planning-artifacts/epics.md`] — Epic 4: Verification & Polish, S9 configure.sh story
- Original S9 story: [`_bmad-output/implementation-artifacts/story-9-configure-sh.md`]
- Common utilities: `scripts/_common.sh` — `load_env_file`, `validate_credentials`, `render_template`, `log_*`, `error_handler`
- Template sources (for variable reference): `templates/openclaw.json.template`, `templates/openclaw-gateway.service`, `templates/claude-studio.service`, `templates/claude-studio-config.json.template`
- Story pattern reference: [`_bmad-output/implementation-artifacts/story-36-s4-1-verification-and-smoke-test-verify-sh.md`]

---

## Dev Agent Record

### Agent Model Used

sonnet

### Debug Log References

### Completion Notes List

### File List

- `configure.sh` (to create)
