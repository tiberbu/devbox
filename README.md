# 🚀 Tiberbu DevBox

One-script setup for the full Tiberbu development environment on a fresh Ubuntu EC2 instance.

**Stack:** OpenClaw + Discord + Claude (Bedrock) + Claude Code Studio + Frappe Bench + Vue Frontend

## Prerequisites

- **Ubuntu 24.04** EC2 instance (or any Ubuntu 24.04 server with systemd)
- **AWS account** with Bedrock model access enabled
- **Discord account** with a server you can add bots to
- **GitHub account** with a personal access token

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
DISCORD_CHANNEL_ID=your-channel-id
DISCORD_USER_ID=your-discord-user-id
GITHUB_TOKEN=ghp_your-github-token

# === OPTIONAL (defaults shown) ===
# BEDROCK_REGION=us-west-1
# BEDROCK_MODEL=global.anthropic.claude-opus-4-6-v1
# FRAPPE_BRANCH=version-15
# BENCH_SITE=dev.local
# MARIADB_ROOT_PASSWORD=tiberbu123
# CLAUDE_STUDIO_PORT=3000
# OPENCLAW_PORT=18789
EOF

# Lock down permissions (file contains secrets)
chmod 600 ~/.tiberbu-env
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

**Expected duration:** ~5 minutes on a `t3.xlarge` instance.

**What happens in each phase:**

| Phase | What | Duration |
|-------|------|----------|
| 1 | System packages (apt, MariaDB, Redis, wkhtmltopdf) | ~60s |
| 2 | Node.js v24 via nvm + yarn | ~5s |
| 3 | Frappe Bench (bench init + site creation) | ~80s |
| 4 | OpenClaw + Discord gateway (npm, config, systemd) | ~50s |
| 5 | Claude Code Studio + Claude Code CLI (clone, build, Bedrock config) | ~80s |

### 4. Verify it worked

```bash
# Check OpenClaw gateway is running
openclaw status

# Check Claude Studio is running
systemctl status claude-studio

# Check Frappe bench
cd ~/frappe-bench && bench --site dev.local doctor
```

### 5. Start working from Discord

Once complete, the agent is live in your designated Discord channel. Just type a message — **no @mention needed**. The bot is configured to respond to all messages in that specific channel.

In other channels on the server, the bot won't respond (it only listens in the channel you specified with `DISCORD_CHANNEL_ID`).

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
| **Claude Code CLI** | Configured for Bedrock (no Anthropic API key needed) |
| **wkhtmltopdf** | 0.12.6 |

## Getting Your Credentials

### AWS Setup

You need an IAM user with Bedrock access. The same credentials power both OpenClaw and Claude Code CLI.

#### Create an IAM User

