---
stepsCompleted: [init, discovery, vision, executive-summary, success, journeys, domain, innovation, project-type, scoping, functional, nonfunctional, polish, complete]
inputDocuments: [docs/requirements.md, README.md]
workflowType: prd
---

# Product Requirements Document - Tiberbu DevBox

**Author:** Ubuntu
**Date:** 2026-04-17
**Version:** 1.0
**Status:** Complete

---

## Executive Summary

### Vision

Tiberbu DevBox eliminates the multi-hour, error-prone manual setup of AI-assisted development environments by providing a single idempotent bootstrap script that provisions a complete stack (Frappe Bench, OpenClaw, Claude Code Studio, MariaDB, Redis) on a fresh Ubuntu 24.04 EC2 instance in under 10 minutes.

### Problem Statement

Tiberbu engineers currently spend 2-4 hours manually installing and configuring interdependent services (Node.js, Python, MariaDB, Redis, Frappe Bench, OpenClaw, Claude Code Studio) with frequent misconfigurations caused by version mismatches, missing dependencies, and credential wiring errors. Each new team member or instance rebuild repeats this cost.

### Target Users

Software engineers at Tiberbu who need a fully working AI-assisted development environment connected to Discord, with Frappe Bench for ERP development and Claude-powered coding tools.

### Differentiator

Single `curl | bash` command transforms a bare EC2 into a production-ready development workstation with all services configured, verified, and reporting status to the engineer's Discord channel.

### Scope

**In scope:** Bootstrap script, modular install phases, configuration templates, credential injection, service verification, idempotency, AMI-compatible reconfigure script.

**Out of scope:** Frappe app installation beyond base framework, custom OpenClaw plugins, CI/CD pipelines, multi-instance orchestration, backup/restore.

---

## Success Criteria

| ID | Criterion | Measurement | Target |
|----|-----------|-------------|--------|
| SC-1 | Total bootstrap time on t3.xlarge | Wall-clock from script start to Discord confirmation | < 10 minutes |
| SC-2 | Zero manual intervention | Engineer provides only `~/.tiberbu-env` before running | 0 interactive prompts |
| SC-3 | All services operational | Post-bootstrap health checks pass | 5/5 services (MariaDB, Redis, Frappe, OpenClaw, Claude Studio) |
| SC-4 | Idempotent re-runs | Second run on already-provisioned instance completes without error | < 60 seconds, 0 errors |
| SC-5 | Discord confirmation | Bot sends setup-complete message to configured channel | Message received within 30s of script completion |
| SC-6 | AMI reconfigure time | `configure.sh` with new credentials on baked AMI | < 60 seconds |

---

## Product Scope

### Phase 1 — MVP (This Release)

- Bootstrap script with 5 modular install phases
- OpenClaw configuration with Discord + Bedrock
- Claude Code Studio from source
- Frappe Bench with base framework only
- Service verification and Discord notification
- Idempotent re-run support
- AMI-compatible `configure.sh`

### Phase 2 — Growth (Future)

- Frappe app catalog (install apps via Discord commands)
- Multi-site bench support
- Automated backup to S3
- Health monitoring dashboard

### Phase 3 — Vision (Future)

- Pre-baked AMI with `configure.sh`-only setup (< 60s)
- Team fleet management via Discord bot
- Auto-scaling development environments

---

## User Journeys

### UJ-1: Fresh Instance Bootstrap

**Actor:** Tiberbu engineer
**Trigger:** New EC2 instance launched

1. Engineer launches Ubuntu 24.04 EC2 (t3.xlarge, 50GB gp3)
2. SSH into instance
3. Create `~/.tiberbu-env` with required credentials (AWS, Discord, GitHub)
4. Run `curl -sL https://raw.githubusercontent.com/tiberbu/devbox/main/bootstrap.sh | bash` OR clone repo and run `./bootstrap.sh`
5. Script validates all required credentials are present
6. Script executes 5 phases with progress reporting and timing
7. Script runs verification checks on all services
8. Script sends Discord message confirming setup complete with URLs
9. Engineer begins working via Discord commands to the AI agent

**Success:** All services running, Discord bot responsive, < 10 minutes total.

### UJ-2: Re-Run After Failure

**Actor:** Tiberbu engineer
**Trigger:** Bootstrap failed mid-way (network issue, timeout)

1. Engineer re-runs `./bootstrap.sh`
2. Script detects completed phases via marker files and service checks
3. Script skips completed phases, resumes from failure point
4. Remaining phases complete successfully
5. Verification passes

**Success:** Only incomplete phases re-execute, no duplicate work, clean completion.

### UJ-3: AMI Credential Reconfigure

**Actor:** Tiberbu engineer
**Trigger:** Instance launched from pre-baked AMI with different credentials

1. Engineer creates `~/.tiberbu-env` with their personal credentials
2. Engineer runs `./configure.sh`
3. Script regenerates OpenClaw config, Claude Studio config, git credentials
4. Script restarts affected services
5. Discord confirmation sent

**Success:** New credentials active, services restarted, < 60 seconds.

### UJ-4: Credential Update

**Actor:** Tiberbu engineer
**Trigger:** Rotated AWS keys or Discord bot token

1. Engineer updates `~/.tiberbu-env` with new credentials
2. Runs `./configure.sh`
3. Templates re-rendered, services restarted
4. Discord confirmation sent with new bot identity

**Success:** Zero downtime beyond service restart (~5s).

---

## Architecture Decision Records

### ADR-1: Modular Scripts over Monolithic Bootstrap

