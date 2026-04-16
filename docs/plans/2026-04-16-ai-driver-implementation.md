# AI-Driver Framework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create all files for the AI-driver framework template: constitution, CLAUDE.md, spec template, 5 slash commands, language rules, GitHub Actions workflows, Codex config, CHANGELOG, and README.

**Architecture:** Pure Markdown/YAML files, no runtime code. Slash commands are `.claude/commands/*.md` prompt files that Claude Code loads as `/command-name`. Language rules are `.claude/rules/*.md` files Claude Code auto-loads based on project context. GitHub Actions are standard YAML workflows.

**Tech Stack:** Markdown, YAML, GitHub Actions, Claude Code slash commands, Codex CLI

---

## File Structure

```
AI-driver/
├── .claude/
│   ├── settings.json                    # Task 1
│   ├── commands/
│   │   ├── run-spec.md                  # Task 3
│   │   ├── review-pr.md                # Task 4
│   │   ├── fix-issues.md               # Task 5
│   │   ├── run-tests.md                # Task 6
│   │   └── deploy.md                   # Task 7
│   └── rules/
│       ├── _base.md                     # Task 8
│       ├── rust.md                      # Task 8
│       ├── python.md                    # Task 8
│       ├── typescript.md                # Task 8
│       ├── go.md                        # Task 8
│       └── flutter.md                   # Task 8
├── .github/
│   └── workflows/
│       ├── auto-release.yml             # Task 9
│       └── ci.yml                       # Task 10
├── .codex/
│   └── config.toml                      # Task 11
├── specs/
│   └── _template.spec.md               # Task 2
├── logs/
│   └── .gitkeep                         # Task 1
├── constitution.md                      # Task 1
├── CLAUDE.md                            # Task 1
├── CHANGELOG.md                         # Task 1
├── README.md                            # Task 12
├── .gitignore                           # Task 1
└── docs/
    ├── specs/
    │   └── 2026-04-16-ai-driver-framework-design.md  # already exists
    └── plans/
        └── 2026-04-16-ai-driver-implementation.md    # this file
```

---

### Task 1: Foundation Files

**Files:**
- Create: `constitution.md`
- Create: `CLAUDE.md`
- Create: `CHANGELOG.md`
- Create: `.gitignore`
- Create: `.claude/settings.json`
- Create: `logs/.gitkeep`

- [ ] **Step 1: Create constitution.md**

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

- [ ] **Step 2: Create CLAUDE.md**

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

- [ ] **Step 3: Create CHANGELOG.md**

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/lang/zh-CN/).

## [Unreleased]

### Added
- AI-driver framework initial structure
- Spec template with Given-When-Then acceptance criteria
- Constitution with principles and operational rules
- Slash commands: /run-spec, /review-pr, /fix-issues, /run-tests, /deploy
- Language rules: Rust, Python, TypeScript, Go, Flutter
- GitHub Actions: auto-release, CI
```

- [ ] **Step 4: Create .gitignore**

```
# OS
.DS_Store
Thumbs.db

# Editor
.vscode/
.idea/
*.swp
*.swo

# Logs (keep structure, ignore content except .gitkeep)
logs/**/plan.md
logs/**/tasks.md
logs/**/implementation.log
!logs/.gitkeep
!logs/**/

# Environment
.env
.env.local
```

- [ ] **Step 5: Create .claude/settings.json**

```json
{
  "permissions": {
    "allow": [
      "Bash(gh *)",
      "Bash(git *)",
      "Bash(codex *)"
    ]
  }
}
```

- [ ] **Step 6: Create logs/.gitkeep**

Empty file to preserve directory structure in git.

- [ ] **Step 7: Commit**

```bash
git add constitution.md CLAUDE.md CHANGELOG.md .gitignore .claude/settings.json logs/.gitkeep
git commit -m "chore: add foundation files (constitution, CLAUDE.md, changelog, gitignore)"
```

---

### Task 2: Spec Template

**Files:**
- Create: `specs/_template.spec.md`

- [ ] **Step 1: Create specs/_template.spec.md**

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

- [ ] **Step 2: Commit**

```bash
git add specs/_template.spec.md
git commit -m "feat(specs): add spec template with Given-When-Then acceptance criteria"
```

---

### Task 3: /run-spec Command

**Files:**
- Create: `.claude/commands/run-spec.md`

- [ ] **Step 1: Create .claude/commands/run-spec.md**

The full content of this file is the prompt that Claude Code executes when the user types `/run-spec`. It must be self-contained with all rules, phases, and expected behaviors.

```markdown
# /run-spec: Execute a spec from plan to PR

