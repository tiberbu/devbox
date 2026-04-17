# Story: S2.1: OpenClaw Installer (install-openclaw.sh)

Status: done

## Story

As a Tiberbu engineer,
I want a `scripts/install-openclaw.sh` Phase 4 installer,
so that OpenClaw is installed globally via npm, its configuration is rendered from the template with all credentials injected, the default workspace files are copied, a systemd user service is created and started, the gateway is listening on the configured port, and the script is fully idempotent — skipping safely on re-runs.

## Acceptance Criteria

### AC-1: Idempotency check
1. At script start, check both conditions: `check_marker 4` (marker file `/var/tmp/devbox/.phase-4-complete` exists) AND `systemctl --user is-active openclaw-gateway` returns "active"
2. If both pass: call `log_success "Phase 4 already complete — skipping"` and `exit 0`
3. If marker exists but service not active: call `clear_marker 4` to remove the stale marker, then continue with full installation

### AC-2: OpenClaw npm installation
4. Source nvm into the current session before using npm:
   ```bash
   export NVM_DIR="${HOME}/.nvm"
   [[ -s "${NVM_DIR}/nvm.sh" ]] && \. "${NVM_DIR}/nvm.sh"
   ```
5. Verify nvm/npm is available: `command -v npm` must succeed; call `log_error` and `exit 1` if not
6. Install openclaw globally using retry: `retry 3 15 npm install -g openclaw`
7. Verify: `openclaw --version` returns a valid version string; call `log_success "openclaw $(openclaw --version) installed"`

### AC-3: Configuration rendering
8. Create the config directory: `mkdir -p "${HOME}/.openclaw"`
9. Call `render_template "${DEVBOX_DIR}/templates/openclaw.json.template" "${HOME}/.openclaw/openclaw.json"` (where `DEVBOX_DIR` is the devbox repo root, one directory above `scripts/`)
10. Set restrictive permissions: `chmod 600 "${HOME}/.openclaw/openclaw.json"`
11. Verify no unresolved `${VAR}` placeholders remain: `grep -q '\${' "${HOME}/.openclaw/openclaw.json"` should exit non-zero (no matches); call `log_error` and `exit 1` if placeholders remain
12. Call `log_success "openclaw.json rendered at ${HOME}/.openclaw/openclaw.json (mode 600)"`

### AC-4: Workspace setup
13. Create the workspace directory: `mkdir -p "${HOME}/.openclaw/workspace"`
14. For each of AGENTS.md, SOUL.md, TOOLS.md, USER.md:
    - Source: `"${DEVBOX_DIR}/workspace/<FILE>"`
    - Destination: `"${HOME}/.openclaw/workspace/<FILE>"`
    - Copy condition: only copy if the destination file does NOT already exist (preserves user customizations)
    - Use: `[[ ! -f "${dest}" ]] && cp "${src}" "${dest}" && log_info "Copied workspace/<FILE>"`
15. Call `log_success "Workspace files in place at ${HOME}/.openclaw/workspace/"` after all four files are processed

### AC-5: Systemd user service
16. Create the systemd user directory: `mkdir -p "${HOME}/.config/systemd/user"`
17. Call `render_template "${DEVBOX_DIR}/templates/openclaw-gateway.service" "${HOME}/.config/systemd/user/openclaw-gateway.service"`
18. Enable user linger (required for user services to persist across sessions):
    `loginctl enable-linger "${USER}"` — wrap with `|| log_warn "loginctl enable-linger failed (may require root or already set)"`
19. Reload the user daemon: `systemctl --user daemon-reload`
20. Enable the service: `systemctl --user enable openclaw-gateway`
21. Start the service: `systemctl --user start openclaw-gateway`
22. Wait up to 10 seconds for the service to stabilize — poll `systemctl --user is-active --quiet openclaw-gateway` once per second with a loop

