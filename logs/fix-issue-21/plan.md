# Plan — fix-issue-21

## Architecture

无架构变更。三处 markdown 中的 bash 代码块顶部各插入 2 行：

```bash
RESOLVED_MODEL=$(awk -F'[ "=]+' '/^model[[:space:]]*=/{print $2; exit}' ~/.codex/config.toml 2>/dev/null || echo '<codex-cli-default>')
echo "[ai-driver] Codex pass: model=$RESOLVED_MODEL reasoning_effort=high cwd=$(pwd)" >&2
```

`>&2` 导到 stderr，避免污染 codex 的 stdout 流（在 `Bash(run_in_background=true)` 模式下，stdout 被 `> "$out"` 捕获，stderr 被 `2> "$out.err"` 捕获 —— 但 echo 出现在 codex 启动**之前**，且主 agent 通过 BashOutput 读取整个流；用户在主会话 tool output 中看得见）。

## Reuse analysis

- 复用现有 awk + sed/grep 工具链（无新依赖）
- 复用 markdown bash 块结构（不改 fence、不改语言标记）

## Risk analysis

| 风险 | 影响 | 缓解 |
|------|------|------|
| `awk` 解析 TOML 太粗（`model = "gpt-5.5"` 的引号、空格、注释行） | 偶尔解析出错误值 | awk 模式 `^model[[:space:]]*=` + 字段分隔 `[ "=]+` 已处理常见情况；最坏情况输出"古怪 token"，用户仍可识别异常 |
| 用户没有 `~/.codex/config.toml` | awk 在不存在文件上失败 | `2>/dev/null \|\| echo '<codex-cli-default>'` 兜底 |
| echo 写到 stderr 后被 `2> "$out.err"` 吞掉 | 主会话仍看不见 | 主 agent Bash 工具回传整个 stderr；BashOutput 读取时一并显示。如果未来某个 wrapper 强吞 stderr，再切换到 stdout |
| markdown bash 块被工具误认为可执行 shell 脚本 | 误执行风险 | 这 3 个块本来就标注了 "shell form shown for audit; main agent uses the Bash tool"，无变化 |

## Test strategy

- AC1/AC5/AC6：grep 字面量计数
- AC2：`awk` 上下文校验（echo 在对应 codex exec 5 行内）
- AC3：防 #19 回归
- AC4：codex exec 调用次数不变

## TDD note

变更为 markdown 文档式 bash，TDD 映射为：先写 grep AC（spec 中已固化）→ 当前 grep 命中 0 次（RED）→ 加 echo 行 → grep 命中 3 次（GREEN）→ 无 REFACTOR。