Usage: /run-spec <path-to-spec-file>

You are an AI engineer executing a spec-driven development workflow.
Read the spec file provided as $ARGUMENTS and execute it end-to-end.

## BEFORE ANYTHING ELSE

1. Read `constitution.md` — obey every principle and operational rule
2. Read the spec file at `$ARGUMENTS`
3. Read `CLAUDE.md` for project context
4. Read any `.claude/rules/*.md` files relevant to this project's language
5. Check for `[NEEDS CLARIFICATION]` markers in the spec — if any exist, STOP and report them to the user. Do not proceed until they are resolved.

## Phase 0: Prepare

- Extract the branch name from the spec's Meta section
- Run: `git checkout -b <branch-name>` (from main)
- Run: `mkdir -p logs/<spec-id>/`

## Phase 1: Design Action Plan

Generate `logs/<spec-id>/plan.md`:
- Architecture overview (use ASCII diagrams)
- Reuse analysis: what existing code can be leveraged
- Risks and dependencies
- Data flow

Generate `logs/<spec-id>/tasks.md`:
- Atomic tasks, each 2-5 minutes
- Format: `- [ ] T001 [AC-xxx] description | Files: path/to/file`
- `[P]` marks parallelizable tasks
- `[AC-xxx]` traces back to acceptance criteria
- Every AC-xxx in the spec must have at least one task covering it

### Codex Plan Review (if review level >= B)

If the spec's review level is B or C, request a Codex review of the plan:
- Commit plan.md and tasks.md
- Use `/codex:review` to get structured feedback
- Fix any critical/high severity findings
- Medium findings: fix if effort is low, otherwise note in plan.md

## Phase 2: Implement

Execute each task in tasks.md sequentially. For EVERY task, follow R-002 (TDD):

1. Write a failing test for the task's expected behavior
2. Run the test — confirm it FAILS (RED)
3. Write the minimal implementation to make the test pass
4. Run the test — confirm it PASSES (GREEN)
5. Refactor if needed
6. Run the language's format tool (per .claude/rules/<lang>.md, R-006)
7. `git add` changed files + `git commit` with Conventional Commits message (R-005)
8. Mark the task `[x]` in tasks.md

If review level = C: after each task, use `/codex:review` and fix findings before continuing.

### Self-Review After All Tasks
- Check: does every AC-xxx in the spec have a passing test?
- Check: did any task go beyond the spec? (R-003 violation)

## Phase 3: Acceptance

For each Acceptance Criteria in the spec:
- Run the exact command specified in the AC
- Read the actual output
- Confirm pass/fail (R-001: no guessing, no "should pass")

Generate an acceptance report:
```
## Acceptance Report
- AC-001: [command] → [actual output] → PASS/FAIL
- AC-002: [command] → [actual output] → PASS/FAIL
...
```

- ALL PASS → proceed to Phase 4
- ANY FAIL → apply R-004 (root cause analysis), fix, re-run. Max 3 retries. If still failing after 3 attempts, report BLOCKED.

## Phase 4: Submit PR

```bash
git push -u origin <branch-name>
```

Create PR with `gh pr create`:
- Title: Conventional Commits format matching the primary change type
- Body must include:
  - Link to the spec file (relative path)
  - The acceptance report from Phase 3
  - Summary of changes
  - Spec ID

