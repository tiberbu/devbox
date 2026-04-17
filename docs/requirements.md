# Tiberbu DevBox — Project Requirements

## Overview
A single bootstrap script + supporting templates that sets up the full Tiberbu development environment on a fresh Ubuntu 24.04 EC2 instance in under 10 minutes.

## Target Users
Software engineers at Tiberbu who need a fully working AI-assisted development environment connected to Discord.

## Stack to Install
1. **System dependencies**: git, curl, python3, pip, build-essential, etc.
2. **MariaDB 10.11** with a root password from config
3. **Redis 7.x**
4. **Node.js v24.x** via nvm
5. **yarn 1.22.x**
6. **wkhtmltopdf 0.12.6** (for Frappe PDF generation)
7. **Frappe Bench** (latest) with frappe version-15 by default
8. **OpenClaw** (latest from npm) configured for Discord + AWS Bedrock
9. **Claude Code Studio** (from github.com/Mwogi/claude-code-studio)

## Engineer-Provided Credentials (via ~/.tiberbu-env)

### Required
- `AWS_ACCESS_KEY_ID` — for Bedrock Claude access
- `AWS_SECRET_ACCESS_KEY`
- `AWS_DEFAULT_REGION` — default us-west-1
- `DISCORD_BOT_TOKEN` — their personal bot token
- `DISCORD_GUILD_ID` — Tiberbu server: 1229822594778267740
- `DISCORD_CHANNEL_ID` — their assigned channel
- `DISCORD_USER_ID` — their Discord user ID
- `GITHUB_TOKEN` — with repo scope for private tiberbu repos

### Optional (with defaults)
- `BEDROCK_REGION` — default us-west-1
- `BEDROCK_MODEL` — default global.anthropic.claude-opus-4-6-v1
- `FRAPPE_BRANCH` — default version-15
- `BENCH_SITE` — default dev.local
- `MARIADB_ROOT_PASSWORD` — default tiberbu123
- `CLAUDE_STUDIO_PORT` — default 3000
- `OPENCLAW_PORT` — default 18789
- `GITHUB_USER` — extracted from token if not provided

## Reference: Current Working Setup (EC2 ip-172-31-8-29)

### OS
- Ubuntu 24.04.4 LTS (noble)

### Node.js
- v24.14.1 installed via nvm at ~/.nvm

### MariaDB
- 10.11.14 via apt
- Character set: utf8mb4

### Redis
- 7.0.15 via apt

### Frappe Bench
- bench 5.29.1
- Site: hmis.frappe.local
- Apps installed: frappe, payments, erpnext, hrms, mpesa_tx, event_streaming, healthcare, hmis_frontend, insights, hmis
- Frappe branch: version-15
- Running on localhost:8000 via gunicorn

### OpenClaw
- Version 2026.4.8
- Installed globally via npm
- Gateway runs as systemd user service (~/.config/systemd/user/openclaw-gateway.service) on port 18789, loopback only
- Config at ~/.openclaw/openclaw.json
- Workspace at ~/.openclaw/workspace
- Plugins: amazon-bedrock (with discovery), anthropic, acpx
- Discord channel configured with streaming, auto-presence
- Memory search via bedrock titan-embed-text-v2

### Claude Code Studio
- Version 5.25.9
- Cloned to ~/claude-code-studio from github.com/Mwogi/claude-code-studio
- Runs as systemd service (claude-studio.service) on port 3000
- Auth via cookie at /tmp/ccs.cookie
- Projects configured in config.json

### OpenClaw Config Structure (openclaw.json)
Key sections:
- `models.providers.amazon-bedrock` — Bedrock endpoint, model config
- `agents.defaults` — workspace path, primary model, memory search config
- `gateway` — mode:local, auth:token, port, bind:loopback
- `channels.discord` — bot token, guild/channel config, streaming, user allowlist
- `plugins.entries` — amazon-bedrock (discovery), anthropic, acpx
- `hooks.internal` — boot-md, session-memory
- `tools.profile` — "coding"

### Systemd Services
1. `openclaw-gateway.service` (user service) — OpenClaw gateway
2. `claude-studio.service` (system service) — Claude Code Studio
3. `mariadb.service` — database
4. `redis-server.service` — cache
5. `nginx.service` — reverse proxy (optional for devbox)

## Requirements

### R1: Single Bootstrap Script
- `bootstrap.sh` that runs on a fresh Ubuntu 24.04 EC2
- Reads credentials from `~/.tiberbu-env`
- Installs everything in the correct order
- Handles errors gracefully with clear messages
- Shows progress with timing for each phase
- Total time target: under 10 minutes on t3.xlarge

### R2: OpenClaw Configuration
- Generate `~/.openclaw/openclaw.json` from template with injected credentials
- Configure Discord with the engineer's bot token, guild, channel, user ID
- Configure Bedrock with their AWS credentials
- Set up workspace with default AGENTS.md, SOUL.md, TOOLS.md, USER.md
- Start gateway as systemd service

### R3: Claude Code Studio
- Clone and build from source
- Create systemd service
- Configure with devbox project
- Start and verify running

### R4: Frappe Bench (Minimal)
- Install bench CLI
- `bench init` with frappe version-15
- Create site with MariaDB
- Only frappe installed by default (other apps added later via Discord commands)
- Start bench (background or systemd)

### R5: Git Configuration
- Configure git with GitHub token for credential store
- Set up for private tiberbu repo access

### R6: Verification
- At end of bootstrap, verify all services are running
- Print summary with URLs and status
- Send a test message to Discord channel confirming setup complete

### R7: Idempotency
- Script should be safe to re-run (skip already-completed steps where possible)
- Use marker files or service checks to detect existing installations

## File Structure
```
devbox/
├── bootstrap.sh                 # Main entry point
├── configure.sh                 # Credentials-only reconfigure (for AMI use)
├── templates/
│   ├── openclaw.json.template   # OpenClaw config with placeholders
│   ├── claude-studio.service    # Systemd unit
│   └── openclaw-gateway.service # Systemd unit
├── workspace/
│   ├── AGENTS.md
│   ├── SOUL.md
│   ├── TOOLS.md
│   └── USER.md
├── scripts/
│   ├── install-system.sh        # Phase 1: system deps
│   ├── install-node.sh          # Phase 2: nvm + node
│   ├── install-bench.sh         # Phase 3: frappe bench
│   ├── install-openclaw.sh      # Phase 4: openclaw + discord
│   └── install-studio.sh        # Phase 5: claude code studio
└── README.md
```
