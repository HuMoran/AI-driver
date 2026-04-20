# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.3.4] - 2026-04-20

### Changed

- `/ai-driver:review-pr` now reads the **entire existing conversation** on the PR — reviews, inline line comments, and issue-style comments — before running Claude Pass 1 and Codex Pass 2. Existing findings from Copilot, human reviewers, and other bots are passed to both AI passes as context. The final report has a dedicated **Existing reviewer findings** table, an **Also flagged by** column for AI findings that match what an existing reviewer already said, and a **Prior-finding resolution** table when a previous `<!-- ai-driver-review -->` comment exists on the PR. This closes the silent loss of Copilot / human findings observed across v0.2 and v0.3 PRs.
- Triple-consensus logic: an issue flagged by 2+ independent sources (Claude, Codex, existing reviewer) is upgraded a severity notch; flagged by all 3 → CRITICAL regardless of individual ratings.
- Every posted `review-pr` body now starts with an `<!-- ai-driver-review -->` HTML-comment marker so subsequent runs can self-identify and avoid meta-recursion.
- `/ai-driver:fix-issues` Mode B now reads the full issue thread (not just title + body) via `gh api /issues/<n>/comments --paginate`. Generated specs cite specific thread excerpts with `> Comment from <author> @ <date>:` format. Bot-posted structured diagnostics (stack traces, Sentry fingerprints, Dependabot advisories) are preserved verbatim and tagged by bot login so human prose and machine data are never conflated.
- `/ai-driver:fix-issues` Mode A now refuses to trust a bot-authored spec comment by default; override with `--trust-bot-spec @<login>`. Same security rationale as the trust-boundary preamble in `/ai-driver:merge-pr` — machine-generated spec content should not implicitly drive destructive actions.

## [0.3.3] - 2026-04-20

### Added

- `/ai-driver:doctor` — read-only health check for a project using AI-driver. Detects: missing `constitution.md` / `AGENTS.md`, `CLAUDE.md` not importing `@AGENTS.md` (or import in wrong position), drift of `constitution.md` from the latest plugin template, legacy v0.1 filename patterns (`specs/pNN_*.spec.md`), missing or malformed `.claude/settings.json` entries, plugin version skew, and invalid `.claude-plugin/*.json` for plugin-publishing projects. Every finding prints an exact copy-paste fix command. Never modifies any file, never calls the network. Frontmatter `allowed-tools` excludes all write / network operations as a hard guardrail.

## [0.3.2] - 2026-04-20

### Added

- `.github/workflows/template-sync.yml` enforces that every file shipped as a plugin template (workflows, `.codex/config.toml`, spec/deploy templates) stays byte-identical with its repo-root counterpart. Any PR that edits only one side of a pair fails with a `cp` command to fix it. Caught 2 pre-existing drifts (deploy templates) on first run.

### Fixed

- `/ai-driver:merge-pr --dry-run` now makes **zero network calls**. Previously Step 0 ran `gh pr view / checks / list` before the dry-run guard, so `--dry-run` failed offline or in sandboxes. Step 0 is now split into `0a: Local preflight` (files + git-local only) and `0b: Network preflight` (mergeability + CI checks); `--dry-run` exits cleanly between them. PR resolution is deferred to 0b when a number is not supplied on the command line — dry-run prints `<unresolved — would resolve via gh pr list at real-run time>`. Closes the Codex round-2 PARTIAL on v0.3.0 PR #2.

## [0.3.1] - 2026-04-17

### Fixed

- `/ai-driver:merge-pr` Step 2 now also bumps the `version` fields in `.claude-plugin/marketplace.json` (`metadata.version` and matching `plugins[].version`) and `.claude-plugin/plugin.json` (only if already present) as part of the same `chore(release): vX.Y.Z` commit. Closes the v0.3.0 gap where `claude plugin update` could not detect a new release because `marketplace.json` was still at the previous version. Non-plugin projects are unaffected (no-op when `.claude-plugin/` is absent).
- Step 0 preflight now validates `marketplace.json` and `plugin.json` are valid JSON when present, so a corrupt manifest aborts before any write.

## [0.3.0] - 2026-04-17

### Added

- `/ai-driver:merge-pr` — ship command that rewrites `CHANGELOG.md` (`[Unreleased]` → `[X.Y.Z]`), commits, merges the PR, tags `main`, and pushes the tag. Supports `--version X.Y.Z`, `--bump major|minor|patch`, `--no-release`, `--squash`, `--no-check`, and `--dry-run`. See `plugins/ai-driver/commands/merge-pr.md`.

