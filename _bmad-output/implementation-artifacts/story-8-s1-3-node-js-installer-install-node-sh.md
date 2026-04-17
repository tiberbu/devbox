# Story: S1.3: Node.js Installer (install-node.sh)

Status: done

## Story

As a Tiberbu engineer,
I want a `scripts/install-node.sh` Phase 2 installer,
so that nvm is installed to `~/.nvm`, Node.js v24.x is installed and aliased as default, yarn 1.22.x is available globally, the script is fully idempotent — skipping safely on re-runs, and all subsequent phases (Frappe Bench, OpenClaw, Claude Studio) that depend on Node.js can rely on `~/.nvm/versions/node/v24.x.x/bin/` being present.

## Acceptance Criteria

### AC-1: Idempotency check
1. At script start, check all three conditions: `check_marker 2` (marker file `/var/tmp/devbox/.phase-2-complete` exists) AND `node -v 2>/dev/null | grep -q "v24"` AND `yarn --version 2>/dev/null`
2. If all three pass: call `log_info "Phase 2 already complete, skipping"` and `exit 0`
3. If marker exists but either check fails: call `clear_marker 2` to remove stale marker, then continue with full installation

### AC-2: nvm installation
4. Download and execute the nvm install script from `https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh` using `curl -o- URL | bash`
5. Wrap the download in `retry 3 10` for resilience against transient network failures
6. Install nvm to `~/.nvm` (default; set via `NVM_DIR` env var before running installer)
7. Source nvm into the current shell session immediately after install:
   ```bash
   export NVM_DIR="${HOME}/.nvm"
   # shellcheck disable=SC1091
   [[ -s "${NVM_DIR}/nvm.sh" ]] && \. "${NVM_DIR}/nvm.sh"
   ```
8. Verify nvm is available: `command -v nvm` must succeed; call `log_success "nvm installed and sourced"`

### AC-3: Node.js v24 installation
9. Run `nvm install 24` to install the latest Node.js v24.x LTS
10. Set it as the default version: `nvm alias default 24`
11. Verify: `node -v` outputs a string matching `v24.` prefix
12. Verify: `npm -v` outputs a valid version string
13. Call `log_success "Node.js $(node -v) installed and set as default"`

### AC-4: yarn installation
14. Install yarn globally: `npm install -g yarn`
15. Verify: `yarn --version` outputs a version string matching `1.22.`
16. Call `log_success "yarn $(yarn --version) installed"`

### AC-5: PATH availability
17. After installation, node/npm/yarn are available via absolute path `~/.nvm/versions/node/v24.x.x/bin/` without sourcing nvm
18. Confirm `.bashrc` has been updated by the nvm installer to source nvm for future interactive shell sessions (the nvm install script handles this automatically — no manual modification needed; verify by grepping `.bashrc` for `NVM_DIR`)

### AC-6: Completion
19. After all verifications pass, call `set_marker 2` to create `/var/tmp/devbox/.phase-2-complete`
20. The marker is only set AFTER all verifications pass — never before

### Definition of Done
21. `bash -n scripts/install-node.sh` exits 0 (syntax clean)
22. ShellCheck passes with no errors: `shellcheck scripts/install-node.sh`
23. On a fresh Ubuntu 24.04 (after Phase 1): script installs nvm + node + yarn without error
24. `node -v` returns `v24.x.x`
25. `npm -v` returns a valid version
26. `yarn --version` returns `1.22.x`
27. `which node` points to `~/.nvm/versions/node/v24.x.x/bin/node`
28. Second run completes in < 2 seconds (idempotency check exits early)

---

## Tasks / Subtasks

- [ ] **Task 1 — Script scaffold** (AC: all)
  - [ ] 1.1 Create `scripts/install-node.sh` with shebang `#!/usr/bin/env bash` and `set -euo pipefail`
  - [ ] 1.2 Add `SCRIPT_DIR` detection: `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`
  - [ ] 1.3 Source `_common.sh`: `source "${SCRIPT_DIR}/_common.sh"` with `# shellcheck source=scripts/_common.sh` and `# shellcheck disable=SC1091` directives above
  - [ ] 1.4 Set ERR trap: `trap 'error_handler "${BASH_SOURCE[0]}" "${LINENO}" "$?"' ERR`
  - [ ] 1.5 Define constants at top: `readonly PHASE_NUM=2`, `readonly PHASE_NAME="Node.js via nvm"`, `readonly TOTAL_PHASES=5`
  - [ ] 1.6 Define `readonly NVM_VERSION="v0.40.3"` and `readonly NVM_INSTALL_URL="https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh"`

