# Available Tools — Tiberbu Dev Assistant

## Shell Execution

Execute arbitrary shell commands on the local EC2 instance.

**Usage:**
```bash
# Run any bash command
ls ~/frappe-bench/apps/
ps aux | grep bench
systemctl --user status openclaw-gateway
```

**Safety constraints:**
- Confirm before running destructive commands (`rm -rf`, `DROP TABLE`, etc.)
- Never pipe credentials to stdout or log files
- Use `|| true` for informational checks that shouldn't halt a sequence

---

## File Read / Write

Read and write files on the local filesystem.

**Usage:**
```python
# Read a file
read_file("~/frappe-bench/apps/frappe/frappe/hooks.py")

# Write a file
write_file("~/frappe-bench/apps/myapp/myapp/doctype/mydt/mydt.py", content)
```

**Notes:**
- Always read a file before modifying it to avoid overwriting unsaved changes
- For large files, read specific line ranges when possible
- Config files (`.env`, `openclaw.json`) are sensitive — do not echo their contents in chat

---

## Git Operations

Perform git operations on repositories under `~/frappe-bench/apps/` or other local repos.

**Common commands:**
```bash
git status
git diff HEAD
git log --oneline -10
git checkout -b feature/my-change
git add <files>
git commit -m "message"
git push origin <branch>
```

**Constraints:**
- Never force-push to `main` or `master`
- Always check `git status` before committing
- Use GitHub token from `~/.git-credentials` for authenticated pushes (already configured)

---

## Bench CLI

Frappe Bench commands for managing the development environment.

**Site management:**
```bash
bench --site dev.local migrate          # Run pending DB migrations
bench --site dev.local clear-cache      # Clear Frappe cache
bench --site dev.local console          # Open Python REPL in site context
bench --site dev.local execute <fn>     # Execute a Python function
bench --site dev.local backup           # Create site backup
bench --site dev.local restore <file>   # Restore from backup
```

**App management:**
```bash
bench get-app <repo-url> --branch <branch>   # Clone and install app source
bench --site dev.local install-app <app>     # Install app to site
bench --site dev.local uninstall-app <app>   # Remove app from site
bench update --apps <app>                    # Update specific app
```

**Development:**
```bash
bench start                             # Start dev server (port 8000)
bench build                             # Build JS/CSS assets for all apps
bench build --app <appname>             # Build assets for one app
bench watch                             # Watch and rebuild assets on change
bench --site dev.local doctor           # Check environment health
```

**Notes:**
- Always `cd ~/frappe-bench` before running bench commands (or use absolute path context)
- `bench start` runs in foreground — use a background process or separate terminal session
- After Python code changes: restart bench server to reload
- After DocType JSON changes: run `bench migrate`

---

## Service Management

Control systemd services on this instance.

**System services (require sudo):**
```bash
sudo systemctl status claude-studio
sudo systemctl restart claude-studio
sudo systemctl status mariadb
sudo systemctl status redis-server
```

**User services (no sudo needed):**
```bash
systemctl --user status openclaw-gateway
systemctl --user restart openclaw-gateway
journalctl --user -u openclaw-gateway -f    # Follow logs
```

---

## MariaDB / MySQL

Direct database access for debugging and data inspection.

```bash
# Connect as root
sudo mariadb

# Connect to specific site database
mariadb -u root -p<password> dev_local

# Run a query
mariadb -u root -p<password> -e "SELECT name FROM \`tabUser\` LIMIT 10;" dev_local
```

**Constraints:**
- Never run `DROP DATABASE` or `TRUNCATE TABLE` without explicit confirmation
- Use `SELECT` before `UPDATE`/`DELETE` to verify target rows
- Prefer Frappe API (`frappe.db.get_value`, `frappe.db.set_value`) over raw SQL when possible

---

## Log Inspection

```bash
# Bench logs
tail -f ~/frappe-bench/logs/bench.log
tail -f ~/frappe-bench/logs/web.error.log
tail -f ~/frappe-bench/logs/worker.error.log

# OpenClaw gateway
journalctl --user -u openclaw-gateway -n 100
cat /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log

# Claude Studio
journalctl -u claude-studio -n 100
```

---

## Claude Code Studio API

Claude Code Studio runs at `http://localhost:3000` and provides REST APIs for task management and BMAD workflows.

**Auth cookie:** `/tmp/ccs.cookie`

### BMAD Command Endpoint

Forward any `bmad` command from users to Studio:
```bash
curl -s -b /tmp/ccs.cookie -X POST http://localhost:3000/api/bmad/command \
  -H "Content-Type: application/json" \
  -d '{"command": "bmad list"}'
```

### Task API

```bash
# List all tasks
curl -s -b /tmp/ccs.cookie http://localhost:3000/api/tasks

# Get a specific task
curl -s -b /tmp/ccs.cookie http://localhost:3000/api/tasks/<id>

# Create a task
curl -s -b /tmp/ccs.cookie -X POST http://localhost:3000/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"...","description":"...","workdir":"/path/to/project","status":"bmad_workflow","notes":"[bmad-workflow:dev-story]"}'

# Update a task
curl -s -b /tmp/ccs.cookie -X PUT http://localhost:3000/api/tasks/<id> \
  -H "Content-Type: application/json" \
  -d '{"status":"done"}'

# Delete a task
curl -s -b /tmp/ccs.cookie -X DELETE http://localhost:3000/api/tasks/<id>

# Bulk move tasks
curl -s -b /tmp/ccs.cookie -X POST http://localhost:3000/api/tasks/bulk-move \
  -H "Content-Type: application/json" \
  -d '{"ids":[1,2,3],"status":"done"}'
```

### Projects API

```bash
# List projects
curl -s -b /tmp/ccs.cookie http://localhost:3000/api/projects

# Create a project
curl -s -b /tmp/ccs.cookie -X POST http://localhost:3000/api/projects \
  -H "Content-Type: application/json" \
  -d '{"name":"my-project","path":"/home/ubuntu/projects/my-project"}'
```

### BMAD Workflow Types

Use `notes: "[bmad-workflow:<type>]"` + `status: "bmad_workflow"` to trigger BMAD agents:

- `domain-research` — Research the problem domain
- `planning` — Create implementation plan
- `ux-design` — Design user experience
- `solutioning` — Technical architecture
- `sprint-planning` — Break into sprint stories
- `create-story` — Create a user story
- `dev-story` — Implement a development story
- `readiness-check` — Pre-implementation review
- `code-review` — Review code changes
- `playwright-qa` — Write Playwright tests

### Task Chaining

Chain tasks to run sequentially:
```bash
curl -s -b /tmp/ccs.cookie -X POST http://localhost:3000/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Step 1","chain_id":"my-chain","sort_order":1,"status":"bmad_workflow","notes":"[bmad-workflow:planning]"}'

curl -s -b /tmp/ccs.cookie -X POST http://localhost:3000/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Step 2","chain_id":"my-chain","sort_order":2,"after":1,"status":"bmad_workflow","notes":"[bmad-workflow:dev-story]"}'
```
