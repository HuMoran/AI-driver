# AI-Driver: AI 驱动开发框架设计文档

**Created**: 2026-04-16
**Status**: Draft
**Repo**: HuMoran/AI-driver

---

## 1. 目标 (Goal)

构建一个**语言无关**的 AI 驱动开发框架模板。人写 spec 定义「做什么」，AI 负责「怎么做」（计划、实施、测试、提 PR、修 issue）。

框架以 Claude Code slash commands 形式提供，clone 后安装 Codex 插件即可使用。团队所有人的 AI 行为完全一致。

## 2. 前置条件 (Prerequisites)

- **Claude Code** — 已安装并登录
- **Codex CLI** — `npm install -g @openai/codex`，已登录 (`codex login`)
- **Codex Plugin for Claude Code** — 项目级安装（见下方安装步骤）
- **GitHub CLI** — `gh auth login` 已完成

### Codex 插件安装（项目级）

```bash
# 在 Claude Code 中执行：
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex
/reload-plugins
/codex:setup    # 验证 Codex CLI 就绪
```

安装后项目获得以下 Codex 能力：
- `/codex:review` — 标准代码审查（结构化 JSON 输出，含 severity/confidence）
- `/codex:adversarial-review` — 对抗性审查（试图打破对代码的信心）
- `/codex:rescue` — 将调查/修复任务委派给 Codex 执行

## 3. 设计原则

- **人定义 What，AI 负责 How** — spec 是真相来源
- **语言无关** — 不假设任何编程语言、框架或运行时
- **3 个命令搞定** — `/run-spec`、`/review-pr`、`/fix-issues`，加可选的 `/run-tests`、`/deploy`
- **Codex 做对抗性审查** — Claude Code 内调用 Codex 插件，不同模型独立审查，真正双盲
- **AI 内部自律，用户无感** — TDD、验证门函数、反合理化等规则内嵌在 commands 中，用户不需要额外操作
- **所有 AI 操作在本地** — GitHub Actions 仅做 merge 后自动化

## 3. 工作流总览

```
完整闭环（9 步）：

  人写 spec ─────────────────────────────┐
                                         ▼
  ┌────────────────────────────────────────────────────┐
  │  /run-spec specs/p01_xxx.spec.md                    │
  │                                                    │
  │  Phase 0: 准备                                     │
  │    读 spec + constitution + CLAUDE.md               │
  │    检查 [NEEDS CLARIFICATION] 标记                  │
  │    创建 git branch                                 │
  │                                                    │
  │  Phase 1: 设计行动计划                              │
  │    生成 plan.md（架构、复用分析、风险）              │
  │    生成 tasks.md（原子任务，2-5分钟/个）             │
  │    可选: Codex 对抗审查计划                         │
  │                                                    │
  │  Phase 2: 实施                                     │
  │    按 tasks.md 顺序执行                             │
  │    每个任务遵循 RED-GREEN-REFACTOR                  │
  │    每完成一个任务标记 [x] + commit                   │
  │    自审: spec 合规 + 代码质量                       │
  │                                                    │
  │  Phase 3: 验收                                     │
  │    逐条检查 Acceptance Criteria                     │
  │    运行验证命令，确认实际输出                        │
  │    不合格 → 回 Phase 1（最多 3 次）                  │
  │                                                    │
  │  Phase 4: 提交 PR                                  │
  │    push + gh pr create                             │
  │    PR body: spec 链接 + 验收报告 + 变更摘要         │
  │    记录 logs/<spec-id>/implementation.log            │
  └────────────────────┬───────────────────────────────┘
                       ▼
  ┌────────────────────────────────────────────────────┐
  │  /review-pr [PR号]                                  │
  │                                                    │
  │  Pass 1: Claude Code 审查                           │
  │    代码质量 + 安全 + spec 合规 + constitution 合规   │
  │  Pass 2: Codex 独立审查（双盲）                     │
  │  交叉对比: 双方都标记 → CRITICAL                    │
  │  输出审查报告: APPROVE / REQUEST_CHANGES             │
  └────────────────────┬───────────────────────────────┘
                       ▼
               审查通过 → merge
                       ▼
  ┌────────────────────────────────────────────────────┐
  │  GitHub Actions: auto-release.yml                   │
  │    auto tag (SemVer) + GitHub Release + CHANGELOG   │
  └────────────────────┬───────────────────────────────┘
                       ▼
           可选: /deploy staging|production
                       ▼
           人工测试 → 发现问题 → 写 GitHub Issue
                       ▼
  ┌────────────────────────────────────────────────────┐
  │  /fix-issues [--label ai-fix] [--limit 5]           │
  │                                                    │
  │  读 open issues                                    │
  │  对每个 issue:                                     │
  │    模式 A: issue 评论中已有 spec → 直接使用         │
  │    模式 B: 无 spec → AI 从上下文生成 → 人确认       │
  │  调用 /run-spec 流程处理                            │
  │  PR body 引用 "Fixes #<issue>"                     │
  └────────────────────────────────────────────────────┘
```

