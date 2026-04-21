# 🚀 Tiberbu DevBox

One-script setup for the full Tiberbu development environment on a fresh Ubuntu EC2 instance.

**Stack:** OpenClaw + Discord + Claude (Bedrock) + Claude Code Studio + Frappe Bench + Vue Frontend

## Quick Start

### 1. Launch a fresh Ubuntu 24.04 EC2 instance
- Recommended: `t3.xlarge` (4 vCPU, 16GB RAM) or larger
- Storage: 50GB+ gp3
- Security group: SSH (22) inbound only

### 2. SSH in and create your config

```bash
cat > ~/.tiberbu-env << 'EOF'
# === REQUIRED ===
AWS_ACCESS_KEY_ID=your-aws-access-key
AWS_SECRET_ACCESS_KEY=your-aws-secret-key
AWS_DEFAULT_REGION=us-west-1
DISCORD_BOT_TOKEN=your-discord-bot-token
DISCORD_GUILD_ID=your-server-id
DISCORD_USER_ID=your-discord-user-id
GITHUB_TOKEN=ghp_your-github-token

# === OPTIONAL (defaults shown) ===
# DISCORD_CHANNEL_ID=your-channel-id  # only needed for verification test message
# BEDROCK_REGION=us-west-1
# BEDROCK_MODEL=global.anthropic.claude-opus-4-6-v1
# FRAPPE_BRANCH=version-15
# BENCH_SITE=dev.local
# MARIADB_ROOT_PASSWORD=tiberbu123
# CLAUDE_STUDIO_PORT=3000
# OPENCLAW_PORT=18789
EOF
```

### 3. Run the bootstrap

The script needs `sudo` for Phase 1 (apt packages, MariaDB, Redis). Phases 2–5 run as your regular user automatically.

```bash
curl -sL https://raw.githubusercontent.com/tiberbu/devbox/main/bootstrap.sh | sudo -E bash
```

Or clone and run:

```bash
git clone https://github.com/tiberbu/devbox.git
cd devbox
chmod +x bootstrap.sh
sudo -E ./bootstrap.sh
```

> **Why `sudo -E`?** Phase 1 installs system packages as root. The `-E` flag preserves your environment so `~/.tiberbu-env` is found. Phases 2–5 automatically drop back to your regular user for nvm, pip, bench, and systemd user services.

### 4. Start working from Discord

Once complete, the agent is live in your Discord channel. **You need to @mention the bot** to talk to it (e.g. `@Tiberbu DevBox what's up?`). The bot uses `requireMention: true` by default so it doesn't respond to every message in the channel.

## What Gets Installed

| Component | Details |
|-----------|---------|
| **Node.js** | v24.x via nvm |
| **Python** | 3.12 (system) |
| **MariaDB** | 10.11 |
| **Redis** | 7.x |
| **Frappe Bench** | Latest with frappe v15 |
| **OpenClaw** | Latest from npm |
| **Claude Code Studio** | v5.x from GitHub |
| **wkhtmltopdf** | 0.12.6 |

## Getting Your Credentials

### Discord Setup (All 4 Parameters)

You need four Discord values. Here's how to get each one:

#### `DISCORD_BOT_TOKEN` — Your Bot's Auth Token

1. Go to the [Discord Developer Portal](https://discord.com/developers/applications)
2. Click **New Application** → give it a name (e.g. "Tiberbu DevBox") → **Create**
3. In the left sidebar, click **Bot**
4. Click **Reset Token** → **Yes, do it!** → **Copy** the token immediately (you won't see it again)
5. Scroll down and enable these **Privileged Gateway Intents**:
   - ✅ **Presence Intent**
   - ✅ **Server Members Intent**
   - ✅ **Message Content Intent**
6. **Invite the bot to your server:**
   - In the left sidebar, click **OAuth2**
   - Under **OAuth2 URL Generator**, check the `bot` scope
   - Under **Bot Permissions**, check: `Send Messages`, `Read Message History`, `Create Public Threads`, `Send Messages in Threads`, `Manage Messages`
   - Copy the generated URL → open it in your browser → select your server → **Authorize**

#### `DISCORD_GUILD_ID` — Your Server ID

1. Open Discord (desktop app or browser)
2. Go to **User Settings** (gear icon) → **Advanced** → enable **Developer Mode**
3. Right-click your **server name** in the left sidebar
4. Click **Copy Server ID** — that's your Guild ID

#### `DISCORD_CHANNEL_ID` — The Channel for Your Agent

1. With Developer Mode enabled (see above)
2. Right-click the **text channel** where you want the agent to listen
3. Click **Copy Channel ID**

#### `DISCORD_USER_ID` — Your Personal User ID

1. With Developer Mode enabled (see above)
2. Right-click **your own username** (in a message or the member list)
3. Click **Copy User ID**

> **Tip:** All IDs are long numbers like `1229822594778267740`. If you see something shorter or with letters, that's not right.

### AWS Bedrock Access
- Need access to `anthropic.claude-*` models in your chosen region
- IAM user/role with `bedrock:InvokeModel` and `bedrock:InvokeModelWithResponseStream`

### GitHub Token
- Personal Access Token with `repo` scope
- Generate at https://github.com/settings/tokens

## Adding Frappe Apps Later

After initial setup, tell your agent on Discord:
```
Install the healthcare app: bench get-app https://github.com/frappe/health --branch version-15
```

Or install from the Tiberbu private repos:
```
Install hmis app from tiberbu/hmis branch dev-features
```

## Troubleshooting

```bash
# Check all services
openclaw status
systemctl status claude-studio
cd ~/frappe-bench && bench --site dev.local doctor

# Logs
journalctl -u claude-studio -f
cat /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log
```

## Structure

```
devbox/
├── bootstrap.sh          # Main bootstrap script
├── configure.sh          # Credentials-only setup (for AMI)
├── templates/
│   ├── openclaw.json     # OpenClaw config template
│   ├── claude-studio.env # Claude Studio env template
│   └── openclaw-gateway.service
├── workspace/
│   ├── AGENTS.md         # Default workspace files
│   ├── SOUL.md
│   ├── TOOLS.md
│   └── USER.md
└── README.md
```

## Changelog

### 2026-04-21 — Bootstrap reliability fixes

1. **Root/user privilege split** — Phase 1 runs as root for apt/MariaDB; Phases 2–5 auto-drop to regular user via `SUDO_USER`
2. **OpenClaw config schema** — Rewrote `openclaw.json.template` to match OpenClaw 2026.4.15 schema (fixed auth, plugins.entries, hooks, guilds structure)
3. **Service restart loops** — Gateway service now uses `openclaw gateway run` (foreground) instead of `gateway start` which delegates to systemctl. Added `OPENCLAW_NO_RESPAWN=1`, increased `RestartSec` to 60s
4. **MariaDB password auth** — `install-bench.sh` now runs `ALTER USER` to enable `mysql_native_password` auth before `bench new-site`, fixing "Access denied" on TCP connections
5. **Service startup timeout** — Increased `wait_for_service` from 10s to 90s with port-listening check (gateway needs ~45s to fully boot)
6. **Docs** — Added Presence Intent to bot setup, documented `@mention` requirement, clarified `sudo -E` usage
