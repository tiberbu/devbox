# Tiberbu DevBox — Technical Architecture

**Version:** 1.0
**Date:** 2026-04-17
**Status:** Approved
**Derived From:** [PRD v1.0](../docs/planning.md), [Domain Research](../_bmad-output/planning-artifacts/domain-research.md)

---

## 1. System Overview

Tiberbu DevBox is a modular bootstrap system that provisions a complete AI-assisted development environment on a fresh Ubuntu 24.04 EC2 instance. The system is composed of an orchestrator script, five phase-specific installers, a shared utility library, configuration templates, and a verification suite.

### 1.1 Component Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Engineer's Workstation                       │
│  ┌──────────────┐                                                   │
│  │ ~/.tiberbu-env│ ─── credentials ──┐                              │
│  └──────────────┘                    │                              │
│                                      ▼                              │
│  ┌──────────────────────────────────────────────────────────┐       │
│  │                    bootstrap.sh                           │       │
│  │  (Orchestrator)                                           │       │
│  │  - Argument parsing (--dry-run, --phase, --env-file)      │       │
│  │  - Environment loading & validation                       │       │
│  │  - Sequential phase execution with timing                 │       │
│  │  - Error handling & progress reporting                    │       │
│  │                                                           │       │
│  │  Sources: scripts/_common.sh                              │       │
│  └────┬─────────┬─────────┬──────────┬──────────┬───────────┘       │
│       │         │         │          │          │                    │
│       ▼         ▼         ▼          ▼          ▼                    │
│  ┌─────────┐┌────────┐┌────────┐┌─────────┐┌─────────┐             │
│  │ Phase 1 ││Phase 2 ││Phase 3 ││ Phase 4 ││ Phase 5 │             │
│  │ System  ││Node.js ││Frappe  ││OpenClaw ││ Claude  │             │
│  │  Deps   ││  nvm   ││ Bench  ││+Discord ││ Studio  │             │
│  └────┬────┘└───┬────┘└───┬────┘└────┬────┘└────┬────┘             │
│       │         │         │          │          │                    │
│       ▼         ▼         ▼          ▼          ▼                    │
│  ┌─────────┐┌────────┐┌────────┐┌─────────┐┌─────────┐             │
│  │MariaDB  ││Node 24 ││~/frappe││~/.open- ││~/claude-│             │
│  │Redis    ││yarn    ││-bench  ││claw/    ││code-    │             │
│  │apt pkgs ││nvm     ││        ││         ││studio   │             │
│  └─────────┘└────────┘└────────┘└─────────┘└─────────┘             │
│       │                    │          │          │                    │
│       └────────────────────┴──────────┴──────────┘                  │
│                            │                                         │
│                            ▼                                         │
│                   ┌─────────────────┐                                │
│                   │  scripts/verify │                                │
│                   │  .sh            │     ┌──────────────┐           │
│                   │  Health checks  │────▶│ Discord API  │           │
│                   │  Summary table  │     │ Notification │           │
│                   └─────────────────┘     └──────────────┘           │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────┐       │
│  │                    configure.sh                            │       │
│  │  (Credential-only reconfigure for AMI / key rotation)     │       │
│  │  - Re-renders templates                                   │       │
│  │  - Restarts services                                      │       │
│  │  - Sends Discord notification                             │       │
│  └──────────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────────┘
```

### 1.2 Service Architecture (Running State)

```
┌─────────────────────────────────────────────────────────────┐
│                    Ubuntu 24.04 EC2 Instance                 │
│                                                              │
│  ┌──────────────────── systemd (system) ──────────────────┐ │
│  │                                                         │ │
│  │  mariadb.service ──────── :3306 (localhost)             │ │
│  │  redis-server.service ─── :6379 (localhost)             │ │
│  │  claude-studio.service ── :3000 (0.0.0.0)              │ │
│  │                                                         │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌──────────────────── systemd (user) ────────────────────┐ │
│  │                                                         │ │
│  │  openclaw-gateway.service ── :18789 (localhost)         │ │
│  │                                                         │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌──────────────────── bench (manual) ────────────────────┐ │
│  │                                                         │ │
│  │  frappe bench (dev mode) ── :8000 (localhost)           │ │
│  │                                                         │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                              │
│  Discord API ◀──────── OpenClaw Gateway ──────── Bedrock    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Data Flow

