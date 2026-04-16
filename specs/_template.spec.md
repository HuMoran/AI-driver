# p<NN>_<功能名>.spec.md

## 元信息 (Meta)
- ID: p<NN>
- 状态: draft | in-review | approved | in-progress | done
- 分支: feat/p<NN>-<功能名> 或 fix/p<NN>-<功能名>
- 对抗审查级别: B
  A = 仅 PR 审查
  B = 计划阶段 + PR 审查（默认）
  C = 每步都审查

## 目标 (Goal)
一两句话。做完后世界有什么不同。
只写 WHAT 和 WHY，禁止写 HOW。

## 背景 (Context)
为什么要做这个？动机、相关 issue、用户反馈等。

## 用户场景 (User Scenarios)

### 场景 1: <标题> (优先级: P1)
**As a** [角色], **I want** [功能], **so that** [收益]

**验收场景:**
1. **Given** [初始状态], **When** [动作], **Then** [期望结果]
2. **Given** [初始状态], **When** [动作], **Then** [期望结果]

**独立测试方法:** [如何单独验证此场景]

### 场景 2: <标题> (优先级: P2)
（同上结构）

### 边界情况 (Edge Cases)
- 当 [条件] 时会发生什么？
- 如何处理 [错误场景]？

## 验收标准 (Acceptance Criteria)
机器可执行的检查清单，每条是布尔判断：
- [ ] AC-001: `<命令>` 执行成功，退出码为 0
- [ ] AC-002: 测试覆盖率 >= X%
- [ ] AC-003: 无新增 lint 警告
- [ ] AC-004: [具体的可测量指标]

## 技术约束 (Constraints)

### 必须 (MUST)
- MUST-001: [不可违反的约束]
- MUST-002: [不可违反的约束]

### 禁止 (MUST NOT)
- MUSTNOT-001: 不得修改 <文件/目录>
- MUSTNOT-002: 不得引入新的运行时依赖

### 建议 (SHOULD)
- SHOULD-001: 优先复用现有代码
- SHOULD-002: 保持单文件 < 300 行

## 部署与测试 (Deploy & Test) [可选]

### 开发调试 (Dev)
- 本地启动命令:
- 调试配置:
- 热重载:

### 测试部署 (Staging)
- 部署目标:
- 测试数据:
- 冒烟测试命令:

### 生产部署 (Production)
- 部署方式:
- 健康检查:
- 回滚方案:

## 实施指南 (Implementation Guide) [可选]
如果你对实现有具体思路。AI 参考但不必遵循。

## 参考资料 (References)
- 相关文件: path/to/file
- 相关 issue: #123
- 外部文档: URL

## 待澄清 (Needs Clarification) [最多 3 项]
- [NEEDS CLARIFICATION] <影响范围/安全/UX的关键问题>