1. Go to the [AWS IAM Console](https://console.aws.amazon.com/iam/)
2. Click **Users** → **Create user**
3. Name it (e.g. `tiberbu-devbox`) → **Next**
4. Choose **Attach policies directly** → search for and check:
   - `AmazonBedrockFullAccess` (or create a custom policy with `bedrock:InvokeModel` and `bedrock:InvokeModelWithResponseStream`)
5. **Create user** → go to the user → **Security credentials** tab
6. **Create access key** → choose **Command Line Interface (CLI)** → **Create**
7. Copy the **Access key ID** and **Secret access key** immediately

#### Enable Bedrock Model Access

1. Go to [Amazon Bedrock Console](https://console.aws.amazon.com/bedrock/) in your chosen region
2. Click **Model access** in the left sidebar
3. Click **Manage model access**
4. Check the Anthropic Claude models you want (at minimum: Claude Sonnet or Opus)
5. Click **Request model access** → wait for approval (usually instant)

> **Which region?** Set `BEDROCK_REGION` to the region where you enabled model access. Common choices: `us-west-2`, `us-east-1`, `eu-west-1`. If using cross-region inference, use the `global.` model prefix (default).

### Discord Setup

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

#### `DISCORD_CHANNEL_ID` — The Bot's Home Channel

This is the channel where the bot responds to **every message** (no @mention needed). Create a dedicated channel for it:

1. In your Discord server, create a new text channel (e.g. `#devbox` or `#agent`)
2. With Developer Mode enabled (see above)
3. Right-click the **text channel** you just created
4. Click **Copy Channel ID**

> **Tip:** The bot only auto-responds in this channel. In all other channels on the server, it stays silent.

#### `DISCORD_USER_ID` — Your Personal User ID

1. With Developer Mode enabled (see above)
2. Right-click **your own username** (in a message or the member list)
3. Click **Copy User ID**

> **Tip:** All IDs are long numbers like `1229822594778267740`. If you see something shorter or with letters, that's not right.

### GitHub Token

1. Go to [GitHub Settings → Tokens](https://github.com/settings/tokens)
2. Click **Generate new token** → **Generate new token (classic)**
3. Name it (e.g. `tiberbu-devbox`)
4. Select the `repo` scope (full control of private repositories)
5. Click **Generate token** → copy it immediately

> This token is used to clone Claude Code Studio and any private Tiberbu repos.

## Bootstrap Options

```bash
# Validate credentials without installing anything
sudo -E ./bootstrap.sh --dry-run

# Run only a specific phase (1-5)
sudo -E ./bootstrap.sh --phase 3

# Use a custom env file location
sudo -E ./bootstrap.sh --env-file ~/my-custom.env
```

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

### Check service status

```bash
# OpenClaw (runs as user service)
systemctl --user status openclaw-gateway
journalctl --user -u openclaw-gateway --no-pager -n 50

# Claude Studio (runs as system service)
systemctl status claude-studio
journalctl -u claude-studio --no-pager -n 50

# Full OpenClaw diagnostic
openclaw status

# Frappe bench
cd ~/frappe-bench && bench --site dev.local doctor
```

### Common issues

| Problem | Cause | Fix |
|---------|-------|-----|
| `openclaw status` shows gateway not running | Service crashed on startup | Check logs: `journalctl --user -u openclaw-gateway -n 50` |
| Discord bot doesn't respond | Bot not invited or wrong channel ID | Verify bot is in server, check `DISCORD_CHANNEL_ID` matches your dedicated channel |
| `bench new-site` fails with "Access denied" | MariaDB auth not configured | Run: `sudo mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('tiberbu123'); FLUSH PRIVILEGES;"` |
| Claude Code says "no API key" | `~/.claude/settings.json` missing | Re-run Phase 5: `sudo -E ./bootstrap.sh --phase 5` |
| `openclaw gateway run` fails with "hooks.token" | Stale config from older version | Delete `~/.openclaw/openclaw.json` and re-run Phase 4 |

### Re-running phases

Each phase is idempotent — safe to re-run if something failed:

```bash
sudo -E ./bootstrap.sh --phase 4   # Re-run OpenClaw setup
sudo -E ./bootstrap.sh --phase 5   # Re-run Claude Studio setup
```

To force a full re-run, clear the markers:
```bash
rm -f /var/tmp/devbox/.phase-*-complete
sudo -E ./bootstrap.sh
```

## Files Created

| Path | Purpose |
|------|---------|
| `~/.tiberbu-env` | Your credentials (you create this) |
| `~/.openclaw/openclaw.json` | OpenClaw config (Bedrock + Discord) |
| `~/.openclaw/workspace/` | Agent workspace (AGENTS.md, SOUL.md, etc.) |
| `~/.claude/settings.json` | Claude Code CLI config (Bedrock) |
| `~/frappe-bench/` | Frappe framework + bench site |
| `~/claude-code-studio/` | Claude Code Studio app |
| `~/.config/systemd/user/openclaw-gateway.service` | OpenClaw systemd unit |
| `/etc/systemd/system/claude-studio.service` | Claude Studio systemd unit |
| `/var/tmp/devbox/` | Bootstrap logs + phase markers |

## Project Structure

```
devbox/
├── bootstrap.sh                           # Main orchestrator (handles sudo/user split)
├── scripts/
│   ├── _common.sh                         # Shared functions (logging, markers, templates)
│   ├── install-system.sh                  # Phase 1: apt, MariaDB, Redis
│   ├── install-node.sh                    # Phase 2: nvm, Node.js, yarn
│   ├── install-bench.sh                   # Phase 3: Frappe Bench + site
│   ├── install-openclaw.sh                # Phase 4: OpenClaw + Discord
│   ├── install-studio.sh                  # Phase 5: Claude Studio + Claude Code CLI
│   └── verify.sh                          # Post-install verification
├── templates/
│   ├── openclaw.json.template             # OpenClaw config (Bedrock + Discord)
│   ├── openclaw-gateway.service           # systemd unit for OpenClaw
│   ├── claude-settings.json.template      # Claude Code CLI Bedrock config
│   ├── claude-studio-config.json.template # Claude Studio config
│   └── claude-studio.service              # systemd unit for Claude Studio
├── workspace/
│   ├── AGENTS.md                          # Default agent instructions
│   ├── SOUL.md                            # Agent personality
│   ├── TOOLS.md                           # Tool notes
│   └── USER.md                            # User profile template
└── README.md
```

## Changelog

### 2026-04-23 — Docker integration testing + fixes

- **Docker test harness** — Full end-to-end testing in Ubuntu 24.04 container with systemd
- **Log file permissions** — Fixed Phase 1 (root) creating files Phase 2+ (user) couldn't write to
- **Env passthrough** — Fixed environment variables lost when dropping privileges via `su -`
- **Missing cron package** — `bench init` needs `/usr/bin/crontab`; added `cron` to apt packages
- **hooks.token error** — Removed top-level `hooks.enabled` from config (requires webhook token)
- **Claude Studio HTTP check** — Added retry loop for port readiness after systemd reports active
- **Claude Code CLI Bedrock** — New `~/.claude/settings.json` template configures Claude Code to use Bedrock (no Anthropic API key needed)

### 2026-04-21 — Bootstrap reliability fixes

1. **Root/user privilege split** — Phase 1 runs as root for apt/MariaDB; Phases 2–5 auto-drop to regular user via `SUDO_USER`
2. **OpenClaw config schema** — Rewrote `openclaw.json.template` to match OpenClaw 2026.4.15 schema (fixed auth, plugins.entries, hooks, guilds structure)
3. **Service restart loops** — Gateway service now uses `openclaw gateway run` (foreground) instead of `gateway start` which delegates to systemctl. Added `OPENCLAW_NO_RESPAWN=1`, increased `RestartSec` to 60s
4. **MariaDB password auth** — `install-bench.sh` now runs `ALTER USER` to enable `mysql_native_password` auth before `bench new-site`, fixing "Access denied" on TCP connections
5. **Service startup timeout** — Increased `wait_for_service` from 10s to 90s with port-listening check (gateway needs ~45s to fully boot)
6. **Docs** — Added Presence Intent to bot setup, documented dedicated channel setup, clarified `sudo -E` usage

### 2026-04-19 — Initial release

- 5-phase bootstrap script with idempotency and structured logging
- Full Tiberbu stack: OpenClaw, Discord, Bedrock, Claude Studio, Frappe Bench