### 2.1 Credential Flow (Bootstrap)

```
~/.tiberbu-env                    envsubst
┌─────────────────┐     ┌─────────────────────┐     ┌─────────────────────────┐
│ AWS_ACCESS_KEY_ID│     │ templates/            │     │ Rendered Config Files    │
│ AWS_SECRET_..    │────▶│   openclaw.json.tmpl  │────▶│ ~/.openclaw/openclaw.json│
│ DISCORD_BOT_..  │     │   openclaw-gw.service │     │ ~/.config/systemd/user/  │
│ DISCORD_GUILD.. │     │   claude-studio.svc   │     │   openclaw-gateway.service│
│ DISCORD_CHAN..   │     │   claude-studio-cfg   │     │ /etc/systemd/system/     │
│ DISCORD_USER..  │     │                       │     │   claude-studio.service   │
│ GITHUB_TOKEN    │     └─────────────────────┘     │ ~/claude-code-studio/    │
│ (+ optional)    │                                   │   config.json             │
└─────────────────┘                                   └─────────────────────────┘
        │                                                        │
        │                                                        ▼
        │         ┌─────────────────────┐              ┌──────────────────┐
        └────────▶│ git credential store│              │ systemd restart  │
                  │ ~/.git-credentials  │              │ services active  │
                  └─────────────────────┘              └──────────────────┘
```

### 2.2 Credential Flow (configure.sh — AMI Reconfigure)

```
~/.tiberbu-env (new credentials)
        │
        ▼
┌─────────────────────────────────────────────────┐
│  configure.sh                                    │
│  1. Load & validate credentials                  │
│  2. Re-render ALL templates via envsubst         │
│  3. Update git credential store                  │
│  4. Restart openclaw-gateway (systemd --user)    │
│  5. Restart claude-studio (systemd system)       │
│  6. Run verification checks                      │
│  7. Send Discord notification                    │
└─────────────────────────────────────────────────┘
        │
        ▼
  Services running with new credentials (< 60s)
```

### 2.3 Runtime Data Flow

```
Discord User
    │
    │ message
    ▼
Discord API ──────▶ OpenClaw Gateway (:18789)
                         │
                         │ AI inference request
                         ▼
                    AWS Bedrock (Claude Opus)
                         │
                         │ tool use / code execution
                         ▼
                    Local tools (file I/O, shell, git)
                         │
                         │ bench commands, file edits
                         ▼
                    Frappe Bench (:8000) ◀──▶ MariaDB (:3306)
                                             Redis (:6379)
                         │
                         │ response
                         ▼
                    Discord API ──────▶ Discord User

Claude Code Studio (:3000) ── Web UI for code editing
    │
    ▼
  Project files (~/frappe-bench, etc.)
```

---

## 3. Dependency Graph

### 3.1 Installation Order (Phase Dependencies)

```
Phase 1: System Dependencies
    │
    ├── MariaDB 10.11 ──────────────────────────────────┐
    ├── Redis 7.x ──────────────────────────────────────┐│
    ├── build-essential, python3, pip, venv              ││
    ├── gettext-base (envsubst)                         ││
    ├── wkhtmltopdf                                     ││
    └── libmysqlclient-dev, libffi-dev, libssl-dev      ││
        │                                               ││
        ▼                                               ││
Phase 2: Node.js via nvm                               ││
    │                                                   ││
    ├── nvm → Node.js v24.x                             ││
    └── yarn 1.22.x (npm install -g)                    ││
        │                                               ││
        ├──────────────────────┬────────────────────┐   ││
        ▼                      ▼                    ▼   ▼▼
Phase 3: Frappe Bench    Phase 4: OpenClaw    Phase 5: Claude Studio
    │                         │                     │
    ├── pip install bench     ├── npm -g openclaw   ├── git clone
    ├── bench init            ├── render config     ├── npm install
    ├── bench new-site ──────▶│   (envsubst)        ├── npm run build
    │   (needs MariaDB) ──┘   ├── copy workspace    ├── render systemd
    └── dev mode config       ├── systemd user svc  └── systemd system svc
                              └── gateway start
```