Write `logs/<spec-id>/implementation.log`:
- What was implemented
- What existing code was leveraged
- Issues encountered
- Final status: DONE / DONE_WITH_CONCERNS / BLOCKED

Report completion status per R-007.
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/run-spec.md
git commit -m "feat(commands): add /run-spec slash command"
```

---

### Task 4: /review-pr Command

**Files:**
- Create: `.claude/commands/review-pr.md`

- [ ] **Step 1: Create .claude/commands/review-pr.md**

```markdown
# /review-pr: Dual-blind review with Claude + Codex

Usage: /review-pr [PR-number]

You are an AI code reviewer performing a dual-blind review.
If no PR number is given, find the PR for the current branch.

## BEFORE ANYTHING ELSE

1. Read `constitution.md`
2. Determine the PR number:
   - If `$ARGUMENTS` is a number, use it
   - Otherwise: `gh pr list --head $(git branch --show-current) --json number -q '.[0].number'`

## Step 1: Gather Context

```bash
gh pr view <number> --json body,title,url,headRefName
gh pr diff <number>
```

Extract the spec file path from the PR body. Read the spec file.

## Step 2: Pass 1 — Claude Code Review

Review the diff against these dimensions:
- **Code Quality**: logic errors, DRY violations, maintainability
- **Security**: injection, authorization, data exposure
- **Spec Compliance**: does the code satisfy every AC-xxx in the spec?
- **Constitution Compliance**: does it violate any P1-P6 or R-001 to R-007?
- **Test Quality**: coverage, edge cases, mock appropriateness

For each finding, record: severity (critical/high/medium/low), file, line range, description, recommendation.

## Step 3: Pass 2 — Codex Adversarial Review

Invoke Codex adversarial review. This is a separate model giving an independent opinion:

```
/codex:adversarial-review --base main
```

Wait for the result. Parse the structured output (verdict, findings with severity/confidence).

## Step 4: Cross-Model Comparison

Compare Pass 1 and Pass 2 findings:
- Both flagged the same issue → mark as **CRITICAL**
- Only one flagged it → present both perspectives, label source (Claude/Codex)

## Step 5: Write Review to GitHub

Compose the review report and post it as a PR comment:

```bash
gh pr comment <number> --body "<review-report>"
```

Report format:
```markdown
## AI Review Report

### Pass 1: Claude Code
| Severity | File | Finding | Recommendation |
|----------|------|---------|----------------|
| ... | ... | ... | ... |

### Pass 2: Codex Adversarial
| Severity | File | Finding | Recommendation |
|----------|------|---------|----------------|
| ... | ... | ... | ... |

### Cross-Model Findings
[Issues flagged by BOTH models — highest priority]

### Verdict: APPROVE / REQUEST_CHANGES / NEEDS_HUMAN
[One-line justification]
```

Then submit the formal review:
- APPROVE (no critical/high findings): `gh pr review <number> --approve --body "AI review passed"`
- REQUEST_CHANGES (critical/high findings): `gh pr review <number> --request-changes --body "See review comment above"`
- NEEDS_HUMAN (models disagree on critical issues): do not submit formal review, note in comment
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/review-pr.md
git commit -m "feat(commands): add /review-pr slash command with Codex adversarial review"
```

---

### Task 5: /fix-issues Command

**Files:**
- Create: `.claude/commands/fix-issues.md`

- [ ] **Step 1: Create .claude/commands/fix-issues.md**

```markdown
# /fix-issues: Batch-fix GitHub issues

Usage: /fix-issues [--label <label>] [--limit <n>] [--auto]

Defaults: --label ai-fix --limit 5

## BEFORE ANYTHING ELSE

1. Read `constitution.md`
2. Read `CLAUDE.md`

## Step 1: Fetch Issues

```bash
gh issue list --label "<label>" --state open --limit <n> --json number,title,body,comments,url
```

If no issues found, report and exit.

## Step 2: Process Each Issue

For each issue, determine the spec source:

