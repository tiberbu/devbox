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
DISCORD_GUILD_ID=1229822594778267740
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
```

### 3. Run the bootstrap

```bash
curl -sL https://raw.githubusercontent.com/tiberbu/devbox/main/bootstrap.sh | bash
```

Or clone and run:

```bash
git clone https://github.com/tiberbu/devbox.git
cd devbox
chmod +x bootstrap.sh
./bootstrap.sh
```

### 4. Start working from Discord

Once complete, the agent is live in your Discord channel. Give it commands!

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

### Discord Bot Token
1. Go to https://discord.com/developers/applications
2. Create New Application → Bot → Reset Token → Copy
3. Enable **Message Content Intent** under Bot settings
4. Invite bot to the Tiberbu server with appropriate permissions

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
