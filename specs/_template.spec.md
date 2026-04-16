# p<NN>_<feature-name>.spec.md

## Meta / 元信息
- ID: p<NN>
- Status / 状态: draft | in-review | approved | in-progress | done
- Branch / 分支: feat/p<NN>-<name> or fix/p<NN>-<name>
- Review Level / 对抗审查级别: B
  A = PR review only / 仅 PR 审查
  B = Plan + PR review (default) / 计划阶段 + PR 审查（默认）
  C = Review every step / 每步都审查

## Goal / 目标
One or two sentences. What changes when this is done.
Write WHAT and WHY only. Do not write HOW.

一两句话。做完后世界有什么不同。只写 WHAT 和 WHY，禁止写 HOW。

## Context / 背景
Why is this needed? Motivation, related issues, user feedback, etc.

为什么要做这个？动机、相关 issue、用户反馈等。

## User Scenarios / 用户场景

### Scenario 1 / 场景 1: <title> (Priority: P1)
**As a** [role], **I want** [feature], **so that** [benefit]

**Acceptance Scenarios / 验收场景:**
1. **Given** [initial state], **When** [action], **Then** [expected result]
2. **Given** [initial state], **When** [action], **Then** [expected result]

**Independent Test Method / 独立测试方法:** [how to verify this scenario alone]

### Scenario 2 / 场景 2: <title> (Priority: P2)
(same structure / 同上结构)

### Edge Cases / 边界情况
- What happens when [condition]? / 当 [条件] 时会发生什么？
- How to handle [error scenario]? / 如何处理 [错误场景]？

## Acceptance Criteria / 验收标准
Machine-executable checklist, each item is a boolean check:
机器可执行的检查清单，每条是布尔判断：
- [ ] AC-001: `<command>` succeeds with exit code 0
- [ ] AC-002: Test coverage >= X%
- [ ] AC-003: Zero new lint warnings
- [ ] AC-004: [specific measurable metric]

## Constraints / 技术约束

### MUST / 必须
- MUST-001: [non-negotiable constraint]
- MUST-002: [non-negotiable constraint]

### MUST NOT / 禁止
- MUSTNOT-001: Do not modify <file/directory>
- MUSTNOT-002: Do not introduce new runtime dependencies

### SHOULD / 建议
- SHOULD-001: Prefer reusing existing code
- SHOULD-002: Keep single files under 300 lines

## Deploy & Test / 部署与测试 [optional / 可选]

### Dev / 开发调试
- Start command / 本地启动命令:
- Debug config / 调试配置:
- Hot reload / 热重载:

### Staging / 测试部署
- Deploy target / 部署目标:
- Test data / 测试数据:
- Smoke test command / 冒烟测试命令:

### Production / 生产部署
- Deploy method / 部署方式:
- Health check / 健康检查:
- Rollback plan / 回滚方案:

## Implementation Guide / 实施指南 [optional / 可选]
Your thoughts on implementation. AI will reference but not necessarily follow.
如果你对实现有具体思路。AI 参考但不必遵循。

## References / 参考资料
- Related files / 相关文件: path/to/file
- Related issues / 相关 issue: #123
- External docs / 外部文档: URL

## Needs Clarification / 待澄清 [max 3 / 最多 3 项]
- [NEEDS CLARIFICATION] <question affecting scope/security/UX>