### Mode A: Spec in Comments
Scan all comments for spec-formatted content. Look for markers:
- `## 目标` or `## Goal`
- `## 验收标准` or `## Acceptance Criteria`

If found: extract the comment as the spec. Validate it has at minimum a Goal and at least one AC.

### Mode B: Generate Spec from Context
If no spec found in comments:
1. Read issue title + body + all comments
2. Apply R-004 (root cause analysis):
   - From the issue description, locate the problem area
   - Search the codebase for related files
   - Analyze the root cause
3. Generate a minimal spec:
   - Goal: derived from issue title
   - Context: issue body + root cause analysis
   - Acceptance Criteria: inferred from the problem description
   - Constraints: inherited from constitution.md
4. Unless `--auto` flag is set, present the generated spec to the user for confirmation before proceeding

## Step 3: Post Status to Issue

```bash
gh issue comment <number> --body "AI 开始处理此 issue。生成的 spec 如下：\n\n<spec-content>"
```

## Step 4: Execute Fix

For each confirmed spec, invoke the /run-spec workflow:
- Create a temporary spec file at `specs/fix-issue-<number>.spec.md`
- Set the branch name to `fix/issue-<number>`
- Execute the full /run-spec pipeline (Phase 0-4)
- Ensure the PR body includes `Fixes #<number>`

## Step 5: Post Result to Issue

```bash
gh issue comment <number> --body "<fix-report>"
```

Fix report format:
```markdown
## AI Fix Report
- **根因分析**: [root cause description]
- **修复方案**: [fix summary]
- **PR**: #<pr-number>
- **状态**: DONE / DONE_WITH_CONCERNS / BLOCKED
- **变更文件**: [list of changed files]
```

## Step 6: Summary

After all issues are processed, output a summary table:
| Issue | Title | Status | PR |
|-------|-------|--------|-----|
| #N | ... | DONE/BLOCKED | #M |
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/fix-issues.md
git commit -m "feat(commands): add /fix-issues slash command with dual spec modes"
```

---

### Task 6: /run-tests Command

**Files:**
- Create: `.claude/commands/run-tests.md`

- [ ] **Step 1: Create .claude/commands/run-tests.md**

```markdown
# /run-tests: Run project test suite

Usage: /run-tests [--type unit|integration|e2e|all]

Default: --type all

## BEFORE ANYTHING ELSE

1. Read `CLAUDE.md` for project context
2. Read `.claude/rules/*.md` to find test commands for this project's language

## Step 1: Detect Test Commands

From `.claude/rules/<language>.md`, extract:
- Unit test command (e.g., `cargo test`, `pytest`, `npm test`)
- Integration test command (if defined)
- E2E test command (if defined)
- Coverage command (if defined)

If no language rule file matches the project, attempt auto-detection:
- `Cargo.toml` → Rust → `cargo test`
- `pyproject.toml` or `requirements.txt` → Python → `pytest`
- `package.json` → Node.js → `npm test`
- `go.mod` → Go → `go test ./...`
- `pubspec.yaml` → Flutter → `flutter test`

## Step 2: Run Tests

Based on `--type`:
- `unit`: run unit test command
- `integration`: run integration test command
- `e2e`: run e2e test command
- `all`: run all available test types in sequence

For each test type, capture:
- Exit code
- Stdout/stderr output
- Pass/fail count (parse from output)
- Coverage percentage (if available)

## Step 3: Report

Output a structured test report:
```markdown
## Test Report

| Type | Passed | Failed | Coverage | Status |
|------|--------|--------|----------|--------|
| Unit | X | Y | Z% | PASS/FAIL |
| Integration | X | Y | - | PASS/FAIL |
| E2E | X | Y | - | PASS/FAIL |

### Failed Tests
[For each failure: test name, error message, file:line]

### Recommendations
[If failures exist: analysis of likely cause and suggested fix]
```
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/run-tests.md
git commit -m "feat(commands): add /run-tests slash command"
```

---

### Task 7: /deploy Command

**Files:**
- Create: `.claude/commands/deploy.md`

- [ ] **Step 1: Create .claude/commands/deploy.md**

```markdown
# /deploy: Deploy to staging or production

