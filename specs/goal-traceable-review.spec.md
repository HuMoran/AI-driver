# goal-traceable-review.spec.md

## Meta

- Date: 2026-04-23
- Review Level: A

## Goal

让 `/ai-driver:run-spec` Phase 0 的 Layer 1 / Layer 2 审查器每条 actionable finding 都必须能追溯到 Goal 的失败路径；无法追溯的自动降级为 `[observation:*]`，不进入 Verdict。阻止审查器在 `[spec:ac-executable]` 和 `[spec:ambiguity]` 两个无底 anchor 上做 refinement 自递归（BSD vs GNU sed、shallow-clone fetch、trailing whitespace 这类 implementation-layer robustness 问题反推给 spec），把审查真正聚焦在"spec 能否交付 Goal"。

## User Scenarios

### Scenario 1: 无底 anchor 上的刁钻 finding 被降级 (Priority: P1)

**As a** spec 作者, **I want** 审查器不再因为"AC 的 sed 在 macOS BSD 下可能不兼容"或"措辞可以更精确"这类离 Goal 两三层远的问题 gate 我的 spec, **so that** 我能在合理轮次内通过 Phase 0 去实施。

**Acceptance Scenarios:**

1. **Given** 一份 Goal 清晰、AC 完整的 spec，且某 AC 用了 GNU-sed 专属 flag，**When** 跑 `/ai-driver:run-spec`，**Then** 审查器将"BSD 兼容性"类 finding 输出为 `[observation:*]`（因为不影响 Goal 交付），不计入 Verdict。
2. **Given** 同一 `(rule_id, normalized_location)` 在上一轮的 review log 中已存在 **且** 已被 spec 作者显式标记为 `resolved` 或 `acknowledged`（写在 review log 的 `## Resolutions` 小节），**When** 第二轮审查重复提出同 key 的新精细化版本，**Then** Gating 将其识别为 refinement-loop 并降级到 Observations。未经显式标记的重复 finding 仍视为合理未解决，保留 actionable 严重度。

**Independent Test Method:** 对一份含故意 BSD-only sed 的 fixture spec 手动跑 Layer 1/2 prompt，比较规则启用前后的 finding 列表。

### Edge Cases

- 若一条 finding 确实会让 Goal 失败（例如 AC 缺失整个 Scenario 的覆盖），它仍应 actionable——Goal-traceability 约束不放水真正的 Goal-critical 问题。
- `[spec:goal]` / `[spec:scope]` / `[spec:must-coverage]` / `[spec:contradiction]` / `[spec:over-specification]` 五个 Goal-proximal anchor 不受新降级规则影响，它们本身就约束 Goal 覆盖。

## Acceptance Criteria

- [ ] AC-001: Layer 1 prompt（`plugins/ai-driver/commands/run-spec.md` 第 107-139 行附近的 literal block）含 Goal-traceability 强制条款。执行 `grep -c 'which Scenario / .* fails to deliver' plugins/ai-driver/commands/run-spec.md` 输出 `≥ 1`。
- [ ] AC-002: Layer 2 prompt（同文件 170-205 行附近）含等价条款。执行 `bash -c 'awk "/^### Layer 2 prompt/,/^### Write review log/" plugins/ai-driver/commands/run-spec.md | grep -c "which Scenario / .* fails to deliver"'` 输出 `≥ 1`。
- [ ] AC-003: Gating 段（同文件 215 行附近）描述 refinement-loop detection 规则。执行 `grep -c 'refinement' plugins/ai-driver/commands/run-spec.md` 输出 `≥ 1`。
- [ ] AC-004: `CHANGELOG.md` `[Unreleased]` 区段含 `### Changed` 条目说明本次 prompt 变更。执行 `bash -c 'awk "/^## \[Unreleased\]/{f=1;next} f&&/^## \[/{f=0} f" CHANGELOG.md | grep -q "Goal-traceab\\|refinement loop\\|Goal-trace"'` 退出 0。
- [ ] AC-005: 既有审查合成回归 `tests/review-synthesis/drift-demotion.sh` 仍通过。执行 `bash tests/review-synthesis/drift-demotion.sh`，退出码 0。

## Constraints

### MUST

- MUST-001: 仅修改 `plugins/ai-driver/commands/run-spec.md`、`CHANGELOG.md`、本 spec 与其 logs 目录。
- MUST-002: Layer 1 与 Layer 2 prompt 的 Goal-traceability 条款文字必须**镜像一致**（双盲对称），仅替换必要的 subagent/Codex 专有措辞。
- MUST-003: 保留现有七条 focus anchor 列表不删；新规则仅**降级**未追溯 Goal 的 finding，不阻止审查器提出它们为 observation。

### MUST NOT

- MUSTNOT-001: 不修改 `review-pr.md` / `merge-pr.md` / `fix-issues.md`；plan-review prompt 的同类修复留给后续 PR。
- MUSTNOT-002: 不改 Layer 0 机械规则表（75-81 行）；本 PR 只调整 Layer 1/2 语义 gate。

### SHOULD

- SHOULD-001: commit message 形如 `feat(run-spec): require Goal traceability for review findings`，单个 conventional commit。

## Implementation Guide [optional]

Layer 1/2 prompt 的 Goal-traceability 追加段落（双盲对称、纳入两个 prompt literal 内）建议这样写：

> **Goal-traceability requirement.** Every actionable finding MUST answer: "If this is not fixed, which Scenario / Acceptance Criterion fails to deliver the stated Goal?" If the answer is "Goal still achieved, just less portable / less precise / less robust in some environments" — emit as `[observation:<tag>]`, not as actionable. `[spec:ac-executable]` and `[spec:ambiguity]` anchors are reserved for defects that break Goal delivery; robustness tightening is the implementer's concern, not the spec's.

Gating 段 refinement-loop detection：Consensus 前加一步。**术语定义**（写入 run-spec.md 或本 spec 的 Implementation Guide）：
- `normalized_location` = 绝对文件路径 + 向上最近 `^##` 或 `^###` header（去除行号，空格压缩）。两个 finding 指向同一 H2/H3 section 视为同 location。
- `previous round` = 同一 `logs/<spec-slug>/` 目录下，文件名按 lexicographic 排序的倒数第二个 `spec-review*.md`。初版 run 没有 previous round，本规则不触发。
- `resolved`/`acknowledged` = 上一轮 review log 中 `## Resolutions` 小节下，以 `- <rule_id> @ <normalized_location>: resolved|acknowledged — <理由>` 行形式由 spec 作者显式书写。

降级触发：本轮 actionable finding 的 `(rule_id, normalized_location)` 在上一轮 review log 中存在 **且** 在上一轮 `## Resolutions` 被标记 `resolved` 或 `acknowledged`。两个条件都满足才降级；仅重复但未被显式标记的，保留原严重度。

## References

- `plugins/ai-driver/commands/run-spec.md:107-215` — Layer 1/2 prompt + Gating 待修 anchors
- `tests/review-synthesis/drift-demotion.sh` — 既有审查合成回归
- 本次对话轨迹（2026-04-23，6 轮 STOP 的教训）
