# Story 8: Verification and Smoke Test

**Story ID:** S8
**Epic:** E4 — Verification & Polish
**Points:** 5
**Estimated Hours:** 2
**Priority:** P1 — Validates entire bootstrap
**Dependencies:** S2 (system deps), S3 (node), S4 (openclaw), S5 (claude studio), S6 (frappe bench)

---

## Description

Create `scripts/verify.sh` — the post-install verification script that runs 16 health checks across all installed components, prints a formatted summary table, sends a Discord notification with the instance status, and exits with appropriate status code. This script is called by `bootstrap.sh` after all phases complete, but can also be run standalone.

---

## Acceptance Criteria

### AC-1: Health check suite (16 checks)
- [ ] **Check 1:** MariaDB running — `systemctl is-active mariadb` → "active"
- [ ] **Check 2:** MariaDB connection — `mariadb -u root -p"${MARIADB_ROOT_PASSWORD}" -e "SELECT 1"` → success
- [ ] **Check 3:** MariaDB charset — `SHOW VARIABLES LIKE 'character_set_server'` → "utf8mb4"
- [ ] **Check 4:** Redis running — `systemctl is-active redis-server` → "active"
- [ ] **Check 5:** Redis PING — `redis-cli ping` → "PONG"
- [ ] **Check 6:** Node.js version — `node -v` → `v24.x.x`
- [ ] **Check 7:** yarn version — `yarn --version` → `1.22.x`
- [ ] **Check 8:** Bench CLI — `bench --version` → `5.x.x`
- [ ] **Check 9:** Bench site — `cd ~/frappe-bench && bench --site ${BENCH_SITE} list-apps` → includes "frappe"
- [ ] **Check 10:** OpenClaw version — `openclaw --version` → valid version
- [ ] **Check 11:** OpenClaw gateway — `systemctl --user is-active openclaw-gateway` → "active"
- [ ] **Check 12:** OpenClaw port — `curl -sf http://localhost:${OPENCLAW_PORT}/health` OR `ss -tlnp | grep ${OPENCLAW_PORT}` → listening
- [ ] **Check 13:** Claude Studio service — `systemctl is-active claude-studio` → "active"
- [ ] **Check 14:** Claude Studio port — `curl -sf http://localhost:${CLAUDE_STUDIO_PORT}` → HTTP 200
- [ ] **Check 15:** Git auth — `git ls-remote https://github.com/tiberbu/devbox.git 2>/dev/null` → exit 0
- [ ] **Check 16:** Discord notification sent (see AC-3)
- [ ] Each check logs PASS or FAIL with `log_success` / `log_error`
- [ ] Tracks pass/fail count

### AC-2: Summary table output
- [ ] Prints formatted table after all checks:
  ```
  ╔══════════════════════════════════════════════════════╗
  ║           Tiberbu DevBox — Verification              ║
  ╠══════════════════╦══════════╦════════════════════════╣
  ║ Component        ║ Status   ║ Detail                 ║
  ╠══════════════════╬══════════╬════════════════════════╣
  ║ MariaDB          ║ ✓ PASS   ║ 10.11.14 :3306         ║
  ║ Redis            ║ ✓ PASS   ║ 7.0.15 :6379           ║
  ║ Node.js          ║ ✓ PASS   ║ v24.14.1               ║
  ║ yarn             ║ ✓ PASS   ║ 1.22.22                ║
  ║ Frappe Bench     ║ ✓ PASS   ║ 5.29.1 site:dev.local  ║
  ║ OpenClaw         ║ ✓ PASS   ║ 2026.4.8 :18789        ║
  ║ Claude Studio    ║ ✓ PASS   ║ :3000                  ║
  ║ Git Auth         ║ ✓ PASS   ║ github.com/tiberbu     ║
  ╠══════════════════╬══════════╬════════════════════════╣
  ║ Total            ║ 16/16    ║ ALL CHECKS PASSED      ║
  ╚══════════════════╩══════════╩════════════════════════╝
  ```
- [ ] Failed checks show `✗ FAIL` in red
- [ ] Summary line shows pass/total count

### AC-3: Discord notification
- [ ] Sends a message to the configured Discord channel via bot API
- [ ] Uses `curl` to POST to `https://discord.com/api/v10/channels/${DISCORD_CHANNEL_ID}/messages`
- [ ] Headers: `Authorization: Bot ${DISCORD_BOT_TOKEN}`, `Content-Type: application/json`
- [ ] Message content includes:
  - Instance hostname
  - Service status summary (e.g., "5/5 services running")
  - Key URLs: Claude Studio, Frappe Bench
  - Timestamp
- [ ] Notification failure does NOT fail the verification script (uses `|| true` / `|| log_warn`)
- [ ] Logs success or warning about Discord notification

### AC-4: Exit code
- [ ] Exits 0 if ALL 16 checks pass (excluding Discord notification which is best-effort)
- [ ] Exits 1 if ANY critical check fails
- [ ] Discord notification failure only triggers a warning, not a failure exit

### AC-5: Standalone execution
- [ ] Can be run independently: `./scripts/verify.sh`
- [ ] Sources `_common.sh` and reads env file
- [ ] Supports `--phase N` flag to verify only one phase's components

---

## Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `scripts/verify.sh` | Create | Post-install verification script |

---

## Technical Notes

- The Discord API call uses the bot token (not a webhook) — requires `Authorization: Bot TOKEN` header
- The Discord message should use an embed format for cleaner rendering:
  ```json
  {
    "embeds": [{
      "title": "DevBox Setup Complete",
      "color": 65280,
      "fields": [
        {"name": "Hostname", "value": "ip-172-31-x-x", "inline": true},
        {"name": "Services", "value": "5/5 running", "inline": true}
      ]
    }]
  }
  ```
- nvm must be sourced before checks that use node/npm/yarn/openclaw
- The `bench` commands must be run from `~/frappe-bench` directory
- Health check port verification should use `curl` where possible (more reliable than `ss`)
- Some services may take a moment to become fully ready — the verify script should have a brief retry for port checks

---

## Definition of Done

- [ ] `bash -n scripts/verify.sh` passes
- [ ] On fully provisioned instance: all 16 checks pass
- [ ] Summary table is printed to stdout with correct formatting
- [ ] Discord channel receives notification message
- [ ] Exit code is 0 when all checks pass
- [ ] Exit code is 1 when any check fails (test by stopping a service)
- [ ] Runs standalone without bootstrap.sh
- [ ] ShellCheck passes with no errors