### AC-6: Verification
23. After the stabilization wait, assert `systemctl --user is-active openclaw-gateway` is "active"; call `log_error` and `exit 1` if not
24. Assert port `${OPENCLAW_PORT}` is listening: use `ss -tlnp 2>/dev/null | grep -q ":${OPENCLAW_PORT}"` OR `curl -sf "http://localhost:${OPENCLAW_PORT}/health" &>/dev/null` — either succeeds; call `log_error` and `exit 1` if neither does
25. After both assertions pass, call `set_marker 4` to create `/var/tmp/devbox/.phase-4-complete`
26. Call `log_success "Phase 4 complete — OpenClaw gateway active on port ${OPENCLAW_PORT}"`

### Definition of Done
27. `bash -n scripts/install-openclaw.sh` exits 0 (syntax clean)
28. ShellCheck passes with no errors: `shellcheck scripts/install-openclaw.sh`
29. On a provisioned instance (after Phases 1–3): script installs openclaw without error
30. `openclaw --version` returns a valid version string
31. `~/.openclaw/openclaw.json` exists with mode 600 and contains no `${VAR}` placeholders
32. `~/.openclaw/workspace/` contains AGENTS.md, SOUL.md, TOOLS.md, USER.md
33. `systemctl --user is-active openclaw-gateway` returns "active"
34. Port `${OPENCLAW_PORT}` (default: 18789) is listening
35. Second run completes in < 2 seconds (idempotency check exits early)

---

## Tasks / Subtasks

- [ ] **Task 1 — Script scaffold** (AC: all)
  - [ ] 1.1 Create `scripts/install-openclaw.sh` with shebang `#!/usr/bin/env bash` and `set -euo pipefail`
  - [ ] 1.2 Add `SCRIPT_DIR` detection: `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`
  - [ ] 1.3 Derive `DEVBOX_DIR` (one level up): `DEVBOX_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"`
  - [ ] 1.4 Source `_common.sh`: `source "${SCRIPT_DIR}/_common.sh"` with `# shellcheck source=scripts/_common.sh` and `# shellcheck disable=SC1091` directives above
  - [ ] 1.5 Set ERR trap: `trap 'error_handler "${BASH_SOURCE[0]}" "${LINENO}" "$?"' ERR`
  - [ ] 1.6 Define constants: `readonly PHASE_NUM=4`, `readonly PHASE_NAME="OpenClaw + Discord"`, `readonly TOTAL_PHASES=5`
  - [ ] 1.7 Add defensive defaults: `: "${OPENCLAW_PORT:=18789}"` and `: "${HOME:=/home/ubuntu}"`

- [ ] **Task 2 — Idempotency check function** (AC: 1–3)
  - [ ] 2.1 Implement `check_idempotency()` that checks `check_marker "${PHASE_NUM}"` AND `systemctl --user is-active --quiet openclaw-gateway`
  - [ ] 2.2 If both pass: `log_success "Phase ${PHASE_NUM} already complete — skipping"` then `exit 0`
  - [ ] 2.3 If marker exists but service check fails: call `clear_marker "${PHASE_NUM}"` and fall through
  - [ ] 2.4 Call `check_idempotency` immediately after sourcing `_common.sh` and setting the ERR trap

- [ ] **Task 3 — nvm/npm sourcing** (AC: 4–5)
  - [ ] 3.1 Implement `source_nvm()` function:
    ```bash
    source_nvm() {
        export NVM_DIR="${HOME}/.nvm"
        # shellcheck disable=SC1091
        [[ -s "${NVM_DIR}/nvm.sh" ]] && \. "${NVM_DIR}/nvm.sh"
        if ! command -v npm &>/dev/null; then
            log_error "npm not found — Phase 2 (install-node.sh) must complete first"
            exit 1
        fi
        log_info "npm $(npm -v) available"
    }
    ```
  - [ ] 3.2 Call `source_nvm` before any npm commands

- [ ] **Task 4 — OpenClaw installation** (AC: 6–7)
  - [ ] 4.1 Implement `install_openclaw()` function
  - [ ] 4.2 Run `retry 3 15 npm install -g openclaw` with `log_info` before
  - [ ] 4.3 Verify `openclaw --version` returns a non-empty string
  - [ ] 4.4 `log_success "openclaw $(openclaw --version) installed"`

