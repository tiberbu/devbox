# Tiberbu DevBox — Domain Research

> Comprehensive analysis of the current working EC2 dev environment (ip-172-31-8-29) for bootstrap automation.
> Generated: 2026-04-17

---

## Table of Contents

1. [Host Environment](#1-host-environment)
2. [System Dependencies Audit](#2-system-dependencies-audit)
3. [Node.js / NVM Setup](#3-nodejs--nvm-setup)
4. [OpenClaw Configuration Deep Dive](#4-openclaw-configuration-deep-dive)
5. [Claude Code Studio Setup](#5-claude-code-studio-setup)
6. [Frappe Bench Setup](#6-frappe-bench-setup)
7. [MariaDB Configuration](#7-mariadb-configuration)
8. [Redis Configuration](#8-redis-configuration)
9. [Service Dependency Order](#9-service-dependency-order)
10. [Known Gotchas](#10-known-gotchas)
11. [Bootstrap Credential Mapping](#11-bootstrap-credential-mapping)

---

## 1. Host Environment

| Property | Value |
|---|---|
| **OS** | Ubuntu 24.04.4 LTS (Noble Numbat) |
| **Kernel** | 6.17.0-1007-aws |
| **Hostname** | ip-172-31-8-29 |
| **CPU cores** | 16 (likely t3.xlarge or m5.4xlarge) |
| **RAM** | 61 GiB |
| **Disk** | 968 GB root (3% used, ~26 GB) |
| **User** | ubuntu (uid 1000) |
| **Lingering** | Enabled (`loginctl enable-linger ubuntu`) — required for user systemd services |

### /etc/hosts

```
127.0.0.1 localhost
```

**Note:** No entry for `hmis.frappe.local`. DNS resolution for this hostname is slow (10s+). The bootstrap should add it to `/etc/hosts` or use `localhost:8000` directly.

---

## 2. System Dependencies Audit

### Core Build Tools

| Package | Version | Notes |
|---|---|---|
| build-essential | 12.10ubuntu1 | gcc, g++, make, etc. |
| gcc-13 | 13.3.0-6 | C compiler |
| g++-13 | 13.3.0-6 | C++ compiler |
| python3 | 3.12.3 | System Python |
| python3-dev | (installed) | Python headers for C extensions |
| python3-pip | 24.0 | pip for Python 3.12 |
| python3-venv | (installed) | Virtual environment support |
| python3-setuptools | (installed) | setuptools for pip installs |
| git | 2.43.0 | Version control |
| curl | 8.5.0 | HTTP client |
| wget | (installed) | Alternative HTTP download |
| jq | 1.7.1 | JSON processing (useful for template generation) |

### Database & Cache

| Package | Version | Notes |
|---|---|---|
| mariadb-server | 10.11.14 | Database server |
| mariadb-client | 10.11.14 | CLI client |
| mariadb-client-core | 10.11.14 | Core client tools |
| default-libmysqlclient-dev | (installed) | MySQL C API headers (needed for frappe mysqlclient) |
| libmysqlclient-dev | (installed) | Same as above |
| redis-server | 7.0.15 | System Redis (port 6379) |
| redis-tools | (installed) | redis-cli etc. |

### Web & PDF

| Package | Version | Notes |
|---|---|---|
| nginx | 1.24.0 | Reverse proxy (optional for devbox) |
| wkhtmltopdf | 0.12.6 | PDF generation for Frappe |
| xvfb | (installed) | Virtual framebuffer for wkhtmltopdf headless |
| xfonts-base | (installed) | Base X11 fonts for PDF rendering |
| xfonts-scalable | (installed) | Scalable fonts |
| fonts-* | (many) | Various font families for PDF i18n |

### Process Management

| Package | Version | Notes |
|---|---|---|
| supervisor | (installed) | Process supervisor for Frappe bench |
| cron | 3.0pl1 | System cron |

### Security & Monitoring

| Package | Version | Notes |
|---|---|---|
| fail2ban | 1.0.2 | SSH brute-force protection |
| htop | 3.3.0 | Process monitor |

### Other Notable

| Package | Version | Notes |
|---|---|---|
| ansible | 9.2.0 | Automation tool (pre-installed, not required for bootstrap) |
| google-chrome-stable | 147.0.7727.55 | Headless Chrome for Playwright |
| software-properties-common | (installed) | apt-add-repository support |
| gnupg | 2.4.4 | GPG key management for apt repos |
| ca-certificates | (installed) | TLS CA bundle |
| unzip | (installed) | Archive extraction |
| libffi8 | (installed) | Foreign function interface (needed by Python) |
| libssl-dev | (installed) | OpenSSL headers (needed for Python crypto) |

### Recommended apt install command for bootstrap

```bash
sudo apt-get update
sudo apt-get install -y \
  build-essential \
  python3 python3-dev python3-pip python3-venv python3-setuptools \
  git curl wget jq unzip \
  mariadb-server mariadb-client libmysqlclient-dev \
  redis-server redis-tools \
  nginx \
  supervisor \
  wkhtmltopdf xvfb xfonts-base xfonts-scalable \
  fonts-liberation fonts-dejavu-core \
  libffi-dev libssl-dev \
  software-properties-common gnupg ca-certificates \
  fail2ban htop
```

---

## 3. Node.js / NVM Setup

### NVM

| Property | Value |
|---|---|
| **NVM version** | 0.40.4 |
| **Install location** | `~/.nvm` |
| **Shell integration** | Lines in `~/.bashrc` |

**~/.bashrc snippet:**
```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
```

**Install method:** Standard curl installer:
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
```

### Node.js

| Property | Value |
|---|---|
| **Version** | v24.14.1 (LTS "krypton") |
| **Binary path** | `~/.nvm/versions/node/v24.14.1/bin/node` |
| **NVM alias** | `default -> 24` |

**Install:**
```bash
nvm install 24
nvm alias default 24
```

### NPM

| Property | Value |
|---|---|
| **Version** | 11.12.1 |
| **Global prefix** | `~/.nvm/versions/node/v24.14.1/lib` |

### Global NPM Packages

| Package | Version | Purpose |
|---|---|---|
| @anthropic-ai/claude-code | 2.1.96 | Claude Code CLI |
| openclaw | 2026.4.8 | OpenClaw gateway + CLI |
| yarn | 1.22.22 | Package manager |
| playwright | 1.52.0 | Browser automation/testing |
| grammy | 1.42.0 | Telegram bot framework (likely not needed for bootstrap) |
| @grammyjs/runner | 2.0.3 | Grammy runner |
| @grammyjs/transformer-throttler | 1.2.1 | Grammy throttler |
| @buape/carbon | 0.14.0 | Discord framework |
| @larksuiteoapi/node-sdk | 1.60.0 | Lark/Feishu SDK |
| @slack/web-api | 7.15.0 | Slack SDK |
| corepack | 0.34.6 | Node.js bundled |

**For bootstrap, install only:**
```bash
npm install -g yarn openclaw @anthropic-ai/claude-code playwright
npx playwright install chromium  # install browser binaries
```

### Yarn

| Property | Value |
|---|---|
| **Version** | 1.22.22 |
| **Install method** | `npm install -g yarn` |
| **Binary path** | `~/.nvm/versions/node/v24.14.1/bin/yarn` |

---

## 4. OpenClaw Configuration Deep Dive

### Installation

```bash
npm install -g openclaw
```

**Version:** 2026.4.8
**Binary:** `~/.nvm/versions/node/v24.14.1/lib/node_modules/openclaw/dist/index.js`

### Directory Structure (~/.openclaw/)

```
~/.openclaw/
├── .env                    # AWS_PROFILE=default
├── openclaw.json           # Main config (4.2 KB)
├── openclaw-backup.json    # Auto-backup
├── openclaw.json.bak*      # Config backup history
├── agents/                 # Agent state
├── canvas/                 # Canvas data
├── completions/            # Completion cache
├── credentials/            # Auth credentials
│   └── discord-pairing.json
├── cron/                   # Cron jobs
├── delivery-queue/         # Message delivery queue
├── devices/                # Device state
├── exec-approvals.json     # Execution approvals
├── flows/                  # Flow definitions
├── identity/               # Device identity
│   ├── device.json         # Device keypair
│   └── device-auth.json    # Auth state
├── logs/                   # Logs
├── media/                  # Media files
├── memory/                 # Memory store
├── qqbot/                  # QQ bot
├── subagents/              # Sub-agent state
├── tasks/                  # Task queue
├── update-check.json       # Update check cache
└── workspace/              # Agent workspace (git repo)
    ├── AGENTS.md
    ├── BOOTSTRAP.md
    ├── HEARTBEAT.md
    ├── IDENTITY.md
    ├── MEMORY.md
    ├── SOUL.md
    ├── TOOLS.md
    ├── USER.md
    ├── claude/
    ├── memory/
    └── state/
```

### openclaw.json — Full Structure Analysis

#### models.providers.amazon-bedrock
```json
{
  "baseUrl": "https://bedrock-runtime.${BEDROCK_REGION}.amazonaws.com",
  "api": "bedrock-converse-stream",
  "auth": "aws-sdk",
  "models": [{
    "id": "${BEDROCK_MODEL}",
    "name": "Claude Opus 4.5 (Bedrock)",
    "reasoning": true,
    "input": ["text", "image"],
    "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
    "contextWindow": 200000,
    "maxTokens": 8192
  }]
}
```
**Credential injection:** `BEDROCK_REGION` into baseUrl, `BEDROCK_MODEL` as model id.
**AWS auth:** Uses `aws-sdk` mode — reads from `~/.aws/credentials` via `AWS_PROFILE=default`.

#### agents.defaults
```json
{
  "workspace": "/home/ubuntu/.openclaw/workspace",
  "model": { "primary": "amazon-bedrock/${BEDROCK_MODEL}" },
  "models": { "amazon-bedrock/${BEDROCK_MODEL}": {} },
  "memorySearch": {
    "provider": "bedrock",
    "model": "amazon.titan-embed-text-v2:0"
  }
}
```
**Static:** workspace path, memorySearch config.
**Dynamic:** model ID from credentials.

#### gateway
```json
{
  "mode": "local",
  "auth": { "mode": "token", "token": "<random-48-char-hex>" },
  "port": 18789,
  "bind": "loopback",
  "tailscale": { "mode": "serve", "resetOnExit": false },
  "controlUi": {
    "allowInsecureAuth": true,
    "allowedOrigins": [
      "http://localhost:18789",
      "http://127.0.0.1:18789"
    ]
  },
  "nodes": { "denyCommands": ["camera.snap", ...] }
}
```
**Generated values:** `auth.token` — random hex string (use `openssl rand -hex 24`).
**Static:** mode, port, bind, tailscale, controlUi, nodes.
**Template var:** `${OPENCLAW_PORT}` for port.

#### channels.discord
```json
{
  "enabled": true,
  "token": "${DISCORD_BOT_TOKEN}",
  "groupPolicy": "open",
  "ackReactionScope": "all",
  "guilds": {
    "${DISCORD_GUILD_ID}": {
      "users": ["${DISCORD_USER_ID}"],
      "channels": {
        "${DISCORD_CHANNEL_ID}": {
          "requireMention": false,
          "enabled": true
        }
      }
    }
  },
  "maxLinesPerMessage": 30,
  "streaming": { "block": { "enabled": true }, "chunkMode": "newline", "mode": "block" },
  "autoPresence": { "enabled": true },
  "threadBindings": { "spawnAcpSessions": true }
}
```
**Credential injection:** `DISCORD_BOT_TOKEN`, `DISCORD_GUILD_ID`, `DISCORD_CHANNEL_ID`, `DISCORD_USER_ID`.
**Static:** everything else.

#### plugins.entries
```json
{
  "amazon-bedrock": {
    "config": {
      "discovery": {
        "enabled": true,
        "region": "${AWS_DEFAULT_REGION}",
        "providerFilter": ["anthropic", "amazon"],
        "refreshInterval": 3600,
        "defaultContextWindow": 32000,
        "defaultMaxTokens": 4096
      }
    },
    "enabled": true
  },
  "anthropic": { "enabled": true },
  "acpx": {
    "config": { "timeoutSeconds": 1800, "permissionMode": "approve-all" },
    "enabled": true
  }
}
```
**Credential injection:** `AWS_DEFAULT_REGION` for discovery region.
**Note:** Current config uses `eu-west-1` for discovery — may differ from `us-west-1` used for baseUrl. Need to clarify or use same region.

#### hooks
```json
{
  "internal": {
    "enabled": true,
    "entries": {
      "boot-md": { "enabled": true },
      "session-memory": { "enabled": true }
    }
  },
  "enabled": true,
  "token": "<same-or-different-random-hex>",
  "path": "/hooks"
}
```
**Generated:** `token` — random hex (use `openssl rand -hex 24`). This token is shared with Claude Code Studio.

#### Other sections
- `session.dmScope`: `"per-channel-peer"` — static
- `tools.profile`: `"coding"` — static
- `tools.sessions.visibility`: `"all"` — static
- `auth.profiles`: anthropic default — static
- `wizard.*`: auto-populated by `openclaw setup`/`openclaw doctor`
- `meta.*`: auto-populated on config save

### Setup Flow

1. `npm install -g openclaw` — installs CLI + gateway
2. `openclaw setup` — interactive wizard that creates `~/.openclaw/openclaw.json` and `~/.openclaw/workspace/`
3. `openclaw doctor` — validates config, checks connectivity
4. For bootstrap, **skip the wizard** and write `openclaw.json` from template directly
5. Create workspace with default markdown files from `workspace/` templates
6. Set up systemd user service
7. Start gateway: `systemctl --user start openclaw-gateway`

### Systemd User Service

**Location:** `~/.config/systemd/user/openclaw-gateway.service`

```ini
[Unit]
Description=OpenClaw Gateway (v2026.4.8)
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/home/ubuntu/.nvm/versions/node/v24.14.1/bin/node \
  /home/ubuntu/.nvm/versions/node/v24.14.1/lib/node_modules/openclaw/dist/index.js \
  gateway --port 18789
Restart=always
RestartSec=5
TimeoutStopSec=30
TimeoutStartSec=30
SuccessExitStatus=0 143
KillMode=control-group
Environment=AWS_PROFILE=default
Environment=HOME=/home/ubuntu
Environment=TMPDIR=/tmp
Environment=NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
Environment=PATH=/home/ubuntu/.nvm/versions/node/v24.14.1/bin:...:/usr/local/bin:/usr/bin:/bin
Environment=OPENCLAW_GATEWAY_PORT=18789
Environment=OPENCLAW_SYSTEMD_UNIT=openclaw-gateway.service
Environment="OPENCLAW_WINDOWS_TASK_NAME=OpenClaw Gateway"
Environment=OPENCLAW_SERVICE_MARKER=openclaw
Environment=OPENCLAW_SERVICE_KIND=gateway
Environment=OPENCLAW_SERVICE_VERSION=2026.4.8

[Install]
WantedBy=default.target
```

**Key points for template:**
- `ExecStart` uses full absolute paths to node and openclaw index.js
- `PATH` must include nvm node bin directory
- `AWS_PROFILE=default` enables AWS SDK credential chain
- `HOME` must be set explicitly for user service
- Port comes from `OPENCLAW_PORT` env var
- Requires `loginctl enable-linger ubuntu` for user services to persist

### .env File (~/.openclaw/.env)

```
AWS_PROFILE=default
```

### AWS Credentials

AWS credentials are stored at `~/.aws/credentials` with `[default]` profile:
```ini
[default]
aws_access_key_id = <from TIBERBU_ENV>
aws_secret_access_key = <from TIBERBU_ENV>
```

And `~/.aws/config`:
```ini
[default]
region = eu-west-1
```

**Bootstrap must write both files from `~/.tiberbu-env` variables.**

---

## 5. Claude Code Studio Setup

### Build Process

```bash
# 1. Clone
git clone https://github.com/Mwogi/claude-code-studio.git ~/claude-code-studio
cd ~/claude-code-studio
git checkout develop

# 2. Install dependencies
npm install

# 3. No separate build step needed — it's a Node.js server
```

**Version:** 5.25.9
**Branch:** `develop`

### Systemd Service (System-level)

**Location:** `/etc/systemd/system/claude-studio.service`

```ini
[Unit]
Description=Claude Code Studio
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/claude-code-studio
ExecStart=/home/ubuntu/.nvm/versions/node/v24.14.1/bin/node server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

**Key points:**
- System service (not user service) — requires `sudo` to manage
- Uses full path to node binary (nvm path)
- `WorkingDirectory` must point to the cloned repo
- Runs as `ubuntu` user

### Environment (.env)

```bash
OPENCLAW_API_URL=http://127.0.0.1:18789/hooks
OPENCLAW_API_KEY=<hooks.token from openclaw.json>
```

**Bootstrap must:** Generate the same random token used in `openclaw.json hooks.token` and set it here as `OPENCLAW_API_KEY`.

### config.json — Project Registration

The `config.json` file contains:

1. **mcpServers**: MCP server configurations (git, github, sequential-thinking, memory, context7, playwright, frappe)
2. **slashCommands**: Custom slash commands
3. **projects**: Registered project paths

**Project registration format:**
```json
{
  "projects": {
    "devbox": {
      "path": "/home/ubuntu/projects/devbox",
      "name": "Tiberbu DevBox",
      "description": "One-script reproducible dev environment setup",
      "branch": "main"
    }
  }
}
```

**MCP servers requiring credentials:**
- `github`: needs `GITHUB_PERSONAL_ACCESS_TOKEN` in env
- `frappe`: needs `FRAPPE_API_KEY`, `FRAPPE_API_SECRET`, `FRAPPE_BASE_URL` in env

### Cookie Auth

**Location:** `/tmp/ccs.cookie` (Netscape cookie format)
**Purpose:** Authenticates Claude Code Studio web UI
**Note:** File is in `/tmp` so it's lost on reboot. The Studio regenerates it on startup.

### Additional .bashrc Environment

```bash
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_REGION=eu-west-1
```

These enable Claude Code CLI to use Bedrock for inference.

---

## 6. Frappe Bench Setup

### Installation

**bench CLI** is installed via pip:
```bash
pip3 install frappe-bench
```
**Version:** 5.29.1
**Location:** `~/.local/bin/bench`
**PATH requirement:** `~/.local/bin` must be in PATH (set in `~/.profile`)

### bench init

```bash
bench init ~/frappe-bench --frappe-branch version-15 --shallow-clone
```

**Timing:** 3-5 minutes with `--shallow-clone`

**Result directory structure:**
```
~/frappe-bench/
├── Procfile              # Process definitions
├── patches.txt           # Patch registry
├── apps/                 # Installed Frappe apps
│   ├── frappe/           # Core framework (version-15 branch)
│   ├── erpnext/
│   ├── healthcare/
│   ├── hmis/
│   ├── hmis_frontend/
│   ├── hrms/
│   ├── insights/
│   ├── mpesa_tx/
│   ├── event_streaming/
│   └── payments/
├── config/               # Generated config files
│   ├── supervisor.conf
│   ├── nginx.conf
│   ├── redis_cache.conf
│   ├── redis_queue.conf
│   ├── redis_cache.acl
│   ├── redis_queue.acl
│   └── pids/
├── env/                  # Python virtual environment
├── logs/                 # Log files
├── sites/                # Sites directory
│   ├── apps.txt          # Installed apps list
│   └── common_site_config.json
└── hmis.frappe.local/    # Symlink? (unusual location)
```

### Site Creation

```bash
cd ~/frappe-bench
bench new-site hmis.frappe.local --mariadb-root-password <MARIADB_ROOT_PASSWORD> --admin-password <admin_password>
```

**For bootstrap (minimal):**
```bash
bench new-site ${BENCH_SITE} --mariadb-root-password ${MARIADB_ROOT_PASSWORD} --admin-password admin
```

### site_config.json

**Location:** `~/frappe-bench/sites/hmis.frappe.local/site_config.json`

Key fields (auto-generated by `bench new-site`):
```json
{
  "db_name": "_6a6f93c714642d80",      // auto-generated
  "db_password": "JfLbS8RcQfKR7exH",    // auto-generated
  "db_type": "mariadb",
  "encryption_key": "...",               // auto-generated
  "allow_cors": ["http://18.132.129.240:5173", "http://localhost:5173"],
  "ignore_csrf": 1
}
```

**Fields added manually post-install (not needed for bootstrap minimal):**
- `allow_cors`, `ignore_csrf`, `CONSENT_MANAGEMENT_*`, `CR_*`, `SAFARICOM_*`, `PPB_TOKEN`, `s3_*`, `hl7_port`, etc.

### common_site_config.json

**Location:** `~/frappe-bench/sites/common_site_config.json`

```json
{
  "background_workers": 1,
  "file_watcher_port": 6787,
  "frappe_user": "ubuntu",
  "gunicorn_workers": 33,
  "live_reload": true,
  "rebase_on_pull": false,
  "redis_cache": "redis://127.0.0.1:13000",
  "redis_queue": "redis://127.0.0.1:11000",
  "redis_socketio": "redis://127.0.0.1:13000",
  "restart_supervisor_on_update": true,
  "restart_systemd_on_update": false,
  "serve_default_site": true,
  "shallow_clone": true,
  "socketio_port": 9000,
  "use_redis_auth": false,
  "webserver_port": 8000
}
```

**Key points:**
- Redis ports are **non-standard**: cache=13000, queue=11000 (bench manages its own Redis instances)
- `gunicorn_workers: 33` is very high (likely auto-calculated: 2×nproc + 1 = 2×16+1=33)
- `frappe_user: ubuntu` — bench runs as ubuntu, not a separate frappe user
- System Redis on port 6379 is separate from bench's Redis instances

### Apps Installed (Current State)

```
frappe, healthcare, hmis_frontend, payments, hmis, insights, erpnext, mpesa_tx, event_streaming, hrms
```

**For bootstrap minimal:** Only `frappe` is needed initially. Other apps added later.

### Procfile

```
redis_cache: redis-server config/redis_cache.conf
redis_queue: redis-server config/redis_queue.conf
web: bench serve --port 8000
socketio: /home/ubuntu/.nvm/versions/node/v24.14.1/bin/node apps/frappe/socketio.js
watch: bench watch
schedule: bench schedule
worker: bench worker 1>> logs/worker.log 2>> logs/worker.error.log
```

### Supervisor Configuration

**Config location:** `/etc/supervisor/conf.d/frappe-bench.conf`

Managed processes:
| Process | Command | Status |
|---|---|---|
| frappe-bench-frappe-web | gunicorn -b 127.0.0.1:8000 -w 33 | RUNNING |
| frappe-bench-frappe-schedule | bench schedule | RUNNING |
| frappe-bench-frappe-short-worker-0 | bench worker --queue short,default | RUNNING |
| frappe-bench-frappe-long-worker-0 | bench worker --queue long,default | RUNNING |
| frappe-bench-node-socketio | node apps/frappe/socketio.js | RUNNING |
| frappe-bench-redis-cache | redis-server config/redis_cache.conf | RUNNING |
| frappe-bench-redis-queue | redis-server config/redis_queue.conf | RUNNING |

**Setup command:**
```bash
sudo bench setup supervisor --yes
sudo ln -sf ~/frappe-bench/config/supervisor.conf /etc/supervisor/conf.d/frappe-bench.conf
sudo supervisorctl reread
sudo supervisorctl update
```

### Nginx Configuration (Optional for DevBox)

**Generated by:** `bench setup nginx --yes`
**Symlinked to:** `/etc/nginx/sites-enabled/` (currently empty — nginx running but no sites enabled)

The bench-generated nginx config:
- Upstream to `127.0.0.1:8000` (gunicorn) and `127.0.0.1:9000` (socketio)
- Server name: `hmis.frappe.local`
- Listens on port 80

**For bootstrap:** Nginx is optional. Direct access to `localhost:8000` is sufficient.

---

## 7. MariaDB Configuration

### Version & Auth

| Property | Value |
|---|---|
| **Version** | 10.11.14 |
| **Auth method** | unix_socket for root (default on Ubuntu 24.04) |
| **Root access** | `sudo mariadb` (no password needed for unix_socket) |
| **Bench DB user** | Auto-created by `bench new-site` |

**CRITICAL:** MariaDB 10.11 on Ubuntu 24.04 defaults to `unix_socket` authentication for root. This means:
- `sudo mariadb -u root` works (no password)
- `mariadb -u root -p<password>` does NOT work by default
- For Frappe's `bench new-site`, you need to set a root password:

```bash
sudo mariadb -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}'; FLUSH PRIVILEGES;"
```

Or switch to `mysql_native_password`:
```bash
sudo mariadb -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${MARIADB_ROOT_PASSWORD}'); FLUSH PRIVILEGES;"
```

### Character Set Configuration

**File:** `/etc/mysql/mariadb.conf.d/50-server.cnf`

```ini
[mysqld]
character-set-server  = utf8mb4
collation-server      = utf8mb4_general_ci
```

**This is already correct for Frappe.** No custom config file needed.

### Frappe-Specific Requirements

Frappe requires:
- `character-set-server = utf8mb4`
- `collation-server = utf8mb4_unicode_ci` (Frappe prefers `unicode_ci`, but `general_ci` works too)

**Note:** The current setup uses `utf8mb4_general_ci`. Frappe's bench init may warn about this but it works. If strict compliance is needed, add:

```ini
# /etc/mysql/mariadb.conf.d/99-frappe.cnf
[mysqld]
character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[mysql]
default-character-set = utf8mb4
```

### Other Config

```ini
[mysqld]
bind-address = 127.0.0.1      # localhost only
expire_logs_days = 10          # binary log retention
```

---

## 8. Redis Configuration

### System Redis

| Property | Value |
|---|---|
| **Version** | 7.0.15 |
| **Service** | redis-server.service (systemd) |
| **Port** | 6379 (default) |
| **Status** | Running |

### Bench Redis (Managed by Supervisor)

| Instance | Port | Config |
|---|---|---|
| redis_cache | 13000 | `~/frappe-bench/config/redis_cache.conf` |
| redis_queue | 11000 | `~/frappe-bench/config/redis_queue.conf` |

Both bind to `127.0.0.1` only.

**Note:** Bench manages its own Redis instances separate from the system Redis. The system Redis (port 6379) is not used by Frappe. Bench launches redis-server directly via supervisor using its own config files.

---

## 9. Service Dependency Order

### Startup Sequence

```
Phase 1: System Services (already running after boot)
  ├── mariadb.service          [systemd, system]
  ├── redis-server.service     [systemd, system]  (not strictly needed by bench)
  └── nginx.service            [systemd, system]  (optional)

Phase 2: Frappe Bench (supervisor)
  ├── frappe-bench-redis-cache     [supervisor] — must start first
  ├── frappe-bench-redis-queue     [supervisor] — must start first
  ├── frappe-bench-frappe-web      [supervisor] — gunicorn, needs MariaDB + Redis
  ├── frappe-bench-node-socketio   [supervisor] — needs Redis
  ├── frappe-bench-frappe-schedule [supervisor] — needs MariaDB + Redis
  ├── frappe-bench-frappe-short-worker-0 [supervisor]
  └── frappe-bench-frappe-long-worker-0  [supervisor]

Phase 3: OpenClaw Gateway
  └── openclaw-gateway.service [systemd, user] — needs network, AWS credentials

Phase 4: Claude Code Studio
  └── claude-studio.service    [systemd, system] — needs OpenClaw gateway (for hooks API)
```

### Dependency Map

```
MariaDB ──────────┐
                   ├──→ Frappe Bench (gunicorn, workers, schedule)
Bench Redis ──────┘         │
                            ├──→ Nginx (optional reverse proxy)
                            │
AWS Credentials ──┐
                  ├──→ OpenClaw Gateway ──→ Claude Code Studio
Discord Token ────┘                              │
                                                 └──→ Web UI on :3000
```

### Bootstrap Installation Order

1. **System deps** (apt install) — no dependencies
2. **NVM + Node.js** — needs curl
3. **MariaDB config** — needs mariadb-server installed
4. **Frappe bench init** — needs Python, Node, pip, yarn, git, MariaDB running
5. **bench new-site** — needs MariaDB running with root password set
6. **bench setup supervisor** — needs bench init complete
7. **OpenClaw install + config** — needs Node.js, AWS creds, Discord token
8. **OpenClaw systemd service** — needs openclaw installed, lingering enabled
9. **Claude Code Studio clone + build** — needs Node.js, git, GitHub token
10. **Claude Code Studio systemd** — needs CCS built, OpenClaw running

---

## 10. Known Gotchas

### 10.1 DNS Slowness for hostname-based sites

**Problem:** `hmis.frappe.local` resolves extremely slowly (10+ seconds) because there's no entry in `/etc/hosts` and it falls through to DNS.

**Fix:** Add to `/etc/hosts`:
```
127.0.0.1  hmis.frappe.local
```

Or use `localhost:8000` directly. The `common_site_config.json` has `serve_default_site: true`, so any request to `localhost:8000` serves the default site.

### 10.2 MariaDB unix_socket vs password auth

**Problem:** Ubuntu 24.04's MariaDB defaults to `unix_socket` auth for root. Frappe's `bench new-site` passes `--mariadb-root-password` which expects password auth.

**Fix:** Set a root password before running bench:
```bash
sudo mariadb -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${MARIADB_ROOT_PASSWORD}'); FLUSH PRIVILEGES;"
```

### 10.3 NVM not available in non-interactive shells

**Problem:** NVM is loaded via `~/.bashrc`, which is only sourced in interactive shells. Systemd services, cron, and scripts using `#!/bin/bash` (without `-i`) won't have NVM.

**Fix:** All systemd services use full absolute paths to node:
```
/home/ubuntu/.nvm/versions/node/v24.14.1/bin/node
```

Scripts should source NVM explicitly:
```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
```

### 10.4 bench CLI not in PATH for new shells

**Problem:** `bench` is installed to `~/.local/bin/bench` via pip. The `~/.profile` adds `~/.local/bin` to PATH, but this only applies to login shells.

**Fix:** Bootstrap should ensure `~/.local/bin` is in PATH:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

### 10.5 Permissions — no separate frappe user

**Current setup:** Everything runs as `ubuntu` user. No separate `frappe` user.
- `common_site_config.json` has `"frappe_user": "ubuntu"`
- Supervisor processes run as `user=ubuntu`
- Claude Studio runs as `User=ubuntu`

**Bootstrap implication:** No need to create a separate user. Keep everything under `ubuntu`.

### 10.6 loginctl enable-linger required for user services

**Problem:** OpenClaw uses a systemd **user** service. Without `enable-linger`, user services stop when the user's last session ends.

**Fix:**
```bash
loginctl enable-linger ubuntu
```

This is already enabled on the reference machine.

### 10.7 Supervisor vs systemd conflict for bench

**Current state:** Bench uses **supervisor** (not systemd) for process management.
- `restart_supervisor_on_update: true` in common_site_config
- `restart_systemd_on_update: false`

**Bootstrap must:**
```bash
sudo bench setup supervisor --yes
sudo ln -sf $(pwd)/config/supervisor.conf /etc/supervisor/conf.d/frappe-bench.conf
sudo supervisorctl reread
sudo supervisorctl update
```

### 10.8 Google Chrome for Playwright

**Current state:** `google-chrome-stable` is installed system-wide. Playwright also needs browser binaries:
```bash
npx playwright install chromium
```

### 10.9 Race condition: OpenClaw → Claude Code Studio

**Problem:** Claude Code Studio connects to OpenClaw's hooks API (`http://127.0.0.1:18789/hooks`). If Studio starts before OpenClaw is ready, the connection fails.

**Fix:** The systemd service has `Restart=always` and `RestartSec=10`, so it retries. But for first-time setup, ensure OpenClaw is confirmed running before starting Studio:
```bash
systemctl --user start openclaw-gateway
sleep 5
# Verify
curl -s http://127.0.0.1:18789/health || echo "Gateway not ready"
# Then start studio
sudo systemctl start claude-studio
```

### 10.10 wkhtmltopdf requires xvfb

**Problem:** wkhtmltopdf 0.12.6 needs a display server for rendering. On headless EC2, this requires xvfb.

**Current state:** `xvfb` package is installed. Frappe's bench handles this internally.

### 10.11 Git credential store

**Current setup:**
```
git config --global credential.helper store
```
Credentials in `~/.git-credentials` (plaintext token). Bootstrap should:
```bash
git config --global credential.helper store
echo "https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com" > ~/.git-credentials
chmod 600 ~/.git-credentials
```

### 10.12 Two separate token generations needed

The bootstrap must generate **two random tokens** that are shared between configs:
1. **Gateway auth token** (`openclaw.json → gateway.auth.token`) — used for gateway API auth
2. **Hooks token** (`openclaw.json → hooks.token`) — shared with Claude Code Studio as `OPENCLAW_API_KEY`

These can be the same token or different. Currently they are different on the reference machine:
- Gateway auth: `c6969a6d7d2c48c218758299b638ae2ccbf5c323e266e57d`
- Hooks token: `1b359c9b8896f494f6d8cc72767b0ba3e8e1b96a02b08434`

Generate with: `openssl rand -hex 24`

---

## 11. Bootstrap Credential Mapping

### From ~/.tiberbu-env to Config Files

| Env Variable | Target File | Target Field |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | `~/.aws/credentials` | `aws_access_key_id` |
| `AWS_SECRET_ACCESS_KEY` | `~/.aws/credentials` | `aws_secret_access_key` |
| `AWS_DEFAULT_REGION` | `~/.aws/config` | `region` |
| `AWS_DEFAULT_REGION` | `openclaw.json` | `plugins.entries.amazon-bedrock.config.discovery.region` |
| `BEDROCK_REGION` | `openclaw.json` | `models.providers.amazon-bedrock.baseUrl` |
| `BEDROCK_MODEL` | `openclaw.json` | `models.providers.amazon-bedrock.models[0].id` |
| `BEDROCK_MODEL` | `openclaw.json` | `agents.defaults.model.primary` |
| `DISCORD_BOT_TOKEN` | `openclaw.json` | `channels.discord.token` |
| `DISCORD_GUILD_ID` | `openclaw.json` | `channels.discord.guilds.<key>` |
| `DISCORD_CHANNEL_ID` | `openclaw.json` | `channels.discord.guilds.<guild>.channels.<key>` |
| `DISCORD_USER_ID` | `openclaw.json` | `channels.discord.guilds.<guild>.users[0]` |
| `GITHUB_TOKEN` | `~/.git-credentials` | token in URL |
| `GITHUB_TOKEN` | `claude-code-studio/config.json` | `mcpServers.github.env.GITHUB_PERSONAL_ACCESS_TOKEN` |
| `MARIADB_ROOT_PASSWORD` | MariaDB root user | password via ALTER USER |
| `CLAUDE_STUDIO_PORT` | `claude-studio.service` | (currently hardcoded to 3000 via server.js defaults) |
| `OPENCLAW_PORT` | `openclaw-gateway.service` | `--port` flag |
| `OPENCLAW_PORT` | `openclaw.json` | `gateway.port` |

### Generated Values (not from credentials)

| Value | Generation | Used In |
|---|---|---|
| Gateway auth token | `openssl rand -hex 24` | `openclaw.json → gateway.auth.token` |
| Hooks token | `openssl rand -hex 24` | `openclaw.json → hooks.token` + `CCS .env → OPENCLAW_API_KEY` |
| DB name | Auto by bench | `site_config.json → db_name` |
| DB password | Auto by bench | `site_config.json → db_password` |
| Encryption key | Auto by bench | `site_config.json → encryption_key` |

### Additional .bashrc Exports Needed

```bash
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_REGION=${AWS_DEFAULT_REGION}
```

---

## Appendix A: Full Package List for apt install

```bash
# Build tools
build-essential python3 python3-dev python3-pip python3-venv python3-setuptools
git curl wget jq unzip

# Database
mariadb-server mariadb-client libmysqlclient-dev

# Cache
redis-server redis-tools

# Web server (optional)
nginx

# Process management
supervisor

# PDF generation
wkhtmltopdf xvfb xfonts-base xfonts-scalable

# Fonts (for PDF i18n)
fonts-liberation fonts-dejavu-core

# SSL/crypto dev headers
libffi-dev libssl-dev

# APT repository management
software-properties-common gnupg ca-certificates

# Security & monitoring
fail2ban htop

# Browser testing (optional)
# google-chrome-stable (installed separately from Google's apt repo)
```

## Appendix B: Port Allocation

| Service | Port | Bind | Protocol |
|---|---|---|---|
| MariaDB | 3306 | 127.0.0.1 | TCP |
| Redis (system) | 6379 | 127.0.0.1 | TCP |
| Redis (bench cache) | 13000 | 127.0.0.1 | TCP |
| Redis (bench queue) | 11000 | 127.0.0.1 | TCP |
| Frappe Web (gunicorn) | 8000 | 127.0.0.1 | TCP |
| Frappe SocketIO | 9000 | 127.0.0.1 | TCP |
| Frappe file watcher | 6787 | 127.0.0.1 | TCP |
| OpenClaw Gateway | 18789 | 127.0.0.1 | TCP |
| Claude Code Studio | 3000 | 0.0.0.0 | TCP |
| Nginx | 80 | 0.0.0.0 | TCP |

## Appendix C: Service Management Quick Reference

```bash
# MariaDB
sudo systemctl start|stop|restart mariadb

# Redis (system)
sudo systemctl start|stop|restart redis-server

# Frappe Bench (all processes)
sudo supervisorctl start|stop|restart all

# OpenClaw Gateway (user service)
systemctl --user start|stop|restart openclaw-gateway

# Claude Code Studio (system service)
sudo systemctl start|stop|restart claude-studio

# Nginx
sudo systemctl start|stop|restart nginx
```
