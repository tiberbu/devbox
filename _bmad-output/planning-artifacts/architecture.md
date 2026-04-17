# Tiberbu DevBox — Technical Architecture

**Version:** 1.0
**Date:** 2026-04-17
**Status:** Approved
**Derived From:** [PRD v1.0](../docs/planning.md), [Domain Research](domain-research.md)

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
├── configure.sh                           # Credential-only reconfigure
├── scripts/
│   ├── _common.sh                         # Shared utility library (sourced)
│   ├── install-system.sh                  # Phase 1: System dependencies
│   ├── install-node.sh                    # Phase 2: Node.js via nvm
│   ├── install-bench.sh                   # Phase 3: Frappe Bench
│   ├── install-openclaw.sh                # Phase 4: OpenClaw + Discord
│   ├── install-studio.sh                  # Phase 5: Claude Code Studio
│   └── verify.sh                          # Post-install verification
├── templates/
│   ├── openclaw.json.template             # OpenClaw config template
│   ├── openclaw-gateway.service           # Systemd user unit template
│   ├── claude-studio.service              # Systemd system unit template
│   └── claude-studio-config.json.template # Claude Studio config template
├── workspace/
│   ├── AGENTS.md                          # Default agent definitions
│   ├── SOUL.md                            # Default agent personality
│   ├── TOOLS.md                           # Default available tools
│   └── USER.md                            # Default user context
├── docs/
│   ├── requirements.md                    # Project requirements
│   ├── planning.md                        # Implementation plan (PRD)
│   └── architecture.md                    # This document
└── README.md                              # Quick start guide
```

### 4.2 Installed Paths (On Target EC2)

```
/home/ubuntu/
├── .tiberbu-env                           # Engineer credentials (mode 600)
├── .nvm/versions/node/v24.x.x/bin/       # node, npm, npx, yarn, openclaw
├── .openclaw/
│   ├── openclaw.json                      # Rendered config (mode 600)
│   └── workspace/{AGENTS,SOUL,TOOLS,USER}.md
├── .config/systemd/user/
│   └── openclaw-gateway.service           # Rendered from template
├── .git-credentials                       # GitHub token storage
├── frappe-bench/                          # Frappe Bench installation
│   ├── apps/frappe/                       # Frappe framework (version-15)
│   ├── sites/dev.local/                   # Default site
│   └── env/                               # Python virtualenv
├── claude-code-studio/                    # Claude Studio (built from source)
│   ├── dist/server.js                     # Built server entry point
│   └── config.json                        # Rendered from template
└── devbox/                                # This repository (if cloned)

/etc/systemd/system/
└── claude-studio.service                  # Rendered from template

/var/tmp/devbox/
├── bootstrap.log                          # Full verbose log
└── .phase-{1..5}-complete                 # Idempotency marker files
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
| `log_phase_start` | `log_phase_start NUM TOTAL "name"` | Phase header |
| `log_phase_end` | `log_phase_end NUM TOTAL "name" ELAPSED` | Phase completion |
| `check_marker` | `check_marker PHASE_NUM` | Returns 0 if marker exists |
| `set_marker` | `set_marker PHASE_NUM` | Creates marker file |
| `clear_marker` | `clear_marker PHASE_NUM` | Removes marker file |
| `require_env` | `require_env VAR_NAME` | Exits 1 if variable empty |
| `require_command` | `require_command CMD_NAME` | Exits 1 if not found |
| `render_template` | `render_template TEMPLATE OUTPUT` | envsubst wrapper |
| `error_handler` | `error_handler LINE EXIT_CODE` | ERR trap handler |
| `retry` | `retry COUNT DELAY CMD...` | Retry with delay |

---

## 6. Template Variable Matrix

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

| Phase | Marker Check | Active Check | Skip Condition |
|-------|-------------|--------------|----------------|
| 1 | `.phase-1-complete` | `systemctl is-active mariadb && redis-cli ping` | Both pass |
| 2 | `.phase-2-complete` | `node -v \| grep v24 && yarn --version` | Both pass |
| 3 | `.phase-3-complete` | `bench --version && site dir exists` | Both pass |
| 4 | `.phase-4-complete` | `systemctl --user is-active openclaw-gateway` | Both pass |
| 5 | `.phase-5-complete` | `systemctl is-active claude-studio` | Both pass |

---

## 8. Error Handling & Security

### Error Strategy
- `set -euo pipefail` globally + `trap 'error_handler $LINENO $?' ERR`
- Retry: 3 attempts with 5s delay for apt, npm, git operations
- Graceful degradation: Discord notification, bench doctor use `|| true`

### Security
- `~/.tiberbu-env` and `~/.openclaw/openclaw.json` set to mode 600
- Credentials never echoed to stdout or log file
- All database/cache services bound to localhost only

---

## 9. Technology Versions

| Technology | Version | Source |
|------------|---------|--------|
| Ubuntu | 24.04 LTS | AMI |
| Node.js | v24.x | nvm |
| Python | 3.12.x | apt |
| MariaDB | 10.11.x | apt |
| Redis | 7.0.x | apt |
| Frappe Bench | 5.x | pip |
| Frappe | version-15 | bench init |
| OpenClaw | latest | npm |
| Claude Studio | latest | GitHub |
| yarn | 1.22.x | npm |
| wkhtmltopdf | 0.12.6 | apt |

---

## 10. Performance Budget

| Phase | Target | Bottleneck |
|-------|--------|------------|
| 1 — System deps | < 90s | apt download |
| 2 — Node.js | < 30s | nvm + npm |
| 3 — Frappe Bench | < 5min | bench init |
| 4 — OpenClaw | < 60s | npm install |
| 5 — Claude Studio | < 90s | clone + build |
| Verification | < 30s | health checks |
| **Total** | **< 10min** | **Phase 3** |
