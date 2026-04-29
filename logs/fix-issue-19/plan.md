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
| 用户 `~/.codex/config.toml` 缺失 `model` 字段 | 由 codex 内置默认接管 | codex CLI 自身保证默认值始终指向最新可用 |
| 模板镜像漂移 | template-sync CI 失败 | 已确认 PAIRS 不含 `commands/*`，无需同步 |

## Test strategy

- AC1/AC4：grep 字面量缺失校验
- AC2：调用次数不变，证明只去 flag、未误删行
- AC3：周边参数保留，证明最小变更

## TDD note

本任务是单点删除，"测试先行"映射为：先写 AC（grep 校验），运行 → RED（当前 grep 命中 3 次），再删除 → GREEN（grep 不命中）。AC 已在 spec 中固化，等同先写测试。