## 4. 项目结构

```
AI-driver/
├── .claude/
│   ├── settings.json              # hooks（pre-commit 格式化等）
│   ├── commands/                  # 自包含 slash commands
│   │   ├── run-spec.md            # /run-spec: spec → PR
│   │   ├── review-pr.md           # /review-pr: 双盲审查
│   │   ├── fix-issues.md          # /fix-issues: issue → PR
│   │   ├── run-tests.md           # /run-tests: 运行测试套件
│   │   └── deploy.md              # /deploy: 部署到 staging/prod
│   └── rules/                     # 语言特定规范
│       ├── _base.md               # 通用规范（所有语言）
│       ├── rust.md
│       ├── flutter.md
│       ├── python.md
│       ├── typescript.md
│       └── go.md
│
├── .github/
│   └── workflows/
│       ├── auto-release.yml       # merge → tag + release + changelog
│       └── ci.yml                 # 可选: PR → lint + test + build
│
├── specs/                         # 人写的 spec 文件
│   ├── _template.spec.md          # spec 模板
│   └── p01_xxx.spec.md            # 具体 spec
│
├── logs/                          # AI 实现日志（组织记忆）
│   └── p01_xxx/
│       ├── plan.md                # AI 生成的行动计划
│       ├── tasks.md               # AI 生成的任务列表
│       └── implementation.log     # 实现过程记录
│
├── .codex/
│   └── config.toml                # Codex 项目级配置
│
├── constitution.md                # 项目宪法 + 操作规则
├── CLAUDE.md                      # AI 上下文
├── CHANGELOG.md                   # 遵从 Keep a Changelog
└── README.md
```

## 5. Spec 模板

文件: `specs/_template.spec.md`

```markdown
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
```

### Spec 模板设计依据

| 字段 | 来源 | 作用 |
|------|------|------|
| Given-When-Then 验收场景 | GitHub Spec-Kit | AI 可直接从中生成测试用例 |
| 编号化约束 (AC-xxx, MUST-xxx) | Pimzino spec-workflow | 任务可追溯到具体需求 |
| 独立测试方法 | GitHub Spec-Kit | 确保每个场景可增量验证 |
| [NEEDS CLARIFICATION] | GitHub Spec-Kit | 限制最多 3 个，防止 AI 乱猜 |
| 对抗审查级别 | 原创 | 用户控制审查力度 |
| 部署与测试 | 原创 | 支持开发/测试/生产全链路 |

## 6. Constitution（项目宪法 + 操作规则）

文件: `constitution.md`

```markdown
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
```

## 7. Slash Commands 设计

### 7.1 /run-spec

文件: `.claude/commands/run-spec.md`

**输入**: spec 文件路径
**输出**: PR + 实现日志

