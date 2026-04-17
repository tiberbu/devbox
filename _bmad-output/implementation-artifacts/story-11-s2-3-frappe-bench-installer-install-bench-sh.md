# Story S2.3: Frappe Bench Installer (install-bench.sh)

Status: done

## Story

As a Tiberbu engineer,
I want `scripts/install-bench.sh` to install the Frappe Bench CLI, initialize a bench with the Frappe framework (version-15), create a development site backed by MariaDB, and configure bench for developer mode,
so that `cd ~/frappe-bench && bench start` immediately serves `http://dev.local:8000` after a fresh bootstrap with zero manual steps.

---

## Acceptance Criteria

### AC-1: Idempotency check
- [ ] Checks marker `/var/tmp/devbox/.phase-3-complete` AND `bench --version 2>/dev/null` AND `[[ -d "${HOME}/frappe-bench/sites/${BENCH_SITE}" ]]`
- [ ] If all three pass: log "Phase 3 already complete, skipping" and `exit 0`
- [ ] If marker exists but either binary check or site dir check fails: `clear_marker 3` and re-run the full installation

### AC-2: Bench CLI installation
- [ ] Sources nvm (`${HOME}/.nvm/nvm.sh`) to make `node` / `npm` / `yarn` available on PATH in non-interactive shell
- [ ] Installs frappe-bench: `pip3 install frappe-bench` — uses `--break-system-packages` flag on Ubuntu 24.04 (externally-managed environment), OR falls back to `pipx install frappe-bench` if pip3 --break-system-packages is unavailable
- [ ] After install, verifies: `bench --version` returns output matching `5.x.x`

### AC-3: Bench initialization
- [ ] Runs: `bench init "${HOME}/frappe-bench" --frappe-branch "${FRAPPE_BRANCH}"` (default `FRAPPE_BRANCH=version-15`)
- [ ] The bench directory is created with: `apps/frappe/`, `env/` (Python venv), `sites/`, `Procfile`
- [ ] Logs a progress banner before init: "Initializing Frappe bench — this may take 3–5 minutes…"
- [ ] Only `frappe` app is installed — no ERPNext, healthcare, or any other apps

### AC-4: Site creation
- [ ] `cd "${HOME}/frappe-bench"` before all bench commands
- [ ] Runs: `bench new-site "${BENCH_SITE}" --mariadb-root-password "${MARIADB_ROOT_PASSWORD}" --admin-password "${MARIADB_ROOT_PASSWORD}"` (defaults: `BENCH_SITE=dev.local`, `MARIADB_ROOT_PASSWORD=tiberbu123`)
- [ ] Adds `/etc/hosts` entry `127.0.0.1  ${BENCH_SITE}` via `sudo tee -a /etc/hosts` if the site name is not already present in the file
- [ ] Runs: `bench use "${BENCH_SITE}"` to set the default site

### AC-5: Development mode configuration
- [ ] Runs: `bench set-config developer_mode 1` (inside `~/frappe-bench`)
- [ ] Runs: `bench set-config dev_server 1`
- [ ] Adds `"serve_default_site": 1` to `~/frappe-bench/sites/common_site_config.json` (use `python3 -c` + `json.load/dump` or `bench set-common-config`)

### AC-6: Verification and marker
- [ ] Directory `${HOME}/frappe-bench/sites/${BENCH_SITE}` exists
- [ ] `cd "${HOME}/frappe-bench" && bench --site "${BENCH_SITE}" list-apps` output includes `frappe`
- [ ] Calls `set_marker 3` → creates `/var/tmp/devbox/.phase-3-complete`

---

## Tasks / Subtasks

- [ ] Task 1 — Scaffold script & idempotency (AC: 1)
  - [ ] Header: `#!/usr/bin/env bash`, `set -euo pipefail`
  - [ ] Locate `SCRIPT_DIR` and `DEVBOX_DIR` via `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)` and parent
  - [ ] Source `"${SCRIPT_DIR}/_common.sh"`
  - [ ] Define constants: `PHASE_NUM=3`, `PHASE_NAME="Frappe Bench"`, `TOTAL_PHASES=5`
  - [ ] Apply defensive defaults: `: "${FRAPPE_BRANCH:=version-15}"`, `: "${BENCH_SITE:=dev.local}"`, `: "${MARIADB_ROOT_PASSWORD:=tiberbu123}"`
  - [ ] Implement `check_idempotency()` — triple check: `check_marker 3` + `bench --version` + site dir exists
  - [ ] Call `check_idempotency` at script top

