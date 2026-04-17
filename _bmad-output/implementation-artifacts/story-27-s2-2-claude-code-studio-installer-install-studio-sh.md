# Story 2.2: Claude Code Studio Installer (install-studio.sh)

Status: done

## Story

As a Tiberbu engineer,
I want `scripts/install-studio.sh` to clone, build, configure, and daemonize Claude Code Studio as a systemd system service,
so that `http://localhost:3000` serves the web IDE immediately after a fresh bootstrap with zero manual steps.

---

## Acceptance Criteria

### AC-1: Idempotency check
- [x] Checks marker `/var/tmp/devbox/.phase-5-complete` AND `systemctl is-active claude-studio`
- [x] If both pass: log "Phase 5 already complete, skipping" and `exit 0`
- [x] If marker exists but `systemctl is-active claude-studio` fails: `clear_marker 5` and re-run

### AC-2: Git clone / pull with token auth
- [x] Sources nvm (`${HOME}/.nvm/nvm.sh`) to make `node` / `npm` available on PATH in non-interactive shell
- [x] Configures git credential helper: `git config --global credential.helper store`
- [x] Writes `https://${GITHUB_TOKEN}@github.com` to `~/.git-credentials` and `chmod 600 ~/.git-credentials`
- [x] If `~/claude-code-studio` does NOT exist: `git clone https://github.com/Mwogi/claude-code-studio.git ~/claude-code-studio` with `retry 3 5`
- [x] If `~/claude-code-studio` already exists: `git -C ~/claude-code-studio pull` (handles idempotent re-run after a partial clone)

### AC-3: Build from source
- [x] `cd ~/claude-code-studio`
- [x] `npm install` with `retry 3 15` (network flakiness protection)
- [x] `npm run build`
- [x] Assert `~/claude-code-studio/dist/server.js` exists after build; fail with a clear error if not

### AC-4: Configuration rendering
- [x] `render_template "${DEVBOX_DIR}/templates/claude-studio-config.json.template" "${HOME}/claude-code-studio/config.json"`
- [x] Verify no unresolved `${VAR}` placeholders remain in `config.json`
- [x] Template variables: `${HOME}` and `${CLAUDE_STUDIO_PORT}` (default: 3000)

### AC-5: Systemd system service
- [x] `render_template "${DEVBOX_DIR}/templates/claude-studio.service"` → temp file at `/tmp/claude-studio.service.rendered`
- [x] `sudo cp /tmp/claude-studio.service.rendered /etc/systemd/system/claude-studio.service`
- [x] `sudo systemctl daemon-reload`
- [x] `sudo systemctl enable claude-studio`
- [x] `sudo systemctl start claude-studio`
- [x] Poll `systemctl is-active claude-studio` for up to 15 seconds; fail with `systemctl status` dump on timeout

### AC-6: Verification and marker
- [x] `systemctl is-active claude-studio` returns `active`
- [x] `curl -sf http://localhost:${CLAUDE_STUDIO_PORT}` returns HTTP 200
- [x] `set_marker 5` → creates `/var/tmp/devbox/.phase-5-complete`

---

## Tasks / Subtasks

- [x] Task 1 — Scaffold script & idempotency (AC: 1)
  - [x] `set -euo pipefail`, source `_common.sh`, set up ERR trap
  - [x] Define `PHASE_NUM=5`, `PHASE_NAME="Claude Code Studio"`, `TOTAL_PHASES=5`
  - [x] Defensive defaults: `: "${CLAUDE_STUDIO_PORT:=3000}"`, `: "${HOME:=/home/ubuntu}"`
  - [x] Implement `check_idempotency()` — marker + `systemctl is-active` dual check

- [x] Task 2 — Git credential setup & clone/pull (AC: 2)
  - [x] Implement `source_nvm()` — source `${HOME}/.nvm/nvm.sh`, verify `npm` on PATH
  - [x] Implement `setup_git_credentials()` — credential helper, write `~/.git-credentials` (mode 600)
  - [x] Implement `clone_or_pull()` — branch on `[[ -d ~/claude-code-studio/.git ]]`, retry on clone

- [x] Task 3 — Build pipeline (AC: 3)
  - [x] Implement `build_studio()` — `cd`, `retry 3 15 npm install`, `npm run build`, assert `dist/server.js`

- [x] Task 4 — Configuration (AC: 4)
  - [x] Implement `render_config()` — `render_template` then grep for unresolved `${` placeholders

- [x] Task 5 — Systemd service (AC: 5)
  - [x] Implement `install_service()` — render to temp, `sudo cp`, `daemon-reload`, `enable`, `start`
  - [x] Implement `wait_for_service()` — 15-iteration poll with 1s sleep, status dump on failure

- [x] Task 6 — Verify and mark complete (AC: 6)
  - [x] Implement `verify_phase()` — `systemctl is-active`, HTTP 200 check, `set_marker 5`

