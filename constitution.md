# Project Constitution

AI 在每次操作前必须加载并遵守。违反任何规则必须立即停止并报告。

## 原则 (Principles)

### P1: Spec 是真相来源
代码是 spec 的实现。当代码与 spec 冲突时，以 spec 为准。
如果 spec 有误，先修 spec 再改代码。

### P2: 人定义 What，AI 负责 How
人写 spec（做什么、为什么）。AI 做 plan + implement（怎么做）。
AI 不得自行扩大或缩小 spec 范围。

### P3: 语言无关
框架不假设任何编程语言、框架或运行时。
所有工具和流程适用于任意技术栈。

### P4: 可验证优先
验收标准必须是机器可执行的。
"代码质量好" 不是验收标准，"lint 零警告" 是。

### P5: 最小变更
每次实施只做 spec 要求的事。不做 spec 未提及的优化或重构。

### P6: 本地执行
所有 AI 操作在本地 Claude Code 中执行。
GitHub Actions 仅用于 merge 后自动化。

## 操作规则 (Operational Rules)

### R-001: 完成前必须验证 (源自 P4)
没有运行验证命令并读取实际输出，不得声称任务完成。
禁止使用"应该通过"、"看起来没问题"等模糊措辞。
必须: 运行命令 → 读取输出 → 确认通过 → 然后才能标记完成。

### R-002: 先测试后实现 (源自 P4)
遵循 RED-GREEN-REFACTOR:
1. 写失败测试 (RED)
2. 写最小实现使测试通过 (GREEN)
3. 重构 (REFACTOR)
没有失败测试就不写生产代码。

### R-003: 不扩大范围 (源自 P2, P5)
spec 没写的，不做。发现"应该顺便做"的事，记录到
implementation.log，不执行。

### R-004: 失败时根因分析 (源自 P4)
测试失败或验收不通过时，必须:
1. 读错误信息
2. 定位根因
3. 形成假说
4. 验证假说
禁止: 盲目重试、随机修改代码。
3 次修复失败 → 报告 BLOCKED 状态，由人介入。

### R-005: 原子 commit (源自 P5)
每个任务一个 commit。commit message 遵从 Conventional Commits:
`<type>(<scope>): <description>`
type: feat|fix|docs|style|refactor|perf|test|chore|ci

### R-006: commit 前格式化
git commit 前必须运行代码格式化工具。
具体工具由 .claude/rules/<language>.md 指定。

### R-007: 4 种完成状态
任务完成时必须报告以下状态之一:
- DONE: 全部完成，有验证证据
- DONE_WITH_CONCERNS: 完成但有问题需关注
- NEEDS_CONTEXT: 缺信息，需人补充
- BLOCKED: 卡住了，需人介入

## 规范遵从 (Standards)

- 更新日志: [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0)
- 版本号: [Semantic Versioning](https://semver.org/lang/zh-CN/)
- Git 提交: [Conventional Commits](https://www.conventionalcommits.org/zh-hans/v1.0.0/)
- API 设计: [OpenAPI 3.0](https://swagger.io/specification/)（如涉及 API）

## 治理

- 修改宪法需要人工明确批准
- AI 不得自行修改 constitution.md
