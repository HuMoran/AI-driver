# Tasks — fix-issue-19

## T1: RED — 验证当前状态命中 3 处硬编码

- Run: `grep -rn -- '--model gpt-5\.4' plugins/ai-driver/commands/`
- Expected: 3 hits (review-pr.md:255, run-spec.md:159, run-spec.md:354)
- Maps to: AC1 (initial RED state)

## T2: GREEN — 删除 plugins/ai-driver/commands/run-spec.md:159 的 `--model gpt-5.4 `

- Edit: 仅删除 `--model gpt-5.4 ` 这串（含尾部空格），其余保留
- Maps to: AC1, AC2, AC3 partial

## T3: GREEN — 删除 plugins/ai-driver/commands/run-spec.md:354 的 `--model gpt-5.4 `

- Edit: 同上模式
- Maps to: AC1, AC2, AC3 partial

## T4: GREEN — 删除 plugins/ai-driver/commands/review-pr.md:255 的 `--model gpt-5.4 `

- Edit: 同上模式
- Maps to: AC1, AC2, AC3 partial

## T5: 验收 — 运行 AC1..AC4

- AC1: `! grep -rn -- '--model gpt-5\.4' plugins/ai-driver/commands/`
- AC2: `codex exec` 出现 3 次
- AC3: `model_reasoning_effort` 保留 3 次
- AC4: `gpt-5.4` 字面量在 commands/ 下不再出现
- Maps to: 全部 AC

## T6: 提交 + PR

- `git add specs/fix-issue-19.spec.md plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-pr.md logs/fix-issue-19/`
- Commit: `fix(commands): drop hardcoded --model gpt-5.4 from codex calls (#19)`
- Push + `gh pr create`
