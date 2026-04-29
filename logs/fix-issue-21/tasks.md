# Tasks — fix-issue-21

## T1: RED — 验证当前状态命中 0 处 echo

- Run: `grep -c '\[ai-driver\] Codex pass:' plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-pr.md`
- Expected: 0:0 三处文件均 0
- Maps to: AC1 (initial RED)

## T2: GREEN — 在 plugins/ai-driver/commands/run-spec.md:159 之前插入 RESOLVED_MODEL + echo

- Edit: 在 `codex exec --config model_reasoning_effort="high" -s read-only "$CODEX_SPEC_REVIEW_PROMPT"` 行之前的 bash 行（pipe 之后）插入 2 行
- Maps to: AC1, AC5, AC6

## T3: GREEN — 在 plugins/ai-driver/commands/run-spec.md:354 之前插入

- Edit: 在 Plan review Pass 2 的 codex exec 之前
- Maps to: AC1, AC5, AC6

## T4: GREEN — 在 plugins/ai-driver/commands/review-pr.md:255 之前插入

- Edit: 在 Pass 2 adversarial review 的 codex exec 之前
- Maps to: AC1, AC5, AC6

## T5: 验收 — 运行 AC1..AC6

- 全部必须 PASS
- 特别注意 AC2 的上下文校验（echo 在对应 codex exec 5 行内）

## T6: 提交 + PR

- `git add specs/fix-issue-21.spec.md plugins/ai-driver/commands/{run-spec.md,review-pr.md} logs/fix-issue-21/ CHANGELOG.md`
- Commit: `feat(commands): print codex config before each pass (#21)`
- Push + `gh pr create`
