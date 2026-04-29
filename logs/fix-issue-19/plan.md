# Plan — fix-issue-19

## Architecture

无架构变更。三处文件内文本删除，相同模式：

```
Before: codex exec --model gpt-5.4 --config model_reasoning_effort="high" -s read-only ...
After:  codex exec --config model_reasoning_effort="high" -s read-only ...
```

## Reuse analysis

- 现有 `codex exec` 调用结构、prompt 注入、stdin fence、`-s read-only` 沙盒、超时机制全部保留。
- 不引入新文件、新变量、新 helper。

## Risk analysis

| 风险 | 影响 | 缓解 |
|------|------|------|
| codex CLI 默认模型与 gpt-5.4 行为差异 | 审查输出可能略有不同 | 这是 issue 的预期目标——跟进新模型；prompt 通用不绑定具体模型 |
| 项目级 `.codex/config.toml` 仍 pin `model = "gpt-5.4"`（首版漏掉的层） | 对于无 `~/.codex/config.toml model=` 行的新用户，可能仍被 pin 到 gpt-5.4 → Goal 失败 | 在跟进提交中整文件删除 `.codex/config.toml`（双侧），同时摘除 `template-sync.yml` PAIRS 中该 pair |
| 模板镜像漂移（commands） | template-sync CI 失败 | 已确认 PAIRS 不含 `commands/*`，无需同步 |
| 模板镜像漂移（template-sync.yml 自身 + .codex 删除） | template-sync CI 失败 | 双侧 `template-sync.yml` 同步更新；删除两侧 `.codex/config.toml` 后 PAIRS 中该条目同步摘除（AC6/AC7） |
| 删除 `model_reasoning_effort` 配置项导致 codex 失去推理等级 | 审查质量下降 | 三处 `codex exec` 调用都已用 `-c model_reasoning_effort="high"` CLI flag 显式传入；项目级配置中该项是冗余的，删除无行为变化 |

## Test strategy

- AC1/AC4：grep 字面量缺失校验
- AC2：调用次数不变，证明只去 flag、未误删行
- AC3：周边参数保留，证明最小变更

## TDD note

本任务是单点删除，"测试先行"映射为：先写 AC（grep 校验），运行 → RED（当前 grep 命中 3 次），再删除 → GREEN（grep 不命中）。AC 已在 spec 中固化，等同先写测试。