- [ ] **Task 5 — Configuration rendering** (AC: 8–12)
  - [ ] 5.1 Implement `render_config()` function
  - [ ] 5.2 `mkdir -p "${HOME}/.openclaw"`
  - [ ] 5.3 `render_template "${DEVBOX_DIR}/templates/openclaw.json.template" "${HOME}/.openclaw/openclaw.json"`
  - [ ] 5.4 `chmod 600 "${HOME}/.openclaw/openclaw.json"`
  - [ ] 5.5 Assert no remaining `${...}` placeholders: `if grep -q '\${' "${HOME}/.openclaw/openclaw.json"; then log_error "..."; exit 1; fi`
  - [ ] 5.6 `log_success "openclaw.json rendered at ${HOME}/.openclaw/openclaw.json (mode 600)"`

- [ ] **Task 6 — Workspace setup** (AC: 13–15)
  - [ ] 6.1 Implement `setup_workspace()` function
  - [ ] 6.2 `mkdir -p "${HOME}/.openclaw/workspace"`
  - [ ] 6.3 Loop over AGENTS.md SOUL.md TOOLS.md USER.md with copy-if-missing logic
  - [ ] 6.4 Verify source files exist in `"${DEVBOX_DIR}/workspace/"` before copying; `log_warn` if missing
  - [ ] 6.5 `log_success "Workspace files in place at ${HOME}/.openclaw/workspace/"`

- [ ] **Task 7 — Systemd user service** (AC: 16–22)
  - [ ] 7.1 Implement `install_service()` function
  - [ ] 7.2 `mkdir -p "${HOME}/.config/systemd/user"`
  - [ ] 7.3 `render_template "${DEVBOX_DIR}/templates/openclaw-gateway.service" "${HOME}/.config/systemd/user/openclaw-gateway.service"`
  - [ ] 7.4 `loginctl enable-linger "${USER}" || log_warn "loginctl enable-linger failed (may require root or already enabled)"`
  - [ ] 7.5 `systemctl --user daemon-reload`
  - [ ] 7.6 `systemctl --user enable openclaw-gateway`
  - [ ] 7.7 `systemctl --user start openclaw-gateway`
  - [ ] 7.8 Implement `wait_for_service()`: poll `systemctl --user is-active --quiet openclaw-gateway` for up to 10 iterations (1s each) with a `sleep 1` between checks; log attempt count

- [ ] **Task 8 — Verification and marker** (AC: 23–26)
  - [ ] 8.1 Implement `verify_phase()` function
  - [ ] 8.2 Assert `systemctl --user is-active openclaw-gateway`; exit 1 with log_error if not
  - [ ] 8.3 Assert port listening via `ss -tlnp 2>/dev/null | grep -q ":${OPENCLAW_PORT}"` with fallback to `curl -sf "http://localhost:${OPENCLAW_PORT}/health" &>/dev/null || true`
  - [ ] 8.4 `set_marker "${PHASE_NUM}"`
  - [ ] 8.5 `log_success "Phase 4 complete — OpenClaw gateway active on port ${OPENCLAW_PORT}"`

- [ ] **Task 9 — `main()` function and phase timing** (AC: all)
  - [ ] 9.1 Wrap all steps in a `main()` function
  - [ ] 9.2 Call `log_phase_start "${PHASE_NUM}" "${TOTAL_PHASES}" "${PHASE_NAME}"` at entry
  - [ ] 9.3 Capture `phase_start="$(date +%s)"` before steps
  - [ ] 9.4 Compute and call `log_phase_end "${PHASE_NUM}" "${TOTAL_PHASES}" "${PHASE_NAME}" "${elapsed}"` at exit
  - [ ] 9.5 Call `main` at the bottom of the script

