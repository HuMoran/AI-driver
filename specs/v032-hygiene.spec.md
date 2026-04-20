# v032-hygiene.spec.md

## Meta

- Date: 2026-04-17
- Review Level: B

## Goal

Close two pieces of technical debt from v0.3.x:

1. **Template sync CI** — the plugin ships templates to users (e.g., `plugins/ai-driver/templates/.github/workflows/auto-release.yml`) that are supposed to mirror files used by this repo itself (e.g., `.github/workflows/auto-release.yml`). Today they are kept in sync by hand — I forgot multiple times in the v0.2 and v0.3 sessions; only `diff` caught it. A CI check should fail any PR where the two drift.

2. **`/ai-driver:merge-pr --dry-run` fully offline** — Codex round-2 PARTIAL: the current Step 0 preflight makes network calls (`gh pr view / checks / list`) BEFORE the Step 1 dry-run guard. A user who passes `--dry-run` offline or in a sandbox still gets network failures. Fix: split Step 0 into `0a: local-only` (file reads, flag parsing, version computation) and `0b: network`, with `--dry-run` exiting between them.

## User Scenarios

### Scenario 1: Template out of sync fails CI (Priority: P0)

**Role:** maintainer of this repo
**Goal:** never ship an out-of-sync template to users
**Benefit:** no "edited repo workflow but forgot template" bug reports

**Acceptance:**

1. **Given** a PR modifies `.github/workflows/auto-release.yml` but NOT `plugins/ai-driver/templates/.github/workflows/auto-release.yml`,
   **When** the `Template Sync` workflow runs on that PR,
   **Then** it fails with an annotation pointing at the missing template update and the exact `cp` command to fix it.

2. **Given** both files are byte-identical,
   **When** the workflow runs,
   **Then** it succeeds with no annotations.

3. **Given** the template is modified but the repo file is not,
   **When** the workflow runs,
   **Then** it fails symmetrically (same error, same remediation command).

**Independent Test:** local dry-run of the workflow's check step on a fixture where only one of the pair was modified.

### Scenario 2: `--dry-run` makes zero network calls (Priority: P0)

**Role:** maintainer running `merge-pr --dry-run` in a sandbox with no network access
**Goal:** the dry-run completes and shows the plan without any HTTP / git-remote call

**Acceptance:**

1. **Given** the command is invoked with `--dry-run --version 0.3.2` on a branch that has a PR but the shell has `NO_PROXY=* http_proxy=http://127.0.0.1:1` (forcing network failure),
   **When** it runs,
   **Then** it completes successfully, prints the planned diff, and never touches `gh pr view / checks / list` or any `git fetch / push / ls-remote`.

2. **Given** `--dry-run` without `--version` (auto-bump path),
   **When** it runs offline,
   **Then** it still determines NEXT from `[Unreleased]` and completes without any network call. PR resolution uses ONLY the local branch name and any cached PR number; if a PR number must be resolved via `gh pr list`, dry-run prints `PR: <unknown — would resolve via gh pr list at real-run time>` instead of actually calling it.

### Scenario 3: Non-dry-run still does network preflight (Priority: P0)

**Role:** maintainer running the real `merge-pr`
**Goal:** mergeability / CI checks are still enforced

**Acceptance:**

1. **Given** a real (non-dry-run) invocation with a PR that has failing required checks,
   **When** Step 0b runs,
   **Then** it aborts before any write, with the same error message as today.

### Edge Cases

- `--dry-run --no-check` combined: mergeability check is skipped anyway; dry-run still exits after 0a. No conflict.
- Template CI workflow file itself is in the sync list (meta): the workflow verifies that the workflow file at `.github/workflows/template-sync.yml` matches the one at `plugins/ai-driver/templates/.github/workflows/template-sync.yml` (bootstrapping).

## Acceptance Criteria

- [ ] AC-001: `.github/workflows/template-sync.yml` exists at repo root AND at `plugins/ai-driver/templates/.github/workflows/template-sync.yml`. `diff -q` between them is clean.
- [ ] AC-002: the sync workflow's `PAIRS` list covers at minimum: `auto-release.yml`, `ci.yml`, `.codex/config.toml`, `specs/_template.spec.md`, `specs/_template.spec.zh-CN.md`, `deploy/_template.deploy.md`, `deploy/_template.deploy.zh-CN.md`, AND the template-sync workflow itself.
- [ ] AC-003: a manual drift test — make one of the pair files differ locally and run the sync workflow's check step inline; verify it exits non-zero with a useful error.
- [ ] AC-004: `merge-pr.md` Step 0 is split into `0a: Local preflight` and `0b: Network preflight`; the `--dry-run` guard is between them.
- [ ] AC-005: `merge-pr.md` §0b explicitly names every network call (`gh pr view`, `gh pr checks`, `git fetch`). These are listed only under 0b, not 0a.
- [ ] AC-006: in `--dry-run` mode, the documented output says `"PR resolution deferred to real-run if not given on command line"` when the user did not supply a PR number.
- [ ] AC-007: `plugins/ai-driver/templates/AGENTS.md` and repo root `AGENTS.md` mention the Template Sync workflow as an expected safety net.
- [ ] AC-008: CHANGELOG [Unreleased] is populated with these changes in the v0.3.2 commit.

## Constraints

### MUST

- MUST-001: Template Sync workflow runs on every PR; a failing sync MUST block merge via `required_status_checks` convention (worker emits `exit 1`, users configure branch protection).
- MUST-002: Dry-run makes ZERO network calls under any flag combination (verified by AC-002's `http_proxy=http://127.0.0.1:1` test).
- MUST-003: Real run's behavior for existing AC (mergeability, CI-check gating, merge-SHA capture, tag push) is unchanged.

### MUST NOT

- MUSTNOT-001: Do not auto-fix drift. CI fails loudly; the maintainer runs the `cp` command shown in the error.
- MUSTNOT-002: Do not introduce new dependencies. Plain bash + `cmp` only.

### SHOULD

- SHOULD-001: Sync workflow finishes in <5 seconds on a clean checkout.
- SHOULD-002: Error message from drift includes the exact command(s) to fix it, copyable as-is.

## References

- v0.2 / v0.3 session's recurring "template out of sync" bugs (e.g., commit `454d97c` fixed the round-1 sync issue; `3faba03` mirrored another round of fixes).
- Codex round-2 PARTIAL on dry-run: PR #2 comment `4267357547`.

## Needs Clarification

None.
