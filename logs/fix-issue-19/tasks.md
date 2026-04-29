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
- AC2: `codex exec` 出现 4 次（3 沙盒调用 + run-spec.md:380 prose 示例）
- AC3: `model_reasoning_effort` 保留 3 次
- AC4: `gpt-5.4` 字面量在 commands/ 下不再出现
- Maps to: AC1..AC4

## T6: 提交 + PR

- `git add specs/fix-issue-19.spec.md plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-pr.md logs/fix-issue-19/`
- Commit: `fix(commands): drop hardcoded --model gpt-5.4 from codex calls (#19)`
- Push + `gh pr create`

## T7: 跟进 PR review — 删除 .codex/config.toml（双侧）+ 摘除 PAIRS

PR review 三源（Claude Pass 1 + Codex Pass 2 + Copilot ×4）共识：项目级 `.codex/config.toml` 仍 pin `model = "gpt-5.4"`，对从模板初始化的新用户可能违背 issue #19 Goal。扩展修复范围。

- `git rm .codex/config.toml plugins/ai-driver/templates/.codex/config.toml`
- 摘除 `.github/workflows/template-sync.yml` 与其镜像中 `.codex/config.toml` 的 PAIR 行
- Maps to: AC5, AC6, AC7

## T8: 验收 round 2 — 运行 AC1..AC7

- 全部 AC 必须 PASS（AC5..AC7 是新加的）
- Maps to: 全部 AC

## T9: 跟进提交 + push

- `git add -A`
- Commit: `fix(config): drop project-level .codex/config.toml model pin (#19)`
- 不创建新 PR，推到同一分支 `fix/issue-19`，PR #20 自动更新