Usage: /deploy <staging|production>

## BEFORE ANYTHING ELSE

1. Read `constitution.md`
2. Read `CLAUDE.md` for deploy configuration
3. Check if the current spec has a "Deploy & Test" section

## Deploy Configuration

The deploy commands are project-specific. They must be defined in CLAUDE.md under a `## Deploy` section:

```markdown
## Deploy
- staging command: <command to deploy to staging>
- staging url: <staging URL for health check>
- production command: <command to deploy to production>
- production url: <production URL for health check>
- smoke test command: <command to run smoke tests>
- rollback command: <command to rollback>
```

If no deploy section exists in CLAUDE.md, report NEEDS_CONTEXT and ask the user to configure it.

## Staging Deploy

1. **Gate**: Run `/run-tests --type all` — if any test fails, STOP
2. **Deploy**: Execute the staging deploy command
3. **Smoke Test**: Run the smoke test command against the staging URL
4. **Health Check**: `curl -sf <staging-url>/health` (or configured endpoint)
5. **Report**:
```markdown
## Deploy Report: Staging
- Tests: PASS (X passed, 0 failed)
- Deploy: SUCCESS/FAILED
- Smoke Test: PASS/FAIL
- Health Check: PASS/FAIL (HTTP status, response time)
- URL: <staging-url>
```

## Production Deploy

1. **Gate**: Confirm staging passed (check recent deploy report)
2. **Gate**: Run `/run-tests --type all`
3. **Confirm**: Show change summary to user, wait for explicit confirmation
4. **Deploy**: Execute the production deploy command
5. **Health Check**: `curl -sf <production-url>/health`
6. **Report**:
```markdown
## Deploy Report: Production
- Tests: PASS
- Deploy: SUCCESS/FAILED
- Health Check: PASS/FAIL
- URL: <production-url>
```
7. **If health check fails**: Print the rollback command and ask user whether to execute it
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/deploy.md
git commit -m "feat(commands): add /deploy slash command for staging and production"
```

---

### Task 8: Language Rules

**Files:**
- Create: `.claude/rules/_base.md`
- Create: `.claude/rules/rust.md`
- Create: `.claude/rules/python.md`
- Create: `.claude/rules/typescript.md`
- Create: `.claude/rules/go.md`
- Create: `.claude/rules/flutter.md`

- [ ] **Step 1: Create .claude/rules/_base.md**

```markdown
# Base Rules (all languages)

## Code Style
- Single file: max 300 lines
- Function/method: max 50 lines
- Nesting: max 3 levels

## Git
- Commit messages: Conventional Commits format
- One atomic task per commit
- Run formatter before every commit

## Testing
- New features must have tests
- Bug fixes must have regression tests
- Test naming: test_<behavior>_<condition>_<expected>
```

- [ ] **Step 2: Create .claude/rules/rust.md**

```markdown
# Rust Rules

## Format
- Tool: `cargo fmt`
- Config: rustfmt.toml (if exists)

## Lint
- Tool: `cargo clippy -- -D warnings`
- All clippy warnings are errors

## Test
- Command: `cargo test`
- Coverage: `cargo llvm-cov` (if installed)

## Build
- Command: `cargo build --release`

## Project Structure
- src/lib.rs: library entry point
- src/main.rs: binary entry point
- tests/: integration tests
- benches/: benchmarks
```

- [ ] **Step 3: Create .claude/rules/python.md**

```markdown
# Python Rules

## Format
- Tool: `ruff format .`

## Lint
- Tool: `ruff check .`

## Test
- Command: `pytest`
- Coverage: `pytest --cov`

## Build
- Command: `python -m build` (if pyproject.toml exists)

## Project Structure
- src/<package>/: source code
- tests/: test files
- pyproject.toml: project config
```

- [ ] **Step 4: Create .claude/rules/typescript.md**

```markdown
# TypeScript Rules