- [ ] Task 2 — nvm sourcing & prerequisite guards (AC: 2)
  - [ ] Implement `source_nvm()` — export `NVM_DIR="${HOME}/.nvm"`, source `nvm.sh` with shellcheck disable SC1090/SC1091
  - [ ] After sourcing, verify `command -v node &>/dev/null` and `command -v yarn &>/dev/null`; if missing, log descriptive error and exit 1

- [ ] Task 3 — Bench CLI installation (AC: 2)
  - [ ] Implement `install_bench_cli()`:
    - Try `pip3 install --break-system-packages frappe-bench`; if that fails (exit ≠ 0), fall back to `pip3 install frappe-bench`
    - Verify `bench --version` matches `5.*` after install
  - [ ] Log success: "frappe-bench $(bench --version) installed"

- [ ] Task 4 — Bench initialization (AC: 3)
  - [ ] Implement `init_bench()`:
    - Guard: skip `bench init` if `[[ -d "${HOME}/frappe-bench/apps/frappe" ]]` (already initialized — do not re-init)
    - Log the 3–5 minute banner before running
    - Run `bench init "${HOME}/frappe-bench" --frappe-branch "${FRAPPE_BRANCH}"`
    - Assert `apps/frappe/`, `env/`, `sites/`, `Procfile` all exist after init

- [ ] Task 5 — Site creation (AC: 4)
  - [ ] Implement `create_site()`:
    - Change into `~/frappe-bench` for all bench commands (use `cd` or `pushd`)
    - Guard: skip `bench new-site` if `[[ -d "${HOME}/frappe-bench/sites/${BENCH_SITE}" ]]`
    - Run `bench new-site "${BENCH_SITE}" --mariadb-root-password "${MARIADB_ROOT_PASSWORD}" --admin-password "${MARIADB_ROOT_PASSWORD}"`
  - [ ] Implement `add_hosts_entry()`:
    - Check `grep -q "\\b${BENCH_SITE}\\b" /etc/hosts` before adding
    - If not found: `echo "127.0.0.1  ${BENCH_SITE}" | sudo tee -a /etc/hosts > /dev/null`
    - Log confirmation
  - [ ] Run `bench use "${BENCH_SITE}"`

- [ ] Task 6 — Development mode configuration (AC: 5)
  - [ ] Implement `configure_dev_mode()`:
    - `cd "${HOME}/frappe-bench"` (or use pushd/popd)
    - `bench set-config developer_mode 1`
    - `bench set-config dev_server 1`
    - Set `serve_default_site` in common_site_config.json using `bench set-common-config serve_default_site 1` if available, or `python3` JSON manipulation as fallback

- [ ] Task 7 — Verify and mark complete (AC: 6)
  - [ ] Implement `verify_phase()`:
    - Assert `[[ -d "${HOME}/frappe-bench/sites/${BENCH_SITE}" ]]`
    - Run `cd "${HOME}/frappe-bench" && bench --site "${BENCH_SITE}" list-apps` and grep for `frappe`
    - Call `set_marker 3`
    - Log `log_success "Phase 3 complete — Frappe Bench ready"`

- [ ] Task 8 — Quality gate
  - [ ] `bash -n scripts/install-bench.sh` exits 0
  - [ ] `shellcheck scripts/install-bench.sh` exits 0 with zero warnings (address SC2155, SC2016, SC1090, SC1091 inline)

---

## Dev Notes

### Architecture Context

- **Phase number:** 3 of 5 (see architecture §3.1 — Installation Order)
- **Script location:** `scripts/install-bench.sh` — sourced by `bootstrap.sh` as `run_phase 3 "Frappe Bench" "scripts/install-bench.sh"`
- **Service type:** Frappe bench runs in **manual dev mode** (`bench start`) — not a systemd service. Contrast with phases 4 and 5 which create systemd services
- **Performance budget:** < 5 minutes on t3.xlarge (architecture §10); `bench init` is the dominant step (~3–4 min due to pip install + git clone frappe + node asset build)
- **Port binding:** Frappe dev server binds to `localhost:8000` (architecture §1.2 Service Architecture)