- [ ] **Task 2 — Idempotency check function** (AC: 1–3)
  - [ ] 2.1 Implement `check_idempotency()` function that checks marker file, `node -v | grep -q "v24"`, and `yarn --version`
  - [ ] 2.2 If all pass: `log_success "Phase 2 already complete — skipping"` then `exit 0`
  - [ ] 2.3 If marker exists but checks fail: call `clear_marker "${PHASE_NUM}"` and fall through
  - [ ] 2.4 Call `check_idempotency` immediately after sourcing `_common.sh` and setting the ERR trap

- [ ] **Task 3 — nvm installation** (AC: 4–8)
  - [ ] 3.1 Export `NVM_DIR="${HOME}/.nvm"` before the install command so nvm installs to the correct location
  - [ ] 3.2 Use `retry 3 10 bash -c 'curl -o- "${NVM_INSTALL_URL}" | bash'` — note: `retry` passes CMD as `"$@"` so wrap curl-pipe in `bash -c` to be treated as a single command
  - [ ] 3.3 Source nvm in the current session after install: `export NVM_DIR="${HOME}/.nvm"` + `[[ -s "${NVM_DIR}/nvm.sh" ]] && \. "${NVM_DIR}/nvm.sh"`
  - [ ] 3.4 Verify: `command -v nvm` succeeds (if it fails, log_error and exit 1)
  - [ ] 3.5 `log_success "nvm ${NVM_VERSION} installed and sourced"`

- [ ] **Task 4 — Node.js v24 installation** (AC: 9–13)
  - [ ] 4.1 Run `nvm install 24` — this installs the latest Node.js v24.x LTS
  - [ ] 4.2 Run `nvm alias default 24` — sets v24 as the default
  - [ ] 4.3 Verify: `node -v | grep -q "^v24\."` — exit 1 with descriptive error if fails
  - [ ] 4.4 Verify: `npm -v` exits 0
  - [ ] 4.5 `log_success "Node.js $(node -v) installed and set as default"`
  - [ ] 4.6 `log_success "npm $(npm -v) available"`

- [ ] **Task 5 — yarn installation** (AC: 14–16)
  - [ ] 5.1 Run `npm install -g yarn`
  - [ ] 5.2 Verify: `yarn --version | grep -q "^1\.22\."` — exit 1 with descriptive error if fails
  - [ ] 5.3 `log_success "yarn $(yarn --version) installed"`

- [ ] **Task 6 — PATH availability check** (AC: 17–18)
  - [ ] 6.1 Locate the node binary path: `NODE_BIN_DIR="$(dirname "$(command -v node)")"` and log it
  - [ ] 6.2 Verify the path contains `.nvm/versions/node/v24`: `echo "${NODE_BIN_DIR}" | grep -q ".nvm/versions/node/v24"` — log_warn if it doesn't match expected pattern (non-fatal)
  - [ ] 6.3 Verify `.bashrc` sources nvm: `grep -q "NVM_DIR" "${HOME}/.bashrc"` — log_success if found, log_warn if not (the nvm installer should have added it)

- [ ] **Task 7 — Completion marker** (AC: 19–20)
  - [ ] 7.1 Call `set_marker "${PHASE_NUM}"` as the last step in the main flow
  - [ ] 7.2 Confirm marker is only set after all verifications succeed

- [ ] **Task 8 — Quality gates** (AC: 21–28)
  - [ ] 8.1 Run `bash -n scripts/install-node.sh` — must exit 0
  - [ ] 8.2 Run `shellcheck scripts/install-node.sh` — must produce no errors
  - [ ] 8.3 Verify `node -v` → `v24.x.x`
  - [ ] 8.4 Verify `npm -v` → valid version
  - [ ] 8.5 Verify `yarn --version` → `1.22.x`
  - [ ] 8.6 Verify `which node` → path containing `.nvm/versions/node/v24`
  - [ ] 8.7 Run script a second time and confirm it exits in < 2 seconds

- [ ] **Task 9 — `main()` function and phase timing** (AC: all)
  - [ ] 9.1 Wrap all steps in a `main()` function
  - [ ] 9.2 Call `log_phase_start "${PHASE_NUM}" "${TOTAL_PHASES}" "${PHASE_NAME}"` at entry
  - [ ] 9.3 Capture `phase_start="$(date +%s)"` before steps
  - [ ] 9.4 Compute and call `log_phase_end "${PHASE_NUM}" "${TOTAL_PHASES}" "${PHASE_NAME}" "${elapsed}"` at exit
  - [ ] 9.5 Call `main` at the bottom of the script