**Status:** Accepted
**Context:** The bootstrap must install 5+ distinct components with different failure modes.
**Decision:** Split into `bootstrap.sh` (orchestrator) + 5 phase scripts in `scripts/`.
**Rationale:**
- Each phase script is independently testable
- Failure isolation: a Redis install failure doesn't corrupt Node.js state
- Idempotency checks are localized to each phase
- Engineers can re-run individual phases: `./scripts/install-node.sh`
- Easier to maintain as component versions change

**Consequences:**
- Slightly more files to manage (6 scripts vs 1)
- Need shared utility functions (sourced from common file)

### ADR-2: envsubst for Configuration Templating

**Status:** Accepted
**Context:** Need to inject credentials into OpenClaw JSON config and systemd units.
**Decision:** Use `envsubst` (from `gettext` package) for template rendering.
**Alternatives Considered:**
- `sed` replacement: Fragile with special characters in credentials (tokens contain `/`, `+`)
- Python `jinja2`: Adds Python dependency before it may be installed
- Node.js templating: Adds Node dependency before it may be installed
- `envsubst`: Available early via `apt install gettext-base`, handles all shell variable types

**Rationale:**
- Zero-dependency beyond base Ubuntu packages
- Native handling of `${VAR}` syntax in any file format
- Safe with special characters in credential values
- Templates remain human-readable with obvious placeholders

**Consequences:**
- Templates use `${VARIABLE}` syntax (standard shell expansion)
- All variables must be exported before `envsubst` call
- No conditional logic in templates (acceptable for our use case)

### ADR-3: Hybrid Idempotency — Marker Files + Service Checks

**Status:** Accepted
**Context:** Script must be safe to re-run without breaking existing installations.
**Decision:** Use a combination of marker files (`/var/tmp/devbox/.phase-N-complete`) and active service checks.
**Strategy:**

| Check Type | Used For | Example |
|------------|----------|---------|
| Marker file | Long-running installs that shouldn't repeat | `bench init` (3-5 min) |
| Binary existence | Tool installations | `command -v node` |
| Service status | Running services | `systemctl is-active mariadb` |
| Version check | Correct version installed | `node -v \| grep v24` |

**Rationale:**
- Marker files alone are unreliable (install may have failed after marker created)
- Service checks alone miss non-service components (nvm, wkhtmltopdf)
- Hybrid approach: marker file = "attempted", service/binary check = "succeeded"
- Phase script checks both: if marker exists AND component works, skip

**Consequences:**
- Marker directory at `/var/tmp/devbox/` survives reboots but not AMI recreation
- Each phase script has a `check_completed()` function at the top
- Failed phases remove their marker file so they retry on next run

### ADR-4: Structured Logging with Phases and Timing

**Status:** Accepted
**Context:** Engineers need clear visibility into bootstrap progress and failure diagnosis.
**Decision:** Structured log output with phase headers, timing, and color-coded status.

**Format:**
```
[Phase 1/5] Installing system dependencies...
  ✓ build-essential (0.2s)
  ✓ python3-dev (0.1s)
  ✓ mariadb-server (4.2s)
  ✓ redis-server (0.8s)
[Phase 1/5] Complete (12.4s)
```

**Logging implementation:**
- `stdout`: Progress messages (color-coded, human-readable)
- Log file at `/var/tmp/devbox/bootstrap.log`: Full verbose output (all apt, npm, bench output)
- On error: Tail last 20 lines of log file to stdout
- Functions: `log_info()`, `log_success()`, `log_error()`, `log_phase_start()`, `log_phase_end()`

**Consequences:**
- Common logging functions in `scripts/_common.sh` sourced by all phase scripts
- Timing captured via `$SECONDS` bash builtin
- Log file enables post-mortem debugging without re-running

### ADR-5: Error Handling — Fail Fast with Context

**Status:** Accepted
**Context:** Need balance between stopping on errors and providing useful diagnostics.
**Decision:** `set -euo pipefail` globally + custom error trap with context.

**Strategy:**
- `set -e`: Exit on any command failure
- `set -u`: Exit on undefined variable (catches missing env vars early)
- `set -o pipefail`: Catch failures in piped commands
- `trap 'error_handler $LINENO $?' ERR`: Custom handler prints file, line, command, and exit code
- Critical sections use explicit error checking with descriptive messages
- Non-critical sections (e.g., Discord notification) use `|| true` to allow graceful degradation

**Consequences:**
- Scripts fail immediately on unexpected errors (safe default)
- Error messages include enough context for self-diagnosis
- Optional steps explicitly marked with `|| true`

### ADR-6: configure.sh as Credential-Only Reconfigure

**Status:** Accepted
**Context:** Pre-baked AMIs need a fast way to inject new engineer's credentials without full reinstall.
**Decision:** Separate `configure.sh` that only handles credential injection and service restarts.

**Scope of configure.sh:**
1. Read `~/.tiberbu-env`
2. Validate required credentials
3. Re-render all config templates (OpenClaw, git, Claude Studio)
4. Restart affected services
5. Verify and send Discord confirmation

**Not in scope:** Package installation, compilation, bench init.

---

## File Structure Plan

