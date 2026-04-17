# merge-pr-command.spec.md

## Meta

- Date: 2026-04-17
- Review Level: B

## Goal

Add `/ai-driver:merge-pr` as the human-gated "ship" step that atomically updates `CHANGELOG.md`, merges the PR, tags the release, and lets GitHub Actions publish a Release whose notes come from `CHANGELOG.md` (not from commit messages). Simultaneously replace the current `main`-triggered auto-release workflow with a `tag`-triggered one that extracts the relevant section of `CHANGELOG.md`. This fixes the observed drift where v0.2.0's Release notes dropped the BREAKING / Migration sections because the workflow only grepped `feat:` / `fix:` commit messages.

## User Scenarios

### Scenario 1: Auto-bump from `[Unreleased]` content (Priority: P0)

**Role:** maintainer shipping a feature branch after review passes
**Goal:** one command to cut the release
**Benefit:** no manual CHANGELOG ritual, no mismatch between CHANGELOG and GitHub Release

**Acceptance:**

1. **Given** the PR branch is mergeable, review passed, and `CHANGELOG.md` has a non-empty `## [Unreleased]` section containing one `### Added` bullet,
   **When** the user runs `/ai-driver:merge-pr 1`,
   **Then** the command computes the next version as a minor bump (0.2.0 → 0.3.0), rewrites `CHANGELOG.md` so `[Unreleased]` becomes `[0.3.0] - <today>` with a new empty `[Unreleased]` block above it, commits that change to the PR branch with message `chore(release): v0.3.0`, pushes, merges the PR with a merge commit, tags `main` as `v0.3.0`, and pushes the tag.

2. **Given** the BREAKING keyword appears inside `## [Unreleased]`,
   **When** the command runs without `--bump` / `--version`,
   **Then** it bumps the major version (0.2.0 → 1.0.0).

3. **Given** `## [Unreleased]` has ONLY `### Fixed` entries,
   **When** the command runs without explicit bump,
   **Then** it bumps the patch version (0.2.0 → 0.2.1).

**Independent Test:** from a throwaway branch with a synthetic CHANGELOG, run `/ai-driver:merge-pr --dry-run` and diff-check the proposed next version + rewritten CHANGELOG against expected.

### Scenario 2: Manual `--version` override (Priority: P0)

**Role:** maintainer who wants to jump to a specific version (e.g. skipping numbers, aligning with a marketing date, or shipping a pre-announced release)
**Goal:** set the exact version number
**Benefit:** escape hatch when auto-bump is not what is wanted

**Acceptance:**

1. **Given** current latest tag is `v0.2.0`,
   **When** the user runs `/ai-driver:merge-pr --version 1.0.0`,
   **Then** the command uses `v1.0.0` verbatim, does not consult `[Unreleased]` heuristics, and everything else proceeds normally.

2. **Given** `--version 0.3` (malformed — not `X.Y.Z`),
   **When** the command validates input,
   **Then** it aborts with a clear error before touching any file: `"--version must match X.Y.Z (got '0.3')"`.

3. **Given** `--version 0.2.0` or any non-monotonic value less than or equal to the latest tag,
   **When** validation runs,
   **Then** the command aborts with `"--version 0.2.0 is not greater than current latest tag v0.2.0"`.

4. **Given** a tag `v0.3.0` already exists,
   **When** the command tries to create it,
   **Then** it aborts before the merge with `"tag v0.3.0 already exists"`.

**Independent Test:** run with each malformed / non-monotonic / already-existing `--version` input on a disposable branch and assert the process halts before the merge.

### Scenario 3: Manual `--bump` level (Priority: P1)

**Role:** maintainer who wants semver semantics but disagrees with the auto-inferred bump
**Goal:** specify `major` / `minor` / `patch` explicitly

**Acceptance:**

1. **Given** `--bump patch` and current tag `v0.3.0`,
   **When** the command runs,
   **Then** the next version is `v0.3.1` regardless of `[Unreleased]` content.

2. **Given** `--bump unknown`,
   **When** validated,
   **Then** abort with `"--bump must be one of major / minor / patch (got 'unknown')"`.

3. **Given** both `--version X.Y.Z` and `--bump patch`,
   **When** validated,
   **Then** abort with `"--version and --bump are mutually exclusive"`.

### Scenario 4: Empty `[Unreleased]` blocks the merge (Priority: P0)

**Role:** maintainer who forgot to fill in the changelog
**Goal:** be told, not be surprised later

**Acceptance:**

1. **Given** `## [Unreleased]` section is empty (no non-heading non-blank content),
   **When** `/ai-driver:merge-pr` runs without `--no-release`,
   **Then** the command aborts BEFORE any git write with:
   `"CHANGELOG.md [Unreleased] is empty. Add entries under ### Added / ### Fixed / ### Changed, or pass --no-release to merge without cutting a release."`.

### Scenario 5: `--no-release` merges without bumping / tagging (Priority: P1)

**Role:** maintainer merging a pure docs or internal refactor that should not cut a release
**Goal:** merge the PR and stop there

**Acceptance:**

1. **Given** `--no-release` flag,
   **When** the command runs,
   **Then** it does NOT read `[Unreleased]`, does NOT modify `CHANGELOG.md`, does NOT tag. It only merges the PR.
2. **Given** `--no-release` plus `--version`,
   **When** validated,
   **Then** abort with `"--no-release and --version are mutually exclusive"`.

### Scenario 6: GitHub Actions publishes Release from CHANGELOG on tag push (Priority: P0)

**Role:** anyone browsing the GitHub Releases page
**Goal:** see the same notes that are in `CHANGELOG.md`