```
核心流程:

Phase 0: 准备
  - 读 constitution.md（必须，每次操作前）
  - 读 spec 文件
  - 读 CLAUDE.md
  - 读 .claude/rules/ 中对应语言的规范（如有）
  - 检查 [NEEDS CLARIFICATION] 标记，有未解决的 → 报错退出
  - 从 spec 元信息中的分支名创建 git branch
  - mkdir -p logs/<spec-id>/

Phase 1: 设计行动计划
  - 生成 logs/<spec-id>/plan.md:
    - 架构设计（ASCII 图）
    - 复用分析: 现有代码中哪些可以 leverage
    - 风险和依赖
    - 数据流
  - 生成 logs/<spec-id>/tasks.md:
    - 原子任务，每个 2-5 分钟
    - 格式: - [ ] T001 [P?] [AC-xxx] 描述 | 文件: path/to/file
    - [P] 标记可并行任务
    - [AC-xxx] 追溯到验收标准
  - 如果审查级别 >= B:
    - 调用 /codex:review 审查 plan + tasks（通过 codex-plugin-cc）
    - Codex 返回结构化审查意见（severity + findings）
    - 根据审查意见修订（critical/high 必须修，medium 酌情）

Phase 2: 实施
  - 按 tasks.md 顺序执行每个任务
  - 每个任务遵循 R-002 (RED-GREEN-REFACTOR):
    1. 写失败测试
    2. 运行测试，确认失败 (RED)
    3. 写最小实现
    4. 运行测试，确认通过 (GREEN)
    5. 重构（如有必要）
    6. 运行格式化工具 (R-006)
    7. git add + commit (R-005)
    8. 标记任务 [x]
  - 如果审查级别 = C: 每个任务完成后 Codex 审查
  - 自审: spec 合规检查（所有 AC-xxx 是否被任务覆盖）

Phase 3: 验收
  - 逐条执行 spec 中的 Acceptance Criteria:
    - AC-001: 运行命令，检查退出码
    - AC-002: 运行测试，检查覆盖率
    - AC-003: 运行 lint，检查警告数
    - ...
  - 遵循 R-001: 运行命令 → 读输出 → 确认
  - 生成验收报告
  - 全部通过 → Phase 4
  - 有失败 → 遵循 R-004 根因分析 → 回 Phase 1
  - 最多重试 3 次，超过报告 BLOCKED

Phase 4: 提交 PR
  - git push -u origin <branch>
  - gh pr create:
    - title: Conventional Commits 格式
    - body: spec 链接 + 验收报告 + 变更摘要
  - 写 logs/<spec-id>/implementation.log:
    - 实现了什么
    - 用了哪些现有代码 (leverage)
    - 遇到了什么问题
    - 最终状态 (DONE/DONE_WITH_CONCERNS)
```

### 7.2 /review-pr

文件: `.claude/commands/review-pr.md`

**输入**: PR 号（默认当前分支的 PR）
**输出**: 审查报告

```
流程:

1. 获取 PR diff (gh pr diff)
2. 从 PR body 提取 spec 文件路径
3. 读 spec + constitution

Pass 1: Claude Code 自审
  - 代码质量: 逻辑错误、DRY、可维护性
  - 安全: 注入、权限、数据泄露
  - Spec 合规: 是否满足所有 AC-xxx
  - Constitution 合规: 是否违反任何原则/规则
  - 测试质量: 覆盖率、边界情况、mock 合理性

Pass 2: Codex 对抗性审查（通过 codex-plugin-cc）
  - 调用: /codex:adversarial-review --base main
  - Codex 独立审查，不看 Pass 1 结果
  - 对抗性立场: 假设代码会以微妙方式失败
  - 重点攻击面:
    - 认证/权限/信任边界
    - 数据丢失/损坏/不可逆变更
    - 竞态条件/排序假设/过期状态
    - 空状态/null/超时/降级行为
  - 输出: 结构化 JSON (verdict + findings + severity)

交叉对比:
  - 双方都标记的问题 → CRITICAL
  - 仅一方标记 → 展示双方观点，标注来源 (Claude/Codex)

输出（写入 GitHub PR 评论）:
  - gh pr comment <number> --body "<审查报告>"
  - 报告格式:
    ## AI Review Report
    ### Pass 1: Claude Code
    [findings 列表，按 severity 排序]
    ### Pass 2: Codex Adversarial
    [findings 列表，按 severity 排序]
    ### 交叉发现 (Cross-Model)
    [双方都标记的 CRITICAL 问题]
    ### Verdict: APPROVE / REQUEST_CHANGES / NEEDS_HUMAN

  - 同时执行: gh pr review --approve 或 --request-changes
```

### 7.3 /fix-issues

文件: `.claude/commands/fix-issues.md`

**输入**: --label（默认 ai-fix）、--limit（默认 5）
**输出**: 每个 issue 一个 PR