```
devbox/
├── bootstrap.sh                    # Main orchestrator (entry point)
│                                   # - Validates environment
│                                   # - Sources _common.sh
│                                   # - Executes phases 1-5 sequentially
│                                   # - Runs verification
│                                   # - Sends Discord notification
│
├── configure.sh                    # Credential-only reconfigure
│                                   # - For AMI-based or credential rotation use
│                                   # - Re-renders templates, restarts services
│
├── scripts/
│   ├── _common.sh                  # Shared utilities (sourced, not executed)
│   │                               # - log_info(), log_success(), log_error()
│   │                               # - log_phase_start(), log_phase_end()
│   │                               # - check_marker(), set_marker(), clear_marker()
│   │                               # - require_env(), require_command()
│   │                               # - render_template() (envsubst wrapper)
│   │                               # - error_handler trap function
│   │                               # - Color codes and formatting
│   │
│   ├── install-system.sh           # Phase 1: System dependencies (~45s)
│   │                               # - apt update && apt install
│   │                               # - build-essential, python3, pip, git, curl
│   │                               # - mariadb-server 10.11, redis-server 7.x
│   │                               # - wkhtmltopdf 0.12.6
│   │                               # - gettext-base (for envsubst)
│   │                               # - Configures MariaDB character set + root pw
│   │
│   ├── install-node.sh             # Phase 2: Node.js via nvm (~30s)
│   │                               # - Installs nvm to ~/.nvm
│   │                               # - Installs Node.js v24.x
│   │                               # - Installs yarn 1.22.x globally
│   │
│   ├── install-bench.sh            # Phase 3: Frappe Bench (~4min)
│   │                               # - pip install frappe-bench
│   │                               # - bench init ~/frappe-bench --frappe-branch version-15
│   │                               # - bench new-site with MariaDB admin password
│   │                               # - Only frappe app (no ERPNext, etc.)
│   │                               # - Configures bench for development mode
│   │
│   ├── install-openclaw.sh         # Phase 4: OpenClaw + Discord (~60s)
│   │                               # - npm install -g openclaw
│   │                               # - Renders openclaw.json from template
│   │                               # - Creates workspace directory + default files
│   │                               # - Creates systemd user service
│   │                               # - Starts and verifies gateway
│   │
│   ├── install-studio.sh           # Phase 5: Claude Code Studio (~90s)
│   │                               # - git clone from GitHub (with token auth)
│   │                               # - npm install && npm run build
│   │                               # - Renders systemd service unit
│   │                               # - Creates config.json with project paths
│   │                               # - Starts and verifies service
│   │
│   └── verify.sh                   # Post-install verification
│                                   # - Checks all 5 services are active
│                                   # - Checks all ports are listening
│                                   # - Runs bench doctor
│                                   # - Sends Discord notification
│                                   # - Prints summary table
│
├── templates/
│   ├── openclaw.json.template      # OpenClaw config with ${VAR} placeholders
│   │                               # - Bedrock provider config
│   │                               # - Discord channel config
│   │                               # - Agent defaults + workspace paths
│   │                               # - Plugin entries
│   │                               # - Gateway settings
│   │
│   ├── openclaw-gateway.service    # Systemd user unit for OpenClaw
│   │                               # - Type=simple, Restart=always
│   │                               # - ExecStart=openclaw gateway start
│   │                               # - Environment vars for AWS credentials
│   │
│   ├── claude-studio.service       # Systemd system unit for Claude Studio
│   │                               # - Type=simple, Restart=always
│   │                               # - WorkingDirectory=~/claude-code-studio
│   │                               # - Port binding on ${CLAUDE_STUDIO_PORT}
│   │
│   └── claude-studio-config.json.template  # Claude Studio configuration
│                                   # - Project paths
│                                   # - Auth settings
│
├── workspace/
│   ├── AGENTS.md                   # Default OpenClaw workspace - agent definitions
│   ├── SOUL.md                     # Default OpenClaw workspace - agent personality
│   ├── TOOLS.md                    # Default OpenClaw workspace - available tools
│   └── USER.md                     # Default OpenClaw workspace - user context
│
├── docs/
│   ├── requirements.md             # Project requirements (exists)
│   └── planning.md                 # Implementation plan (this document)
│
└── README.md                       # Quick start guide (exists)
```

---

## Script Flow Design

### bootstrap.sh — Main Orchestrator

```
┌─────────────────────────────────────────┐
│           bootstrap.sh                   │
├─────────────────────────────────────────┤
│                                         │
│  1. Parse arguments (--dry-run, --phase) │
│  2. Source scripts/_common.sh           │
│  3. Load ~/.tiberbu-env                 │
│  4. Export all env vars with defaults   │
│  5. Validate required credentials       │
│  6. Create marker directory             │
│  7. Start overall timer                 │
│                                         │
│  ┌───────────────────────────────┐      │
│  │ Phase 1: install-system.sh    │ ~45s │
│  │ Phase 2: install-node.sh      │ ~30s │
│  │ Phase 3: install-bench.sh     │ ~4m  │
│  │ Phase 4: install-openclaw.sh  │ ~60s │
│  │ Phase 5: install-studio.sh    │ ~90s │
│  └───────────────────────────────┘      │
│                                         │
│  8. Run scripts/verify.sh               │
│  9. Print summary with timing           │
│ 10. Send Discord notification           │
│                                         │
└─────────────────────────────────────────┘
```

### Argument Parsing

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/_common.sh"

# Defaults
DRY_RUN=false
SINGLE_PHASE=""
ENV_FILE="${HOME}/.tiberbu-env"

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)     DRY_RUN=true; shift ;;
        --phase)       SINGLE_PHASE="$2"; shift 2 ;;
        --env-file)    ENV_FILE="$2"; shift 2 ;;
        --help|-h)     show_help; exit 0 ;;
        *)             log_error "Unknown option: $1"; exit 1 ;;
    esac
