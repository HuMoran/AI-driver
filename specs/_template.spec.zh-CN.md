# <功能名>.spec.md

## Meta

- Date: YYYY-MM-DD
- Review Level: B
  A = 仅 PR 审查
  B = 计划阶段 + PR 审查（默认）
  C = 每步都审查

## Goal

1-3 句：做完后世界有什么不同，以及为什么现在要做。
只写 WHAT 和 WHY，禁止写 HOW。

## User Scenarios

### Scenario 1: <标题> (Priority: P1)

**As a** [角色], **I want** [功能], **so that** [收益]

**Acceptance Scenarios:**

1. **Given** [初始状态], **When** [动作], **Then** [期望结果]
2. **Given** [初始状态], **When** [动作], **Then** [期望结果]

**Independent Test Method:** [如何单独验证此场景]

### Scenario 2: <标题> (Priority: P2)

（同上结构）

### Edge Cases

- 当 [条件] 时会发生什么？
- 如何处理 [错误场景]？

## Acceptance Criteria

机器可执行的检查清单，每条是布尔判断：

- [ ] AC-001: `<命令>` 执行成功，退出码为 0
- [ ] AC-002: 测试覆盖率 >= X%
- [ ] AC-003: 无新增 lint 警告
- [ ] AC-004: [具体的可测量指标]

## Constraints

### MUST

- MUST-001: [不可违反的约束]
- MUST-002: [不可违反的约束]

### MUST NOT

- MUSTNOT-001: 不得修改 <文件/目录>
- MUSTNOT-002: 不得引入新的运行时依赖

### SHOULD

- SHOULD-001: 优先复用现有代码
- SHOULD-002: 保持单文件 < 300 行

## Deploy & Test [optional]

### Dev

- 本地启动命令：
- 调试配置：
- 热重载：

### Staging

- 部署目标：
- 测试数据：
- 冒烟测试命令：

### Production

- 部署方式：
- 健康检查：
- 回滚方案：

## Implementation Guide [optional]

如果你对实现有具体思路。AI 参考但不必遵循。

## References

- 相关文件：path/to/file
- 相关 issue: #123
- 外部文档：URL

## Needs Clarification [max 3]

- [NEEDS CLARIFICATION] <影响范围/安全/UX 的关键问题>
