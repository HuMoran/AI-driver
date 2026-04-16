# AI-Driver

语言无关的 AI 驱动开发框架。人写 spec，AI 做其余的事。

## 快速开始

### 前置条件

- [Claude Code](https://claude.ai/code) 已安装并登录
- [Codex CLI](https://github.com/openai/codex) 已安装: `npm install -g @openai/codex`
- [GitHub CLI](https://cli.github.com/) 已安装: `gh auth login`

### 安装

```bash
# 1. Clone 模板
git clone https://github.com/HuMoran/AI-driver.git my-project
cd my-project

# 2. 安装 Codex CLI（如未安装）
npm install -g @openai/codex
codex login

# 3. 验证环境
codex --version    # Codex CLI 可用
gh auth status     # GitHub CLI 已登录
```

Slash commands (`/run-spec`, `/review-pr` 等) 已包含在 `.claude/commands/` 中，
打开 Claude Code 即可使用，无需额外安装。

### 使用

```bash
# 1. 写 spec
cp specs/_template.spec.md specs/p01_my-feature.spec.md
# 编辑 spec 文件...

# 2. 执行 spec（在 Claude Code 中）
/run-spec specs/p01_my-feature.spec.md
# AI 自动: 设计计划 → 写代码 → 跑测试 → 提 PR

# 3. 审查 PR
/review-pr
# Claude + Codex 双盲审查，报告写入 GitHub PR 评论

# 4. 合并后自动发布
# GitHub Actions 自动: tag + release + changelog

# 5. 发现 bug？写 issue，加 ai-fix 标签
/fix-issues
# AI 读 issue → 分析根因 → 修复 → 提 PR
```

## 命令一览

| 命令 | 作用 | 输入 | 输出 |
|------|------|------|------|
| `/run-spec <file>` | 执行 spec 全流程 | spec 文件路径 | PR + 实现日志 |
| `/review-pr [number]` | 双盲审查 PR | PR 号（可选） | GitHub PR 评论 |
| `/fix-issues` | 批量修复 issue | --label, --limit | 每个 issue 一个 PR |
| `/run-tests` | 运行测试 | --type | 测试报告 |
| `/deploy <env>` | 部署 | staging/production | 部署报告 |

## 项目结构

```
.claude/commands/   — Claude Code slash commands（核心工作流）
.claude/rules/      — 语言特定规范（Rust/Python/TS/Go/Flutter）
.github/workflows/  — GitHub Actions（auto-release + CI）
.codex/             — Codex 项目级配置
specs/              — Spec 文件（人写的需求）
deploy/             — 部署文档（人写的构建/部署配置）
logs/               — AI 实现日志（计划、任务、记录）
constitution.md     — 项目宪法（AI 必须遵守的规则）
CLAUDE.md           — AI 上下文
```

## 工作流

```
人写 spec → /run-spec → AI plan+code+test → PR
                                              ↓
              /review-pr → Claude+Codex 审查 → merge
                                              ↓
                     GitHub Actions → tag + release
                                              ↓
              人测试 → issue → /fix-issues → PR → ...
```

## 规范遵从

- [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) — 更新日志
- [Semantic Versioning](https://semver.org/lang/zh-CN/) — 版本号
- [Conventional Commits](https://www.conventionalcommits.org/zh-hans/v1.0.0/) — Git 提交信息
- [OpenAPI 3.0](https://swagger.io/specification/) — API 设计（如涉及）

## 设计依据

基于以下项目和实践的研究:
- [GitHub Spec-Kit](https://github.github.com/spec-kit/) — 规范驱动开发工具
- [Pimzino spec-workflow](https://github.com/Pimzino/claude-code-spec-workflow) — Claude Code spec 工作流
- [Superpowers](https://github.com/obra/superpowers) — AI 工程纪律插件
- [codex-plugin-cc](https://github.com/openai/codex-plugin-cc) — Codex 对抗性审查

## License

MIT