### Changed (BREAKING)

- `auto-release.yml` now triggers on `push.tags: ['v*.*.*']` instead of `push.branches: [main]`. GitHub Release notes are extracted byte-for-byte from the matching `## [X.Y.Z]` section of `CHANGELOG.md`, not grepped from commit messages. Fixes the v0.2.0 drift where Release notes dropped BREAKING / Migration / Changed sections. Existing consumers who push to `main` expecting an auto-release must switch to pushing a tag (which is what `/ai-driver:merge-pr` does for you).
- `plugins/ai-driver/templates/.github/workflows/auto-release.yml` updated to match.

### Migration from v0.2.x

1. Keep a populated `## [Unreleased]` section in your `CHANGELOG.md` while work is in flight.
2. Instead of merging a PR through the GitHub UI and waiting for the main-triggered workflow, run `/ai-driver:merge-pr <PR>` from Claude Code.
3. If you prefer the old "push to main → auto-version-from-commits" behavior, pin the v0.2.x template or write your own `auto-release.yml`.

## [0.2.0] - 2026-04-17

### Changed (BREAKING)

- **Distribution**: shipped as a Claude Code plugin via marketplace. The `git clone` install flow is removed.
  - Install: `/plugin marketplace add HuMoran/AI-driver` then `/plugin install ai-driver@ai-driver`.
- **Command namespace**: all slash commands are now prefixed with `ai-driver:`.
  - `/run-spec` → `/ai-driver:run-spec`
  - `/review-pr` → `/ai-driver:review-pr`
  - `/fix-issues` → `/ai-driver:fix-issues`
  - `/run-tests` → `/ai-driver:run-tests`
  - `/deploy` → `/ai-driver:deploy`
- **Language rules location**: `.claude/rules/` is no longer in user projects. Rules live inside the installed plugin at `${CLAUDE_PLUGIN_ROOT}/rules/`.
- **Memory**: `CLAUDE.md` now imports `AGENTS.md` via `@AGENTS.md`. This follows the Claude Code convention (Claude Code reads `CLAUDE.md`, not `AGENTS.md`).
- **Spec Meta block simplified** — removed `ID`, `Status`, `Branch` (redundant with filename/git state). Kept `Date` and `Review Level`. File name now matches the slug directly (e.g., `specs/user-auth.spec.md`, no more `p01_` prefix).

### Added

- `/ai-driver:init` — scaffold AI-driver files into the current project. Merge-safe by default (does not overwrite existing files); `--force` backs up and overwrites. Supports `--with-ci`, `--with-deploy`, `--with-codex`, `--lang`.
- `.claude-plugin/marketplace.json` — marketplace catalog.
- `plugins/ai-driver/.claude-plugin/plugin.json` — plugin manifest.
- `plugins/ai-driver/templates/` — files copied into user projects by `/ai-driver:init`: constitution, AGENTS.md, CLAUDE.md stub, spec templates, deploy templates, CI workflows, Codex config.
- `docs/research/2026-04-17-plugin-interface.md` — research-confirmed interface contract for marketplace / plugin.json / CLAUDE.md import semantics. All v0.2 design decisions are grounded here.

### Unchanged

- Given/When/Then acceptance criteria format.
- `constitution.md` principles and operational rules.
- `deploy/<project>.deploy.md` format.
- GitHub Actions workflows.

### Migration from v0.1

1. Install the plugin (see above).
2. Run `/ai-driver:init` in your existing project. Existing files are preserved.
3. Update any custom scripts that called `/run-spec` etc. to use the `ai-driver:` namespace.
4. Optional: for old `specs/p01_foo.spec.md` files, rename to `specs/foo.spec.md` and trim the Meta block (the `ID` / `Status` / `Branch` lines can be deleted; keep `Date` and `Review Level`). Existing files still parse if left alone.

## [0.1.0] - 2026-04-16 (pre-plugin)

### Added

- AI-driver framework initial structure (distributed via `git clone`)
- Spec template with Given-When-Then acceptance criteria
- Constitution with principles and operational rules
- Slash commands: `/run-spec`, `/review-pr`, `/fix-issues`, `/run-tests`, `/deploy`
- Language rules: Rust, Python, TypeScript, Go, Flutter
- GitHub Actions: auto-release, CI
