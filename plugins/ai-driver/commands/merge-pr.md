# /ai-driver:merge-pr: Merge a PR, cut the release, tag

Usage:

```shell
/ai-driver:merge-pr [<PR-number>] [flags]
```

Atomically: rewrites `CHANGELOG.md` (Unreleased → next version block), commits, merges the PR, tags `main`, and pushes the tag. The Release itself is created by `.github/workflows/auto-release.yml` on tag push — its body comes from the matching `CHANGELOG.md` section, not from commit messages.

## Flags

- `--version X.Y.Z` — use this exact version. Highest precedence. Must match `^\d+\.\d+\.\d+$` and be strictly greater than the current latest tag.
- `--bump major|minor|patch` — semver bump from the current latest tag. Mutually exclusive with `--version`.
- `--no-release` — merge only. Do NOT read `[Unreleased]`, do NOT rewrite `CHANGELOG.md`, do NOT tag. Mutually exclusive with `--version` and `--bump`.
- `--squash` — use `gh pr merge --squash` instead of the default `--merge`.
- `--no-check` — skip the mergeable + CI checks (use when you know what you're doing).
- `--dry-run` — print planned actions (next version, rewritten CHANGELOG block, `gh pr merge` command, tag command) without executing anything.

## Pre-flight

Run these BEFORE any write. Any failure aborts with a one-line message and no state change.

1. **Resolve PR number.** If `$ARGUMENTS` begins with a number, use it. Otherwise: `gh pr list --head "$(git branch --show-current)" --json number -q '.[0].number'`. If still empty, abort with: `"No PR found. Pass a PR number or checkout the PR branch first."`
2. **Validate flags.** Parse `$ARGUMENTS`. Enforce mutual exclusion:
   - `--version` + `--bump` → abort: `"--version and --bump are mutually exclusive"`
   - `--no-release` + `--version` (or `--bump`) → abort: `"--no-release and --version/--bump are mutually exclusive"`
3. **`--version` format**: must match `^[0-9]+\.[0-9]+\.[0-9]+$`. Reject `v0.3.0`, `0.3`, `0.3.0-beta`, etc.
4. **`--bump` value**: must be `major`, `minor`, or `patch`. Any other value → abort.
5. **PR mergeability** (skip if `--no-check`):
   - `gh pr view <n> --json mergeable,mergeStateStatus --jq .mergeable` must be `"MERGEABLE"`.
   - CI status: `gh pr checks <n>` — if any REQUIRED check is FAILURE → abort.
6. **Current tag lookup**: `LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")`.
7. **Version monotonicity** (skip if `--no-release`):
   - If `--version X.Y.Z`: compare against `LAST_TAG`. If not strictly greater (semver), abort: `"--version X.Y.Z is not greater than current latest tag $LAST_TAG"`.
   - Existing-tag check: `git rev-parse -q --verify "refs/tags/v$X.Y.Z" > /dev/null` — if it exists, abort: `"tag v$X.Y.Z already exists"`.
8. **Working tree clean** on the PR branch (uncommitted changes would get swept into the release commit).

## Step 1: Determine next version (skip if `--no-release`)

Use the first matching rule:

1. `--version X.Y.Z` → `NEXT=X.Y.Z`.
2. `--bump major|minor|patch` → parse `LAST_TAG` as `M.m.p` and bump the corresponding field, zero the lower fields.
3. **Auto from `[Unreleased]`:**
   - Extract `## [Unreleased]` section from `CHANGELOG.md`.
   - Empty section (no non-heading non-blank content) → abort: `"CHANGELOG.md [Unreleased] is empty. Add entries under ### Added / ### Fixed / ### Changed, or pass --no-release to merge without cutting a release."`
   - Contains `BREAKING` (case-insensitive) → `major` bump.
   - Contains `### Added` with at least one `- ` bullet → `minor` bump.
   - Only `### Fixed` content → `patch` bump.

Print the resolved version: `"Next version: v$NEXT (reason: --version | --bump | auto-BREAKING | auto-Added | auto-Fixed)"`.

## Step 2: Rewrite CHANGELOG.md (skip if `--no-release`)

In-memory transform, then write to disk:

- Replace the line `## [Unreleased]` with `## [$NEXT] - $(date +%Y-%m-%d)`.
- Prepend above it: two new lines — `## [Unreleased]` followed by a blank line.

Pseudo-code:

```bash
DATE=$(date +%Y-%m-%d)
awk -v ver="$NEXT" -v date="$DATE" '
  /^## \[Unreleased\]/ && !seen {
    print "## [Unreleased]"
    print ""
    print "## [" ver "] - " date
    seen = 1
    next
  }
  { print }
' CHANGELOG.md > CHANGELOG.md.new
mv CHANGELOG.md.new CHANGELOG.md
```

Stage: `git add CHANGELOG.md`.

## Step 3: Commit CHANGELOG (skip if `--no-release`)

```bash
git commit -m "chore(release): v$NEXT"
git push origin HEAD
```

This lands on the PR branch, so the PR picks up the release commit and the merge commit carries it.

## Step 4: Dry-run guard

If `--dry-run` was passed: print a summary of what WOULD happen (next version, the rewritten CHANGELOG diff, the `gh pr merge` command, the `git tag` command) and exit 0 without touching anything else. The CHANGELOG rewrite from Step 2 is discarded in dry-run mode — perform it in a temp file so the real `CHANGELOG.md` is untouched.

## Step 5: Merge PR

```bash
if [ -n "$SQUASH" ]; then
  gh pr merge "$PR" --squash --delete-branch
else
  gh pr merge "$PR" --merge --delete-branch
fi
```

If this fails, the CHANGELOG commit is already on the branch but not yet merged. Recovery: the user can push additional fixes and re-run `/ai-driver:merge-pr` — the `[Unreleased]` is already consumed, so the user must either `git revert` the release commit on the branch or pass `--version` explicitly on re-run.

## Step 6: Tag main (skip if `--no-release`)

```bash
git checkout main && git pull --ff-only
git tag "v$NEXT" -m "v$NEXT"
git push origin "v$NEXT"
```

The tag push fires `.github/workflows/auto-release.yml`, which extracts the matching section from `CHANGELOG.md` and creates the GitHub Release.

## Step 7: Report

```markdown
## Merge + Release Report
- PR #<n> merged: <commit-sha>
- Version: v$NEXT
- Tag pushed: v$NEXT
- CHANGELOG section: ## [$NEXT] - <date>
- Release workflow: https://github.com/<owner>/<repo>/actions (check the Auto Release run)
- Release page: https://github.com/<owner>/<repo>/releases/tag/v$NEXT (available once workflow finishes)
```

## Recovery guidance

If the tag push fails (network, auth):

```bash
git tag v$NEXT
git push origin v$NEXT
```

If the GitHub Actions release fails (e.g., CHANGELOG.md has no matching section):

```bash
# Check the workflow run for the error
gh run list --workflow=auto-release.yml --limit 1

# Fix CHANGELOG.md, commit, then either:
#  - re-run the workflow: gh run rerun <run-id>
#  - or manually: gh release create v$NEXT --notes-file <(awk ... CHANGELOG.md)
```

## Out of scope

- Does not sign tags (add `-s` manually if GPG configured).
- Does not write the `[Unreleased]` entries for you — that's a human / AI-earlier-step task.
- Does not support pre-release / build-metadata version suffixes in v1. (Follow-up if needed.)
- Does not open a "release PR" pattern — the CHANGELOG commit goes directly onto the PR under review.