```
流程:

1. gh issue list --label "ai-fix" --state open --limit N
2. 对每个 issue:

   检测 spec 来源:
   模式 A: 扫描 issue 评论，查找 spec 格式的内容
     - 识别标志: "## 目标"/"## Goal"、"## 验收标准"/"## Acceptance Criteria"
     - 找到 → 提取为临时 spec → 直接使用

   模式 B: 无 spec
     - 读 issue title + body + 所有评论
     - 遵循 R-004 (根因分析):
       1. 从 issue 描述定位问题
       2. 在代码中找到相关文件
       3. 分析根因
     - 生成精简版 spec:
       - Goal: 从 issue 提取
       - Context: issue body + 根因分析
       - AC: 基于问题描述推断
       - Constraints: 从 constitution 继承
     - 展示 spec 给人确认（除非 --auto）

3. 在 issue 中评论处理状态:
   gh issue comment <number> --body "AI 开始处理此 issue..."
4. 对确认的 spec 调用 /run-spec 流程
5. PR body 引用 "Fixes #<issue-number>"
6. 在 issue 中评论结果:
   gh issue comment <number> --body "<处理报告>"
   报告格式:
     ## AI Fix Report
     - 根因分析: [分析结果]
     - 修复方案: [方案摘要]
     - PR: #<pr-number>
     - 状态: DONE / DONE_WITH_CONCERNS / BLOCKED
7. 处理完成后输出汇总报告
```

### 7.4 /run-tests

文件: `.claude/commands/run-tests.md`

**输入**: --type（unit|integration|e2e|all，默认 all）
**输出**: 测试报告

```
流程:

1. 读 CLAUDE.md + .claude/rules/<language>.md 获取测试命令
2. 按类型运行:
   - unit: 语言对应的单元测试命令
   - integration: 集成测试命令
   - e2e: 端到端测试命令
3. 收集结果:
   - 通过/失败数量
   - 覆盖率
   - 失败测试的错误信息
4. 输出测试报告
5. 如果有失败，分析原因并给出修复建议
```

### 7.5 /deploy

文件: `.claude/commands/deploy.md`

**输入**: 目标环境（staging|production）
**输出**: 部署状态报告

```
流程:

1. 读 spec 中的"部署与测试"章节（如有）
2. 读 CLAUDE.md 获取部署配置

部署到 staging:
  a. 运行 /run-tests --type all（门控）
  b. 执行 staging 部署命令
  c. 运行冒烟测试
  d. 报告部署状态

部署到 production:
  a. 检查: staging 是否已通过
  b. 运行 /run-tests --type all（门控）
  c. 确认: 展示变更摘要，等人确认
  d. 执行 production 部署命令
  e. 运行健康检查
  f. 报告部署状态
  g. 如果健康检查失败 → 提示回滚命令
```

## 8. 语言规范 (.claude/rules/)

### 8.1 _base.md（通用规范）

```markdown
# 通用规范

## 代码风格
- 单文件不超过 300 行
- 函数/方法不超过 50 行
- 嵌套不超过 3 层

## Git
- commit message: Conventional Commits
- 每个原子任务一个 commit
- commit 前运行格式化

## 测试
- 新功能必须有测试
- bug fix 必须有回归测试
- 测试命名: test_<被测行为>_<输入条件>_<期望结果>
```

### 8.2 语言规范示例（rust.md）

```markdown
# Rust 规范

## 格式化
- 工具: `cargo fmt`
- 配置: rustfmt.toml（如有）

## Lint
- 工具: `cargo clippy -- -D warnings`
- 所有 clippy 警告视为错误

## 测试
- 命令: `cargo test`
- 覆盖率: `cargo llvm-cov`

## 构建
- 命令: `cargo build --release`

## 项目结构
- src/lib.rs: 库入口
- src/main.rs: 二进制入口
- tests/: 集成测试
```

## 9. CLAUDE.md

