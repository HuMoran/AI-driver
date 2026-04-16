# AI-Driver

Language-agnostic AI-driven development framework. Humans write specs, AI does the rest.

[中文文档](README.zh-CN.md)

## Quick Start

### Prerequisites

- [Claude Code](https://claude.ai/code) installed and logged in
- [Codex CLI](https://github.com/openai/codex) installed: `npm install -g @openai/codex`
- [GitHub CLI](https://cli.github.com/) installed: `gh auth login`

### Install

```bash
# 1. Clone the template
git clone https://github.com/HuMoran/AI-driver.git my-project
cd my-project

# 2. Install Codex CLI (if not installed)
npm install -g @openai/codex
codex login

# 3. Verify environment
codex --version    # Codex CLI available
gh auth status     # GitHub CLI logged in
```

Slash commands (`/run-spec`, `/review-pr`, etc.) are included in `.claude/commands/`.
Open Claude Code and they're ready to use. No extra plugins needed.

### Usage

```bash
# 1. Write a spec
cp specs/_template.spec.md specs/p01_my-feature.spec.md
# Edit the spec file...

# 2. Execute spec (in Claude Code)
/run-spec specs/p01_my-feature.spec.md
# AI auto: plan → code → test → PR

# 3. Review PR
/review-pr
# Claude + Codex dual-blind review, report written to GitHub PR comment

# 4. Auto-release after merge
# GitHub Actions auto: tag + release + changelog

# 5. Found a bug? File an issue with ai-fix label
/fix-issues
# AI reads issue → root cause analysis → fix → PR
```

## Commands

| Command | Purpose | Input | Output |
|---------|---------|-------|--------|
| `/run-spec <file>` | Execute spec end-to-end | spec file path | PR + logs |
| `/review-pr [number]` | Dual-blind PR review | PR number (optional) | GitHub PR comment |
| `/fix-issues` | Batch-fix issues | --label, --limit | One PR per issue |
| `/run-tests` | Run test suite | --type | Test report |
| `/deploy <env>` | Deploy | staging/production | Deploy report |

## Project Structure

```
.claude/commands/   — Slash commands (core workflow)
.claude/rules/      — Language-specific rules (Rust/Python/TS/Go/Flutter)
.github/workflows/  — GitHub Actions (auto-release + CI)
.codex/             — Codex project config
specs/              — Spec files (human-written requirements)
deploy/             — Deploy documents (build/deploy/rollback config)
logs/               — AI implementation logs
constitution.md     — Project constitution (rules AI must follow)
CLAUDE.md           — AI context
```

## Workflow

```
Human writes spec → /run-spec → AI plan+code+test → PR
                                                      ↓
                    /review-pr → Claude+Codex review → merge
                                                      ↓
                           GitHub Actions → tag + release
                                                      ↓
                    Human tests → issue → /fix-issues → PR → ...
```

## Standards

- [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) — Changelog
- [Semantic Versioning](https://semver.org/) — Version numbers
- [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) — Git commit messages
- [OpenAPI 3.0](https://swagger.io/specification/) — API design (when applicable)

## Design References

Built on research from:
- [GitHub Spec-Kit](https://github.github.com/spec-kit/) — Spec-driven development toolkit
- [Pimzino spec-workflow](https://github.com/Pimzino/claude-code-spec-workflow) — Claude Code spec workflow
- [Superpowers](https://github.com/obra/superpowers) — AI engineering discipline plugin
- [codex-plugin-cc](https://github.com/openai/codex-plugin-cc) — Codex adversarial review

## License

MIT