done
```

### Environment File Loading

```bash
load_env_file() {
    local env_file="$1"

    if [[ ! -f "$env_file" ]]; then
        log_error "Environment file not found: $env_file"
        log_error "Create it with: cat > ~/.tiberbu-env << 'EOF'"
        log_error "See README.md for required variables"
        exit 1
    fi

    # Source the env file (KEY=VALUE format, no export needed)
    set -a  # auto-export all variables
    source "$env_file"
    set +a

    # Apply defaults for optional variables
    : "${BEDROCK_REGION:=us-west-1}"
    : "${BEDROCK_MODEL:=global.anthropic.claude-opus-4-6-v1}"
    : "${FRAPPE_BRANCH:=version-15}"
    : "${BENCH_SITE:=dev.local}"
    : "${MARIADB_ROOT_PASSWORD:=tiberbu123}"
    : "${CLAUDE_STUDIO_PORT:=3000}"
    : "${OPENCLAW_PORT:=18789}"

    export BEDROCK_REGION BEDROCK_MODEL FRAPPE_BRANCH BENCH_SITE
    export MARIADB_ROOT_PASSWORD CLAUDE_STUDIO_PORT OPENCLAW_PORT
}
```

### Credential Validation

```bash
validate_credentials() {
    local missing=()

    [[ -z "${AWS_ACCESS_KEY_ID:-}" ]]     && missing+=("AWS_ACCESS_KEY_ID")
    [[ -z "${AWS_SECRET_ACCESS_KEY:-}" ]] && missing+=("AWS_SECRET_ACCESS_KEY")
    [[ -z "${AWS_DEFAULT_REGION:-}" ]]    && missing+=("AWS_DEFAULT_REGION")
    [[ -z "${DISCORD_BOT_TOKEN:-}" ]]     && missing+=("DISCORD_BOT_TOKEN")
    [[ -z "${DISCORD_GUILD_ID:-}" ]]      && missing+=("DISCORD_GUILD_ID")
    [[ -z "${DISCORD_CHANNEL_ID:-}" ]]    && missing+=("DISCORD_CHANNEL_ID")
    [[ -z "${DISCORD_USER_ID:-}" ]]       && missing+=("DISCORD_USER_ID")
    [[ -z "${GITHUB_TOKEN:-}" ]]          && missing+=("GITHUB_TOKEN")

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required credentials in ~/.tiberbu-env:"
        for var in "${missing[@]}"; do
            log_error "  - $var"
        done
        exit 1
    fi

    log_success "All required credentials present"
}
```

### Phase Execution with Timing

```bash
MARKER_DIR="/var/tmp/devbox"
mkdir -p "$MARKER_DIR"

run_phase() {
    local phase_num="$1"
    local phase_name="$2"
    local phase_script="$3"

    log_phase_start "$phase_num" 5 "$phase_name"
    local start=$SECONDS

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute: $phase_script"
    else
        bash "${SCRIPT_DIR}/${phase_script}"
    fi

    local elapsed=$(( SECONDS - start ))
    log_phase_end "$phase_num" 5 "$phase_name" "$elapsed"
}

# Execute phases
run_phase 1 "System dependencies"  "scripts/install-system.sh"
run_phase 2 "Node.js via nvm"      "scripts/install-node.sh"
run_phase 3 "Frappe Bench"         "scripts/install-bench.sh"
run_phase 4 "OpenClaw + Discord"   "scripts/install-openclaw.sh"
run_phase 5 "Claude Code Studio"   "scripts/install-studio.sh"
```

### Progress Reporting

```bash
# In _common.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
LOG_FILE="/var/tmp/devbox/bootstrap.log"

log_info()        { echo -e "  ${BLUE}→${NC} $*"; echo "[INFO] $*" >> "$LOG_FILE"; }
log_success()     { echo -e "  ${GREEN}✓${NC} $*"; echo "[OK]   $*" >> "$LOG_FILE"; }
log_error()       { echo -e "  ${RED}✗${NC} $*"; echo "[ERR]  $*" >> "$LOG_FILE"; }
log_warn()        { echo -e "  ${YELLOW}!${NC} $*"; echo "[WARN] $*" >> "$LOG_FILE"; }

log_phase_start() {
    local num="$1" total="$2" name="$3"
    echo ""
    echo -e "${BLUE}[Phase ${num}/${total}]${NC} ${name}..."
    echo "=== Phase ${num}/${total}: ${name} ===" >> "$LOG_FILE"
}

log_phase_end() {
    local num="$1" total="$2" name="$3" elapsed="$4"
    echo -e "${GREEN}[Phase ${num}/${total}]${NC} Complete (${elapsed}s)"
    echo "=== Phase ${num}/${total}: Complete (${elapsed}s) ===" >> "$LOG_FILE"
}
```

### Error Handling and Rollback

```bash
# In _common.sh

error_handler() {
    local line="$1" exit_code="$2"
    log_error "Command failed at line ${line} with exit code ${exit_code}"
    log_error "Last 20 lines of log:"
    tail -20 "$LOG_FILE" | while read -r line; do
        echo -e "  ${RED}|${NC} $line"
    done
    log_error "Full log: $LOG_FILE"
    exit "$exit_code"
}

trap 'error_handler $LINENO $?' ERR

# Marker file management
check_marker()  { [[ -f "${MARKER_DIR}/.phase-${1}-complete" ]]; }
set_marker()    { touch "${MARKER_DIR}/.phase-${1}-complete"; }
clear_marker()  { rm -f "${MARKER_DIR}/.phase-${1}-complete"; }

# Template rendering
render_template() {
    local template="$1" output="$2"
    envsubst < "$template" > "$output"
    log_success "Rendered: $output"
}
```

### Phase Script Pattern

Each phase script follows this pattern:

```bash
#!/usr/bin/env bash
# scripts/install-<component>.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_common.sh"

PHASE_NUM=N  # 1-5

# --- Idempotency Check ---
check_completed() {
    if check_marker "$PHASE_NUM" && <component_specific_check>; then
        log_info "Phase $PHASE_NUM already complete, skipping"
        exit 0
    fi
    clear_marker "$PHASE_NUM"  # Clear stale marker if check failed
}

check_completed

# --- Installation Logic ---
# ... component-specific installation ...

# --- Verification ---
<verify_component_works>