### Dependencies (Prerequisites)

Phase 3 requires Phases 1 and 2 to be complete:
- Phase 1 provides: `mariadb-server` (running), `redis-server` (running), `python3`, `pip3`, `build-essential`, `libmysqlclient-dev`, `libffi-dev`, `libssl-dev`, `wkhtmltopdf`, `git`
- Phase 2 provides: `node` (v24.x via nvm), `npm`, `yarn`

Add optional prerequisite guards at the top of the script for better error messages:
```bash
require_command python3 || { log_error "python3 not found — run install-system.sh first"; exit 1; }
require_command git     || { log_error "git not found — run install-system.sh first"; exit 1; }
```

### nvm Sourcing in Non-Interactive Shell

Bash does not source `~/.bashrc` or `~/.profile` in non-interactive scripts. nvm must be manually sourced:

```bash
source_nvm() {
    export NVM_DIR="${HOME}/.nvm"
    # shellcheck disable=SC1090,SC1091
    if [[ -s "${NVM_DIR}/nvm.sh" ]]; then
        \. "${NVM_DIR}/nvm.sh"
    else
        log_error "nvm not found at ${NVM_DIR} — run install-node.sh first"
        exit 1
    fi
    command -v node &>/dev/null || { log_error "node not on PATH after sourcing nvm"; exit 1; }
    command -v yarn &>/dev/null || { log_error "yarn not on PATH after sourcing nvm"; exit 1; }
    log_success "nvm sourced — node $(node -v), yarn $(yarn --version)"
}
```

### pip3 / break-system-packages

Ubuntu 24.04 uses PEP 668 "externally managed" Python. A bare `pip3 install frappe-bench` will exit with an error unless `--break-system-packages` is passed (or a venv is used):

```bash
install_bench_cli() {
    log_info "Installing frappe-bench via pip3..."
    if pip3 install --break-system-packages frappe-bench 2>/dev/null; then
        log_success "frappe-bench installed (--break-system-packages)"
    elif pip3 install frappe-bench 2>/dev/null; then
        log_success "frappe-bench installed (system pip fallback)"
    else
        log_error "pip3 install frappe-bench failed — check pip3 and Python environment"
        exit 1
    fi

    local bench_ver
    bench_ver="$(bench --version 2>/dev/null)" || { log_error "bench command not found after install"; exit 1; }
    log_success "bench version: ${bench_ver}"
}
```

After `pip3 install --break-system-packages`, the `bench` binary lands at `/usr/local/bin/bench` (system pip path).

### Bench Init Guard

`bench init` is a long, non-idempotent operation. Guard against re-running it:

```bash
init_bench() {
    if [[ -d "${HOME}/frappe-bench/apps/frappe" ]]; then
        log_info "~/frappe-bench already initialized — skipping bench init"
        return 0
    fi

    log_info "Initializing Frappe bench (FRAPPE_BRANCH=${FRAPPE_BRANCH}) — this may take 3–5 minutes..."
    bench init "${HOME}/frappe-bench" --frappe-branch "${FRAPPE_BRANCH}"

    # Validate bench structure
    local required_dirs=("apps/frappe" "env" "sites")
    for dir in "${required_dirs[@]}"; do
        [[ -d "${HOME}/frappe-bench/${dir}" ]] \
            || { log_error "bench init missing expected dir: ${dir}"; exit 1; }
    done
    [[ -f "${HOME}/frappe-bench/Procfile" ]] \
        || { log_error "bench init missing Procfile"; exit 1; }

    log_success "bench init complete"
}
```

### Site Creation Guard

`bench new-site` will error if the site already exists. Guard:

```bash
create_site() {
    cd "${HOME}/frappe-bench"

    if [[ -d "sites/${BENCH_SITE}" ]]; then
        log_info "Site ${BENCH_SITE} already exists — skipping new-site"
    else
        log_info "Creating site ${BENCH_SITE}..."
        bench new-site "${BENCH_SITE}" \
            --mariadb-root-password "${MARIADB_ROOT_PASSWORD}" \
            --admin-password "${MARIADB_ROOT_PASSWORD}"
        log_success "Site ${BENCH_SITE} created"
    fi

    add_hosts_entry
    bench use "${BENCH_SITE}"
    log_success "Default site set to ${BENCH_SITE}"
}
```

