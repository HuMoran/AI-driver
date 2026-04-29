---
Goal: 移除 codex 调用中硬编码的 `--model gpt-5.4`，让 codex CLI 自身的默认模型生效，使框架能随 codex 升级自动跟进最新模型，无需修改本仓库。
Review Level: A
Source: GitHub issue #19 (https://github.com/HuMoran/AI-driver/issues/19)
---

## Goal

移除 `plugins/ai-driver/commands/` 下三处 `codex exec --model gpt-5.4` 中的 `--model gpt-5.4` 硬编码，使 Codex 子进程沿用 codex CLI 自身默认模型（由 `~/.codex/config.toml` 或 codex 内置默认决定）。

## Context

> Comment from @HuMoran (issue body) @ 2026-04-29 (human author, is_bot=false):
> commands里面，用codex做对抗性审查时，把模型写死的 gpt-5.4，
> 这会导致当gpt升级后，默认没有调用最新模型

**根因分析 (R-004)**：

三处 `codex exec --model gpt-5.4` 硬编码：

| 文件 | 行号 | 用途 |
|------|------|------|
| `plugins/ai-driver/commands/run-spec.md` | 159 | Phase 0 Layer 2 spec review |
| `plugins/ai-driver/commands/run-spec.md` | 354 | Plan review Pass 2 |
| `plugins/ai-driver/commands/review-pr.md` | 255 | Pass 2 adversarial diff review |

`codex exec --help` 验证：`-m, --model <MODEL>` 不传时，由 `~/.codex/config.toml` 决定，等同于"跟随 codex CLI 自身的默认值"。因此移除该 flag 即可让升级自动生效。

**模板镜像影响**：`.github/workflows/template-sync.yml` 的 PAIRS 列表不含 `plugins/ai-driver/commands/*`（只覆盖 `.github/`、`.codex/`、constitution.md、CLAUDE.md、specs/_template.*）。无需同步到 templates。

**正交 skill**：`codex:gpt-5-4-prompting` 是 Claude 侧的 prompting 指南，与 codex 子进程的模型选择正交，不受本变更影响。

## User Scenarios

GIVEN 用户已升级 codex CLI（其默认模型从 gpt-5.4 升到下一代）
WHEN  在本仓库运行 `/ai-driver:run-spec` 或 `/ai-driver:review-pr`
THEN  Codex 子进程必须使用 codex CLI 当前默认模型，而非 `gpt-5.4`

GIVEN 用户希望临时锁定到某个模型
WHEN  在 `~/.codex/config.toml` 设置 `model = "..."` 或调用方注入 `-c model="..."`
THEN  本仓库不再硬编码覆盖，用户层面配置生效

## Acceptance Criteria

AC1: `! grep -rn -- '--model gpt-5\.4' plugins/ai-driver/commands/`
     —— 三处硬编码已全部移除（grep 退出码非 0 即通过）

AC2: `[ "$(grep -c 'codex exec' plugins/ai-driver/commands/review-pr.md plugins/ai-driver/commands/run-spec.md | awk -F: '{s+=$2} END {print s}')" = "4" ]`
     —— `codex exec` 文本出现次数仍为 4（3 处沙盒调用 + run-spec.md:380 prose 示例；仅去掉 `--model` flag，不增删行）

AC3: `grep -n 'model_reasoning_effort=\"high\"' plugins/ai-driver/commands/review-pr.md plugins/ai-driver/commands/run-spec.md | wc -l | tr -d ' '` 输出 `3`
     —— 周边 `--config model_reasoning_effort="high"` 全部保留（P5 最小变更）

AC4: `! grep -rn 'gpt-5\.4' plugins/ai-driver/commands/`
     —— commands/ 下不再出现 `gpt-5.4` 字面量（兜底校验）

## Constraints (from constitution.md)

- **P5 最小变更**：仅删除 `--model gpt-5.4` token，不调整周边参数（`--config model_reasoning_effort="high"`、`-s read-only` 等保留）
- **R-005 原子提交**：单一 `fix(commands): ...` 提交完成全部三处
- **R-006 提交前格式化**：Markdown 保持现有缩进/换行，不重排
- **R-003 不扩展范围**：不顺手清理其他无关文档