# --- Mark Complete ---
set_marker "$PHASE_NUM"
```

---

## Template Design

### templates/openclaw.json.template

**Placeholder Variables:**

| Variable | Source | Default | Description |
|----------|--------|---------|-------------|
| `${AWS_ACCESS_KEY_ID}` | ~/.tiberbu-env | required | AWS IAM access key |
| `${AWS_SECRET_ACCESS_KEY}` | ~/.tiberbu-env | required | AWS IAM secret key |
| `${BEDROCK_REGION}` | ~/.tiberbu-env | us-west-1 | AWS Bedrock region |
| `${BEDROCK_MODEL}` | ~/.tiberbu-env | global.anthropic.claude-opus-4-6-v1 | Bedrock model ID |
| `${DISCORD_BOT_TOKEN}` | ~/.tiberbu-env | required | Discord bot authentication token |
| `${DISCORD_GUILD_ID}` | ~/.tiberbu-env | 1229822594778267740 | Tiberbu Discord server ID |
| `${DISCORD_CHANNEL_ID}` | ~/.tiberbu-env | required | Engineer's assigned channel |
| `${DISCORD_USER_ID}` | ~/.tiberbu-env | required | Engineer's Discord user ID |
| `${OPENCLAW_PORT}` | ~/.tiberbu-env | 18789 | Gateway listen port |
| `${HOME}` | system | /home/ubuntu | User home directory |

**Example Rendered Output (abbreviated):**

```json
{
  "models": {
    "providers": {
      "amazon-bedrock": {
        "endpoint": "https://bedrock-runtime.us-west-1.amazonaws.com",
        "credentials": {
          "accessKeyId": "AKIAIOSFODNN7EXAMPLE",
          "secretAccessKey": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
        },
        "models": {
          "primary": {
            "id": "global.anthropic.claude-opus-4-6-v1",
            "maxTokens": 16384
          }
        }
      }
    }
  },
  "agents": {
    "defaults": {
      "workspace": "${HOME}/.openclaw/workspace",
      "primaryModel": "amazon-bedrock:${BEDROCK_MODEL}",
      "memory": {
        "search": {
          "provider": "amazon-bedrock",
          "model": "amazon.titan-embed-text-v2:0"
        }
      }
    }
  },
  "gateway": {
    "mode": "local",
    "auth": "token",
    "port": 18789,
    "bind": "loopback"
  },
  "channels": {
    "discord": {
      "token": "${DISCORD_BOT_TOKEN}",
      "guild": "${DISCORD_GUILD_ID}",
      "channels": [
        {
          "id": "${DISCORD_CHANNEL_ID}",
          "streaming": true,
          "autoPresence": true
        }
      ],
      "allowlist": ["${DISCORD_USER_ID}"]
    }
  },
  "plugins": {
    "entries": [
      { "name": "amazon-bedrock", "options": { "discovery": true } },
      { "name": "anthropic" },
      { "name": "acpx" }
    ]
  },
  "hooks": {
    "internal": ["boot-md", "session-memory"]
  },
  "tools": {
    "profile": "coding"
  }
}
```

### templates/openclaw-gateway.service

**Placeholder Variables:**

| Variable | Source | Default | Description |
|----------|--------|---------|-------------|
| `${HOME}` | system | /home/ubuntu | User home path |
| `${AWS_ACCESS_KEY_ID}` | ~/.tiberbu-env | required | Passed to service environment |
| `${AWS_SECRET_ACCESS_KEY}` | ~/.tiberbu-env | required | Passed to service environment |
| `${AWS_DEFAULT_REGION}` | ~/.tiberbu-env | us-west-1 | Passed to service environment |

**Template:**

```ini
[Unit]
Description=OpenClaw Gateway
After=network.target

[Service]
Type=simple
ExecStart=${HOME}/.nvm/versions/node/v24/bin/openclaw gateway start
WorkingDirectory=${HOME}/.openclaw
Restart=always
RestartSec=5
Environment=HOME=${HOME}
Environment=AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
Environment=AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
Environment=AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
Environment=PATH=${HOME}/.nvm/versions/node/v24/bin:/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=default.target
```

**Note:** This is a systemd **user** service, installed to `~/.config/systemd/user/openclaw-gateway.service`.

### templates/claude-studio.service

**Placeholder Variables:**

| Variable | Source | Default | Description |
|----------|--------|---------|-------------|
| `${USER}` | system | ubuntu | Linux username |
| `${HOME}` | system | /home/ubuntu | User home path |
| `${CLAUDE_STUDIO_PORT}` | ~/.tiberbu-env | 3000 | HTTP listen port |

**Template:**

```ini
[Unit]
Description=Claude Code Studio
After=network.target

[Service]
Type=simple
User=${USER}
WorkingDirectory=${HOME}/claude-code-studio
ExecStart=${HOME}/.nvm/versions/node/v24/bin/node dist/server.js
Restart=always
RestartSec=5
Environment=PORT=${CLAUDE_STUDIO_PORT}
Environment=HOME=${HOME}
Environment=PATH=${HOME}/.nvm/versions/node/v24/bin:/usr/local/bin:/usr/bin:/bin
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
```

**Note:** This is a systemd **system** service, installed to `/etc/systemd/system/claude-studio.service`.

### templates/claude-studio-config.json.template

**Placeholder Variables:**

| Variable | Source | Default | Description |
|----------|--------|---------|-------------|
| `${HOME}` | system | /home/ubuntu | User home path |
| `${CLAUDE_STUDIO_PORT}` | ~/.tiberbu-env | 3000 | HTTP port |

**Example Rendered Output:**

```json
{
  "port": 3000,
  "auth": {
    "type": "cookie",
    "cookiePath": "/tmp/ccs.cookie"
  },
  "projects": [
    {
      "name": "frappe-bench",
      "path": "${HOME}/frappe-bench"
    }
  ]
}
```

---

## Functional Requirements

### FR-1: Environment File Parsing

The bootstrap script reads `~/.tiberbu-env` as a shell-compatible KEY=VALUE file, exports all variables, and applies default values for optional variables.

**Acceptance Criteria:**
- Parses standard KEY=VALUE format (no `export` prefix required)
- Handles values with special characters (`/`, `+`, `=`)
- Ignores blank lines and `#` comments
- Exits with error code 1 and descriptive message if file not found