---

## Dev Notes

### Architecture Patterns

- **Script scaffold (from S1.1):** Every phase script follows the exact same pattern established in `bootstrap.sh` and `install-system.sh`:
  ```bash
  #!/usr/bin/env bash
  # scripts/install-node.sh — Phase 2: Node.js via nvm

  set -euo pipefail

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  # shellcheck source=scripts/_common.sh
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/_common.sh"

  trap 'error_handler "${BASH_SOURCE[0]}" "${LINENO}" "$?"' ERR

  readonly PHASE_NUM=2
  readonly PHASE_NAME="Node.js via nvm"
  readonly TOTAL_PHASES=5
  readonly NVM_VERSION="v0.40.3"
  readonly NVM_INSTALL_URL="https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh"
  ```
  Note: `_common.sh`'s `error_handler` takes **3 args** (SCRIPT LINE EXIT_CODE) — so the trap must include `"${BASH_SOURCE[0]}"` as first arg (see `scripts/_common.sh` line 138).

- **`check_idempotency()` pattern (from architecture § 7):** Phase 2 hybrid idempotency — marker file + `node -v` + `yarn --version`:
  ```bash
  check_idempotency() {
      if ! check_marker "${PHASE_NUM}"; then
          return 0   # No marker — proceed with full installation
      fi

      log_info "Marker .phase-${PHASE_NUM}-complete found — verifying Node.js and yarn"

      local checks_ok=true

      if ! node -v 2>/dev/null | grep -q "^v24\."; then
          log_warn "node -v did not return v24.x"
          checks_ok=false
      fi

      if ! yarn --version 2>/dev/null | grep -q "^1\.22\."; then
          log_warn "yarn --version did not return 1.22.x"
          checks_ok=false
      fi

      if [[ "${checks_ok}" == "true" ]]; then
          log_success "Phase ${PHASE_NUM} already complete — skipping (marker + checks OK)"
          exit 0
      else
          log_warn "Marker exists but checks failed — clearing marker and re-running"
          clear_marker "${PHASE_NUM}"
      fi
  }
  ```

- **nvm sourcing in non-interactive scripts:** nvm is a shell function loaded by sourcing `~/.nvm/nvm.sh`. In non-interactive scripts (like phase scripts), `.bashrc` is NOT automatically sourced. The script MUST explicitly source nvm after installation and before any `nvm`, `node`, `npm`, or `yarn` commands:
  ```bash
  export NVM_DIR="${HOME}/.nvm"
  # shellcheck disable=SC1091
  [[ -s "${NVM_DIR}/nvm.sh" ]] && \. "${NVM_DIR}/nvm.sh"
  ```
  This pattern is idempotent — sourcing nvm.sh twice is safe.

- **nvm install + nvm source order:** The nvm installer (`install.sh`) installs nvm to `~/.nvm` AND appends the sourcing lines to `~/.bashrc`. However, in the current shell session, the installer does NOT automatically activate nvm. The script must source it manually after the install:
  ```bash
  install_nvm() {
      log_info "Downloading nvm ${NVM_VERSION} installer..."
      export NVM_DIR="${HOME}/.nvm"
      retry 3 10 bash -c "curl -o- \"${NVM_INSTALL_URL}\" | bash"
      log_success "nvm installer executed"

      # Source nvm into current session
      # shellcheck disable=SC1091
      [[ -s "${NVM_DIR}/nvm.sh" ]] && \. "${NVM_DIR}/nvm.sh"

      if command -v nvm &>/dev/null; then
          log_success "nvm ${NVM_VERSION} installed and sourced"
      else
          log_error "nvm command not found after installation"
          return 1
      fi
  }
  ```

- **`retry` with pipe commands:** The `retry` function in `_common.sh` passes all its extra arguments to `"$@"`. Since `curl -o- URL | bash` is a pipeline (two processes), it cannot be passed as separate arguments to `retry`. Wrap it in `bash -c '...'`:
  ```bash
  retry 3 10 bash -c "curl -o- \"${NVM_INSTALL_URL}\" | bash"
  ```
  Alternatively, download to a temp file first, then execute:
  ```bash
  local nvm_tmp
  nvm_tmp="$(mktemp)"
  retry 3 10 curl -o "${nvm_tmp}" "${NVM_INSTALL_URL}"
  bash "${nvm_tmp}"
  rm -f "${nvm_tmp}"
  ```
  The temp file approach is more reliable since it separates download retries from execution.