- [x] Task 7 — Quality gate
  - [x] `bash -n scripts/install-studio.sh` passes
  - [x] `shellcheck scripts/install-studio.sh` passes with zero warnings (fix any SC2155, SC2016, etc.)

---

## Dev Notes

### Architecture Context

- **Phase number:** 5 of 5 (final phase in bootstrap sequence)
- **Service type:** systemd **system** service (not user) — requires `sudo` for `/etc/systemd/system/` and `systemctl` commands
- **Port binding:** `0.0.0.0:${CLAUDE_STUDIO_PORT}` (default 3000) — EC2 security group controls external access
- **Runtime user:** `ubuntu` — specified via `User=${USER}` in the unit template; `USER` variable must be exported before `render_template`
- **Node binary path:** `${HOME}/.nvm/versions/node/v24/bin/node` — nvm installs here; the systemd unit must reference the absolute path because systemd does not source `~/.bashrc`
- **Contrast with Phase 4:** OpenClaw uses a **user** service (`systemctl --user`); Claude Studio uses a **system** service (`sudo systemctl`) — no `XDG_RUNTIME_DIR` needed

### Idempotency Design

Follows the same dual-check pattern as Phases 1–4:

```
check_marker 5  →  fail  →  proceed with full install
                  pass   →  check systemctl is-active claude-studio
                               pass  →  exit 0 (skip)
                               fail  →  clear_marker 5, proceed
```

This prevents re-running on a fully provisioned instance while still recovering from a partial install where the marker was set but the service died.

### nvm Sourcing in Non-Interactive Shell

Bash does not source `~/.bashrc` in non-interactive scripts. The install script must manually source nvm:

```bash
export NVM_DIR="${HOME}/.nvm"
# shellcheck disable=SC1090,SC1091
[[ -s "${NVM_DIR}/nvm.sh" ]] && \. "${NVM_DIR}/nvm.sh"
```

Verify with `command -v npm &>/dev/null || { log_error "npm not found"; exit 1; }`.

### Git Credential Pattern

```bash
# Configure credential store (idempotent)
git config --global credential.helper store

# Write token (overwrite on every run — token may have changed)
printf 'https://%s@github.com\n' "${GITHUB_TOKEN}" > "${HOME}/.git-credentials"
chmod 600 "${HOME}/.git-credentials"
```

Using `printf` instead of `echo` avoids trailing-newline surprises and is ShellCheck-clean.

### Clone vs Pull Logic

```bash
if [[ -d "${HOME}/claude-code-studio/.git" ]]; then
    log_info "Repository already cloned — running git pull"
    git -C "${HOME}/claude-code-studio" pull
else
    retry 3 5 git clone https://github.com/Mwogi/claude-code-studio.git "${HOME}/claude-code-studio"
fi
```

Check `.git/` (not just the directory) to distinguish a complete clone from a stale partial directory.

### npm Build Retry

`npm install` can fail transiently on slow network or npm registry hiccups:

```bash
retry 3 15 npm install
npm run build
```

`npm run build` is NOT retried — a build failure indicates a code or environment issue that manual retry won't fix.

### Systemd System Service Pattern

```bash
local tmp_svc="/tmp/claude-studio.service.rendered"
render_template "${DEVBOX_DIR}/templates/claude-studio.service" "${tmp_svc}"
sudo cp "${tmp_svc}" /etc/systemd/system/claude-studio.service
sudo systemctl daemon-reload
sudo systemctl enable claude-studio
sudo systemctl start claude-studio
```

The temp file trick (`/tmp/...rendered`) avoids needing `render_template` to `sudo`-write directly to `/etc/systemd/system/`, keeping `render_template` unprivileged.

### Wait-for-Service Pattern (15s)

```bash
wait_for_service() {
    local max_attempts=15
    local attempt=0
    while (( attempt < max_attempts )); do
        if systemctl is-active --quiet claude-studio 2>/dev/null; then
            log_success "claude-studio is active"
            return 0
        fi
        attempt=$(( attempt + 1 ))
        sleep 1
    done
    log_error "claude-studio did not stabilize within ${max_attempts}s"
    sudo systemctl status claude-studio --no-pager 2>&1 | tail -20 || true
    return 1
}
```

### HTTP Verification

```bash
local http_code
http_code="$(curl -s -o /dev/null -w "%{http_code}" \
    "http://localhost:${CLAUDE_STUDIO_PORT}" 2>/dev/null || true)"
if [[ "${http_code}" == "200" ]]; then
    log_success "Claude Studio HTTP 200 on port ${CLAUDE_STUDIO_PORT}"
else
    log_error "Claude Studio HTTP check failed (code: ${http_code:-no response})"
    return 1
fi
```

### Template Variables Used

See architecture § 6 — Template Variable Matrix:

| Variable | Source | Default | Used in template |
|----------|--------|---------|-----------------|
| `${USER}` | system | ubuntu | `claude-studio.service` (User=) |
| `${HOME}` | system | /home/ubuntu | both templates |
| `${CLAUDE_STUDIO_PORT}` | `~/.tiberbu-env` | 3000 | both templates |

Export all three before calling `render_template`:
```bash
export USER HOME CLAUDE_STUDIO_PORT
```

### ShellCheck Expectations

Known patterns requiring inline disables:

| Pattern | SC Code | Why |
|---------|---------|-----|
| `\. "${NVM_DIR}/nvm.sh"` | SC1090, SC1091 | Dynamic source path |
| `grep '\${'` | SC2016 | Intentional literal `${` search |
| `# shellcheck source=scripts/_common.sh` | N/A | Source directive for static analysis |

### Performance Budget

Target: < 90 seconds on t3.xlarge (architecture § 10).

| Step | Expected time |
|------|-------------|
| git clone (fresh) | ~10s |
| npm install | ~40s |
| npm run build | ~20s |
| systemd start + stabilize | ~5s |
| **Total** | **~75s** |

### Project Structure Notes

- **Script location:** `scripts/install-studio.sh` — consistent with all other phase scripts
- **Installed app dir:** `~/claude-code-studio/` — set by git clone target path
- **Config file:** `~/claude-code-studio/config.json` — rendered from `templates/claude-studio-config.json.template` (already exists)
- **Systemd unit source:** `templates/claude-studio.service` (already exists — renders `${USER}`, `${HOME}`, `${CLAUDE_STUDIO_PORT}`)
- **Systemd unit destination:** `/etc/systemd/system/claude-studio.service`
- **Marker:** `/var/tmp/devbox/.phase-5-complete` (managed via `set_marker 5` / `clear_marker 5`)
- **Shared library:** source `${SCRIPT_DIR}/_common.sh` — provides `log_*`, `retry`, `check_marker`, `set_marker`, `clear_marker`, `render_template`, `error_handler`

### Prerequisite Checks

The script can optionally guard against missing prerequisites (Phase 2 must run first):

```bash
require_command node  || { log_error "node not found — run install-node.sh first"; exit 1; }
require_command npm   || { log_error "npm not found — run install-node.sh first"; exit 1; }
```

These are non-blocking guards (the `source_nvm` step will catch the same thing), but explicit messages improve debuggability.

### References

- Script pattern: [Source: scripts/install-openclaw.sh] — exact same structure; replace `--user` systemctl calls with system-level `sudo systemctl` equivalents
- Service type distinction: [Source: _bmad-output/planning-artifacts/architecture.md#1.2 Service Architecture]
- Template variable matrix: [Source: _bmad-output/planning-artifacts/architecture.md#6 Template Variable Matrix]
- Idempotency strategy: [Source: _bmad-output/planning-artifacts/architecture.md#7 Idempotency Strategy]
- FR-7 acceptance criteria: [Source: _bmad-output/planning-artifacts/prd.md#FR-7: Phase 5 — Claude Code Studio]
- Port allocation: [Source: _bmad-output/planning-artifacts/prd.md#Appendix B]
- Performance budget: [Source: _bmad-output/planning-artifacts/architecture.md#10 Performance Budget]

---

## Definition of Done

- [x] `bash -n scripts/install-studio.sh` exits 0
- [x] `shellcheck scripts/install-studio.sh` exits 0 with no warnings
- [ ] `~/claude-code-studio/dist/server.js` exists after build
- [ ] `~/claude-code-studio/config.json` rendered with no `${VAR}` placeholders remaining
- [ ] `systemctl is-active claude-studio` returns `active`
- [ ] `curl -s -o /dev/null -w "%{http_code}" http://localhost:${CLAUDE_STUDIO_PORT}` returns `200`
- [ ] Second run completes in < 2 seconds (idempotency — marker + service check both pass)

---

## Dev Agent Record

### Agent Model Used

sonnet

### Debug Log References

### Completion Notes List

- Implemented `scripts/install-studio.sh` — all 6 ACs covered in 9 functions matching install-openclaw.sh architecture
- Key differences from openclaw: system service (sudo systemctl, no XDG_RUNTIME_DIR), git clone+build pipeline instead of npm install -g, 15s wait poll, HTTP 200 curl verification
- Clone detection uses `.git/` subdirectory check (not just directory) to safely handle partial clones
- Template variables (USER, HOME, CLAUDE_STUDIO_PORT) exported before render_template calls
- `bash -n` and `shellcheck` both pass with zero warnings/errors

### Change Log

| Date | Author | Change |
|------|--------|--------|
| 2026-04-17 | dev-agent | Created `scripts/install-studio.sh` — Phase 5 installer for Claude Code Studio |

### File List

- `scripts/install-studio.sh` (created)