- [ ] **Task 10 — Quality gates** (AC: 27–35)
  - [ ] 10.1 Run `bash -n scripts/install-openclaw.sh` — must exit 0
  - [ ] 10.2 Run `shellcheck scripts/install-openclaw.sh` — must produce no errors
  - [ ] 10.3 Verify `openclaw --version` → valid version string
  - [ ] 10.4 Verify `~/.openclaw/openclaw.json` exists with mode 600
  - [ ] 10.5 Verify no `${VAR}` placeholders in rendered JSON
  - [ ] 10.6 Verify all four workspace files present
  - [ ] 10.7 Verify `systemctl --user is-active openclaw-gateway` → "active"
  - [ ] 10.8 Verify port 18789 listening
  - [ ] 10.9 Run script a second time and confirm it exits in < 2 seconds

---

## Dev Notes

### Architecture Patterns

- **Script scaffold (from S1.1 / S1.3):** Every phase script follows the same pattern. This is Phase 4:
  ```bash
  #!/usr/bin/env bash
  # scripts/install-openclaw.sh — Phase 4: OpenClaw + Discord gateway
  set -euo pipefail

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  DEVBOX_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

  # shellcheck source=scripts/_common.sh
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/_common.sh"

  trap 'error_handler "${BASH_SOURCE[0]}" "${LINENO}" "$?"' ERR

  readonly PHASE_NUM=4
  readonly PHASE_NAME="OpenClaw + Discord"
  readonly TOTAL_PHASES=5

  : "${OPENCLAW_PORT:=18789}"
  : "${HOME:=/home/ubuntu}"
  ```
  Note: `_common.sh` `error_handler` takes 3 args (SCRIPT LINE EXIT_CODE) — see `scripts/_common.sh`.

- **`check_idempotency()` pattern (from architecture § 7):** Phase 4 uses marker + `systemctl --user is-active`:
  ```bash
  check_idempotency() {
      if ! check_marker "${PHASE_NUM}"; then
          return 0   # No marker — proceed
      fi

      log_info "Marker .phase-${PHASE_NUM}-complete found — verifying openclaw-gateway"

      if systemctl --user is-active --quiet openclaw-gateway 2>/dev/null; then
          log_success "Phase ${PHASE_NUM} already complete — skipping (marker + service active)"
          exit 0
      fi

      log_warn "Marker exists but openclaw-gateway not active — clearing marker and re-running"
      clear_marker "${PHASE_NUM}"
  }
  ```

- **nvm sourcing in non-interactive scripts:** `.bashrc` is NOT automatically sourced in phase scripts. Always source nvm manually before any npm/node/openclaw commands:
  ```bash
  source_nvm() {
      export NVM_DIR="${HOME}/.nvm"
      # shellcheck disable=SC1091
      [[ -s "${NVM_DIR}/nvm.sh" ]] && \. "${NVM_DIR}/nvm.sh"
      if ! command -v npm &>/dev/null; then
          log_error "npm not found — ensure install-node.sh ran successfully first"
          exit 1
      fi
  }
  ```
  This is the same pattern used in `install-node.sh`.

- **`render_template` usage (from `_common.sh`):** The `render_template` function is:
  ```bash
  render_template() {
      local template="$1" output="$2"
      envsubst < "$template" > "$output"
      log_success "Rendered: $output"
  }
  ```
  All template variables (AWS_*, DISCORD_*, OPENCLAW_PORT, HOME, BEDROCK_*) must be exported in the environment before calling. `bootstrap.sh` exports them via `load_env_file()`. When running standalone, the caller must export them first.

- **`retry` usage (from architecture § 8):** The `retry` function in `_common.sh` takes `COUNT DELAY CMD...`. Use for npm install which can fail due to network:
  ```bash
  retry 3 15 npm install -g openclaw
  ```

- **Systemd USER vs SYSTEM services:** This is a **user** service, not a system service. All systemctl commands MUST use the `--user` flag:
  ```bash
  systemctl --user daemon-reload
  systemctl --user enable openclaw-gateway
  systemctl --user start openclaw-gateway
  systemctl --user is-active openclaw-gateway
  ```
  The service file is installed to `~/.config/systemd/user/` (NOT `/etc/systemd/system/`). The `--user` distinction is critical — without it, `systemctl` targets the system bus and will fail or affect the wrong unit.

