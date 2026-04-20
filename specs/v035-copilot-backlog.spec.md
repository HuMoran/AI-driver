# v035-copilot-backlog.spec.md

## Meta

- Date: 2026-04-20
- Review Level: B

## Goal

Clear six real bugs Copilot flagged on PRs #1, #2, #3, #4 that we silently ignored before v0.3.4 made `/ai-driver:review-pr` comment-aware. None is a new feature; each is a fix for something already on `main` that was caught by a reviewer we failed to read. Shipping them in one batch both closes the debt and serves as the first real dogfood of the v0.3.4 workflow (this PR's review will pull in any residual Copilot / Codex / human findings via the new pipeline).

## Six bugs to fix

### B-1: `run-spec.md` references removed `Meta.ID` / `Meta.Branch`

**Source:** Copilot on PR #1 (v0.2), suppressed-low-confidence comments.

`plugins/ai-driver/commands/run-spec.md` still derives `logs/<spec-id>/` paths, branch names, and the PR body's "Spec ID" field from `Meta.ID` / `Meta.Branch`. v0.2 removed those Meta fields (only Date + Review Level remain). The intent is to derive a **spec slug** from the filename basename (`specs/user-auth.spec.md` → `user-auth`) and use that consistently.

**Fix:** every `<spec-id>` in run-spec.md → `<spec-slug>` derived as `basename(<spec-path>) - .spec.md`. Every "branch from Meta" → "branch from default convention `feat/<spec-slug>` or `fix/<spec-slug>`, based on the primary Conventional-Commits type intended for the work". The PR body's "Spec ID" field becomes a link to the spec file path.

### B-2: CI template doesn't install Flutter

**Source:** Copilot on PR #1.

`plugins/ai-driver/templates/.github/workflows/ci.yml` runs `dart analyze` / `flutter test` when `pubspec.yaml` exists, but never installs Flutter on the runner, so a Flutter project using `/ai-driver:init --with-ci` will fail CI immediately.

**Fix:** prepend a `subosito/flutter-action@v2` setup step (channel: stable) under the Flutter branch of the language detection. Mirror the change to the repo-root `.github/workflows/ci.yml` per template-sync.

### B-3: `auto-release.yml` tag glob matches pre-release

**Source:** Copilot on PR #2.

Workflow trigger is `tags: ['v*.*.*']`, which matches `v0.3.0-beta.1`, `v1.0.0-rc.2`, etc. The extractor assumes `VER` is strict semver `X.Y.Z` and looks up `## [X.Y.Z]` in `CHANGELOG.md`, which will silently miss on a pre-release tag and fail with the empty-section error (but already cloned, already posted a workflow run, polluting the history).

**Fix:** first step of the job validates `$GITHUB_REF_NAME` strips to strict `[0-9]+\.[0-9]+\.[0-9]+`. If not, exit 0 with a clear log message ("skipping non-semver tag"). Mirror to template.

### B-4: `marketplace.json` rewrite not atomic

**Source:** Copilot on PR #3.

`merge-pr.md` Step 2b ends with `printf '%s\n' "$NEW" > "$MP"`. If `jq` failed, `$NEW` is empty, and the redirection truncates `marketplace.json` to zero bytes before `printf` writes anything. Same issue in Step 2c (`plugin.json`).

**Fix:** write jq output to a tempfile, only `mv` on success:

```bash
if NEW=$(jq ... "$MP"); then
  printf '%s\n' "$NEW" > "${MP}.new" && mv "${MP}.new" "$MP"
else
  echo "ERROR: jq failed to transform $MP; file unchanged" >&2
  exit 1
fi
```

Cover both marketplace.json and plugin.json rewrites.

### B-5: `template-sync.yml` paths filter vs "every PR" promise

**Source:** Copilot on PR #4.

The workflow has `on.pull_request.paths` limiting when it runs, but `AGENTS.md` / spec say it "runs on every PR". If configured as a required status check, GitHub treats skipped workflow runs ambiguously — can block merges (no check reported) or let them through silently.

**Fix:** drop the `paths:` filter. Let the workflow run on every PR. The internal completeness check already handles "no drift" cheaply (<1s). Mirror to template. Keep AGENTS.md wording aligned.

### B-6: `merge-pr.md` `--dry-run` wording absolute

**Source:** Copilot on PR #4.

The flag description says "before any write, git operation, or network call", but Step 0a runs local git commands (`git describe`, `git status`). Accurate contract: "before any write, git mutation, git-remote operation, or network call; local read-only git commands may run during preflight".

**Fix:** tighten the flag docstring in Flags and the dry-run guard header.

## User Scenarios (one per bug)

### Scenario 1: run-spec uses filename-derived slug (B-1) (P0)

1. **Given** a spec at `specs/user-auth.spec.md` with only Date + Review Level in Meta,
   **When** `/ai-driver:run-spec specs/user-auth.spec.md` runs,
   **Then** it uses `user-auth` as the slug everywhere (`logs/user-auth/`, branch `feat/user-auth`, PR body links the spec path) and never references `Meta.ID` or `Meta.Branch`.

