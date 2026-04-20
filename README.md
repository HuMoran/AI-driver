# AI-Driver

Language-agnostic AI-driven development framework. Humans write specs, AI does the rest.

[中文文档](README.zh-CN.md)

## Quick Start

### Prerequisites

- [Claude Code](https://claude.ai/code) ≥ 2.1 installed and logged in
- [Codex CLI](https://github.com/openai/codex) installed: `npm install -g @openai/codex`
- [GitHub CLI](https://cli.github.com/) installed: `gh auth login`
- `jq` (used by `/ai-driver:init` to merge settings)

### Install as a Claude Code plugin

```shell
# In Claude Code
/plugin marketplace add HuMoran/AI-driver
/plugin install ai-driver@ai-driver
```

Then, in the project you want to drive with AI-driver:

```shell
/ai-driver:init --with-ci --with-deploy --with-codex
```

This copies `constitution.md`, `AGENTS.md`, `specs/_template.spec.md`, CI workflows, and deploy templates into your project. `CLAUDE.md` is created (or `@AGENTS.md` is **prepended** if it already exists, so Claude-specific notes after the import can override it). Existing files are never overwritten without `--force`.

### Usage

```bash
# 1. Write a spec
cp specs/_template.spec.md specs/my-feature.spec.md
# Edit the spec file...

# 2. Execute spec (in Claude Code)
/ai-driver:run-spec specs/my-feature.spec.md
# AI auto: plan → code → test → PR

# 3. Review PR
/ai-driver:review-pr
# Claude + Codex dual-blind review, report written to the GitHub PR comment

# 4. Auto-release after merge
# GitHub Actions auto: tag + release + changelog

# 5. Found a bug? File an issue with the ai-fix label
/ai-driver:fix-issues
# AI reads issue → root cause analysis → fix → PR
```

## Commands

| Command                         | Purpose                                                   |
| ------------------------------- | --------------------------------------------------------- |
| `/ai-driver:init`               | Scaffold AI-driver files into the current project         |
| `/ai-driver:run-spec <file>`    | Execute a spec end-to-end: plan, implement, test, PR      |
| `/ai-driver:review-pr [number]` | Dual-blind PR review (Claude + Codex)                     |
| `/ai-driver:merge-pr [number]`  | Merge PR, update CHANGELOG, tag, trigger release          |
| `/ai-driver:doctor`             | Read-only health check — detects drift and misconfiguration |
| `/ai-driver:fix-issues`         | Batch-fix GitHub issues labeled `ai-fix`                  |
| `/ai-driver:run-tests`          | Detect and run the project test suite                     |
| `/ai-driver:deploy <env>`       | Execute the deploy flow from `deploy/<project>.deploy.md` |

See [`plugins/ai-driver/commands/`](plugins/ai-driver/commands) for the full command definitions.

### Recommended model and effort per command

AI-driver commands do **not** hard-code a model or effort level — you stay in control. Pick before invoking:

| Command                 | Suggested session setting                                       |
| ----------------------- | --------------------------------------------------------------- |
| `/ai-driver:run-spec`   | Opus + `xhigh` effort (multi-step planning, TDD, orchestration) |
| `/ai-driver:review-pr`  | Opus + `xhigh` effort (adversarial deep-read of the diff)       |
| `/ai-driver:merge-pr`   | Sonnet or session default (deterministic: rewrite CHANGELOG, merge, tag) |
| `/ai-driver:doctor`     | Haiku or session default (pure read-only — file checks + diff) |
| `/ai-driver:fix-issues` | Opus + `xhigh` effort (root cause analysis)                     |
| `/ai-driver:run-tests`  | Haiku or session default (executes commands, parses output)     |
| `/ai-driver:deploy`     | Sonnet or session default (follows the deploy doc step-by-step) |
| `/ai-driver:init`       | Session default (file copy + jq merge)                          |

Set per-session in Claude Code:

```shell
/model <latest-opus>         # switch model for this session (see /model for current IDs)
/effort xhigh                # switch reasoning depth
```

Or persistently in `.claude/settings.json` (under the project root) — use the exact model ID your Claude Code version advertises via `/model`, e.g.:

```json
{
  "model": "claude-opus-4-7",
  "effort": "xhigh"
}
```

Sonnet + `xhigh` works for all three heavy commands if you want lower cost; Opus is recommended for the best verdicts and deepest planning.

## Project Structure (a project using AI-driver)

After running `/ai-driver:init`, your project contains:

```markdown
constitution.md     — project rules (P1-P6, R-001 to R-007)
AGENTS.md           — workflow for any AI coding tool (imported by CLAUDE.md)
CLAUDE.md           — one-line @AGENTS.md import (+ any Claude-specific notes)
specs/              — your spec files
deploy/             — optional deploy docs
.github/workflows/  — optional CI + auto-release
.codex/             — optional Codex config
.claude/settings.json  — marketplace + enabled-plugins config for the team
```

Commands and language rules live inside the installed plugin, not in your project.

## Workflow

```txt
Human writes spec → /ai-driver:run-spec → AI plan+code+test → PR
                                                              ↓
              /ai-driver:review-pr → Claude+Codex review → merge
                                                              ↓
                           GitHub Actions → tag + release
                                                              ↓
       Human tests → issue → /ai-driver:fix-issues → PR → ...
```

## Standards

- [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) — Changelog
- [Semantic Versioning](https://semver.org/) — Version numbers
- [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) — Git commit messages
- [OpenAPI 3.0](https://swagger.io/specification/) — API design (when applicable)

## Design References

Built on research from:

- [GitHub Spec-Kit](https://github.github.com/spec-kit/) — Spec-driven development toolkit
- [OpenSpec](https://github.com/Fission-AI/OpenSpec) — SDD patterns and change lifecycle concepts
- [Superpowers](https://github.com/obra/superpowers) — AI engineering discipline plugin
- [codex-plugin-cc](https://github.com/openai/codex-plugin-cc) — Codex adversarial review

## Release flow changed in v0.3

Merges to `main` no longer auto-release. Pushing a tag does. Use `/ai-driver:merge-pr` (which rewrites `CHANGELOG.md`'s `[Unreleased]` → `[X.Y.Z]`, merges, tags, pushes), or do it by hand:

```bash
# Rewrite CHANGELOG.md manually, then:
git tag vX.Y.Z <merge-commit-sha>
git push origin vX.Y.Z
```

The GitHub Release body is extracted byte-for-byte from the matching `## [X.Y.Z]` section of `CHANGELOG.md` — keep that section honest.

## Upgrade from v0.1

The previous `git clone` flow is gone. To upgrade an existing AI-driver-style project:

1. Install the plugin (`/plugin marketplace add HuMoran/AI-driver` + `/plugin install ai-driver@ai-driver`).
2. Run `/ai-driver:init` in your existing project (merge-safe; existing files are preserved).
3. Update any custom scripts that invoked `/run-spec` → `/ai-driver:run-spec`.

Spec format is unchanged — existing `specs/*.spec.md` files continue to work as-is.

## License

MIT