- **`loginctl enable-linger`:** This is required so that the user's systemd instance starts at boot even when the user is not logged in. Without linger, the openclaw-gateway service stops when the SSH session ends. Run as:
  ```bash
  loginctl enable-linger "${USER}" || log_warn "loginctl enable-linger failed (may need sudo or already set)"
  ```

- **`DBUS_SESSION_BUS_ADDRESS` for systemd --user:** On some Ubuntu 24.04 configurations, `systemctl --user` may fail with "Failed to connect to bus: No such file or directory" when called from non-interactive scripts. If this occurs, set:
  ```bash
  export XDG_RUNTIME_DIR="/run/user/$(id -u)"
  ```
  Add this before any `systemctl --user` calls. This ensures the user bus is accessible.

- **`openclaw --version` binary location:** After `npm install -g openclaw`, the binary is at `~/.nvm/versions/node/v24.x.x/bin/openclaw`. It's accessible via `command -v openclaw` only after nvm has been sourced.

- **Service stabilization wait:** The openclaw gateway takes 2–5 seconds to start and connect to Discord. Poll instead of a fixed sleep:
  ```bash
  wait_for_service() {
      local max_attempts=10
      local attempt=0
      log_info "Waiting for openclaw-gateway to stabilize (up to ${max_attempts}s)..."
      while (( attempt < max_attempts )); do
          if systemctl --user is-active --quiet openclaw-gateway 2>/dev/null; then
              log_success "openclaw-gateway is active (attempt $((attempt + 1)))"
              return 0
          fi
          attempt=$(( attempt + 1 ))
          sleep 1
      done
      log_error "openclaw-gateway did not become active within ${max_attempts} seconds"
      systemctl --user status openclaw-gateway --no-pager 2>&1 | tail -20 || true
      return 1
  }
  ```

### Template Variable Requirements

The following environment variables must be exported before `render_template` is called. `bootstrap.sh` sets them via `load_env_file()`. For standalone execution, they must be exported manually:

| Variable | Required | Default | Used In Template |
|----------|----------|---------|-----------------|
| `AWS_ACCESS_KEY_ID` | Yes | — | openclaw.json, openclaw-gateway.service |
| `AWS_SECRET_ACCESS_KEY` | Yes | — | openclaw.json, openclaw-gateway.service |
| `AWS_DEFAULT_REGION` | Yes | — | openclaw-gateway.service |
| `BEDROCK_REGION` | No | us-west-1 | openclaw.json (endpoint URL) |
| `BEDROCK_MODEL` | No | global.anthropic.claude-opus-4-6-v1 | openclaw.json |
| `DISCORD_BOT_TOKEN` | Yes | — | openclaw.json |
| `DISCORD_GUILD_ID` | Yes | — | openclaw.json |
| `DISCORD_CHANNEL_ID` | Yes | — | openclaw.json |
| `DISCORD_USER_ID` | Yes | — | openclaw.json |
| `OPENCLAW_PORT` | No | 18789 | openclaw.json |
| `HOME` | System | /home/ubuntu | Both templates |

The `openclaw-gateway.service` template path is: `ExecStart=${HOME}/.nvm/versions/node/v24/bin/openclaw gateway start` — uses a `v24` symlink (not the exact version), which works because nvm creates `~/.nvm/versions/node/v24` as an alias after `nvm alias default 24`.

### Placeholder Verification

After rendering `openclaw.json`, verify no unresolved placeholders remain:
```bash
if grep -q '\${' "${HOME}/.openclaw/openclaw.json"; then
    log_error "Unresolved placeholders in openclaw.json — check required env vars:"
    grep '\${' "${HOME}/.openclaw/openclaw.json" >&2
    exit 1
fi
```

### Workspace Copy Pattern

