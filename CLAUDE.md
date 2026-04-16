# AI-Driver

Language-agnostic AI-driven development framework. Humans write specs, AI does the rest.

## IMPORTANT: Read constitution.md before any operation

The constitution defines all principles (P1-P6) and operational rules (R-001 to R-007) that govern AI behavior in this project. Obey every rule. Halt and report on any violation.

## Workflow
1. Human writes specs/pxx_xxx.spec.md
2. /run-spec → AI plan + implement + test → PR
3. /review-pr → Claude + Codex dual-blind review
4. merge → auto tag + release
5. Optional: /deploy staging|production
6. Human tests → files GitHub Issue (label: ai-fix)
7. /fix-issues → AI reads issue → fix → PR

## Key Files
- constitution.md — project constitution, rules AI must follow
- specs/_template.spec.md — spec template (EN), .zh-CN.md for Chinese
- deploy/_template.deploy.md — deploy template (EN), .zh-CN.md for Chinese
- .claude/commands/ — slash commands
- .claude/rules/ — language-specific rules (format/lint/test/build per language)
- logs/ — AI implementation logs

## Rules
- Do not modify constitution.md (unless human explicitly requests)
- Do not expand spec scope
- One atomic commit per task
- Commit messages follow Conventional Commits
- PR body must reference the spec file path
