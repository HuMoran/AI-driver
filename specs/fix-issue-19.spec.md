---
Goal: 移除 codex 调用中硬编码的 `--model gpt-5.4`，让 codex CLI 自身的默认模型生效，使框架能随 codex 升级自动跟进最新模型，无需修改本仓库。
Review Level: A
Source: GitHub issue #19 (https://github.com/HuMoran/AI-driver/issues/19)
---

## Goal

让 codex CLI 自身的默认模型生效，使框架能随 codex 升级自动跟进最新模型，无需修改本仓库。具体修改两类位置：

1. `plugins/ai-driver/commands/` 下三处 `codex exec --model gpt-5.4`：移除 `--model gpt-5.4` flag
2. `.codex/config.toml`（repo 根 + 模板镜像）：整文件删除（同时从 `template-sync.yml` PAIRS 中摘除该 pair）

## Context

> Comment from @HuMoran (issue body) @ 2026-04-29 (human author, is_bot=false):
> commands里面，用codex做对抗性审查时，把模型写死的 gpt-5.4，
> 这会导致当gpt升级后，默认没有调用最新模型

**根因分析 (R-004)**：模型版本被 pin 在两个层级：

| 位置 | 内容 | 影响 |
|------|------|------|
| `plugins/ai-driver/commands/run-spec.md:159` | `--model gpt-5.4` | Phase 0 Layer 2 spec review |
| `plugins/ai-driver/commands/run-spec.md:354` | `--model gpt-5.4` | Plan review Pass 2 |
| `plugins/ai-driver/commands/review-pr.md:255` | `--model gpt-5.4` | Pass 2 adversarial diff review |
| `.codex/config.toml:4` | `model = "gpt-5.4"` | 项目级 config，对从 template 初始化的新用户可能仍然 pin 模型 |
| `plugins/ai-driver/templates/.codex/config.toml:4` | `model = "gpt-5.4"` | 上面的镜像（被 `template-sync.yml` PAIRS 强制 byte-identical） |

**仅删 commands flag 不够**：codex CLI 的配置解析链中，项目级 `.codex/config.toml` 可能在用户级 `~/.codex/config.toml` 之前/之后被读取（codex 文档不明确，且 `codex exec --help` 仅提到用户级）。即便本机实证（maintainer 的 `~/.codex/config.toml` pin 了 gpt-5.5，banner 显示 `model: gpt-5.5`）说明用户级生效，**对于从模板初始化的新用户（无 `~/.codex/config.toml` 或其中无 `model =` 行），项目级配置仍可能把他们 pin 在 gpt-5.4** —— 完全违背 issue 原意。

**为何整文件删除而非仅删 `model` 行**：

- `model` 是问题
- `model_reasoning_effort = "high"` 在三处 `codex exec` 调用中已通过 `-c model_reasoning_effort="high"` 显式传入，项目级 config 中冗余
- 文件中没有其他 key
- 删除整文件比"删一行保留一行"更干净，行为不变

**模板同步影响**：删除两侧 `.codex/config.toml` 后，`.github/workflows/template-sync.yml` 的 PAIRS 列表中 `.codex/config.toml:plugins/ai-driver/templates/.codex/config.toml` 这一行也必须摘除，否则 CI 会报"file missing"。同时 `plugins/ai-driver/templates/.github/workflows/template-sync.yml` 是该文件的镜像，也要同步修改。

**正交 skill**：`codex:gpt-5-4-prompting` 是 Claude 侧的 prompting 指南，与 codex 子进程的模型选择正交，不受本变更影响。

## User Scenarios

GIVEN 用户已升级 codex CLI（其默认模型从 gpt-5.4 升到下一代）
WHEN  在本仓库运行 `/ai-driver:run-spec` 或 `/ai-driver:review-pr`
THEN  Codex 子进程必须使用 codex CLI 当前默认模型，而非 `gpt-5.4`

GIVEN 一个新用户从模板初始化项目，且 `~/.codex/config.toml` 不存在或不包含 `model =` 行
WHEN  其在新项目中运行 `/ai-driver:run-spec`
THEN  Codex 子进程不应被项目级 `.codex/config.toml` pin 到 `gpt-5.4`，应使用 codex CLI 内置默认

GIVEN 用户希望临时锁定到某个模型
WHEN  在 `~/.codex/config.toml` 设置 `model = "..."` 或调用方注入 `-c model="..."`
THEN  本仓库不再硬编码覆盖，用户层面配置生效

## Acceptance Criteria

AC1: `! grep -rn -- '--model gpt-5\.4' plugins/ai-driver/commands/`
     —— 三处 commands 硬编码已全部移除

AC2: `[ "$(grep -c 'codex exec' plugins/ai-driver/commands/review-pr.md plugins/ai-driver/commands/run-spec.md | awk -F: '{s+=$2} END {print s}')" = "4" ]`
     —— `codex exec` 文本出现次数仍为 4（3 处沙盒调用 + run-spec.md:380 prose 示例）

AC3: `grep -n 'model_reasoning_effort=\"high\"' plugins/ai-driver/commands/review-pr.md plugins/ai-driver/commands/run-spec.md | wc -l | tr -d ' '` 输出 `3`
     —— 周边 `--config model_reasoning_effort="high"` 全部保留

AC4: `! grep -rn 'gpt-5\.4' plugins/ai-driver/commands/`
     —— commands/ 下不再出现 `gpt-5.4` 字面量

AC5: `[ ! -e .codex/config.toml ] && [ ! -e plugins/ai-driver/templates/.codex/config.toml ]`
     —— 两侧 `.codex/config.toml` 已删除（项目级 model pin 不再存在）

AC6: `! grep -n '\.codex/config\.toml' .github/workflows/template-sync.yml plugins/ai-driver/templates/.github/workflows/template-sync.yml`
     —— PAIRS 中 `.codex` 条目已摘除（避免 template-sync CI 抱怨 missing）

AC7: `diff -q .github/workflows/template-sync.yml plugins/ai-driver/templates/.github/workflows/template-sync.yml`
     —— template-sync.yml 自身的两侧仍 byte-identical（PAIRS 改动两侧同步）

## Constraints (from constitution.md)

- **P5 最小变更**：commands 三处仅删 `--model gpt-5.4` flag；`.codex/config.toml` 整文件删除（保留 `model_reasoning_effort` 没有意义，已通过 `-c` flag 传递）
- **R-005 原子提交**：本次扩展为单一 `fix(commands+config): ...` 跟进 PR review；首次提交保留原样作为审查痕迹
- **R-006 提交前格式化**：Markdown / YAML 保持现有缩进/换行
- **R-003 范围管理**：扩展受 PR review consensus 驱动（Pass 1 + Codex Pass 2 + Copilot 三源），不算"顺手清理"