**Key constraints:**
- Phase 1 must complete before all others (provides apt packages, MariaDB, Redis)
- Phase 2 must complete before 3, 4, 5 (provides Node.js, npm, yarn)
- Phase 3 needs MariaDB from Phase 1 (for `bench new-site`)
- Phase 4 needs Node.js from Phase 2 (for `npm install -g openclaw`)
- Phase 5 needs Node.js from Phase 2 (for `npm install && npm run build`)
- Phases 3, 4, 5 are independent of each other (but run sequentially for simplicity)

### 3.2 Service Dependency Graph

```
network.target
    │
    ├──▶ mariadb.service (system)
    │        │
    │        └──▶ frappe bench (manual, dev mode)
    │
    ├──▶ redis-server.service (system)
    │        │
    │        └──▶ frappe bench (manual, dev mode)
    │
    ├──▶ openclaw-gateway.service (user)
    │        │
    │        ├──▶ Discord API (outbound)
    │        └──▶ AWS Bedrock API (outbound)
    │
    └──▶ claude-studio.service (system)
             │
             └──▶ Project files on disk
```

---

## 4. File Layout (Exact Paths)

### 4.1 Repository Structure

```
devbox/                                    # Project root (cloned or curl'd)
├── bootstrap.sh                           # Main orchestrator entry point
│                                          #   - Parses --dry-run, --phase, --env-file
│                                          #   - Sources scripts/_common.sh
│                                          #   - Loads & validates ~/.tiberbu-env
│                                          #   - Executes phases 1-5 sequentially
│                                          #   - Invokes scripts/verify.sh
│
├── configure.sh                           # Credential-only reconfigure
│                                          #   - For AMI-based setup or key rotation
│                                          #   - Re-renders all templates
│                                          #   - Restarts affected services
│                                          #   - Runs verification + Discord notify
│
├── scripts/
│   ├── _common.sh                         # Shared utility library (sourced, never executed)
│   │                                      #   Functions:
│   │                                      #     log_info(), log_success(), log_error(), log_warn()
│   │                                      #     log_phase_start(), log_phase_end()
│   │                                      #     check_marker(), set_marker(), clear_marker()
│   │                                      #     require_env(), require_command()
│   │                                      #     render_template()  (envsubst wrapper)
│   │                                      #     error_handler()    (ERR trap)
│   │                                      #     retry()            (retry with backoff)
│   │                                      #   Constants:
│   │                                      #     MARKER_DIR=/var/tmp/devbox
│   │                                      #     LOG_FILE=/var/tmp/devbox/bootstrap.log
│   │                                      #     Color codes (RED, GREEN, YELLOW, BLUE, NC)
│   │
│   ├── install-system.sh                  # Phase 1: System dependencies (~45s)
│   │                                      #   - apt update && apt install (20+ packages)
│   │                                      #   - MariaDB: utf8mb4 charset, root password
│   │                                      #   - Redis: verify PONG response
│   │                                      #   - wkhtmltopdf installation
│   │                                      #   - Idempotency: marker + systemctl is-active
│   │
│   ├── install-node.sh                    # Phase 2: Node.js via nvm (~30s)
│   │                                      #   - nvm install to ~/.nvm
│   │                                      #   - Node.js v24.x LTS
│   │                                      #   - yarn 1.22.x via npm install -g
│   │                                      #   - Idempotency: marker + node -v check
│   │
│   ├── install-bench.sh                   # Phase 3: Frappe Bench (~4min)
│   │                                      #   - pip install frappe-bench
│   │                                      #   - bench init ~/frappe-bench --frappe-branch version-15
│   │                                      #   - bench new-site dev.local
│   │                                      #   - Development mode config
│   │                                      #   - Idempotency: marker + bench --version + site check
│   │
│   ├── install-openclaw.sh                # Phase 4: OpenClaw + Discord (~60s)
│   │                                      #   - npm install -g openclaw
│   │                                      #   - Render openclaw.json from template
│   │                                      #   - Copy workspace files (AGENTS.md, etc.)
│   │                                      #   - Create systemd user service
│   │                                      #   - Enable linger, start gateway
│   │                                      #   - Idempotency: marker + service active check
│   │
│   ├── install-studio.sh                  # Phase 5: Claude Code Studio (~90s)
│   │                                      #   - git clone (with GITHUB_TOKEN auth)
│   │                                      #   - npm install && npm run build
│   │                                      #   - Render systemd service + config
│   │                                      #   - Enable and start service
│   │                                      #   - Idempotency: marker + HTTP 200 check
│   │
│   └── verify.sh                          # Post-install verification
│                                          #   - 16-point health check suite
│                                          #   - Summary table with status/version/port
│                                          #   - Discord notification (graceful degradation)
│                                          #   - Exit 0 only if all checks pass
│
├── templates/
│   ├── openclaw.json.template             # OpenClaw config with ${VAR} placeholders
│   │                                      #   Vars: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY,
│   │                                      #         BEDROCK_REGION, BEDROCK_MODEL,
│   │                                      #         DISCORD_BOT_TOKEN, DISCORD_GUILD_ID,
│   │                                      #         DISCORD_CHANNEL_ID, DISCORD_USER_ID,
│   │                                      #         OPENCLAW_PORT, HOME
│   │
│   ├── openclaw-gateway.service           # Systemd user unit template
│   │                                      #   Vars: HOME, AWS_ACCESS_KEY_ID,
│   │                                      #         AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION
│   │                                      #   Target: ~/.config/systemd/user/
│   │
│   ├── claude-studio.service              # Systemd system unit template
│   │                                      #   Vars: USER, HOME, CLAUDE_STUDIO_PORT
│   │                                      #   Target: /etc/systemd/system/
│   │
│   └── claude-studio-config.json.template # Claude Studio config template
│                                          #   Vars: HOME, CLAUDE_STUDIO_PORT
│                                          #   Target: ~/claude-code-studio/config.json
│
├── workspace/
│   ├── AGENTS.md                          # Default OpenClaw workspace — agent definitions
│   ├── SOUL.md                            # Default OpenClaw workspace — agent personality
│   ├── TOOLS.md                           # Default OpenClaw workspace — available tools
│   └── USER.md                            # Default OpenClaw workspace — user context
│
├── docs/
│   ├── requirements.md                    # Project requirements
│   ├── planning.md                        # Implementation plan (PRD)
│   └── architecture.md                    # This document
│
└── README.md                              # Quick start guide
```

