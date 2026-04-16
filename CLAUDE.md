# AI-Driver

## What Is This
Language-agnostic AI-driven development framework. Humans write specs, AI does the rest.

## Workflow
1. Human writes specs/pxx_xxx.spec.md
2. /run-spec → AI plan + implement + test → PR
3. /review-pr → Claude + Codex dual-blind review
4. merge → auto tag + release
5. Optional: /deploy staging|production
6. Human tests → files GitHub Issue (label: ai-fix)
7. /fix-issues → AI reads issue → fix → PR

## Key Files
- constitution.md — project constitution, AI must read before every operation
- specs/_template.spec.md — spec template
- specs/ — all spec files
- deploy/ — deploy documents (build/deploy/rollback config)
- logs/ — AI implementation logs
- .claude/commands/ — slash commands
- .claude/rules/ — language-specific rules
- CHANGELOG.md — changelog

## Rules
- Read constitution.md before any implementation
- Do not modify constitution.md (unless human explicitly requests)
- Do not expand spec scope
- One atomic commit per task
- Commit messages follow Conventional Commits
- PR body must reference the spec file path