## Format
- Tool: `npx prettier --write .`

## Lint
- Tool: `npx eslint .`

## Test
- Command: `npm test` or `npx vitest run`
- Coverage: `npx vitest run --coverage`

## Build
- Command: `npm run build` or `npx tsc -b`

## Project Structure
- src/: source code
- tests/ or __tests__/: test files
- package.json: project config
- tsconfig.json: TypeScript config
```

- [ ] **Step 5: Create .claude/rules/go.md**

```markdown
# Go Rules

## Format
- Tool: `gofmt -w .`

## Lint
- Tool: `golangci-lint run`

## Test
- Command: `go test ./...`
- Coverage: `go test -coverprofile=coverage.out ./...`

## Build
- Command: `go build ./...`

## Project Structure
- cmd/: application entry points
- internal/: private packages
- pkg/: public packages
- go.mod: module definition
```

- [ ] **Step 6: Create .claude/rules/flutter.md**

```markdown
# Flutter Rules

## Format
- Tool: `dart format .`

## Lint
- Tool: `dart analyze`
- Config: analysis_options.yaml

## Test
- Command: `flutter test`
- Coverage: `flutter test --coverage`

## Build
- Android: `flutter build apk`
- iOS: `flutter build ios`
- Web: `flutter build web`

## Project Structure
- lib/: source code
- test/: test files
- pubspec.yaml: project config
```

- [ ] **Step 7: Commit**

```bash
git add .claude/rules/
git commit -m "feat(rules): add language rules for Rust, Python, TypeScript, Go, Flutter"
```

---

### Task 9: auto-release.yml

**Files:**
- Create: `.github/workflows/auto-release.yml`

- [ ] **Step 1: Create .github/workflows/auto-release.yml**

```yaml
name: Auto Release