### /etc/hosts Entry Pattern

```bash
add_hosts_entry() {
    if grep -qF "${BENCH_SITE}" /etc/hosts; then
        log_info "/etc/hosts already contains ${BENCH_SITE} — skipping"
    else
        echo "127.0.0.1  ${BENCH_SITE}" | sudo tee -a /etc/hosts > /dev/null
        log_success "Added 127.0.0.1  ${BENCH_SITE} to /etc/hosts"
    fi
}
```

Using `-qF` (fixed string, quiet) avoids regex interpretation of dots in hostnames like `dev.local`.

### Dev Mode Configuration

```bash
configure_dev_mode() {
    cd "${HOME}/frappe-bench"
    bench set-config developer_mode 1
    bench set-config dev_server 1
    # serve_default_site — try bench command first, fall back to python
    if bench set-common-config serve_default_site 1 2>/dev/null; then
        log_success "serve_default_site set via bench set-common-config"
    else
        # Fallback: direct JSON edit
        local cfg="${HOME}/frappe-bench/sites/common_site_config.json"
        python3 - <<EOF
import json, pathlib
p = pathlib.Path("${cfg}")
data = json.loads(p.read_text()) if p.exists() else {}
data["serve_default_site"] = 1
p.write_text(json.dumps(data, indent=2))
print("serve_default_site set via python3 fallback")
EOF
    fi
    log_success "Developer mode configured"
}
```

### Idempotency Design

Follows the dual-check pattern from architecture §7 (Idempotency Strategy):

```
check_marker 3  →  fail  →  proceed with full install
                  pass   →  check bench --version
                               fail  →  clear_marker 3, proceed
                             pass   →  check ~/frappe-bench/sites/${BENCH_SITE} exists
                                          fail  →  clear_marker 3, proceed
                                         pass  →  exit 0 (skip)
```

Full implementation:
```bash
check_idempotency() {
    if check_marker 3 \
        && bench --version &>/dev/null \
        && [[ -d "${HOME}/frappe-bench/sites/${BENCH_SITE}" ]]; then
        log_info "Phase 3 already complete — skipping"
        exit 0
    fi
    # Clear stale marker if install is incomplete
    clear_marker 3
    log_info "Phase 3 starting fresh install"
}
```

### bench Command Working Directory

Most `bench` commands (new-site, use, set-config, set-common-config, list-apps) **must** be run from inside `~/frappe-bench/`. Use `cd "${HOME}/frappe-bench"` at the top of each function that calls bench, or use a `pushd`/`popd` block. Do NOT rely on a global `cd` at the top of the script.

### Verification Pattern

```bash
verify_phase() {
    log_info "Verifying Phase 3..."

    [[ -d "${HOME}/frappe-bench/sites/${BENCH_SITE}" ]] \
        || { log_error "Site directory missing: ${HOME}/frappe-bench/sites/${BENCH_SITE}"; exit 1; }

    cd "${HOME}/frappe-bench"
    local apps_list
    apps_list="$(bench --site "${BENCH_SITE}" list-apps 2>/dev/null)" \
        || { log_error "bench list-apps failed"; exit 1; }
    echo "${apps_list}" | grep -q "frappe" \
        || { log_error "frappe not found in list-apps output: ${apps_list}"; exit 1; }

    set_marker 3
    log_success "Phase 3 complete — bench $(bench --version), site ${BENCH_SITE} ready"
}
```

### ShellCheck Expectations

| Pattern | SC Code | Reason |
|---------|---------|--------|
| `\. "${NVM_DIR}/nvm.sh"` | SC1090, SC1091 | Dynamic source path — disable per-line |
| `# shellcheck source=scripts/_common.sh` | N/A | Source directive for static analysis |
| `bench --version` in subshell | SC2006 | Use `$()` not backticks |
| Here-doc with embedded vars | SC2148 | Use `EOF` (quoted) to avoid expansion |