### FR-2: Credential Validation

Before any installation phase, the script validates all 8 required credential variables are non-empty.

**Acceptance Criteria:**
- Checks: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION, DISCORD_BOT_TOKEN, DISCORD_GUILD_ID, DISCORD_CHANNEL_ID, DISCORD_USER_ID, GITHUB_TOKEN
- Lists ALL missing variables in a single error message (not fail-on-first)
- Exits with code 1 if any are missing

### FR-3: Phase 1 — System Dependencies

Installs all system-level packages required by subsequent phases.

**Acceptance Criteria:**
- Installs: build-essential, python3, python3-dev, python3-pip, python3-venv, git, curl, wget, gettext-base, libffi-dev, libssl-dev, libjpeg-dev, libpng-dev, libxml2-dev, libxslt1-dev, libmysqlclient-dev, redis-server, mariadb-server, mariadb-client, wkhtmltopdf
- Configures MariaDB: utf8mb4 character set, root password from `$MARIADB_ROOT_PASSWORD`
- Verifies MariaDB and Redis are active via `systemctl is-active`
- Completes in under 90 seconds on t3.xlarge with standard Ubuntu mirrors

### FR-4: Phase 2 — Node.js via nvm

Installs nvm, Node.js v24.x, and yarn.

**Acceptance Criteria:**
- Installs nvm to `~/.nvm`
- Installs latest Node.js v24.x LTS
- Installs yarn 1.22.x globally via `npm install -g yarn`
- `node -v` returns `v24.x.x`
- `yarn --version` returns `1.22.x`

### FR-5: Phase 3 — Frappe Bench

Installs Frappe Bench CLI and initializes a bench with a site.

**Acceptance Criteria:**
- Installs `frappe-bench` via pip
- Runs `bench init ~/frappe-bench --frappe-branch ${FRAPPE_BRANCH}` (default: version-15)
- Creates site `${BENCH_SITE}` (default: dev.local) with MariaDB admin password
- Only `frappe` app installed (no ERPNext, healthcare, etc.)
- `bench --site ${BENCH_SITE} doctor` passes basic checks
- Bench configured for development mode

### FR-6: Phase 4 — OpenClaw Configuration

Installs OpenClaw and configures it for Discord + Bedrock.

**Acceptance Criteria:**
- Installs `openclaw` globally via npm
- Renders `~/.openclaw/openclaw.json` from template with all credentials injected
- Creates `~/.openclaw/workspace/` with AGENTS.md, SOUL.md, TOOLS.md, USER.md from `workspace/` directory
- Creates systemd user service at `~/.config/systemd/user/openclaw-gateway.service`
- Enables and starts the gateway service
- `openclaw status` reports gateway running on configured port

### FR-7: Phase 5 — Claude Code Studio

Clones, builds, and runs Claude Code Studio.

**Acceptance Criteria:**
- Clones `github.com/Mwogi/claude-code-studio` to `~/claude-code-studio` using GITHUB_TOKEN for auth
- Runs `npm install` and `npm run build`
- Renders systemd service unit to `/etc/systemd/system/claude-studio.service`
- Creates configuration with project paths
- Enables and starts the service
- HTTP request to `localhost:${CLAUDE_STUDIO_PORT}` returns 200

### FR-8: Git Configuration

Configures git for private Tiberbu repo access.

**Acceptance Criteria:**
- Sets git credential helper to store
- Stores GitHub token for `github.com` domain
- `git ls-remote https://github.com/tiberbu/devbox.git` succeeds (validates token)

### FR-9: Post-Install Verification

Runs comprehensive health checks on all installed components.

**Acceptance Criteria:**
- Checks MariaDB is active and accepting connections
- Checks Redis is active and responding to PING
- Checks Frappe bench site responds
- Checks OpenClaw gateway is active on configured port
- Checks Claude Code Studio is active on configured port
- Prints summary table with component, status, and version/port
- Exits with code 0 only if all checks pass

### FR-10: Discord Notification

Sends a confirmation message to the engineer's Discord channel.

**Acceptance Criteria:**
- Uses Discord webhook or bot API to send message
- Message includes: instance hostname, all service statuses, relevant URLs
- Sends within 30 seconds of verification completion
- Failure to send notification does not fail the bootstrap (graceful degradation)

### FR-11: Idempotent Re-Run

Script detects previously completed phases and skips them.

**Acceptance Criteria:**
- Each phase checks marker file + component health before executing
- Already-complete phases log "skipping" and exit in under 1 second
- A full re-run on a complete installation finishes in under 60 seconds
- Clearing a marker file for phase N causes only phase N to re-execute

### FR-12: Credential Reconfigure (configure.sh)

A separate script that re-renders templates and restarts services for new credentials.

**Acceptance Criteria:**
- Reads `~/.tiberbu-env` and validates required credentials
- Re-renders: openclaw.json, systemd service files, git credentials
- Restarts: openclaw-gateway, claude-studio services
- Completes in under 60 seconds
- Sends Discord notification from new bot identity

### FR-13: Dry-Run Mode

Bootstrap supports `--dry-run` flag that validates without executing.

**Acceptance Criteria:**
- Validates env file exists and all credentials present
- Prints what each phase would do without executing
- Shows rendered templates without writing them
- Exits with code 0 if all validations pass