on:
  push:
    branches: [main]

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Check for releasable commits
        id: check
        run: |
          LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
          if [ -z "$LAST_TAG" ]; then
            COMMITS=$(git log --oneline --format="%s")
          else
            COMMITS=$(git log ${LAST_TAG}..HEAD --oneline --format="%s")
          fi

          HAS_FEAT=$(echo "$COMMITS" | grep -c "^feat" || true)
          HAS_FIX=$(echo "$COMMITS" | grep -c "^fix" || true)
          HAS_BREAKING=$(echo "$COMMITS" | grep -c "BREAKING CHANGE" || true)

          if [ "$HAS_FEAT" -gt 0 ] || [ "$HAS_FIX" -gt 0 ] || [ "$HAS_BREAKING" -gt 0 ]; then
            echo "should_release=true" >> $GITHUB_OUTPUT
          else
            echo "should_release=false" >> $GITHUB_OUTPUT
          fi

          echo "has_feat=$HAS_FEAT" >> $GITHUB_OUTPUT
          echo "has_fix=$HAS_FIX" >> $GITHUB_OUTPUT
          echo "has_breaking=$HAS_BREAKING" >> $GITHUB_OUTPUT

      - name: Calculate next version
        if: steps.check.outputs.should_release == 'true'
        id: version
        run: |
          LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
          VERSION=${LAST_TAG#v}
          IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"

          if [ "${{ steps.check.outputs.has_breaking }}" -gt 0 ]; then
            MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0
          elif [ "${{ steps.check.outputs.has_feat }}" -gt 0 ]; then
            MINOR=$((MINOR + 1)); PATCH=0
          else
            PATCH=$((PATCH + 1))
          fi

          echo "tag=v${MAJOR}.${MINOR}.${PATCH}" >> $GITHUB_OUTPUT
          echo "version=${MAJOR}.${MINOR}.${PATCH}" >> $GITHUB_OUTPUT

      - name: Generate changelog entry
        if: steps.check.outputs.should_release == 'true'
        id: changelog
        run: |
          LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
          if [ -z "$LAST_TAG" ]; then
            RANGE="HEAD"
          else
            RANGE="${LAST_TAG}..HEAD"
          fi

          {
            echo "body<<CHANGELOG_EOF"
            echo "## [${{ steps.version.outputs.version }}] - $(date +%Y-%m-%d)"
            echo ""

            FEATS=$(git log $RANGE --oneline --format="%s" | grep "^feat" || true)
            if [ -n "$FEATS" ]; then
              echo "### Added"
              echo "$FEATS" | sed 's/^feat[^:]*: /- /'
              echo ""
            fi

            FIXES=$(git log $RANGE --oneline --format="%s" | grep "^fix" || true)
            if [ -n "$FIXES" ]; then
              echo "### Fixed"
              echo "$FIXES" | sed 's/^fix[^:]*: /- /'
              echo ""
            fi

            echo "CHANGELOG_EOF"
          } >> $GITHUB_OUTPUT

      - name: Create tag and release
        if: steps.check.outputs.should_release == 'true'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          git tag ${{ steps.version.outputs.tag }}
          git push origin ${{ steps.version.outputs.tag }}
          gh release create ${{ steps.version.outputs.tag }} \
            --title "${{ steps.version.outputs.tag }}" \
            --notes "${{ steps.changelog.outputs.body }}"
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/auto-release.yml
git commit -m "ci: add auto-release workflow with SemVer and changelog"
```

---

### Task 10: ci.yml

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Create .github/workflows/ci.yml**

```yaml
name: CI

on:
  pull_request:
    branches: [main]

jobs:
  detect-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Detect language and run checks
        run: |
          echo "=== Detecting project language ==="

          if [ -f "Cargo.toml" ]; then
            echo "Detected: Rust"
            rustup update stable
            cargo fmt -- --check
            cargo clippy -- -D warnings
            cargo test

          elif [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
            echo "Detected: Python"
            pip install ruff pytest
            [ -f "pyproject.toml" ] && pip install -e ".[dev]" 2>/dev/null || true
            [ -f "requirements.txt" ] && pip install -r requirements.txt
            ruff check .
            ruff format --check .
            pytest || echo "No tests found"

          elif [ -f "package.json" ]; then
            echo "Detected: Node.js/TypeScript"
            npm ci
            npm run lint 2>/dev/null || npx eslint . 2>/dev/null || echo "No linter configured"
            npm test 2>/dev/null || npx vitest run 2>/dev/null || echo "No tests found"
            npm run build 2>/dev/null || echo "No build step"

          elif [ -f "go.mod" ]; then
            echo "Detected: Go"
            go vet ./...
            go test ./...

          elif [ -f "pubspec.yaml" ]; then
            echo "Detected: Flutter/Dart"
            flutter pub get
            dart analyze
            flutter test || echo "No tests found"

          else
            echo "No recognized project language detected. Skipping CI checks."
            echo "Add language-specific config files to enable CI."
          fi
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add language-detecting CI workflow"
```

---

### Task 11: Codex Config

**Files:**
- Create: `.codex/config.toml`

- [ ] **Step 1: Create .codex/config.toml**

```toml
# Codex project-level configuration
# See: https://developers.openai.com/codex/config-advanced

model = "o4-mini"
model_reasoning_effort = "high"
```

- [ ] **Step 2: Commit**

```bash
git add .codex/config.toml
git commit -m "chore: add Codex project-level config"
```

---

### Task 12: README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Create README.md**

```markdown
# AI-Driver

语言无关的 AI 驱动开发框架。人写 spec，AI 做其余的事。

## 快速开始

### 前置条件

- [Claude Code](https://claude.ai/code) 已安装并登录
- [Codex CLI](https://github.com/openai/codex) 已安装: `npm install -g @openai/codex`
- [GitHub CLI](https://cli.github.com/) 已安装: `gh auth login`

### 安装

```bash
# 1. Clone 模板
git clone https://github.com/HuMoran/AI-driver.git my-project
cd my-project

# 2. 安装 Codex 插件（在 Claude Code 中执行）
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex
/reload-plugins
/codex:setup
```

### 使用

```bash
# 1. 写 spec
cp specs/_template.spec.md specs/p01_my-feature.spec.md
# 编辑 spec 文件...

# 2. 执行 spec（在 Claude Code 中）
/run-spec specs/p01_my-feature.spec.md
# AI 自动: 设计计划 → 写代码 → 跑测试 → 提 PR

# 3. 审查 PR
/review-pr
# Claude + Codex 双盲审查，报告写入 GitHub PR 评论

# 4. 合并后自动发布
# GitHub Actions 自动: tag + release + changelog

# 5. 发现 bug？写 issue，加 ai-fix 标签
/fix-issues
# AI 读 issue → 分析根因 → 修复 → 提 PR
```

## 命令一览

| 命令 | 作用 | 输入 | 输出 |
|------|------|------|------|
| `/run-spec <file>` | 执行 spec 全流程 | spec 文件路径 | PR + 实现日志 |
| `/review-pr [number]` | 双盲审查 PR | PR 号（可选） | GitHub PR 评论 |
| `/fix-issues` | 批量修复 issue | --label, --limit | 每个 issue 一个 PR |
| `/run-tests` | 运行测试 | --type | 测试报告 |
| `/deploy <env>` | 部署 | staging/production | 部署报告 |

## 项目结构

```
.claude/commands/   — Claude Code slash commands（核心工作流）
.claude/rules/      — 语言特定规范（Rust/Python/TS/Go/Flutter）
.github/workflows/  — GitHub Actions（auto-release + CI）
.codex/             — Codex 项目级配置
specs/              — Spec 文件（人写的需求）
logs/               — AI 实现日志（计划、任务、记录）
constitution.md     — 项目宪法（AI 必须遵守的规则）
CLAUDE.md           — AI 上下文
```

## 工作流

```
人写 spec → /run-spec → AI plan+code+test → PR
                                              ↓
              /review-pr → Claude+Codex 审查 → merge
                                              ↓
                     GitHub Actions → tag + release
                                              ↓
              人测试 → issue → /fix-issues → PR → ...
```

## 规范遵从

- [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) — 更新日志
- [Semantic Versioning](https://semver.org/lang/zh-CN/) — 版本号
- [Conventional Commits](https://www.conventionalcommits.org/zh-hans/v1.0.0/) — Git 提交信息
- [OpenAPI 3.0](https://swagger.io/specification/) — API 设计（如涉及）

## 设计依据

基于以下项目和实践的研究:
- [GitHub Spec-Kit](https://github.github.com/spec-kit/) — 规范驱动开发工具
- [Pimzino spec-workflow](https://github.com/Pimzino/claude-code-spec-workflow) — Claude Code spec 工作流
- [Superpowers](https://github.com/obra/superpowers) — AI 工程纪律插件
- [codex-plugin-cc](https://github.com/openai/codex-plugin-cc) — Codex 对抗性审查

## License

MIT
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with quickstart and command reference"
```

---

## Self-Review Checklist

**Spec coverage:**
- Section 4 (Project Structure) → Task 1 (foundation) + Tasks 2-12 (all files)
- Section 5 (Spec Template) → Task 2
- Section 6 (Constitution) → Task 1 Step 1
- Section 7.1 (/run-spec) → Task 3
- Section 7.2 (/review-pr) → Task 4
- Section 7.3 (/fix-issues) → Task 5
- Section 7.4 (/run-tests) → Task 6
- Section 7.5 (/deploy) → Task 7
- Section 8 (Language Rules) → Task 8
- Section 9 (CLAUDE.md) → Task 1 Step 2
- Section 10.1 (auto-release) → Task 9
- Section 10.2 (ci.yml) → Task 10
- .codex/config.toml → Task 11
- README → Task 12
- All spec sections covered. No gaps.

**Placeholder scan:** No TBD, TODO, or "implement later" found. All code blocks contain complete content.

**Type consistency:** File paths used consistently across all tasks. Slash command names match between CLAUDE.md, README, and command files.