### 4.2 Installed Paths (On Target EC2)

```
/home/ubuntu/                              # User home ($HOME)
├── .tiberbu-env                           # Engineer credentials (mode 600)
│
├── .nvm/                                  # Node Version Manager
│   └── versions/node/v24.x.x/            # Active Node.js installation
│       └── bin/
│           ├── node
│           ├── npm
│           ├── npx
│           ├── yarn
│           └── openclaw
│
├── .openclaw/                             # OpenClaw configuration
│   ├── openclaw.json                      # Rendered config (mode 600)
│   └── workspace/                         # Agent workspace
│       ├── AGENTS.md
│       ├── SOUL.md
│       ├── TOOLS.md
│       └── USER.md
│
├── .config/systemd/user/                  # User systemd units
│   └── openclaw-gateway.service           # Rendered from template
│
├── .git-credentials                       # GitHub token storage
│
├── frappe-bench/                           # Frappe Bench installation
│   ├── apps/
│   │   └── frappe/                        # Frappe framework (version-15)
│   ├── sites/
│   │   ├── dev.local/                     # Default site
│   │   └── common_site_config.json
│   ├── env/                               # Python virtualenv
│   └── Procfile
│
├── claude-code-studio/                    # Claude Studio (built from source)
│   ├── dist/
│   │   └── server.js                      # Built server entry point
│   ├── config.json                        # Rendered from template
│   ├── node_modules/
│   └── package.json
│
└── devbox/                                # This repository (if cloned)

/etc/systemd/system/
└── claude-studio.service                  # Rendered from template

/var/tmp/devbox/                           # Runtime state (survives reboot)
├── bootstrap.log                          # Full verbose log (append mode)
├── .phase-1-complete                      # Marker files for idempotency
├── .phase-2-complete
├── .phase-3-complete
├── .phase-4-complete
└── .phase-5-complete
```