- **Absolute paths for systemd services (architecture § 4.2):** After this phase completes, the node binary path will be `~/.nvm/versions/node/v24.x.x/bin/node`. Other phase scripts (install-openclaw.sh, install-studio.sh) and systemd service templates reference node via absolute path (NOT via `nvm` shell function). The exact path at install time can be determined with:
  ```bash
  NODE_BIN_DIR="$(dirname "$(command -v node)")"
  # e.g. /home/ubuntu/.nvm/versions/node/v24.7.0/bin
  ```
  This path is used in the `openclaw-gateway.service` and `claude-studio.service` templates.

- **`retry` usage (from architecture § 8):** The `retry` function in `_common.sh` takes `COUNT DELAY CMD...`:
  ```bash
  retry 3 10 curl -o "${nvm_tmp}" "${NVM_INSTALL_URL}"
  npm install -g yarn  # npm has its own retry, no wrapping needed
  ```

### nvm-Specific Notes

- The `NVM_DIR` variable must be exported **before** calling the nvm install script, otherwise nvm installs to `~/.nvm` by default anyway, but it's good practice to be explicit.
- After `nvm install 24`, the `node` and `npm` binaries are available in the current session (nvm modifies `PATH`). There's no need to re-source nvm after `nvm install`.
- `nvm alias default 24` creates a symlink at `~/.nvm/alias/default` pointing to the installed version. This ensures that future `nvm` invocations in new shell sessions default to v24.
- The yarn version installed via `npm install -g yarn` is currently `1.22.22` (classic yarn). This is correct — do NOT install yarn v2+ (berry) unless explicitly requested.
- After `npm install -g yarn`, the `yarn` binary is placed in the same `bin/` directory as `node` and `npm`: `~/.nvm/versions/node/v24.x.x/bin/yarn`.

### Environment Variables Required

This phase script does **not** require any variables from `~/.tiberbu-env`. It operates purely on the system's Node.js installation. However, `HOME` must be set (it always is in normal bash execution).

No `require_env` calls needed. Add a defensive guard for `HOME`:
```bash
: "${HOME:=/home/ubuntu}"
```

### ShellCheck Notes

- Add `# shellcheck source=scripts/_common.sh` above the `source` line
- Add `# shellcheck disable=SC1091` above the nvm sourcing line (SC1091: not following sourced file)
- Use `# shellcheck disable=SC1090` if sourcing a dynamic path
- Prefer `command -v nvm` over `which nvm` for portability (ShellCheck prefers `command -v`)
- Quote all variable references: `"${NVM_DIR}"` not `$NVM_DIR`
- The `\. "${NVM_DIR}/nvm.sh"` pattern (dot command) is preferred by ShellCheck over `source`

### Project Structure Notes

**Files to Create:**
```
devbox/
└── scripts/
    ├── _common.sh          ← Already exists (from S1.1 / task #15)
    ├── install-system.sh   ← Already exists (from S1.2 / task #19)
    └── install-node.sh     ← CREATE THIS (Phase 2 installer)
```

**This story does NOT create:**
- `scripts/install-bench.sh` (S2.3 story)
- `scripts/install-openclaw.sh` (S2.1 story)
- `scripts/install-studio.sh` (S2.2 story)
- `scripts/verify.sh` (S4.1 story)

