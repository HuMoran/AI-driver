# AI-Driver

Language-agnostic AI-driven development framework. Humans write specs, AI does the rest.

语言无关的 AI 驱动开发框架。人写 spec，AI 做其余的事。

## Quick Start / 快速开始

### Prerequisites / 前置条件

- [Claude Code](https://claude.ai/code) installed and logged in / 已安装并登录
- [Codex CLI](https://github.com/openai/codex) installed / 已安装：`npm install -g @openai/codex`
- [GitHub CLI](https://cli.github.com/) installed / 已安装：`gh auth login`

### Install / 安装

```bash
# 1. Clone the template / 克隆模板
git clone https://github.com/HuMoran/AI-driver.git my-project
cd my-project

# 2. Install Codex CLI (if not installed) / 安装 Codex CLI（如未安装）
npm install -g @openai/codex
codex login

# 3. Verify environment / 验证环境
codex --version    # Codex CLI available / Codex CLI 可用
gh auth status     # GitHub CLI logged in / GitHub CLI 已登录
```

Slash commands (`/run-spec`, `/review-pr`, etc.) are included in `.claude/commands/`.
Open Claude Code and they're ready to use. No extra plugins needed.

Slash commands 已包含在 `.claude/commands/` 中，打开 Claude Code 即可使用，无需额外安装。

### Usage / 使用

```bash
# 1. Write a spec / 写 spec
cp specs/_template.spec.md specs/p01_my-feature.spec.md
# Edit the spec file... / 编辑 spec 文件...

# 2. Execute spec (in Claude Code) / 执行 spec（在 Claude Code 中）
/run-spec specs/p01_my-feature.spec.md
# AI auto: plan → code → test → PR
# AI 自动：设计计划 → 写代码 → 跑测试 → 提 PR

# 3. Review PR / 审查 PR
/review-pr
# Claude + Codex dual-blind review, report written to GitHub PR comment
# Claude + Codex 双盲审查，报告写入 GitHub PR 评论

# 4. Auto-release after merge / 合并后自动发布
# GitHub Actions auto: tag + release + changelog
# GitHub Actions 自动：tag + release + changelog

# 5. Found a bug? File an issue with ai-fix label / 发现 bug？写 issue 加 ai-fix 标签
/fix-issues
# AI reads issue → root cause analysis → fix → PR
# AI 读 issue → 分析根因 → 修复 → 提 PR
```

## Commands / 命令一览

| Command / 命令 | Purpose / 作用 | Input / 输入 | Output / 输出 |
|------|------|------|------|
| `/run-spec <file>` | Execute spec end-to-end / 执行 spec 全流程 | spec file path / spec 文件路径 | PR + logs / PR + 实现日志 |
| `/review-pr [number]` | Dual-blind PR review / 双盲审查 PR | PR number (optional) / PR 号（可选） | GitHub PR comment / GitHub PR 评论 |
| `/fix-issues` | Batch-fix issues / 批量修复 issue | --label, --limit | One PR per issue / 每个 issue 一个 PR |
| `/run-tests` | Run test suite / 运行测试 | --type | Test report / 测试报告 |
| `/deploy <env>` | Deploy / 部署 | staging/production | Deploy report / 部署报告 |

## Project Structure / 项目结构

```
.claude/commands/   — Slash commands (core workflow / 核心工作流)
.claude/rules/      — Language rules (Rust/Python/TS/Go/Flutter / 语言规范)
.github/workflows/  — GitHub Actions (auto-release + CI)
.codex/             — Codex project config / Codex 项目级配置
specs/              — Spec files (human-written requirements / 人写的需求)
deploy/             — Deploy documents (build/deploy config / 构建部署配置)
logs/               — AI implementation logs / AI 实现日志
constitution.md     — Project constitution (rules AI must follow / AI 必须遵守的规则)
CLAUDE.md           — AI context / AI 上下文
```

## Workflow / 工作流

```
Human writes spec → /run-spec → AI plan+code+test → PR
人写 spec                                           ↓
                /review-pr → Claude+Codex review → merge
                                                    ↓
                       GitHub Actions → tag + release
                                                    ↓
                Human tests → issue → /fix-issues → PR → ...
                人工测试
```

## Standards / 规范遵从

- [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) — Changelog / 更新日志
- [Semantic Versioning](https://semver.org/) — Version numbers / 版本号
- [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) — Git commit messages / Git 提交信息
- [OpenAPI 3.0](https://swagger.io/specification/) — API design (when applicable) / API 设计（如涉及）

## Design References / 设计依据

Built on research from / 基于以下项目和实践的研究：
- [GitHub Spec-Kit](https://github.github.com/spec-kit/) — Spec-driven development toolkit / 规范驱动开发工具
- [Pimzino spec-workflow](https://github.com/Pimzino/claude-code-spec-workflow) — Claude Code spec workflow
- [Superpowers](https://github.com/obra/superpowers) — AI engineering discipline plugin / AI 工程纪律插件
- [codex-plugin-cc](https://github.com/openai/codex-plugin-cc) — Codex adversarial review / Codex 对抗性审查

## License

MIT