---

## 5. Shared Utility Library (`scripts/_common.sh`)

### 5.1 API Surface

| Function | Signature | Purpose |
|----------|-----------|---------|
| `log_info` | `log_info "message"` | Blue arrow prefix, logs to file |
| `log_success` | `log_success "message"` | Green checkmark prefix, logs to file |
| `log_error` | `log_error "message"` | Red X prefix, logs to file |
| `log_warn` | `log_warn "message"` | Yellow bang prefix, logs to file |
| `log_phase_start` | `log_phase_start NUM TOTAL "name"` | Phase header with formatting |
| `log_phase_end` | `log_phase_end NUM TOTAL "name" ELAPSED` | Phase completion with timing |
| `check_marker` | `check_marker PHASE_NUM` | Returns 0 if marker file exists |
| `set_marker` | `set_marker PHASE_NUM` | Creates marker file |
| `clear_marker` | `clear_marker PHASE_NUM` | Removes marker file |
| `require_env` | `require_env VAR_NAME` | Exits 1 if variable is empty |
| `require_command` | `require_command CMD_NAME` | Exits 1 if command not found |
| `render_template` | `render_template TEMPLATE OUTPUT` | envsubst wrapper with logging |
| `error_handler` | `error_handler LINE EXIT_CODE` | ERR trap: shows log tail, exits |
| `retry` | `retry COUNT DELAY CMD...` | Retry command with delay between attempts |

### 5.2 Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `MARKER_DIR` | `/var/tmp/devbox` | Marker file storage |
| `LOG_FILE` | `/var/tmp/devbox/bootstrap.log` | Verbose log output |
| `RED` | `\033[0;31m` | Error color |
| `GREEN` | `\033[0;32m` | Success color |
| `YELLOW` | `\033[1;33m` | Warning color |
| `BLUE` | `\033[0;34m` | Info color |
| `NC` | `\033[0m` | Reset color |

---

## 6. Template System

### 6.1 Rendering Pipeline

```
Step 1: Load ~/.tiberbu-env (set -a; source; set +a)
Step 2: Apply defaults (: "${VAR:=default}")
Step 3: Export all required variables
Step 4: envsubst < template > output
Step 5: Set permissions (chmod 600 for credential files)
```

### 6.2 Template Variable Matrix

| Variable | openclaw.json | gw.service | studio.service | studio-config |
|----------|:---:|:---:|:---:|:---:|
| `AWS_ACCESS_KEY_ID` | ✓ | ✓ | | |
| `AWS_SECRET_ACCESS_KEY` | ✓ | ✓ | | |
| `AWS_DEFAULT_REGION` | | ✓ | | |
| `BEDROCK_REGION` | ✓ | | | |
| `BEDROCK_MODEL` | ✓ | | | |
| `DISCORD_BOT_TOKEN` | ✓ | | | |
| `DISCORD_GUILD_ID` | ✓ | | | |
| `DISCORD_CHANNEL_ID` | ✓ | | | |
| `DISCORD_USER_ID` | ✓ | | | |
| `OPENCLAW_PORT` | ✓ | | | |
| `HOME` | ✓ | ✓ | ✓ | ✓ |
| `USER` | | | ✓ | |
| `CLAUDE_STUDIO_PORT` | | | ✓ | ✓ |

---

## 7. Idempotency Strategy

### 7.1 Hybrid Check per Phase

Each phase script implements `check_completed()` at the top:

| Phase | Marker Check | Active Check | Skip Condition |
|-------|-------------|--------------|----------------|
| 1 — System | `.phase-1-complete` | `systemctl is-active mariadb && redis-cli ping` | Both pass |
| 2 — Node.js | `.phase-2-complete` | `node -v \| grep v24 && yarn --version` | Both pass |
| 3 — Bench | `.phase-3-complete` | `bench --version && [[ -d ~/frappe-bench/sites/dev.local ]]` | Both pass |
| 4 — OpenClaw | `.phase-4-complete` | `systemctl --user is-active openclaw-gateway` | Both pass |
| 5 — Studio | `.phase-5-complete` | `systemctl is-active claude-studio` | Both pass |

