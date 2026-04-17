# Story 3: Node.js Installer

**Story ID:** S3
**Epic:** E1 — Bootstrap Core Framework
**Points:** 3
**Estimated Hours:** 1
**Priority:** P0 — Phase 2 of bootstrap (required by Phases 3-5)
**Dependencies:** S1 (bootstrap.sh core framework, _common.sh)

---

## Description

Create `scripts/install-node.sh` — the Phase 2 installer that provisions nvm (Node Version Manager), installs Node.js v24.x LTS, and installs yarn 1.22.x globally. Node.js is required by Frappe Bench assets, OpenClaw, and Claude Code Studio.

---

## Acceptance Criteria

### AC-1: Idempotency check
- [ ] Checks marker file `.phase-2-complete` AND `node -v 2>/dev/null | grep -q "v24"` AND `yarn --version 2>/dev/null`
- [ ] If all pass: logs "Phase 2 already complete, skipping" and exits 0
- [ ] If marker exists but checks fail: clears marker and re-runs

### AC-2: nvm installation
- [ ] Downloads and runs nvm install script from `https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh` (or latest stable)
- [ ] Installs to `~/.nvm` (default location)
- [ ] Sources nvm into current shell session after install: `export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"`
- [ ] Uses retry logic (3 attempts) for the download
- [ ] Verifies: `command -v nvm` succeeds after sourcing

### AC-3: Node.js v24 installation
- [ ] Runs `nvm install 24` to install latest v24.x
- [ ] Sets as default: `nvm alias default 24`
- [ ] Verifies: `node -v` outputs `v24.x.x`
- [ ] Verifies: `npm -v` outputs a valid version

### AC-4: yarn installation
- [ ] Installs yarn globally: `npm install -g yarn`
- [ ] Verifies: `yarn --version` outputs `1.22.x`

### AC-5: PATH availability
- [ ] After installation, node/npm/yarn are available without sourcing nvm (via absolute path `~/.nvm/versions/node/v24.x.x/bin/`)
- [ ] Ensures `.bashrc` or `.profile` sources nvm for future shell sessions (nvm installer usually handles this)

### AC-6: Completion
- [ ] Sets marker file `.phase-2-complete` after all checks pass
- [ ] Total execution time logged

---

## Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `scripts/install-node.sh` | Create | Phase 2 installer |

---

## Technical Notes

- nvm modifies `~/.bashrc` to add its initialization. For non-interactive scripts, we must explicitly source nvm.
- The nvm sourcing pattern is needed in every phase script that uses node/npm/yarn (phases 3-5), OR each script should add nvm's bin to PATH directly.
- For systemd services, we use absolute paths to node binary (e.g., `${HOME}/.nvm/versions/node/v24/bin/node`) rather than relying on nvm shell integration.
- The nvm install script URL should use a pinned version for reproducibility.

---

## Definition of Done

- [ ] `bash -n scripts/install-node.sh` passes
- [ ] On fresh Ubuntu 24.04 (after Phase 1): script installs nvm + node + yarn without error
- [ ] `node -v` returns `v24.x.x`
- [ ] `npm -v` returns a valid version
- [ ] `yarn --version` returns `1.22.x`
- [ ] `which node` points to `~/.nvm/versions/node/v24.x.x/bin/node`
- [ ] Second run skips (exits 0 in < 2 seconds)
- [ ] ShellCheck passes with no errors
