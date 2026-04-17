# merge-pr-version-bump.spec.md

## Meta

- Date: 2026-04-17
- Review Level: B

## Goal

`/ai-driver:merge-pr` (v0.3.0) rewrites `CHANGELOG.md` and tags, but does NOT bump the `version` fields in `.claude-plugin/marketplace.json` / `.claude-plugin/plugin.json`. For projects that publish as a Claude Code plugin (ai-driver itself is one), this leaves the marketplace manifest stale: `claude plugin update` still sees the old version and refuses to pull the new code. We found this gap while shipping v0.3.0 (had to hand-bump `marketplace.json` post-release). Fix: have `merge-pr` Step 2 also bump the version in these manifests when present, in the same `chore(release): vX.Y.Z` commit that rewrites CHANGELOG.

## User Scenarios

### Scenario 1: Plugin-publishing project — bump version in marketplace.json (Priority: P0)

**Role:** maintainer of a project that ships a Claude Code plugin
**Goal:** one `/ai-driver:merge-pr` call leaves marketplace.json in sync with the new tag
**Benefit:** no post-release hand-fixup; `plugin update` detects the new version immediately

**Acceptance:**

1. **Given** the repo has `.claude-plugin/marketplace.json` containing `metadata.version = "0.3.0"` and `plugins[].version = "0.3.0"`,
   **When** `/ai-driver:merge-pr --version 0.3.1` runs Step 2,
   **Then** both those `version` fields are updated to `"0.3.1"` in the same commit that rewrites CHANGELOG. The commit is `chore(release): v0.3.1` and contains both `CHANGELOG.md` AND `marketplace.json` changes.

2. **Given** `.claude-plugin/plugin.json` also exists and contains a top-level `"version"` field,
   **When** the same Step 2 runs,
   **Then** `plugin.json`'s `version` is also bumped to `"0.3.1"`.

3. **Given** `.claude-plugin/plugin.json` exists WITHOUT a `version` field (as in ai-driver's current layout),
   **When** Step 2 runs,
   **Then** `plugin.json` is NOT modified (no key injection).

**Independent Test:** on a fixture directory with known starting versions, run the Step-2 rewrite logic and `diff` the before/after to confirm exact fields changed.

### Scenario 2: Non-plugin project — no bump, no error (Priority: P1)

**Role:** maintainer of an ordinary project using AI-driver that does NOT publish itself as a plugin
**Goal:** `merge-pr` works identically to v0.3.0 for non-plugin projects

**Acceptance:**

1. **Given** no `.claude-plugin/` directory exists in the project,
   **When** `merge-pr` Step 2 runs,
   **Then** only `CHANGELOG.md` is rewritten; the version-bump logic is a silent no-op; the `chore(release):` commit contains only `CHANGELOG.md`.

### Scenario 3: Invalid manifest JSON is surfaced in preflight, not silently skipped (Priority: P1)

**Role:** maintainer whose marketplace.json is corrupt
**Goal:** fail fast with a clear message, not silently skip the bump

**Acceptance:**

1. **Given** `.claude-plugin/marketplace.json` exists but is invalid JSON,
   **When** `merge-pr` Step 0 preflight runs,
   **Then** it aborts with: `"ERROR: .claude-plugin/marketplace.json is not valid JSON. Fix it and rerun."` — before any write.

### Edge Cases

- `marketplace.json` has multiple plugins listed: bump each entry's `version` that currently matches the **pre-merge** version (don't indiscriminately set all to NEXT; unrelated plugins have their own versions). v1 rule: if there is exactly one plugin entry, bump it; if multiple, only bump entries whose current version equals `metadata.version`.
- `marketplace.json` lacks `metadata.version`: just bump plugin entries that match the conservative rule above; do not inject `metadata.version`.
- Dry-run must show the planned `marketplace.json` / `plugin.json` diff, not execute it.

## Acceptance Criteria

- [ ] AC-001: `plugins/ai-driver/commands/merge-pr.md` Step 2 documents the version-bump logic for both `marketplace.json` and `plugin.json`.
- [ ] AC-002: fixture A (both files present, both versions at 0.3.0): after Step 2 for `--version 0.3.1`, `marketplace.json.metadata.version == "0.3.1"` AND all matching `plugins[].version == "0.3.1"`. `diff` output shows exactly 2 changed lines in `marketplace.json` (assuming one plugin entry).
- [ ] AC-003: fixture B (only `plugin.json`, no marketplace.json): Step 2 bumps `plugin.json.version` only; no marketplace.json is created.
- [ ] AC-004: fixture C (no `.claude-plugin/` directory at all): Step 2 is a no-op for manifests; only `CHANGELOG.md` changes.
- [ ] AC-005: fixture D (`plugin.json` with NO version field): Step 2 does NOT add a `version` key — file is unchanged.
- [ ] AC-006: fixture E (`marketplace.json` with invalid JSON): Step 0 preflight aborts with the specified message before any write.
- [ ] AC-007: dry-run on fixture A prints the planned `marketplace.json` diff without modifying the file on disk (`cmp` before/after).
- [ ] AC-008: AGENTS.md template's "Update templates" instruction updated to reflect that `/ai-driver:merge-pr` now handles the version bump automatically (the prior manual-bump warning becomes stale).

## Constraints

### MUST

- MUST-001: The manifest bump commits in the same `chore(release): vX.Y.Z` commit as `CHANGELOG.md`. Not two commits.
- MUST-002: Use `jq` for JSON rewriting (already a preflight dep). No ad-hoc `sed` on JSON.
- MUST-003: Invalid JSON in an existing manifest is a preflight error. Never partially rewritten.

### MUST NOT

- MUSTNOT-001: Do not add a `version` key to `plugin.json` if it was not already present.
- MUSTNOT-002: Do not bump unrelated plugin entries in a multi-plugin `marketplace.json` (only entries whose current version matches `metadata.version`).

### SHOULD

- SHOULD-001: Dry-run shows all manifest diffs alongside the CHANGELOG diff.
- SHOULD-002: `--no-release` skips the bump along with everything else.

## References

- v0.3.0 release post-mortem: `af38a02` on main — the manual marketplace.json bump we had to do by hand.
- v0.3.0 merge-pr spec: `specs/merge-pr-command.spec.md` — original command.
- jq `*` merge operator used in `/ai-driver:init` settings.json merge.

## Needs Clarification

None.