### FR-14: Single-Phase Execution

Bootstrap supports `--phase N` flag to run only one phase.

**Acceptance Criteria:**
- Validates that prerequisite phases are complete (marker files exist)
- Executes only the specified phase
- Runs verification for that phase's components only

---

## Non-Functional Requirements

### NFR-1: Performance

- Total bootstrap time under 10 minutes on t3.xlarge (4 vCPU, 16GB RAM) with standard Ubuntu apt mirrors
- Phase 3 (Frappe Bench) is the bottleneck at ~4 minutes; other phases under 90 seconds each
- Idempotent re-run completes in under 60 seconds

### NFR-2: Reliability

- Script handles transient network failures with up to 3 retries for apt, npm, and git operations
- `apt install` uses `--retry 3` and `--retry-delay 5` equivalent logic
- `npm install` uses `--retry 3`
- `git clone` retries 3 times with 5-second delay

### NFR-3: Observability

- All stdout output is color-coded and human-readable with phase progress indicators
- Full verbose log written to `/var/tmp/devbox/bootstrap.log` (append mode, survives re-runs)
- On error, last 20 lines of log file displayed to stdout
- Each phase reports wall-clock time on completion

### NFR-4: Security

- `~/.tiberbu-env` permissions set to 600 (owner read/write only)
- `~/.openclaw/openclaw.json` permissions set to 600
- No credentials echoed to stdout or log file
- GITHUB_TOKEN stored in git credential store (standard git mechanism)
- Systemd service files do not contain credentials directly; they reference environment variables

### NFR-5: Compatibility

- Tested on Ubuntu 24.04 LTS (Noble Numbat) only
- Supports x86_64 (amd64) architecture
- Requires minimum 4GB RAM, 20GB disk (recommended: 16GB RAM, 50GB disk)
- Works with both `bash` execution and `curl | bash` piped execution

### NFR-6: Maintainability

- Modular script architecture: each phase independently testable
- Shared utilities in single `_common.sh` file
- Template-based configuration: adding a new variable requires only template edit + env var
- Version pinning via variables at top of each phase script (easy to update)

---

## Testing Strategy

### Local Testing Without EC2

**Docker-Based Testing:**
```bash
# Build a test container matching the target environment
docker build -t devbox-test -f tests/Dockerfile.test .

# Run bootstrap in container (fast, free, repeatable)
docker run --rm -it \
  -v $(pwd):/devbox \
  -e DRY_RUN=true \
  devbox-test /devbox/bootstrap.sh --dry-run
```

**Dockerfile.test:**
```dockerfile
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y sudo curl
RUN useradd -m -s /bin/bash ubuntu && echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER ubuntu
WORKDIR /home/ubuntu
```

**Limitations:** systemd does not work in standard Docker containers. Service start/enable commands must be mocked or skipped in container tests.

### Dry-Run Mode

The `--dry-run` flag enables full validation without execution:

```bash
./bootstrap.sh --dry-run
```

**What it validates:**
- Environment file exists and is parseable
- All required credentials are non-empty
- All templates render without errors
- Dependency order is correct
- Prints estimated timing for each phase

**What it skips:**
- Package installation
- Service creation and management
- File system writes (beyond /tmp)
- Network requests to external services

### EC2 Testing Protocol

**Cost-Optimized Approach:**
1. Use spot instances (t3.xlarge spot ~$0.05/hr vs $0.17/hr on-demand)
2. Test in batches: run bootstrap, verify, terminate in < 30 minutes
3. Estimated cost per full test: $0.03

**Test Script:**
```bash
#!/usr/bin/env bash
# tests/test-ec2.sh - Launch, test, terminate

INSTANCE_ID=$(aws ec2 run-instances \
    --image-id ami-ubuntu-24.04 \
    --instance-type t3.xlarge \
    --spot-instance-type one-time \
    --key-name devbox-test \
    --query 'Instances[0].InstanceId' \
    --output text)

# Wait for running, SSH in, run bootstrap, verify, terminate
# ... (automated via SSM or SSH)
```

### Verification Checklist

Run after every bootstrap (automated in `scripts/verify.sh`):

| # | Check | Command | Expected |
|---|-------|---------|----------|
| 1 | MariaDB running | `systemctl is-active mariadb` | active |
| 2 | MariaDB accepts connections | `mariadb -u root -p${MARIADB_ROOT_PASSWORD} -e "SELECT 1"` | 1 |
| 3 | MariaDB charset | `mariadb -e "SHOW VARIABLES LIKE 'character_set_server'"` | utf8mb4 |
| 4 | Redis running | `systemctl is-active redis-server` | active |
| 5 | Redis responds | `redis-cli ping` | PONG |
| 6 | Node.js version | `node -v` | v24.x.x |
| 7 | yarn version | `yarn --version` | 1.22.x |
| 8 | Bench CLI | `bench --version` | 5.x.x |
| 9 | Bench site exists | `bench --site ${BENCH_SITE} doctor` | 0 exit |
| 10 | OpenClaw installed | `openclaw --version` | 2026.x.x |
| 11 | OpenClaw gateway | `systemctl --user is-active openclaw-gateway` | active |
| 12 | OpenClaw port | `curl -s http://localhost:${OPENCLAW_PORT}/health` | 200 |
| 13 | Claude Studio service | `systemctl is-active claude-studio` | active |
| 14 | Claude Studio port | `curl -s http://localhost:${CLAUDE_STUDIO_PORT}` | 200 |
| 15 | Git auth | `git ls-remote https://github.com/tiberbu/devbox.git 2>/dev/null` | 0 exit |
| 16 | Discord notification | check Discord channel | message received |

### Unit Testing Phase Scripts