### Scenario 2: Flutter CI works out of the box (B-2) (P0)

1. **Given** a Flutter project (containing `pubspec.yaml`) that ran `/ai-driver:init --with-ci`,
   **When** a PR triggers CI,
   **Then** the workflow installs Flutter via `subosito/flutter-action@v2` before running `dart analyze` / `flutter test`, and both steps succeed on a minimal valid Flutter project.

### Scenario 3: auto-release skips pre-release tags (B-3) (P0)

1. **Given** a tag `v0.3.5-beta.1` is pushed,
   **When** `auto-release.yml` fires,
   **Then** the first step detects non-semver, exits 0 with log `"Skipping non-semver tag v0.3.5-beta.1"`, and no GitHub Release is attempted.

2. **Given** a tag `v0.3.5` is pushed,
   **When** the workflow fires,
   **Then** it proceeds as before.

### Scenario 4: merge-pr manifest writes are atomic (B-4) (P0)

1. **Given** a `.claude-plugin/marketplace.json` that produces a `jq` failure (e.g., corrupted during edit),
   **When** merge-pr Step 2b runs,
   **Then** the original file is **unchanged** (not truncated), and the command aborts with a clear error.

### Scenario 5: template-sync runs on every PR (B-5) (P0)

1. **Given** a PR that touches only `README.md`,
   **When** pushed,
   **Then** the Template Sync workflow fires (no `paths:` filter anymore) and passes instantly because no PAIRS differ. The GitHub check "Template Sync" is present on the PR and required-status-check setups see a resolved result.

### Scenario 6: merge-pr `--dry-run` wording accurate (B-6) (P1)

1. **Given** a reader opens `merge-pr.md`,
   **When** they read the `--dry-run` flag description,
   **Then** they see "before any write, git mutation, git-remote operation, or network call; local read-only git commands may run during preflight" — which matches the actual behavior.

## Acceptance Criteria

- [ ] AC-001 (B-1): `grep -c 'Meta.ID\|Meta.Branch\|<spec-id>' plugins/ai-driver/commands/run-spec.md == 0`
- [ ] AC-002 (B-1): `grep -c '<spec-slug>\|spec-slug' plugins/ai-driver/commands/run-spec.md >= 2` (slug concept introduced and used)
- [ ] AC-003 (B-2): `grep -q 'subosito/flutter-action' plugins/ai-driver/templates/.github/workflows/ci.yml`
- [ ] AC-004 (B-2): same in repo-root `.github/workflows/ci.yml`
- [ ] AC-005 (B-3): semver guard AND proper step gating. `grep -Fq 'is_semver=true' .github/workflows/auto-release.yml` AND `grep -Fq "if: steps.semver.outputs.is_semver == 'true'" .github/workflows/auto-release.yml` — verify the check AND that subsequent steps are actually gated by it (earlier design with `exit 0` inside a run step did not skip following steps). Same in template copy.
- [ ] AC-006 (B-4): `grep -A3 'jq.*marketplace.json' plugins/ai-driver/commands/merge-pr.md | grep -q '\\.new'` (tempfile pattern present)
- [ ] AC-007 (B-5): `! grep -q '^\\s\\+paths:' .github/workflows/template-sync.yml` and same for template copy (paths filter removed)
- [ ] AC-008 (B-6): `grep -q 'local read-only git commands may run' plugins/ai-driver/commands/merge-pr.md`
- [ ] AC-009: CHANGELOG `[Unreleased]` populated with all six fixes
- [ ] AC-010: Template sync CI passes on this PR (no drift)

## Constraints

### MUST

- MUST-001: No new commands, no new features. Only fixes to existing files.
- MUST-002: Every fix preserves the previous behavior for the successful path (e.g., `merge-pr.md` atomic write still ends with an updated manifest on success).
- MUST-003: Template pairs stay byte-identical (template-sync will enforce this too).

### MUST NOT

- MUSTNOT-001: Do not rewrite the whole `run-spec.md` — targeted substitutions only (the rest of the logic is still correct).
- MUSTNOT-002: Do not change the set of files copied by `/ai-driver:init`.

### SHOULD

- SHOULD-001: Mention in the PR body that this is "the first PR reviewed by the v0.3.4 comment-aware review-pr". The review itself should cross-validate against any residual Copilot / Codex comments from earlier PRs that mention these same fixes.

## References

- PR #1 Copilot suppressed-low-confidence comments (run-spec Meta refs).
- PR #1 Copilot inline comment (CI Flutter not installed).
- PR #2 Copilot inline comment (tag glob pre-release).
- PR #3 Copilot inline comment (printf > "$MP" not atomic).
- PR #4 Copilot inline comments (paths filter + dry-run wording).

## Needs Clarification

None.
