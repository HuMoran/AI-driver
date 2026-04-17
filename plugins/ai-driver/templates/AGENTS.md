# AI-Driver

Language-agnostic AI-driven development framework. Humans write specs, AI does the rest.

## IMPORTANT: Read constitution.md before any operation

The constitution defines all principles (P1-P6) and operational rules (R-001 to R-007) that govern AI behavior in this project. Obey every rule. Halt and report on any violation.

## Workflow
1. Human writes `specs/<name>.spec.md` (template at `specs/_template.spec.md`)
2. `/ai-driver:run-spec <spec-path>` — AI plan + implement + test → PR
3. `/ai-driver:review-pr` — Claude + Codex dual-blind review
4. merge → auto tag + release (via `.github/workflows/auto-release.yml`)
5. Optional: `/ai-driver:deploy staging|production` (requires `deploy/<project>.deploy.md`)
6. Human tests → files GitHub Issue (label: `ai-fix`)
7. `/ai-driver:fix-issues` — AI reads issue → fix → PR

## Key Files
- `constitution.md` — project constitution, rules AI must follow
- `specs/_template.spec.md` — spec template (EN), `.zh-CN.md` for Chinese
- `specs/<name>.spec.md` — actual specs (you write these)
- `deploy/_template.deploy.md` — deploy doc template, `.zh-CN.md` for Chinese
- `deploy/<project>.deploy.md` — actual deploy docs (optional)
- `.github/workflows/` — auto-release + CI

## Plugin-provided resources
- Commands: `/ai-driver:run-spec`, `/ai-driver:review-pr`, `/ai-driver:fix-issues`, `/ai-driver:run-tests`, `/ai-driver:deploy`
- Language rules: inside the plugin at `${CLAUDE_PLUGIN_ROOT}/rules/<lang>.md`
  Covers Rust / Python / TypeScript / Go / Flutter format/lint/test/build commands

## Rules
- Do not modify `constitution.md` unless human explicitly requests
- Do not expand spec scope
- One atomic commit per task
- Commit messages follow Conventional Commits
- PR body must reference the spec file path