### 7.2 Failure Recovery

```
if marker exists AND active check passes:
    → skip phase (log "already complete")
elif marker exists AND active check fails:
    → clear marker, re-run phase (log "stale marker, retrying")
else:
    → run phase normally
```

---

## 8. Error Handling Architecture

### 8.1 Global Strategy

```bash
set -euo pipefail                          # Fail fast on any error
trap 'error_handler $LINENO $?' ERR        # Custom handler with context
```

### 8.2 Error Handler Behavior

```
On Error:
  1. Print file name, line number, exit code
  2. Print last 20 lines of /var/tmp/devbox/bootstrap.log
  3. Print path to full log file
  4. Exit with original exit code
```

### 8.3 Retry Strategy

| Operation | Max Retries | Delay | Rationale |
|-----------|-------------|-------|-----------|
| `apt install` | 3 | 5s | Transient mirror failures |
| `npm install` | 3 | 5s | Registry timeout |
| `git clone` | 3 | 5s | GitHub rate limits |
| `bench init` | 1 | 0s | Long-running; failures are usually deterministic |
| Discord API | 2 | 3s | Rate limit or transient network |

### 8.4 Graceful Degradation

Non-critical operations use `|| true` to prevent bootstrap failure:
- Discord notification send
- Bench doctor check (informational)
- Git credential validation

---

## 9. Security Architecture

### 9.1 Credential Protection

| File | Permissions | Contains |
|------|------------|----------|
| `~/.tiberbu-env` | 600 | All secrets (AWS, Discord, GitHub) |
| `~/.openclaw/openclaw.json` | 600 | Rendered AWS + Discord credentials |
| `~/.git-credentials` | 600 | GitHub token |
| `~/.config/systemd/user/openclaw-gateway.service` | 644 | AWS env vars in Environment= lines |

### 9.2 Credential Flow Security

- Credentials are **never** echoed to stdout
- Credentials are **never** written to the log file
- `envsubst` renders templates in-memory (no intermediate temp files)
- Systemd service files use `Environment=` directives (not EnvironmentFile for simplicity; acceptable for single-user dev instance)
- Git credential store is standard git mechanism (`store` helper)

### 9.3 Network Security

| Port | Binding | Access |
|------|---------|--------|
| 3306 (MariaDB) | localhost | Local only |
| 6379 (Redis) | localhost | Local only |
| 8000 (Frappe) | localhost | Local only |
| 18789 (OpenClaw) | loopback | Local only |
| 3000 (Claude Studio) | 0.0.0.0 | EC2 security group controls access |

---

## 10. Port Allocation

| Port | Service | Protocol | Binding | Managed By |
|------|---------|----------|---------|------------|
| 3306 | MariaDB 10.11 | MySQL | localhost | systemd (system) |
| 6379 | Redis 7.x | Redis | localhost | systemd (system) |
| 8000 | Frappe Bench | HTTP | localhost | bench (manual/dev mode) |
| 3000 | Claude Code Studio | HTTP | 0.0.0.0 | systemd (system) |
| 18789 | OpenClaw Gateway | HTTP | loopback | systemd (user) |

---

## 11. Architecture Decision Records

### ADR-1: Modular Scripts over Monolithic Bootstrap
**Status:** Accepted
**Decision:** Split into `bootstrap.sh` (orchestrator) + 5 phase scripts in `scripts/`.
**Rationale:** Each phase is independently testable, failure-isolated, and idempotent. Engineers can re-run individual phases.

### ADR-2: envsubst for Configuration Templating
**Status:** Accepted
**Decision:** Use `envsubst` from `gettext-base` package for all template rendering.
**Rationale:** Zero external dependencies, handles special characters in credentials, templates remain human-readable.

### ADR-3: Hybrid Idempotency (Marker Files + Service Checks)
**Status:** Accepted
**Decision:** Combine marker files at `/var/tmp/devbox/.phase-N-complete` with active service/binary checks.
**Rationale:** Marker alone is unreliable after failed installs; service check alone misses non-service components.

### ADR-4: Structured Logging with Phases and Timing
**Status:** Accepted
**Decision:** Color-coded stdout + verbose append-mode log file at `/var/tmp/devbox/bootstrap.log`.
**Rationale:** Engineers need immediate visual feedback and post-mortem debugging capability.