Each phase script can be tested independently on a partially provisioned instance:

```bash
# Test a single phase
./bootstrap.sh --phase 4  # Only runs install-openclaw.sh

# Verify only that phase
./scripts/verify.sh --phase 4
```

### Regression Testing

After any change to scripts or templates:

1. Run `--dry-run` locally to validate parsing and template rendering
2. Run in Docker container to validate package installation commands
3. Run on fresh EC2 spot instance for full integration test
4. Run twice on same instance to verify idempotency

---

## Implementation Sprint Plan

### Sprint 1: Foundation (Est. 4 hours)

| Story | Description | Points |
|-------|-------------|--------|
| S1.1 | Create `scripts/_common.sh` with logging, markers, error handling, render_template | 3 |
| S1.2 | Create `bootstrap.sh` orchestrator with arg parsing, env loading, validation | 3 |
| S1.3 | Create `scripts/install-system.sh` (Phase 1: apt packages, MariaDB, Redis) | 3 |
| S1.4 | Create `scripts/install-node.sh` (Phase 2: nvm, Node.js, yarn) | 2 |

### Sprint 2: Core Stack (Est. 5 hours)

| Story | Description | Points |
|-------|-------------|--------|
| S2.1 | Create `scripts/install-bench.sh` (Phase 3: Frappe Bench) | 5 |
| S2.2 | Create `templates/openclaw.json.template` with all placeholders | 3 |
| S2.3 | Create `scripts/install-openclaw.sh` (Phase 4: OpenClaw + systemd) | 3 |
| S2.4 | Create `templates/openclaw-gateway.service` | 1 |

### Sprint 3: Studio + Verification (Est. 4 hours)

| Story | Description | Points |
|-------|-------------|--------|
| S3.1 | Create `scripts/install-studio.sh` (Phase 5: Claude Code Studio) | 3 |
| S3.2 | Create `templates/claude-studio.service` and config template | 2 |
| S3.3 | Create `scripts/verify.sh` with full health check suite | 3 |
| S3.4 | Create Discord notification function in verification | 2 |

### Sprint 4: Polish + AMI (Est. 3 hours)

| Story | Description | Points |
|-------|-------------|--------|
| S4.1 | Create `configure.sh` for AMI/credential rotation | 3 |
| S4.2 | Create `workspace/` default files (AGENTS.md, SOUL.md, TOOLS.md, USER.md) | 2 |
| S4.3 | Add `--dry-run` and `--phase N` support to bootstrap.sh | 2 |
| S4.4 | Full EC2 integration test + idempotency test | 3 |

**Total Estimated Effort:** 16 hours, 42 story points

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `bench init` exceeds 5-minute timeout | Medium | High | Pre-test with target Node/Python versions; consider `--skip-assets` if available |
| wkhtmltopdf package not available for Noble | Medium | Medium | Fall back to direct .deb download from wkhtmltopdf releases page |
| OpenClaw npm package API changes | Low | High | Pin version in install script; add version check to verification |
| Claude Code Studio build fails | Medium | Medium | Pin to known-good commit hash; add build error handling with clear message |
| Discord API rate limiting during notification | Low | Low | Single notification at end; graceful degradation with `\|\| true` |
| MariaDB 10.11 not in default Ubuntu 24.04 repos | Low | Medium | Add MariaDB official apt repository if needed |

---

## Appendix A: Environment Variable Reference

| Variable | Required | Default | Used By |
|----------|----------|---------|---------|
| `AWS_ACCESS_KEY_ID` | Yes | - | OpenClaw (Bedrock), systemd env |
| `AWS_SECRET_ACCESS_KEY` | Yes | - | OpenClaw (Bedrock), systemd env |
| `AWS_DEFAULT_REGION` | Yes | - | OpenClaw (Bedrock), systemd env |
| `DISCORD_BOT_TOKEN` | Yes | - | OpenClaw (Discord channel) |
| `DISCORD_GUILD_ID` | Yes | - | OpenClaw (Discord channel) |
| `DISCORD_CHANNEL_ID` | Yes | - | OpenClaw (Discord channel) |
| `DISCORD_USER_ID` | Yes | - | OpenClaw (Discord allowlist) |
| `GITHUB_TOKEN` | Yes | - | git credential store, Studio clone |
| `BEDROCK_REGION` | No | us-west-1 | OpenClaw Bedrock endpoint URL |
| `BEDROCK_MODEL` | No | global.anthropic.claude-opus-4-6-v1 | OpenClaw primary model |
| `FRAPPE_BRANCH` | No | version-15 | bench init --frappe-branch |
| `BENCH_SITE` | No | dev.local | bench new-site name |
| `MARIADB_ROOT_PASSWORD` | No | tiberbu123 | MariaDB root + bench site creation |
| `CLAUDE_STUDIO_PORT` | No | 3000 | Claude Studio HTTP port |
| `OPENCLAW_PORT` | No | 18789 | OpenClaw gateway port |
| `GITHUB_USER` | No | (extracted from token) | git config user |

## Appendix B: Port Allocation

| Port | Service | Binding | Protocol |
|------|---------|---------|----------|
| 3306 | MariaDB | localhost | MySQL |
| 6379 | Redis | localhost | Redis |
| 8000 | Frappe Bench | localhost | HTTP |
| 3000 | Claude Code Studio | 0.0.0.0 | HTTP |
| 18789 | OpenClaw Gateway | localhost | HTTP |

## Appendix C: Systemd Service Summary

| Service | Type | Scope | Restart | After |
|---------|------|-------|---------|-------|
| mariadb.service | system | system | - | network.target |
| redis-server.service | system | system | - | network.target |
| openclaw-gateway.service | user | user | always (5s) | network.target |
| claude-studio.service | system | system | always (5s) | network.target |