Copy workspace files only if missing (preserve user customizations):
```bash
setup_workspace() {
    mkdir -p "${HOME}/.openclaw/workspace"
    local workspace_files=( AGENTS.md SOUL.md TOOLS.md USER.md )
    for f in "${workspace_files[@]}"; do
        local src="${DEVBOX_DIR}/workspace/${f}"
        local dst="${HOME}/.openclaw/workspace/${f}"
        if [[ ! -f "${dst}" ]]; then
            if [[ -f "${src}" ]]; then
                cp "${src}" "${dst}"
                log_info "Copied workspace/${f}"
            else
                log_warn "Source workspace/${f} not found in ${DEVBOX_DIR}/workspace/ — skipping"
            fi
        else
            log_info "workspace/${f} already exists — preserving user customization"
        fi
    done
    log_success "Workspace files in place at ${HOME}/.openclaw/workspace/"
}
```

### Port Verification

The openclaw gateway listens on `${OPENCLAW_PORT}` (default 18789) bound to loopback (per `openclaw.json` template: `"bind": "loopback"`). Verify with `ss` (preferred, no external deps):
```bash
verify_port() {
    if ss -tlnp 2>/dev/null | grep -q ":${OPENCLAW_PORT}"; then
        log_success "Port ${OPENCLAW_PORT} is listening"
        return 0
    fi
    # Fallback: try curl to health endpoint
    if curl -sf "http://localhost:${OPENCLAW_PORT}/health" &>/dev/null; then
        log_success "OpenClaw gateway health check passed on port ${OPENCLAW_PORT}"
        return 0
    fi
    log_error "Port ${OPENCLAW_PORT} not listening — openclaw-gateway may have failed to start"
    return 1
}
```

### Security Notes (architecture § 8)

- `~/.openclaw/openclaw.json` MUST be mode 600 — it contains AWS keys and Discord bot token
- Credentials in environment variables are NOT echoed to stdout or log file
- The service file contains credentials via `Environment=AWS_ACCESS_KEY_ID=...` — this is intentional; systemd user services store env in the unit file which has mode 644, but the actual values were already in `~/.tiberbu-env` (mode 600). This is acceptable per architecture ADR-2.
- The openclaw.json mode 600 is enforced AFTER rendering (otherwise the rendered file might be world-readable momentarily):
  ```bash
  render_template "..." "${HOME}/.openclaw/openclaw.json"
  chmod 600 "${HOME}/.openclaw/openclaw.json"
  ```

### Complete Script Structure

The final `install-openclaw.sh` should follow this structure:

```bash
#!/usr/bin/env bash
# scripts/install-openclaw.sh — Phase 4: OpenClaw + Discord gateway
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVBOX_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/_common.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_common.sh"

trap 'error_handler "${BASH_SOURCE[0]}" "${LINENO}" "$?"' ERR

readonly PHASE_NUM=4
readonly PHASE_NAME="OpenClaw + Discord"
readonly TOTAL_PHASES=5

: "${OPENCLAW_PORT:=18789}"
: "${HOME:=/home/ubuntu}"

check_idempotency()  { ... }
source_nvm()         { ... }
install_openclaw()   { ... }
render_config()      { ... }
setup_workspace()    { ... }
install_service()    { ... }
wait_for_service()   { ... }
verify_phase()       { ... }

main() {
    log_phase_start "${PHASE_NUM}" "${TOTAL_PHASES}" "${PHASE_NAME}"
    local phase_start; phase_start="$(date +%s)"

    check_idempotency
    source_nvm
    install_openclaw
    render_config
    setup_workspace
    install_service
    wait_for_service
    verify_phase

    local phase_end elapsed
    phase_end="$(date +%s)"
    elapsed=$(( phase_end - phase_start ))
    log_phase_end "${PHASE_NUM}" "${TOTAL_PHASES}" "${PHASE_NAME}" "${elapsed}"
}

main
```

### Performance Target

From architecture § 10: Phase 4 target is **< 60 seconds** on t3.xlarge. The bottleneck is `npm install -g openclaw`. The service start adds ~5 seconds. Total budget is well within 60 seconds unless npm registry is slow.