### ADR-5: Fail Fast with Context (set -euo pipefail + ERR trap)
**Status:** Accepted
**Decision:** Global strict mode with custom error handler showing file, line, and log tail.
**Rationale:** Catches errors early while providing enough context for self-diagnosis.

### ADR-6: configure.sh as Separate Credential-Only Script
**Status:** Accepted
**Decision:** Separate script for credential injection without reinstallation.
**Rationale:** Pre-baked AMIs need fast (<60s) credential setup without repeating package installs.

---

## 12. Technology Versions

| Technology | Version | Source | Notes |
|------------|---------|--------|-------|
| Ubuntu | 24.04 LTS (Noble) | AMI | Base OS |
| Node.js | v24.x LTS | nvm | Via nvm install |
| Python | 3.12.x | System apt | Ubuntu default |
| MariaDB | 10.11.x | apt | Ubuntu default repo |
| Redis | 7.0.x | apt | Ubuntu default repo |
| Frappe Bench CLI | 5.x | pip | Latest stable |
| Frappe Framework | version-15 | bench init | Configurable via FRAPPE_BRANCH |
| OpenClaw | latest | npm | Global install |
| Claude Code Studio | latest | GitHub | Built from source |
| yarn | 1.22.x | npm | Classic yarn |
| wkhtmltopdf | 0.12.6 | apt/deb | PDF generation for Frappe |
| nvm | latest | curl script | Node version manager |

---

## 13. Performance Budget

| Phase | Component | Target Time | Bottleneck |
|-------|-----------|-------------|------------|
| 1 | System dependencies | < 90s | apt download on standard mirrors |
| 2 | Node.js via nvm | < 30s | nvm install + npm global |
| 3 | Frappe Bench | < 5min | `bench init` (git clone + pip install) |
| 4 | OpenClaw + Discord | < 60s | npm install + service start |
| 5 | Claude Code Studio | < 90s | git clone + npm install + build |
| — | Verification | < 30s | Service health checks |
| **Total** | **All phases** | **< 10min** | **Phase 3 dominates** |

---

## 14. Testing Strategy

### 14.1 Test Layers

| Layer | Method | What it Validates |
|-------|--------|-------------------|
| Dry-run | `./bootstrap.sh --dry-run` | Env parsing, credential validation, template rendering |
| Docker | `docker run ... --dry-run` | Package list validity, script syntax |
| EC2 fresh | Full run on spot instance | End-to-end installation |
| EC2 idempotent | Second run on same instance | Re-run completes < 60s, 0 errors |
| Single-phase | `./bootstrap.sh --phase N` | Individual phase isolation |

### 14.2 Verification Checklist (16 points)

Automated in `scripts/verify.sh`:

| # | Check | Command | Expected |
|---|-------|---------|----------|
| 1 | MariaDB running | `systemctl is-active mariadb` | active |
| 2 | MariaDB connection | `mariadb -u root -p... -e "SELECT 1"` | 1 |
| 3 | MariaDB charset | `SHOW VARIABLES LIKE 'character_set_server'` | utf8mb4 |
| 4 | Redis running | `systemctl is-active redis-server` | active |
| 5 | Redis PING | `redis-cli ping` | PONG |
| 6 | Node.js version | `node -v` | v24.x.x |
| 7 | yarn version | `yarn --version` | 1.22.x |
| 8 | Bench CLI | `bench --version` | 5.x.x |
| 9 | Bench site | `bench --site $BENCH_SITE doctor` | exit 0 |
| 10 | OpenClaw version | `openclaw --version` | 2026.x |
| 11 | OpenClaw gateway | `systemctl --user is-active openclaw-gateway` | active |
| 12 | OpenClaw port | `curl localhost:$OPENCLAW_PORT/health` | 200 |
| 13 | Studio service | `systemctl is-active claude-studio` | active |
| 14 | Studio port | `curl localhost:$CLAUDE_STUDIO_PORT` | 200 |
| 15 | Git auth | `git ls-remote github.com/tiberbu/devbox` | exit 0 |
| 16 | Discord | Check channel for notification | received |
