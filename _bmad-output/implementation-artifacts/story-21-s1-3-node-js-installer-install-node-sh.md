# Story: S1.3: Node.js Installer (install-node.sh)

Status: done
Task ID: mo38dehpe4s57k
Task Number: #21
Workflow: dev-story
Model: sonnet
Created: 2026-04-17T18:17:27.445Z

## Description

## Story S3 — Node.js Installer
**Epic:** E1 — Bootstrap Core Framework | **Points:** 3 | **Priority:** P0

### Acceptance Criteria

#### AC-1: Idempotency check
- [ ] Checks marker .phase-2-complete AND node -v returns v24 AND yarn --version succeeds
- [ ] If all pass: logs skip and exits 0
- [ ] If marker exists but checks fail: clears marker and re-runs

#### AC-2: nvm installation
- [ ] Downloads nvm v0.40.3 install script with retry (3 attempts)
- [ ] Installs to ~/.nvm
- [ ] Sources nvm in current session
- [ ] Verifies command -v nvm

#### AC-3: Node.js v24
- [ ] nvm install 24, nvm alias default 24
- [ ] Verifies node -v outputs v24.x.x
- [ ] Verifies npm -v works

#### AC-4: yarn installation
- [ ] npm install -g yarn
- [ ] Verifies yarn --version outputs 1.22.x

#### AC-5: PATH availability
- [ ] node/npm/yarn available via absolute path ~/.nvm/versions/node/v24.x.x/bin/
- [ ] .bashrc sources nvm for future sessions

#### AC-6: Completion
- [ ] Set marker .phase-2-complete

### Files to Create
- scripts/install-node.sh

### Definition of Done
- bash -n passes, ShellCheck clean
- node -v returns v24.x.x, yarn --version returns 1.22.x
- which node points to ~/.nvm/versions/node/v24.x.x/bin/node
- Second run skips in < 2 seconds

Story file created by task #8. Read the story from _bmad-output/implementation-artifacts/ and implement all acceptance criteria.

## Acceptance Criteria

- [x] #### AC-1: Idempotency check
- [x] Checks marker .phase-2-complete AND node -v returns v24 AND yarn --version succeeds
- [x] If all pass: logs skip and exits 0
- [x] If marker exists but checks fail: clears marker and re-runs

- [x] #### AC-2: nvm installation
- [x] Downloads nvm v0.40.3 install script with retry (3 attempts)
- [x] Installs to ~/.nvm
- [x] Sources nvm in current session
- [x] Verifies command -v nvm

- [x] #### AC-3: Node.js v24
- [x] nvm install 24, nvm alias default 24
- [x] Verifies node -v outputs v24.x.x
- [x] Verifies npm -v works

- [x] #### AC-4: yarn installation
- [x] npm install -g yarn
- [x] Verifies yarn --version outputs 1.22.x

- [x] #### AC-5: PATH availability
- [x] node/npm/yarn available via absolute path ~/.nvm/versions/node/v24.x.x/bin/
- [x] .bashrc sources nvm for future sessions

- [x] #### AC-6: Completion
- [x] Set marker .phase-2-complete

## Tasks / Subtasks

- [x] Implement changes
- [x] Verify build passes (bash -n + ShellCheck clean)

## Dev Notes



### References

- Task source: Claude Code Studio task #21

## Dev Agent Record

### Agent Model Used

sonnet

### Completion Notes List

- Implemented `scripts/install-node.sh` satisfying all 6 acceptance criteria.
- Script is fully idempotent: checks `.phase-2-complete` marker + `node -v` v24.x.x + `yarn --version`; skips on success, clears marker and re-runs on partial state.
- nvm v0.40.3 is downloaded via `curl` with 3-attempt retry to a temp file, then executed. nvm is sourced immediately for the current session via `_source_nvm()` helper.
- Node.js v24 installed via `nvm install 24` with `nvm alias default 24`; both `node -v` and `npm -v` verified.
- yarn installed via `npm install -g yarn`; `yarn --version` verified.
- `.bashrc` checked for NVM_DIR block; added if absent (nvm installer typically adds it).
- Absolute paths for node/npm/yarn logged to confirm AC-5.
- `bash -n` passes; `shellcheck 0.9.0` passes with zero warnings.

### Change Log

| Date | Change |
|------|--------|
| 2026-04-17 | Created `scripts/install-node.sh` — Phase 2 Node.js installer (nvm v0.40.3 + Node.js v24 + yarn). All ACs implemented. bash -n and ShellCheck clean. |

### File List

- `scripts/install-node.sh` — **created**
