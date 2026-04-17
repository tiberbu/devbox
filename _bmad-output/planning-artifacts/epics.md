# Tiberbu DevBox — Epics & Stories

**Version:** 1.0
**Date:** 2026-04-17
**Status:** Approved
**Derived From:** [Architecture v1.0](architecture.md), [PRD v1.0](../../docs/planning.md)

---

## Epic Overview

| Epic | Name | Stories | Total Points | Est. Hours |
|------|------|---------|-------------|-----------|
| E1 | Bootstrap Core Framework | S1, S2, S3 | 11 | 5 |
| E2 | Application Stack | S4, S5, S6 | 11 | 6 |
| E3 | Configuration & Templates | S7 | 5 | 2 |
| E4 | Verification & Polish | S8, S9 | 8 | 3 |
| **Total** | | **9 stories** | **35 points** | **16 hours** |

---

## Epic 1: Bootstrap Core Framework

**Goal:** Establish the orchestrator, shared utilities, and foundational system-level infrastructure that all subsequent phases depend on.

**Success Criteria:**
- `bootstrap.sh` loads credentials, validates them, and can orchestrate phase execution
- `_common.sh` provides logging, markers, templates, and error handling
- System dependencies (apt, MariaDB, Redis) installed and running
- Node.js v24 + yarn available on PATH

### Stories in Epic 1

| Story | Title | Points | Depends On |
|-------|-------|--------|------------|
| S1 | bootstrap.sh core framework | 3 | — |
| S2 | System dependencies installer | 5 | S1 |
| S3 | Node.js installer | 3 | S1 |

---

## Epic 2: Application Stack

**Goal:** Install and configure the three application-level components (Frappe Bench, OpenClaw, Claude Studio) with systemd services and credential injection.

**Success Criteria:**
- Frappe Bench initialized with site and running in dev mode
- OpenClaw gateway running as systemd user service with Discord connected
- Claude Code Studio built from source and running as systemd system service

### Stories in Epic 2

| Story | Title | Points | Depends On |
|-------|-------|--------|------------|
| S4 | OpenClaw installer | 3 | S1, S3, S7 |
| S5 | Claude Studio installer | 3 | S1, S3, S7 |
| S6 | Frappe Bench installer | 5 | S1, S2, S3 |

---

## Epic 3: Configuration & Templates

**Goal:** Create all configuration templates and workspace files that are consumed by the installers and the reconfigure script.

**Success Criteria:**
- All 4 templates render correctly with envsubst
- Workspace files provide meaningful defaults for OpenClaw agent
- Template variable coverage matches architecture document

### Stories in Epic 3

| Story | Title | Points | Depends On |
|-------|-------|--------|------------|
| S7 | Config templates and workspace files | 5 | — |

---

## Epic 4: Verification & Polish

**Goal:** Comprehensive health checks, Discord notification, and a credential-only reconfigure script for AMI use.

**Success Criteria:**
- 16-point verification suite passes on fresh bootstrap
- Discord notification received with service status
- `configure.sh` completes credential rotation in < 60 seconds

### Stories in Epic 4

| Story | Title | Points | Depends On |
|-------|-------|--------|------------|
| S8 | Verification and smoke test | 5 | S2, S3, S4, S5, S6 |
| S9 | configure.sh (credential-only reconfigure) | 3 | S1, S7 |

---

## Dependency Graph

```
S1 (bootstrap.sh core)
├──▶ S2 (system deps)
│     └──▶ S6 (frappe bench)
├──▶ S3 (node.js)
│     ├──▶ S4 (openclaw)
│     ├──▶ S5 (claude studio)
│     └──▶ S6 (frappe bench)
└──▶ S9 (configure.sh)

S7 (templates) ─── independent, but consumed by S4, S5, S9

S8 (verify) ◀── depends on all of S2-S6 being implementable
```

---

## Recommended Implementation Order

```
Sprint 1 (Foundation):     S1 → S7 → S2 → S3
Sprint 2 (App Stack):      S4 → S5 → S6
Sprint 3 (Polish):         S8 → S9
```

**Rationale:**
- S1 + S7 have zero dependencies — start them first
- S2 + S3 depend only on S1's _common.sh being available
- S4, S5, S6 need Node.js (S3) and templates (S7)
- S8 needs all installers complete to write meaningful checks
- S9 reuses S1's env loading + S7's templates

---

## Story Detail Index

Each story has a dedicated implementation file in `_bmad-output/implementation-artifacts/`:

| File | Story |
|------|-------|
| `story-1-bootstrap-core.md` | S1: bootstrap.sh core framework |
| `story-2-system-deps.md` | S2: System dependencies installer |
| `story-3-node-installer.md` | S3: Node.js installer |
| `story-4-openclaw-installer.md` | S4: OpenClaw installer |
| `story-5-claude-studio-installer.md` | S5: Claude Studio installer |
| `story-6-frappe-bench-installer.md` | S6: Frappe Bench installer |
| `story-7-config-templates.md` | S7: Config templates |
| `story-8-verification.md` | S8: Verification and smoke test |
| `story-9-configure-sh.md` | S9: configure.sh |