Standard header:
```bash
#!/usr/bin/env bash
# scripts/install-bench.sh — Phase 3: Frappe Bench
# shellcheck source=scripts/_common.sh
set -euo pipefail
```

### Performance Budget

Target: < 5 minutes on t3.xlarge (architecture §10).

| Step | Expected time |
|------|---------------|
| pip3 install frappe-bench | ~30s |
| bench init (clone + venv + assets) | ~3–4 min |
| bench new-site (MariaDB create) | ~20s |
| dev mode config | ~5s |
| Verification | ~5s |
| **Total** | **~4–5 min** |

Second run (idempotent skip): < 2 seconds.

### Environment Variables Used

| Variable | Default | Source | Purpose |
|----------|---------|--------|---------|
| `FRAPPE_BRANCH` | `version-15` | `~/.tiberbu-env` or default | `bench init --frappe-branch` |
| `BENCH_SITE` | `dev.local` | `~/.tiberbu-env` or default | Site name for `bench new-site` and `/etc/hosts` |
| `MARIADB_ROOT_PASSWORD` | `tiberbu123` | `~/.tiberbu-env` or default | MariaDB root pw and site admin pw |
| `HOME` | `/home/ubuntu` | system | Bench directory: `${HOME}/frappe-bench` |
| `NVM_DIR` | `${HOME}/.nvm` | set in script | nvm install directory |

All must be exported before bench commands run. Defaults applied with `: "${VAR:=default}"` pattern.

### Project Structure Notes

- **Script location:** `scripts/install-bench.sh` — consistent with all phase scripts in `scripts/`
- **Bench directory:** `~/frappe-bench/` — set by `bench init "${HOME}/frappe-bench"`
- **Site directory:** `~/frappe-bench/sites/${BENCH_SITE}/` — created by `bench new-site`
- **Marker file:** `/var/tmp/devbox/.phase-3-complete` — managed via `set_marker 3` / `clear_marker 3`
- **Shared library:** source `${SCRIPT_DIR}/_common.sh` — provides `log_*`, `check_marker`, `set_marker`, `clear_marker`, `require_command`, `error_handler`
- **No templates needed:** Phase 3 has no `templates/` directory usage (unlike phases 4 and 5)
- **No systemd service:** Frappe bench runs manually (`bench start`) — no unit file created in this phase

### Key PRD / Architecture References

- Phase 3 acceptance criteria: [prd.md §FR-5: Phase 3 — Frappe Bench]
- Idempotency table row 3: [architecture.md §7 Idempotency Strategy]
- Performance budget row: [architecture.md §10 Performance Budget]
- Installation order: [architecture.md §3.1 Installation Order]
- Service architecture (bench port 8000): [architecture.md §1.2 Service Architecture]
- Technology versions (bench 5.x, frappe version-15): [architecture.md §9 Technology Versions]

---

## Definition of Done

- [ ] `bash -n scripts/install-bench.sh` exits 0
- [ ] `shellcheck scripts/install-bench.sh` exits 0 with zero warnings
- [ ] On provisioned instance (phases 1+2 complete): script runs end-to-end without error
- [ ] `bench --version` returns `5.x.x`
- [ ] `~/frappe-bench/apps/frappe/` exists
- [ ] `~/frappe-bench/env/` (Python venv) exists
- [ ] `~/frappe-bench/sites/${BENCH_SITE}/` exists
- [ ] `cd ~/frappe-bench && bench --site ${BENCH_SITE} list-apps` shows `frappe` (only — no ERPNext)
- [ ] `/etc/hosts` contains `127.0.0.1  ${BENCH_SITE}` (or equivalent)
- [ ] `~/frappe-bench/sites/common_site_config.json` has `"serve_default_site": 1`
- [ ] Second run exits in < 2 seconds (all three idempotency checks pass)
- [ ] Total time < 5 minutes on t3.xlarge

---

## Dev Agent Record

### Agent Model Used

_to be filled by dev agent_

### Debug Log References

_to be filled by dev agent_

### Completion Notes List

_to be filled by dev agent_

### Change Log

| Date | Author | Change |
|------|--------|--------|
| 2026-04-17 | pm-agent | Created story-11 for S2.3: Frappe Bench Installer (install-bench.sh) |

### File List

- `scripts/install-bench.sh` (to be created)
