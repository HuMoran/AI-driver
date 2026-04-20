# doctor-command.spec.md

## Meta

- Date: 2026-04-20
- Review Level: B

## Goal

Add `/ai-driver:doctor` — a read-only health check for a project that uses AI-driver. It detects silent drift between the project's copies of AI-driver files and the latest plugin templates, flags misconfiguration (`CLAUDE.md` not importing `AGENTS.md`, `settings.json` missing the enabled-plugins entry, legacy v0.1 spec filenames, etc.), and prints actionable fix commands. It never modifies files. This is the complement to `/ai-driver:init`: init sets things up; doctor tells you they're still set up correctly.

## User Scenarios

### Scenario 1: Clean project — everything green (Priority: P0)

**Role:** maintainer of a healthy AI-driver project
**Goal:** quick sanity check confirming nothing has drifted
**Benefit:** cheap peace of mind before a release

**Acceptance:**

1. **Given** a project initialized by `/ai-driver:init` with current v0.3.x plugin, with no manual drift,
   **When** the user runs `/ai-driver:doctor`,
   **Then** the report prints `[✓]` for every check and ends with `Summary: 0 errors, 0 warnings, <N> checks passed`. Exit 0.

2. **Given** a non-plugin project (no `.claude-plugin/` directory) using AI-driver for its own development,
   **When** doctor runs,
   **Then** plugin-specific checks (marketplace.json, plugin.json) are marked `[—]` (N/A) and do not count as errors.

**Independent Test:** run `/ai-driver:init` in a scratch dir, then `/ai-driver:doctor`. Expect all green.

### Scenario 2: CLAUDE.md not importing AGENTS.md (Priority: P0)

**Role:** maintainer whose `CLAUDE.md` was edited by hand and lost the `@AGENTS.md` import
**Goal:** be told immediately

**Acceptance:**

1. **Given** `CLAUDE.md` exists but contains no line matching `^@(\./)?AGENTS\.md$`,
   **When** doctor runs,
   **Then** it prints: `[✗] CLAUDE.md does not import AGENTS.md. Fix: prepend '@AGENTS.md' at the top of CLAUDE.md.` and exits non-zero.

2. **Given** `CLAUDE.md` imports `AGENTS.md` somewhere in the middle (not at the top),
   **When** doctor runs,
   **Then** it prints a `[⚠]` warning noting that the import should come first for correct precedence (Codex flagged this in round-1 on v0.2).

### Scenario 3: Constitution.md drifted from latest template (Priority: P1)

**Role:** maintainer whose project constitution is several versions old
**Goal:** see what changed without guessing

**Acceptance:**

1. **Given** `./constitution.md` differs from `${CLAUDE_PLUGIN_ROOT}/templates/constitution.md`,
   **When** doctor runs,
   **Then** it prints `[⚠] constitution.md — drifted from plugin template v<X.Y.Z>` with the first 10 lines of the unified diff, and suggests: `diff constitution.md \${CLAUDE_PLUGIN_ROOT}/templates/constitution.md | less`.

2. **Given** `./constitution.md` is byte-identical to the template,
   **When** doctor runs,
   **Then** the check passes `[✓]`.

### Scenario 4: Legacy v0.1 spec filenames (Priority: P1)

**Role:** maintainer upgrading from v0.1 who forgot to rename `specs/p01_foo.spec.md` → `specs/foo.spec.md`
**Goal:** have doctor remind them

**Acceptance:**

1. **Given** `./specs/p<NN>_<name>.spec.md` files exist,
   **When** doctor runs,
   **Then** it lists each such file under `[⚠] Legacy v0.1 filename` with the exact `git mv` command to rename it.

### Scenario 5: Settings.json missing enabledPlugins entry (Priority: P1)

**Role:** team member who expected `ai-driver@ai-driver` to be enabled but isn't
**Goal:** see the specific settings entry to add

**Acceptance:**

1. **Given** `./.claude/settings.json` exists but does NOT have `.enabledPlugins["ai-driver@ai-driver"] == true`,
   **When** doctor runs,
   **Then** it prints `[⚠] .claude/settings.json does not enable ai-driver@ai-driver` and suggests the exact `jq` command to add it.

2. **Given** `./.claude/settings.json` does not exist,
   **When** doctor runs,
   **Then** it prints `[⚠] .claude/settings.json missing — run /ai-driver:init`.

