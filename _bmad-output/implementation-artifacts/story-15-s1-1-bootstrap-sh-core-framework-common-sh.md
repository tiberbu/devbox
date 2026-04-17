# Story: S1.1: bootstrap.sh Core Framework + _common.sh

Status: done
Task ID: mo37hajhfq0lpy
Task Number: #15
Workflow: dev-story
Model: sonnet
Created: 2026-04-17T17:52:29.165Z

## Description

## Story S1 — bootstrap.sh Core Framework
**Epic:** E1 — Bootstrap Core Framework | **Points:** 3 | **Priority:** P0

### Acceptance Criteria

#### AC-1: scripts/_common.sh utility library
- [ ] Logging functions: log_info(), log_success(), log_error(), log_warn(), log_phase_start(), log_phase_end()
- [ ] Color-coded stdout (RED, GREEN, YELLOW, BLUE, NC)
- [ ] All log functions append to /var/tmp/devbox/bootstrap.log
- [ ] Marker functions: check_marker(), set_marker(), clear_marker() using /var/tmp/devbox/.phase-N-complete
- [ ] render_template() wraps envsubst with success logging
- [ ] error_handler() prints file, line, exit code, tails last 20 lines of log
- [ ] retry() function: count, delay, command with retries
- [ ] require_env() and require_command() validators
- [ ] Constants: MARKER_DIR, LOG_FILE, color codes exported

#### AC-2: bootstrap.sh orchestrator
- [ ] set -euo pipefail + ERR trap
- [ ] Sources scripts/_common.sh via $SCRIPT_DIR
- [ ] Argument parsing: --dry-run, --phase N, --env-file PATH, --help
- [ ] load_env_file(): reads ~/.tiberbu-env, applies defaults for optional vars
- [ ] validate_credentials(): checks 8 required vars, collects ALL missing before reporting
- [ ] run_phase(): timing, dry-run support, sequential execution of 5 phases
- [ ] Creates /var/tmp/devbox/ directory
- [ ] Prints total elapsed time
- [ ] File is executable (chmod +x)

#### AC-3: Dry-run mode
- [ ] --dry-run prevents execution, validates env + credentials, prints plan

#### AC-4: Error handling
- [ ] set -euo pipefail + ERR trap with context

### Files to Create
- scripts/_common.sh
- bootstrap.sh

### Definition of Done
- bash -n passes on both files
- ./bootstrap.sh --help prints usage
- ./bootstrap.sh --dry-run with valid env exits 0
- ShellCheck passes

Story file created by task #5. Read the story from _bmad-output/implementation-artifacts/ and implement all acceptance criteria.

## Acceptance Criteria

- [x] #### AC-1: scripts/_common.sh utility library
- [x] Logging functions: log_info(), log_success(), log_error(), log_warn(), log_phase_start(), log_phase_end()
- [x] Color-coded stdout (RED, GREEN, YELLOW, BLUE, NC)
- [x] All log functions append to /var/tmp/devbox/bootstrap.log
- [x] Marker functions: check_marker(), set_marker(), clear_marker() using /var/tmp/devbox/.phase-N-complete
- [x] render_template() wraps envsubst with success logging
- [x] error_handler() prints file, line, exit code, tails last 20 lines of log
- [x] retry() function: count, delay, command with retries
- [x] require_env() and require_command() validators
- [x] Constants: MARKER_DIR, LOG_FILE, color codes exported

## Tasks / Subtasks

- [x] Implement changes
- [x] Verify build passes

## Dev Notes



### References

- Task source: Claude Code Studio task #15

## Dev Agent Record

### Agent Model Used

sonnet

### Completion Notes List

Implemented all acceptance criteria for S1.1. Both files pass bash -n syntax check,
ShellCheck (0 warnings), --help and --dry-run exit 0. All 14 required functions in
_common.sh, all 9 required bootstrap.sh features implemented.

Key decisions:
- Used $'\033[...]m' syntax for color constants so printf '%s' works without -e flag
- Used case/printf functions for phase names/scripts instead of associative arrays
  (avoids potential bash 4.x compat issues, cleaner ShellCheck output)
- Added # shellcheck disable=SC1091 alongside source= directive so both
  `shellcheck bootstrap.sh` and `shellcheck -x bootstrap.sh` pass cleanly
- error_handler takes SCRIPT LINE EXIT_CODE (script passed explicitly in trap)
- validate_credentials collects ALL missing vars before reporting (one combined error)

### Change Log

2026-04-17: Created scripts/_common.sh — full utility library (AC-1)
2026-04-17: Created bootstrap.sh — orchestrator with all AC-2 features (AC-2, AC-3, AC-4)
2026-04-17: Made bootstrap.sh executable (chmod +x)
2026-04-17: All verification checks pass (bash -n, ShellCheck, --help, --dry-run)

### File List

- scripts/_common.sh (created)
- bootstrap.sh (created)
