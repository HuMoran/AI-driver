# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

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

### Added

- `/ai-driver:init` — scaffold AI-driver files into the current project. Merge-safe by default (does not overwrite existing files); `--force` backs up and overwrites. Supports `--with-ci`, `--with-deploy`, `--with-codex`, `--lang`.
- `.claude-plugin/marketplace.json` — marketplace catalog.
- `plugins/ai-driver/.claude-plugin/plugin.json` — plugin manifest.
- `plugins/ai-driver/templates/` — files copied into user projects by `/ai-driver:init`: constitution, AGENTS.md, CLAUDE.md stub, spec templates, deploy templates, CI workflows, Codex config.
- `docs/research/2026-04-17-plugin-interface.md` — research-confirmed interface contract for marketplace / plugin.json / CLAUDE.md import semantics. All v0.2 design decisions are grounded here.

### Unchanged

- Spec format (`specs/<name>.spec.md`, Given/When/Then acceptance criteria).
- `constitution.md` principles and operational rules.
- `deploy/<project>.deploy.md` format.
- GitHub Actions workflows.

### Migration from v0.1

1. Install the plugin (see above).
2. Run `/ai-driver:init` in your existing project. Existing files are preserved.
3. Update any custom scripts that called `/run-spec` etc. to use the `ai-driver:` namespace.

Existing `specs/*.spec.md` files continue to work as-is.

## [Unreleased 0.1 (pre-plugin)]

### Added
- AI-driver framework initial structure
- Spec template with Given-When-Then acceptance criteria
- Constitution with principles and operational rules
- Slash commands: /run-spec, /review-pr, /fix-issues, /run-tests, /deploy
- Language rules: Rust, Python, TypeScript, Go, Flutter
- GitHub Actions: auto-release, CI