**Acceptance:**

1. **Given** a tag `v0.3.0` is pushed to `origin`,
   **When** the new `.github/workflows/auto-release.yml` fires,
   **Then** it extracts the `## [0.3.0]` section from `CHANGELOG.md` and creates a GitHub Release whose body equals that section byte-for-byte (minus the heading line itself).
2. **Given** a tag `v9.9.9` is pushed but `CHANGELOG.md` has no `## [9.9.9]` section,
   **When** the workflow runs extraction,
   **Then** the workflow fails with a clear error (so the missing-entry bug surfaces in CI, not silently).

### Edge Cases

- PR has conflicts with main — abort before touching CHANGELOG; user resolves.
- Not currently on the PR's head branch — command switches to it and back.
- `CHANGELOG.md` has Windows CRLF line endings — parser tolerates.
- User's git credentials cannot push tags — command fails after merge; prints recovery command (`git tag vX.Y.Z; git push origin vX.Y.Z`).
- `jq` not available — this command does not need jq; no dep.
- `--dry-run` (implicit in every scenario above) prints the planned diff without executing.

## Acceptance Criteria

Machine-executable checklist:

- [ ] AC-001: `test -f plugins/ai-driver/commands/merge-pr.md` (command file exists)
- [ ] AC-002: all three flags are documented in the command file: `for f in -- --version --bump --no-release; do [ "$f" = "--" ] && continue; grep -q -- "$f" plugins/ai-driver/commands/merge-pr.md || exit 1; done`
- [ ] AC-003: `.github/workflows/auto-release.yml` triggers on `push.tags`, NOT on `push.branches`. Verify: `grep -E '^\s+tags:' .github/workflows/auto-release.yml`
- [ ] AC-004: `plugins/ai-driver/templates/.github/workflows/auto-release.yml` has the same tag-triggered shape (template stays in sync).
- [ ] AC-005: `README.md` + `README.zh-CN.md` document `/ai-driver:merge-pr` in the Commands table.
- [ ] AC-006: `CHANGELOG.md` has a non-empty `## [Unreleased]` section with entries describing this spec's changes — later the merge-pr run converts it to `## [0.3.0]`.
- [ ] AC-007: `plugins/ai-driver/templates/AGENTS.md` mentions the new `merge-pr` step in the workflow.
- [ ] AC-008: awk extraction test: creating a throwaway CHANGELOG with `## [1.2.3]` and running `awk -v v=1.2.3 '$0 ~ "^## \\[" v "\\]" {found=1; next} found && /^## \[/ {exit} found {print}'` returns exactly the section body.
- [ ] AC-009: version-validation regex tests: `0.3.0` passes, `v0.3.0` fails, `0.3` fails, `0.3.0-beta` fails. (Automated test script committed under `specs/fixtures/` or inline in the command's test block.)

## Constraints

### MUST

- MUST-001: `/ai-driver:merge-pr` MUST NOT destructively modify `CHANGELOG.md` on failure. If any later step (merge, tag, push) fails after CHANGELOG is rewritten, the command prints a recovery guide and leaves the branch in a well-defined state (either re-run the merge, or `git reset --hard <sha-before-changelog-commit>` to roll back).
- MUST-002: Release notes on GitHub MUST equal the corresponding `CHANGELOG.md` section byte-for-byte (minus the `## [X.Y.Z]` heading line). No synthesizing, no commit-message scraping.
- MUST-003: Template workflow `plugins/ai-driver/templates/.github/workflows/auto-release.yml` MUST match the shape used by this repo. No divergence.

### MUST NOT

- MUSTNOT-001: Do not force-push the PR branch.
- MUSTNOT-002: Do not consult commit messages for changelog content (that was the v0.2 bug).
- MUSTNOT-003: Do not overwrite an existing tag.

### SHOULD

- SHOULD-001: `--dry-run` prints the exact actions that would be taken (next version, rewritten CHANGELOG section, planned `gh pr merge` and tag commands) without executing any of them.
- SHOULD-002: Output is machine-parseable enough for a future `/ai-driver:ship` wrapper to chain on it.
- SHOULD-003: Prefer `gh pr merge --merge` (preserves commit history of reviewed work) over `--squash` by default. Support `--squash` as an explicit flag.

## Deploy & Test [optional]

Not applicable — this is a local maintainer command + a CI workflow change. No runtime deploy involved.

## Implementation Guide [optional]

- The command is pure shell + `gh` + `git` + `awk` + `sed`. No new dependencies.
- Version extraction from latest tag: `git describe --tags --abbrev=0`.
- CHANGELOG rewrite: use `awk` to split-and-rewrite; never trust in-place sed with regex on multi-line markdown.
- GitHub Actions workflow simplification: drop the "calculate next version" and "generate changelog entry (from commits)" steps. Replace with a single awk extraction and `gh release create`.
- For the chicken-and-egg bootstrap of v0.3.0 itself: since `/ai-driver:merge-pr` will not exist when we cut v0.3.0 (the PR that adds it), the v0.3.0 release will be created by running the command's steps manually, as a dogfood validation. From v0.3.1 onward the command is self-hosted.

## References

- v0.2.0 Release notes drift incident (GitHub Release vs CHANGELOG.md): https://github.com/HuMoran/AI-driver/releases/tag/v0.2.0
- Existing workflow being replaced: `.github/workflows/auto-release.yml`
- Keep-a-Changelog: https://keepachangelog.com/en/1.1.0/
- Conventional Commits: https://www.conventionalcommits.org/

## Needs Clarification

None.