### Scenario 6: Plugin version skew warning (Priority: P2)

**Role:** maintainer whose local installed plugin is behind the version in `.claude/settings.json`'s marketplace source
**Goal:** know to run `claude plugin update`

**Acceptance:**

1. **Given** the installed plugin version (from `${CLAUDE_PLUGIN_ROOT}` path's `0.X.Y` component) is older than the version in the plugin's own `marketplace.json` (read from the cache, same file),
   **When** doctor runs,
   **Then** it prints `[⚠] Plugin 0.X.Y installed but 0.Y.Z available. Run: claude plugin update ai-driver@ai-driver`.

(This only works if the installed cache actually has the newer marketplace.json; if the user hasn't run `plugin marketplace update`, this check silently passes. That's OK — not worth over-engineering.)

### Edge Cases

- Doctor is run from a directory that is NOT an AI-driver project (no `constitution.md`, no `AGENTS.md`): exit with a single clear message `"Not an AI-driver project — run /ai-driver:init first"`. Do NOT print a long misleading report.
- Doctor is run with `--fix` flag: this v1 does NOT support auto-fix. If `--fix` is passed, abort with: `"--fix is not supported. Doctor is read-only; run the suggested commands yourself."`.
- Plugin cache directory not readable (reinstall needed): print `[⚠]` and skip plugin-template drift checks; continue with everything else.

## Acceptance Criteria

- [ ] AC-001: `plugins/ai-driver/commands/doctor.md` exists and follows the documented command format.
- [ ] AC-002: Doctor is a pure-read command — frontmatter `allowed-tools` excludes `Write`, `Edit`, `Bash(rm:*)`, `Bash(git commit:*)`, `Bash(git push:*)`, `Bash(gh:*)`. Only `Read`, `Glob`, `Grep`, `Bash(git status:*)`, `Bash(git log:*)`, `Bash(jq:*)`, `Bash(diff:*)`, `Bash(cmp:*)`, `Bash(find:*)` are allowed.
- [ ] AC-003: Running doctor in a fresh `/ai-driver:init`-ed scratch dir prints `Summary: 0 errors, 0 warnings`.
- [ ] AC-004: Running doctor on a fixture where CLAUDE.md is missing `@AGENTS.md` prints the documented `[✗]` message and the summary line shows `>= 1 errors`.
- [ ] AC-005: Running doctor on a fixture where CLAUDE.md imports `@AGENTS.md` but NOT at the top prints a `[⚠]` warning with the correct remediation.
- [ ] AC-006: Running doctor with `--fix` passed in `$ARGUMENTS` exits with the "not supported" message without printing any `[✓]` checks.
- [ ] AC-007: Running doctor in a non-AI-driver directory (no `constitution.md`, no `AGENTS.md`) prints the "Not an AI-driver project" message and exits.
- [ ] AC-008: Running doctor on a project that has legacy `specs/p01_foo.spec.md` prints a `[⚠]` line per such file with the `git mv` fix command.
- [ ] AC-009: README (EN + zh-CN) Commands table + per-command model table include `/ai-driver:doctor`.
- [ ] AC-010: `plugins/ai-driver/templates/AGENTS.md` workflow section mentions running `/ai-driver:doctor` after major framework upgrades.

## Constraints

### MUST

- MUST-001: Doctor NEVER modifies any file (enforced by `allowed-tools` frontmatter — no Write/Edit/rm/mv).
- MUST-002: Doctor exits non-zero if any `[✗]` error is printed. `[⚠]` warnings alone still exit 0 (don't break CI for drift-nudges).
- MUST-003: Every check must emit an exact, copyable remediation command. No vague "fix this" guidance.

### MUST NOT

- MUSTNOT-001: Do not call any network / `gh` / `git push` / `git fetch` command.
- MUSTNOT-002: Do not auto-fix anything in v1.
- MUSTNOT-003: Do not fail loudly on missing plugin cache — degrade gracefully.

### SHOULD

- SHOULD-001: Report grouped by severity: errors first, then warnings, then informational.
- SHOULD-002: Finish under 3 seconds on a reasonable project (target: local file reads only).

## References

- Codex's original v0.2 HIGH on version-skew: the first mention of doctor in this session.
- Template drift bugs we kept fixing by hand across v0.2 and v0.3 — doctor is the user-facing counterpart of the Template Sync CI (which fixes it for the plugin repo).

## Needs Clarification

None.
