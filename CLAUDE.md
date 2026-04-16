# AI-Driver

## 这是什么
语言无关的 AI 驱动开发框架。人写 spec，AI 做其余的事。

## 工作流
1. 人写 specs/pxx_xxx.spec.md
2. /run-spec → AI plan + implement + test → PR
3. /review-pr → Claude + Codex 双盲审查
4. merge → auto tag + release
5. 可选: /deploy staging|production
6. 人测试 → 写 GitHub Issue（加 ai-fix 标签）
7. /fix-issues → AI 读 issue → 修复 → PR

## 关键文件
- constitution.md — 项目宪法，AI 每次操作前必读
- specs/_template.spec.md — spec 模板
- specs/ — 所有 spec 文件
- logs/ — AI 实现日志
- .claude/commands/ — slash commands
- .claude/rules/ — 语言特定规范
- CHANGELOG.md — 变更日志

## 规则
- 实施前必须读 constitution.md
- 不得修改 constitution.md（除非人明确要求）
- 不得扩大 spec 范围
- 每个 commit 对应一个原子任务
- commit message 遵从 Conventional Commits
- PR body 必须引用 spec 文件路径