**Pre-existing dependencies:**
- `scripts/_common.sh` — MUST exist before this script runs (created in S1.1 / task #15). Verify: `ls scripts/_common.sh`
- Phase 1 must have completed successfully on the target system (provides `curl`, `build-essential`, etc.)

### Complete Script Structure

The final `install-node.sh` should follow this structure:

```bash
#!/usr/bin/env bash
# scripts/install-node.sh — Phase 2: Node.js via nvm
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/_common.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_common.sh"

trap 'error_handler "${BASH_SOURCE[0]}" "${LINENO}" "$?"' ERR

readonly PHASE_NUM=2
readonly PHASE_NAME="Node.js via nvm"
readonly TOTAL_PHASES=5
readonly NVM_VERSION="v0.40.3"
readonly NVM_INSTALL_URL="https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh"

: "${HOME:=/home/ubuntu}"

check_idempotency() { ... }
install_nvm()       { ... }
install_node()      { ... }
install_yarn()      { ... }
verify_path()       { ... }

main() {
    log_phase_start "${PHASE_NUM}" "${TOTAL_PHASES}" "${PHASE_NAME}"
    local phase_start; phase_start="$(date +%s)"

    check_idempotency
    install_nvm
    install_node
    install_yarn
    verify_path
    set_marker "${PHASE_NUM}"

    local phase_end elapsed
    phase_end="$(date +%s)"
    elapsed=$(( phase_end - phase_start ))
    log_phase_end "${PHASE_NUM}" "${TOTAL_PHASES}" "${PHASE_NAME}" "${elapsed}"
}

main
```

### Performance Target

From architecture § 10: Phase 2 target is **< 30 seconds** on t3.xlarge. The main bottleneck is `nvm install 24` (downloading the Node.js tarball). The script should NOT add unnecessary sleeps beyond the `retry` backoff.

### Security Notes (architecture § 8)

- No credentials used in this phase
- nvm installs to `~/.nvm` (user-owned, not system-wide) — appropriate for per-user Node.js toolchain
- Binaries in `~/.nvm/versions/node/v24.x.x/bin/` are owned by the current user — no `sudo` needed for `npm install -g yarn`

### Verification Commands (from PRD testing table, rows 6–7)

Run these to confirm DoD criteria met:
```bash
# AC-3: Node.js version
node -v
# Expected: v24.x.x

# AC-3: npm version
npm -v
# Expected: valid semver

# AC-4: yarn version
yarn --version
# Expected: 1.22.x

# AC-5: node absolute path
which node
# Expected: /home/ubuntu/.nvm/versions/node/v24.x.x/bin/node

# AC-1: Idempotency (second run < 2s)
time bash scripts/install-node.sh
# Expected: "Phase 2 already complete, skipping" in < 2 seconds
```

### References

- Architecture § 3.1 — Phase 2 Node.js dependencies [Source: _bmad-output/planning-artifacts/architecture.md#31-installation-order-phase-dependencies]
- Architecture § 4.1 — Repository Structure [Source: _bmad-output/planning-artifacts/architecture.md#41-repository-structure]
- Architecture § 4.2 — Installed Paths (`~/.nvm/versions/node/v24.x.x/bin/`) [Source: _bmad-output/planning-artifacts/architecture.md#42-installed-paths-on-target-ec2]
- Architecture § 5 — `_common.sh` API Surface [Source: _bmad-output/planning-artifacts/architecture.md#5-shared-utility-library]
- Architecture § 7 — Idempotency Strategy (Phase 2 row) [Source: _bmad-output/planning-artifacts/architecture.md#7-idempotency-strategy]
- Architecture § 8 — Error Handling & Security [Source: _bmad-output/planning-artifacts/architecture.md#8-error-handling--security]
- Architecture § 9 — Technology Versions (Node.js v24.x, yarn 1.22.x) [Source: _bmad-output/planning-artifacts/architecture.md#9-technology-versions]
- Architecture § 10 — Performance Budget (Phase 2: < 30s) [Source: _bmad-output/planning-artifacts/architecture.md#10-performance-budget]
- Architecture ADR-3 — Hybrid Idempotency [Source: _bmad-output/planning-artifacts/architecture.md#adr-3-hybrid-idempotency--marker-files--service-checks]
- Architecture ADR-5 — Error Handling [Source: _bmad-output/planning-artifacts/architecture.md#adr-5-error-handling--fail-fast-with-context]
- PRD FR-4 — Phase 2 Node.js via nvm [Source: _bmad-output/planning-artifacts/prd.md#fr-4-phase-2--nodejs-via-nvm]
- PRD FR-11 — Idempotent Re-Run [Source: _bmad-output/planning-artifacts/prd.md#fr-11-idempotent-re-run]
- PRD NFR-1 — Performance (< 30s Phase 2) [Source: _bmad-output/planning-artifacts/prd.md#nfr-1-performance]
- PRD NFR-2 — Reliability / Retries [Source: _bmad-output/planning-artifacts/prd.md#nfr-2-reliability]
- PRD Verification Table rows 6–7 — node -v, yarn --version [Source: _bmad-output/planning-artifacts/prd.md#verification-checklist]
- Existing `_common.sh` — `error_handler` signature: 3 args (SCRIPT LINE EXIT_CODE) [Source: scripts/_common.sh line 138]
- Existing `_common.sh` — `retry COUNT DELAY CMD...` [Source: scripts/_common.sh line 159]
- Existing `install-system.sh` — reference implementation for script structure [Source: scripts/install-system.sh]

---

## Dev Agent Record

### Agent Model Used

_to be filled by dev agent_

### Debug Log References

_to be filled by dev agent_

### Completion Notes List

_to be filled by dev agent_

### File List

- `scripts/install-node.sh`