```markdown
# AI-Driver

## 这是什么
语言无关的 AI 驱动开发框架。人写 spec，AI 做其余的事。

## 工作流
1. 人写 specs/pxx_xxx.spec.md
2. /run-spec → AI plan + implement + test → PR
3. /review-pr → Claude + Codex 双盲审查
4. merge → auto tag + release
5. 可选: /deploy staging|production
6. 人测试 → 写 GitHub Issue（加 ai-fix 标签）
7. /fix-issues → AI 读 issue → 修复 → PR

## 关键文件
- constitution.md — 项目宪法，AI 每次操作前必读
- specs/_template.spec.md — spec 模板
- specs/ — 所有 spec 文件
- logs/ — AI 实现日志
- .claude/commands/ — slash commands
- .claude/rules/ — 语言特定规范
- CHANGELOG.md — 变更日志

## 规则
- 实施前必须读 constitution.md
- 不得修改 constitution.md（除非人明确要求）
- 不得扩大 spec 范围
- 每个 commit 对应一个原子任务
- commit message 遵从 Conventional Commits
- PR body 必须引用 spec 文件路径
```

## 10. GitHub Actions

### 10.1 auto-release.yml

```yaml
触发: push to main
条件: commit message 包含 feat/fix/perf（语义化版本相关）

步骤:
1. 基于 Conventional Commits 计算下一个版本号 (SemVer)
   - feat → MINOR
   - fix → PATCH
   - BREAKING CHANGE → MAJOR
2. 更新 CHANGELOG.md（按 Keep a Changelog 格式）
3. 创建 git tag
4. 创建 GitHub Release（body = changelog 条目）
```

### 10.2 ci.yml（可选）

```yaml
触发: pull_request to main

步骤:
1. 检测项目语言（从文件特征推断）
2. 安装依赖
3. 运行 lint
4. 运行测试
5. 运行构建（如适用）

注: 如果项目没有配置 CI，此 workflow 不执行。
    具体的 lint/test/build 命令从 CLAUDE.md 或
    .claude/rules/<language>.md 中读取。
```

## 11. 设计依据

### 研究来源

| 来源 | 采纳的要素 |
|------|-----------|
| [GitHub Spec-Kit](https://github.github.com/spec-kit/) | Given-When-Then 验收格式、[NEEDS CLARIFICATION] 机制、Constitution 概念、Spec 只写 WHAT/WHY |
| [Pimzino spec-workflow](https://github.com/Pimzino/claude-code-spec-workflow) | 原子任务（1-3文件、15-30分钟）、需求追溯（_Requirements）、Implementation Logs、复用分析 |
| [GitHub SDD 博文](https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/) | "意图是真相来源"理念、分离稳定的 What 和灵活的 How、每阶段验证检查点 |
| [Superpowers](https://github.com/obra/superpowers) | TDD 铁律 (RED-GREEN-REFACTOR)、verification-before-completion 门函数、反合理化机制、4 种完成状态、两阶段审查、systematic-debugging 4 阶段根因分析 |
| [codex-plugin-cc](https://github.com/openai/codex-plugin-cc) | Codex 对抗性审查（adversarial-review）、结构化审查输出（JSON verdict/findings/severity）、任务委派（rescue）、后台运行支持 |

### 关键设计决策

| 决策 | 理由 |
|------|------|
| Slash commands 而非 shell 脚本 | 原生集成 Claude Code，不需要管 API key |
| 规则内嵌 commands 而非依赖外部插件 | 团队一致性，clone 即用 |
| 所有 AI 操作在本地 | 不需要 CI 中配置 API key，更可控 |
| Codex 做对抗审查而非冗余 Claude 审查 | 不同模型独立审查，真正的双盲 |
| 使用 codex-plugin-cc 而非裸 CLI 调用 | 插件提供结构化输出（JSON verdict/findings/severity）、对抗审查专用模式、后台运行支持 |
| 3+2 个命令（核心 3 + 可选 2） | 用户界面极简，AI 内部复杂度对用户透明 |
| Constitution 合并原则和操作规则 | 避免铁律和宪法重复，单一来源 |
| 去掉 project.yml | CLAUDE.md + rules/ 已够，不需额外配置文件 |

## 12. 不在范围内 (NOT in Scope)

- 具体应用代码（这是框架模板，不是应用）
- 特定云平台的部署实现（deploy.md 是接口，用户自己填部署命令）
- Sentry / 错误监控集成（语言特定，不适合通用模板）
- Feature flags 系统（与核心 AI 驱动流程无关）
- GitHub Actions 中的 AI 操作（所有 AI 在本地）
- 自动合并 PR（merge 必须由人确认）