### ShellCheck Notes

- Add `# shellcheck source=scripts/_common.sh` above the `source` line
- Add `# shellcheck disable=SC1091` above nvm sourcing
- Use `# shellcheck disable=SC2154` if using `PHASE_NUM` set via `readonly` — not usually needed
- Quote all variable references: `"${HOME}"`, `"${OPENCLAW_PORT}"`, `"${USER}"`
- The `wait_for_service` loop uses `(( ))` arithmetic — add `|| true` if the counter can reach zero and ShellCheck warns
- `loginctl` may not be available in all environments — the `|| log_warn` pattern handles this gracefully

### Project Structure Notes

**Files to Create:**
```
devbox/
└── scripts/
    ├── _common.sh              ← Already exists (from S1.1 / task #15)
    ├── install-system.sh       ← Already exists (from S1.2 / task #19)
    ├── install-node.sh         ← Already exists (from S1.3 / task #21)
    └── install-openclaw.sh     ← CREATE THIS (Phase 4 installer)
```

**Pre-existing files consumed by this script:**
- `scripts/_common.sh` — MUST exist (verify: `ls scripts/_common.sh`)
- `templates/openclaw.json.template` — MUST exist (verify: `ls templates/openclaw.json.template`)
- `templates/openclaw-gateway.service` — MUST exist (verify: `ls templates/openclaw-gateway.service`)
- `workspace/AGENTS.md`, `workspace/SOUL.md`, `workspace/TOOLS.md`, `workspace/USER.md` — should exist (from S3.1 / task #14); script logs a warning and continues if missing

**This story does NOT create:**
- `scripts/install-studio.sh` (S2.2 story)
- `scripts/install-bench.sh` (S2.3 story)
- `scripts/verify.sh` (S4.1 story)
- Any template files (S3.1 story — templates already exist per current repo state)

**Pre-existing system requirements:**
- Phase 1 complete: `curl`, `gettext-base` (envsubst), `ss` (iproute2) available
- Phase 2 complete: nvm + Node.js v24 + npm available at `~/.nvm/versions/node/v24/bin/`
- XDG_RUNTIME_DIR accessible (systemd user bus): set `export XDG_RUNTIME_DIR="/run/user/$(id -u)"` if `systemctl --user` fails

### Verification Commands (from PRD testing table, rows 10–12)

Run these after the script to confirm DoD criteria:
```bash
# AC-2: openclaw installed
openclaw --version
# Expected: non-empty version string (e.g. 2026.x.x or 0.x.x)

# AC-3: config rendered with mode 600, no placeholders
ls -la ~/.openclaw/openclaw.json
# Expected: -rw------- (600)
grep '\${' ~/.openclaw/openclaw.json
# Expected: no output (exit 1)

# AC-4: workspace files present
ls ~/.openclaw/workspace/
# Expected: AGENTS.md  SOUL.md  TOOLS.md  USER.md

# AC-5: service active
systemctl --user is-active openclaw-gateway
# Expected: active

# AC-6: port listening
ss -tlnp | grep 18789
# Expected: line containing :18789

# AC-1: Idempotency (second run < 2s)
time bash scripts/install-openclaw.sh
# Expected: "Phase 4 already complete — skipping" in < 2 seconds
```

### References

- Architecture § 3.1 — Phase 4 installation order [Source: _bmad-output/planning-artifacts/architecture.md#31-installation-order-phase-dependencies]
- Architecture § 4.1 — Repository structure (`scripts/install-openclaw.sh`) [Source: _bmad-output/planning-artifacts/architecture.md#41-repository-structure]
- Architecture § 4.2 — Installed paths (`~/.openclaw/`, `~/.config/systemd/user/`) [Source: _bmad-output/planning-artifacts/architecture.md#42-installed-paths-on-target-ec2]
- Architecture § 5 — `_common.sh` API Surface (`render_template`, `retry`, `check_marker`, `set_marker`, `clear_marker`, `log_*`) [Source: _bmad-output/planning-artifacts/architecture.md#5-shared-utility-library]
- Architecture § 6 — Template Variable Matrix (openclaw.json + gw.service columns) [Source: _bmad-output/planning-artifacts/architecture.md#6-template-variable-matrix]
- Architecture § 7 — Idempotency Strategy (Phase 4 row: `.phase-4-complete` + `systemctl --user is-active openclaw-gateway`) [Source: _bmad-output/planning-artifacts/architecture.md#7-idempotency-strategy]
- Architecture § 8 — Error Handling & Security (mode 600 for openclaw.json, no credential echoing) [Source: _bmad-output/planning-artifacts/architecture.md#8-error-handling--security]
- Architecture § 10 — Performance Budget (Phase 4: < 60s) [Source: _bmad-output/planning-artifacts/architecture.md#10-performance-budget]
- Architecture ADR-2 — envsubst for configuration templating [Source: _bmad-output/planning-artifacts/architecture.md#adr-2-envsubst-for-configuration-templating]
- Architecture ADR-3 — Hybrid Idempotency (marker + service check) [Source: _bmad-output/planning-artifacts/architecture.md#adr-3-hybrid-idempotency--marker-files--service-checks]
- Architecture ADR-5 — Error Handling — Fail Fast with Context [Source: _bmad-output/planning-artifacts/architecture.md#adr-5-error-handling--fail-fast-with-context]
- Architecture Service Table — `openclaw-gateway.service` is user scope on port 18789 [Source: _bmad-output/planning-artifacts/architecture.md#appendix-c-systemd-service-summary]
- PRD FR-6 — Phase 4 OpenClaw Configuration [Source: _bmad-output/planning-artifacts/prd.md#fr-6-phase-4--openclaw-configuration]
- PRD FR-11 — Idempotent Re-Run [Source: _bmad-output/planning-artifacts/prd.md#fr-11-idempotent-re-run]
- PRD NFR-1 — Performance (Phase 4: < 60s) [Source: _bmad-output/planning-artifacts/prd.md#nfr-1-performance]
- PRD NFR-2 — Reliability / Retries (npm: 3 attempts) [Source: _bmad-output/planning-artifacts/prd.md#nfr-2-reliability]
- PRD NFR-4 — Security (mode 600 for openclaw.json) [Source: _bmad-output/planning-artifacts/prd.md#nfr-4-security]
- PRD Appendix B — Port Allocation (18789 OpenClaw, loopback) [Source: _bmad-output/planning-artifacts/prd.md#appendix-b-port-allocation]
- PRD Appendix C — Service Summary (openclaw-gateway.service: user scope) [Source: _bmad-output/planning-artifacts/prd.md#appendix-c-systemd-service-summary]
- PRD Verification Table rows 10–12 — openclaw checks [Source: _bmad-output/planning-artifacts/prd.md#verification-checklist]
- Existing `scripts/_common.sh` — `error_handler` takes 3 args: SCRIPT LINE EXIT_CODE [Source: scripts/_common.sh]
- Existing `scripts/_common.sh` — `retry COUNT DELAY CMD...` [Source: scripts/_common.sh]
- Existing `scripts/_common.sh` — `render_template TEMPLATE OUTPUT` (envsubst wrapper) [Source: scripts/_common.sh]
- Existing `templates/openclaw.json.template` — variables: AWS_*, BEDROCK_*, DISCORD_*, OPENCLAW_PORT, HOME [Source: templates/openclaw.json.template]
- Existing `templates/openclaw-gateway.service` — variables: HOME, AWS_*, AWS_DEFAULT_REGION; ExecStart uses v24 symlink [Source: templates/openclaw-gateway.service]
- Existing `scripts/install-node.sh` — reference implementation (nvm sourcing pattern, retry, idempotency) [Source: scripts/install-node.sh]

---

## Dev Agent Record

### Agent Model Used

_to be filled by dev agent_

### Debug Log References

_to be filled by dev agent_

### Completion Notes List

_to be filled by dev agent_

### File List

- `scripts/install-openclaw.sh`
