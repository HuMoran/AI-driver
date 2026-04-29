---
Goal: 在每次 codex 子进程启动前，主流程显式向 stderr 输出一行可见的配置摘要，让用户在 dual-blind 审查 / plan review / spec review 过程中立刻识别实际生效的模型，避免用户级 `~/.codex/config.toml` 漂移导致 dual-blind 审查质量静默下降。
Review Level: A
Source: GitHub issue #21 (https://github.com/HuMoran/AI-driver/issues/21)
---

## Goal

在三处 `codex exec` 调用之前各加 2 行 bash：

```bash
RESOLVED_MODEL=$(awk -F'[ "=]+' '/^model[[:space:]]*=/{print $2; exit}' ~/.codex/config.toml 2>/dev/null || echo '<codex-cli-default>')
echo "[ai-driver] Codex pass: model=$RESOLVED_MODEL reasoning_effort=high cwd=$(pwd)" >&2
```

输出写到 stderr，避免污染 codex 的 stdout 收集流。

## Context

> Issue #21 from @HuMoran @ 2026-04-29 (human, is_bot=false):
> #19 已移除 `codex exec --model gpt-5.4` 硬编码，让 codex CLI 自身的默认模型生效。
> 但用户对"实际运行时用了什么模型 / reasoning_effort"失去了直接可见性 ——
> 如果用户的 `~/.codex/config.toml` 默认漂到一个低成本/低能力模型，
> dual-blind 审查质量会静默下降。

**根因 (R-004)**：

- codex CLI 自身的 banner（`model: ...` / `reasoning effort: ...` / `workdir: ...`）写到 stderr。
- 三处调用都通过 `Bash(run_in_background=true)` + `2> "$out.err"` 把 stderr 重定向到 staging tempdir。
- 主会话的 tool output 看不到 banner，所以模型可见性丢了。
- 解决方案：在 codex 启动前，主会话自己 echo 一行到 stderr —— 因为 `Bash(run_in_background=true)` 的 wrapper 是 ai-driver 自己写的 bash 块，echo 输出会进入 background task 的 stdout/stderr 通道，主 agent 的 BashOutput 读取该流时即可看到。但更直接的做法是，在主会话 dispatch 之前，于"foreground 准备阶段"echo（即 markdown 中提供的"shell form 用于审计"snippet 移到主 agent 真正执行的部分），见 §scope。

**实际实现策略**（重要）：

回看现有 markdown，三处 codex 调用所在的 ` ```bash ` 块都标注了 `# Shell form shown for audit; main agent uses the Bash tool with run_in_background=true`。即 markdown 内的 bash 块本身是"主 agent 应执行的内容"的伪代码 / 审计形式。本变更采取的做法是：

1. 在每个 bash 块顶部加 `RESOLVED_MODEL=...; echo ... >&2` 两行
2. 主 agent 在调用 Bash 工具时，会把整个块作为单条命令传入；echo 在 codex exec **之前**先执行，结果对主会话 stdout 直接可见（`>&2` 落到 stderr，但 Bash 工具的 task notification 同时回传 stdout/stderr）

**三处 call site**：

- `plugins/ai-driver/commands/run-spec.md:159` (Phase 0 Layer 2 spec review)
- `plugins/ai-driver/commands/run-spec.md:354` (Plan review Pass 2)
- `plugins/ai-driver/commands/review-pr.md:255` (PR review Pass 2)

**模板同步**：`commands/*` 不在 `template-sync.yml` PAIRS 中，无需镜像。

**正交 skill**：与 `codex:gpt-5-4-prompting` 等 Claude 侧 prompting 指南无关。

## User Scenarios

GIVEN 用户的 `~/.codex/config.toml` 含 `model = "gpt-5.5"`
WHEN  运行 `/ai-driver:run-spec` 或 `/ai-driver:review-pr`
THEN  在 codex 子进程启动前，主会话的输出流可见一行
      `[ai-driver] Codex pass: model=gpt-5.5 reasoning_effort=high cwd=/Users/.../project`

GIVEN 用户没有 `~/.codex/config.toml`，或文件中无 `model =` 行
WHEN  运行 codex 调用
THEN  显示 `[ai-driver] Codex pass: model=<codex-cli-default> reasoning_effort=high cwd=...`

GIVEN 用户希望 codex 启动前阻塞确认（issue #21 中提到的 `AI_DRIVER_REQUIRE_CONFIRM=1`）
WHEN  设置该 env 变量
THEN  **不在本 spec 范围**：`Bash(run_in_background=true)` 的 wrapper 不能交互 `read`，
      要做需要重新设计 codex 调度流程（main 会话先 echo + 显式询问 → 用户回 y → 再后台 dispatch），
      属于 P5 不允许的"附带改动"。如需要，开 follow-up issue。

## Acceptance Criteria

AC1: `[ "$(grep -c '\[ai-driver\] Codex pass:' plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-pr.md | awk -F: '{s+=$2} END {print s}')" = "3" ]`
     —— 三处 codex 调用对应的 echo 行总数为 3

AC2: 每处 echo 都在对应 codex exec 行之前 5 行内
     `awk '/\[ai-driver\] Codex pass:/{seen=NR} /codex exec /{ if(seen && NR-seen<=5) hits++; seen=0 } END {exit (hits==3?0:1)}' plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-pr.md`

AC3: `! grep -rn -- '--model gpt-5\.4' plugins/ai-driver/commands/`
     —— 不回退 #19 的修复

AC4: `[ "$(grep -c 'codex exec' plugins/ai-driver/commands/review-pr.md plugins/ai-driver/commands/run-spec.md | awk -F: '{s+=$2} END {print s}')" = "4" ]`
     —— `codex exec` 文本仍 4 次（3 沙盒 + 1 prose 示例），证明只增不删

AC5: 每处新增 echo 都通过 `>&2` 导到 stderr
     `[ "$(grep -c 'echo "\[ai-driver\] Codex pass:.*>&2$' plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-pr.md | awk -F: '{s+=$2} END {print s}')" = "3" ]`

AC6: `RESOLVED_MODEL=$(awk` 解析行也对应出现 3 次
     `[ "$(grep -c '^[[:space:]]*RESOLVED_MODEL=' plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-pr.md | awk -F: '{s+=$2} END {print s}')" = "3" ]`

## Constraints (from constitution.md)

- **P5 最小变更**：仅在三处 `codex exec` 之前各加 2 行（RESOLVED_MODEL + echo），不动 codex 命令本身、不动 prompt、不动 fence
- **R-005 原子提交**：单一 `feat(commands): print codex config before each pass (#21)`
- **R-006 提交前格式化**：保持 markdown 缩进/换行，不重排
- **R-003 范围管理**：`AI_DRIVER_REQUIRE_CONFIRM` 阻塞模式 out-of-scope；如需要另开 issue
