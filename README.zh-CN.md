# AI-Driver

语言无关的 AI 驱动开发框架。人写 spec，AI 做其余的事。

[English](README.md)

## 快速开始

### 前置条件

- [Claude Code](https://claude.ai/code) ≥ 2.1 已安装并登录
- [Codex CLI](https://github.com/openai/codex) 已安装：`npm install -g @openai/codex`
- [GitHub CLI](https://cli.github.com/) 已安装：`gh auth login`
- `jq`（`/ai-driver:init` 合并设置时用到）

### 作为 Claude Code 插件安装

```shell
# 在 Claude Code 里
/plugin marketplace add HuMoran/AI-driver
/plugin install ai-driver@ai-driver
```

然后在你要用 AI-driver 驱动的项目里：

```shell
/ai-driver:init --with-ci --with-deploy --with-codex
```

这会把 `constitution.md`、`AGENTS.md`、`specs/_template.spec.md`、CI workflows 和部署模板铺到你的项目里。`CLAUDE.md` 会被创建（若已存在则把 `@AGENTS.md` **前置**到文件顶部，让后面的 Claude 专属说明能覆盖导入）。**已存在的文件不会被覆盖**，除非带 `--force`。

### 使用

```bash
# 1. 写 spec
cp specs/_template.spec.md specs/my-feature.spec.md
# 编辑 spec 文件...

# 2. 执行 spec（在 Claude Code 中）
/ai-driver:run-spec specs/my-feature.spec.md
# AI 自动：设计计划 → 写代码 → 跑测试 → 提 PR

# 3. 审查 PR
/ai-driver:review-pr
# Claude + Codex 双盲审查，报告写入 GitHub PR 评论

# 4. 合并后自动发布
# GitHub Actions 自动：tag + release + changelog

# 5. 发现 bug？写 issue 加 ai-fix 标签
/ai-driver:fix-issues
# AI 读 issue → 分析根因 → 修复 → 提 PR
```

## 命令一览

| 命令                            | 作用                                     |
| ------------------------------- | ---------------------------------------- |
| `/ai-driver:init`               | 把 AI-driver 文件铺到当前项目            |
| `/ai-driver:run-spec <文件>`    | 端到端执行 spec：**Phase 0 spec 审查** → 规划 → 实现 → 测试 → 提 PR |
| `/ai-driver:review-spec <文件>` | 独立三层 spec 审查（机械 grep + Claude + Codex）；在切分支前迭代草稿 spec |
| `/ai-driver:review-pr [编号]`   | Claude + Codex 双盲 PR 审查；读取全部已有 review/评论（含 Copilot） |
| `/ai-driver:merge-pr [编号]`    | 合并 PR、更新 CHANGELOG、打 tag、触发发版 |
| `/ai-driver:doctor`             | 只读健康检查 —— 探测漂移和误配置        |
| `/ai-driver:fix-issues`         | 批量修复带 `ai-fix` 标签的 GitHub issue；读取完整 issue 线程含 bot 诊断 |
| `/ai-driver:deploy <环境>`      | 按 `deploy/<project>.deploy.md` 执行部署 |

完整命令定义见 [`plugins/ai-driver/commands/`](plugins/ai-driver/commands)。

### 每个命令推荐的模型与思考深度

AI-driver 命令**不**在 frontmatter 里写死 `model` / `effort`，你自己控制。调用前按需切换：

| 命令                     | 建议会话设置                                       |
| ------------------------ | -------------------------------------------------- |
| `/ai-driver:run-spec`    | Opus + `xhigh` effort（多步规划 + TDD + 任务编排） |
| `/ai-driver:review-spec` | Opus + `xhigh` effort（对抗性读 spec）             |
| `/ai-driver:review-pr`   | Opus + `xhigh` effort（对抗性深读 diff）           |
| `/ai-driver:merge-pr`    | Sonnet 或会话默认（确定性流程：改 CHANGELOG、合并、打 tag） |
| `/ai-driver:doctor`      | Haiku 或会话默认（纯只读：文件对比 + diff）         |
| `/ai-driver:fix-issues`  | Opus + `xhigh` effort（根因分析）                  |
| `/ai-driver:deploy`      | Sonnet 或会话默认（按部署文档走步骤）              |
| `/ai-driver:init`        | 会话默认（文件复制 + jq 合并）                     |

在 Claude Code 会话里临时切换：

```shell
/model <latest-opus>         # 切本次会话的模型（当前有效 ID 用 /model 命令查看）
/effort xhigh                # 切思考深度
```

或在项目根 `.claude/settings.json` 里持久化 —— 用你 Claude Code 版本里 `/model` 列出的实际 ID，例如：

```json
{
  "model": "claude-opus-4-7",
  "effort": "xhigh"
}
```

想省成本可以用 Sonnet + `xhigh`，三个重命令也能跑；追求最好结果用 Opus。

## 项目结构（使用 AI-driver 的项目）

跑完 `/ai-driver:init` 后，你的项目长这样：

```markdown
constitution.md     — 项目规则（P1-P6、R-001 到 R-007）
AGENTS.md           — AI 工作流（被 CLAUDE.md 导入，任何 AI 工具都能读）
CLAUDE.md           — 一行 @AGENTS.md 导入（+ 可选的 Claude 专属说明）
specs/              — 你的 spec 文件
deploy/             — 可选的部署文档
.github/workflows/  — 可选的 CI + auto-release
.codex/             — 可选的 Codex 配置
.claude/settings.json — 团队共享的 marketplace + enabled-plugins 配置
```

命令和语言规则都在装好的插件里，不在你的项目里。

## 工作流

```txt
人写 spec → /ai-driver:run-spec
                  ↓
   Phase 0: spec 审查（Layer 0 grep + subagent + Codex，无条件）   ← 第 1/3 道门
                  ↓
   Phase 1: plan 审查（subagent + Codex，仅当 Review Level ≥ B）   ← 第 2/3 道门（可选）
                  ↓
             AI 编码 + 测试 → PR
                  ↓
             /ai-driver:review-pr                                  ← 第 3/3 道门
             （subagent Pass 1 + Codex Pass 2 + 已有 reviewer）
                  ↓
             /ai-driver:merge-pr → GitHub Actions → tag + release
                  ↓
        人工测试 → issue → /ai-driver:fix-issues → PR → ...
```

三门流水线（v0.3.6+，v0.3.8 统一双 LLM）在最便宜的阶段夹断缺陷：spec 在 plan 之前、plan 在 code 之前、code 在 merge 之前。**v0.3.8 起三道门形态一致：**

- **第 1 道门**（spec 审查）：Layer 0 机械 grep + **Claude subagent**（沙箱化，`Read, Grep, Glob` 三件套，path-based 交付）+ Codex 外部 `codex exec -s read-only`。双共识（`rule_id + normalized location` 匹配）升一级严重度。**无条件**执行。
- **第 2 道门**（run-spec 里的 plan 审查）：同构 — **subagent + Codex 双 LLM** — 但 **仅当 Review Level ≥ B 才跑**。
- **第 3 道门**（PR 审查）：**stage-then-read**（untrusted PR 产物通过 `gh ... > "$STAGE/..."` 拉到 `mktemp -d` 临时目录，stdout 和 stderr 都重定向，主会话**不吃原始字节**）+ subagent Pass 1 + Codex Pass 2 + 已有 reviewer 三方共识。

Claude 审查跑在**沙箱化 subagent** 里（v0.3.8+）：不可信内容从不进主会话 prompt。Codex 调用走 Claude Code 的 `Bash(run_in_background=true)` — 完成通知下一轮自动送达，无需轮询，不会悄悄漏审。

独立的 `/ai-driver:review-spec` 让你在切分支前先对草稿 spec 做预检 — 与第 1 道门同一套 Layer 0 + subagent + Codex。

## 规范遵从

- [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) — 更新日志
- [Semantic Versioning](https://semver.org/lang/zh-CN/) — 版本号
- [Conventional Commits](https://www.conventionalcommits.org/zh-hans/v1.0.0/) — Git 提交信息
- [OpenAPI 3.0](https://swagger.io/specification/) — API 设计（如涉及）

## 设计依据

基于以下项目和实践的研究：

- [GitHub Spec-Kit](https://github.github.com/spec-kit/) — 规范驱动开发工具
- [OpenSpec](https://github.com/Fission-AI/OpenSpec) — SDD 模式和变更生命周期思路
- [Superpowers](https://github.com/obra/superpowers) — AI 工程纪律插件
- [codex-plugin-cc](https://github.com/openai/codex-plugin-cc) — Codex 对抗性审查

## v0.3 发版流程变更

合并到 `main` 不再自动触发 release，改为 **push tag 触发**。用 `/ai-driver:merge-pr`（会改写 `CHANGELOG.md` 的 `[Unreleased]` → `[X.Y.Z]`、合并、打 tag、push），或者手工做：

```bash
# 手动先改写 CHANGELOG.md，然后：
git tag vX.Y.Z <merge-commit-sha>
git push origin vX.Y.Z
```

GitHub Release 正文逐字节取自 `CHANGELOG.md` 的 `## [X.Y.Z]` 段 —— 所以 CHANGELOG 要写准。

## 从 v0.1 升级

原来的 `git clone` 方式已废弃。升级已有的 AI-driver 项目：

1. 装插件（`/plugin marketplace add HuMoran/AI-driver` + `/plugin install ai-driver@ai-driver`）
2. 在原项目里跑 `/ai-driver:init`（合并安全，已有文件不会被破坏）
3. 脚本里的 `/run-spec` 等改为 `/ai-driver:run-spec` 等

Spec 格式没变 —— 你原来的 `specs/*.spec.md` 继续可用。

## 许可证

MIT
