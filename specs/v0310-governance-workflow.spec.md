# v0310-governance-workflow.spec.md

## Meta

- Date: 2026-04-21
- Review Level: A

## Goal

v0.3.9 事故：AI-driver 自身合并 PR #11 时没检查 PR comment，错过了 R-009 的 `approve as-is`，导致审批过的修宪没同步合并，不得不补发 v0.3.9 docs-only release 来修正 constitution.md 与 template。

根因：**merge-pr 在 preflight 阶段不看 PR body 的 `R-NNN` 提议，也不看 issue-comments 里是否有审批**。这是流程/工具缺口，不是恶意攻击面。

v0.3.10 就补这个缺口 —— 一个最小、可靠、grep-级别的 preflight check：

1. **PR body 提到 `R-NNN` 提议** → 进入 governance 模式
2. **issue-comments 有 admin/maintainer 写的 `approve R-NNN` 或 `同意R-NNN`** → 合法审批
3. **branch 有 `docs(constitution): add R-NNN ...` commit** → 修宪内容已 staged，可合并
4. 三者不全 → `merge-pr` fail-closed，提示补 commit 或 `--defer "<rationale>"` 显式延迟

不在范围内（留给未来 spec）：
- digest / canonical form 抗篡改
- per-proposal 多规则并发
- stage-then-read trust-boundary（merge-pr 目前直接 `gh` 就够 —— review-pr 已经 stage，attack surface 在那里已封）
- return-channel 消毒 + 三 sink 审计（单 PR comment sink 足够复盘用）
- runtime fixture harness（grep AC + 手动复现 v0.3.9 场景足以 regression-test）

## User Scenarios

### Scenario 1: merge-pr 检测治理提议并 fail-closed (Priority: P0)

**As a** AI-driver 的维护者运行 `/ai-driver:merge-pr <N>`，
**I want** 命令在合并前自动识别 PR body 的 `R-NNN` 提议并检查审批+落地状态，
**so that** v0.3.9 那种"审批已给但 merge 忘了同步"的事故不再发生。

**Acceptance Scenarios:**

1. **Given** PR body 含 `R-NNN` 提议（行首匹配 `^####?\s+R-[0-9]+:` 或 `^\*\*R-[0-9]+:`），且 issue-comments 里有 admin/maintainer 身份作者的首行（去除前导 `> ` 引用和 fenced code block 后）匹配 `^(approve|同意)\s*R-NNN\b` 的评论，且 branch 上 `git log main..HEAD -- constitution.md` 有 subject 匹配 `^docs\(constitution\): add R-NNN ` 的 commit，**When** merge-pr 跑，**Then** 正常 proceed。
2. **Given** 有提议、无审批评论，**When** merge-pr 跑，**Then** abort：`ERROR: R-NNN proposed in PR body but no "approve R-NNN" / "同意R-NNN" comment found from an admin/maintainer. Obtain approval first, or remove the R-NNN block from the PR body before merging.`
3. **Given** 有提议、有审批、但 branch 上无修宪 commit，**When** merge-pr 跑，**Then** abort：`ERROR: R-NNN approved by @<login> but no "docs(constitution): add R-NNN ..." commit on this branch. Add the commit now, or pass --defer "<rationale>" to defer the amendment to a follow-up PR (v0.3.9 shape).`
4. **Given** 传了 `--defer "<rationale>"` 且 rationale ≤ 200 char 无换行，**When** merge-pr 跑，**Then** 合并前向 PR 追加一条 comment `<!-- ai-driver-defer:R-NNN --> Governance deferral: <rationale>` 后 proceed。Rationale 超长或含换行 → abort at Step 0（no writes）。

**Independent Test Method**：把 PR #11（v0.3.9 真实事故）的 body + comments 快照喂给 preflight check，确认 Scenario 2 / 3 的 abort 命中；再喂 PR #8（R-008 正常合并的 case），确认 Scenario 1 proceed。

### Scenario 2: AGENTS.md 记录 commit 模板 (Priority: P1)

**As a** 维护者在批准了 R-NNN 之后，
**I want** AGENTS.md 有一段说清 amendment commit 的规范 message 形状，
**so that** 我不用翻历史 PR 猜。

**Acceptance Scenarios:**

1. **Given** AGENTS.md 在本 spec 合并后，**When** 我读 Governance 小节，**Then** 看到 `docs(constitution): add R-NNN — approved by @<login> in PR #<n>` 这个字面模板和一条 `git commit` 示例。

### Edge Cases

- **审批作者不是 admin/maintain**：允许列表来自 `gh api --paginate /repos/{owner}/{repo}/collaborators` 后以 `.role_name == "admin" or "maintain"` 过滤。非允许列表作者的 `approve` 当普通评论处理，不算审批。
- **审批在代码块或引用里**：处理 comment 首行前先删掉每个 `^\s*>` 开头的行（blockquote）和三反引号/三 tilde fence 里的所有内容。示例 `> approve R-009` 不算审批。
- **多 R-NNN 提议**：每条 `R-NNN` 独立检查 —— 每条都需要自己的 approve 评论和自己的 `docs(constitution): add R-NNN` commit。`--defer` 在多 proposal 未决时禁用并 abort（简单处理，需要时再扩展）。
- **v0.3.9 shape 的 deferral**：维护者评估"修宪改动大，适合单独 PR 审查"时，`--defer "<rationale>"` 允许合并特性 PR 并要求后续补发 constitution-only PR；deferral 以 PR comment 形式留痕。

## Constraints

### MUST

- MUST-001: merge-pr Step 0 preflight 检测 PR body `R-NNN` 提议，使用 regex `^####?\s+R-[0-9]+:|^\*\*R-[0-9]+:`。检测到即进入 governance mode。
- MUST-002: 审批语法是**规则作用域的双语接受**。去除 blockquote + fence 后的 comment 首个非空行必须匹配 `^\s*(approve|同意)\s*R-NNN\b.*$`（大小写不敏感、首尾空白忽略）。bare `approve` / `同意` 不带规则号不算审批。
- MUST-003: 审批作者 allowlist 从 `gh api --paginate /repos/{owner}/{repo}/collaborators` 取，保留 `role_name` 为 `admin` 或 `maintain` 的 `.login`。非允许列表作者的审批评论当普通留言处理。
- MUST-004: amendment commit 检测 —— branch 上 `git log --format='%H %s' main..HEAD -- constitution.md` 必须存在至少一个 commit 其 subject 匹配 `^docs\(constitution\): add R-NNN `（字面 R-NNN 同号）。
- MUST-005: 三条件（提议 + 审批 + commit）缺一即 abort，错误消息按 Scenario 1 AC-2 / AC-3 字面。`--defer "<rationale>"` 仅适用于"审批有、commit 无"这一种情况；其他缺失不允许 flag 绕过。
- MUST-006: `--defer` rationale 清洗：≤ 200 字符、单行（无 `\n`/`\r`）、转义 `` ` ``、`|`、`$`、`<`、`>`、反斜杠、引号 `"` `'` 后 interpolate 进 PR comment。超长或含换行 → Step 0 abort，无写入。

### MUST NOT

- MUSTNOT-001: 不要自动修改 constitution.md。修宪 commit 是人手工加的，merge-pr 只检测、不代写。
- MUSTNOT-002: 不要弱化 v0.3.4–v0.3.9 任何既有防护（trust boundary、path gate、subagent allowlist、stage-then-read、return-channel sanitization、R-008、R-009）。本 spec 只添新 preflight check。
- MUSTNOT-003: 本 spec 不引入新 R-rule。功能是现有 R-008/R-009 的执行器，不是新规则。

## Acceptance Criteria

每条 AC 是可执行 shell 表达式，非零退出即失败。

- [ ] AC-001: merge-pr.md Step 0 preflight 明确 grep PR body 找 `R-NNN` 提议。`grep -Eq 'R-\[0-9\]\+|governance.*check|constitution.*amendment' plugins/ai-driver/commands/merge-pr.md`
- [ ] AC-002: merge-pr.md 文档里有双语审批正则。`grep -Eq 'approve.*同意|同意.*approve' plugins/ai-driver/commands/merge-pr.md`
- [ ] AC-003: merge-pr.md 文档里指明 admin/maintain allowlist 来源。`grep -Fq '/repos/{owner}/{repo}/collaborators' plugins/ai-driver/commands/merge-pr.md && grep -Fq 'role_name' plugins/ai-driver/commands/merge-pr.md`
- [ ] AC-004: merge-pr.md 文档里有 canonical commit subject 检测。`grep -Fq 'docs(constitution): add R-' plugins/ai-driver/commands/merge-pr.md`
- [ ] AC-005: merge-pr.md 文档里有三条 abort 路径（no-approval / no-commit / defer-invalid）。`for tok in 'no "approve R-' 'no "docs(constitution): add R-' 'defer'; do grep -Fq "$tok" plugins/ai-driver/commands/merge-pr.md || exit 1; done`
- [ ] AC-006: `--defer` flag 文档化且含 rationale 长度/单行/转义规则。`grep -Fq -- '--defer' plugins/ai-driver/commands/merge-pr.md && grep -Eq '200 char|single.line|escape' plugins/ai-driver/commands/merge-pr.md`
- [ ] AC-007: AGENTS.md 有 Governance 小节含 commit 模板。`grep -Fq 'docs(constitution): add R-' AGENTS.md && grep -Fq 'approved by @' AGENTS.md`
- [ ] AC-008: CHANGELOG `[Unreleased]` 提到治理缺口修复。`awk '/^## \[Unreleased\]/{f=1;next} /^## \[/{f=0} f' CHANGELOG.md | grep -Eiq 'governance|amendment|merge-pr'`
- [ ] AC-009: 不弱化现有防护 —— review-pr.md 的 stage-then-read / subagent / trust-boundary 仍在。`for tok in 'mktemp -d' 'chmod 700' 'subagent' 'trap'; do grep -Fq "$tok" plugins/ai-driver/commands/review-pr.md || exit 1; done`
- [ ] AC-010: injection-lint 和既有 harness 仍通过。`bash .github/scripts/injection-lint.sh >/dev/null && bash tests/injection-lint-cases/run.sh >/dev/null 2>&1`

## Implementation Guide

行为不变式；具体 grep / jq / shell 细节在 merge-pr.md 里。

### merge-pr Step 0.10 Governance preflight

伪代码（validation-only，无写入）：

```
# 1. 检测 PR body 提议
proposals = grep -E '^####?\s+R-[0-9]+:|^\*\*R-[0-9]+:' <pr_body>
if empty(proposals): continue to Step 1 (non-governance PR)

# 2. 拉 admin/maintain allowlist（一次）
allowlist = gh api --paginate "/repos/{owner}/{repo}/collaborators" \
  --jq '.[] | select(.role_name == "admin" or .role_name == "maintain") | .login'

# 3. 对每条提议
for R_NNN in proposals:
  # 3a. 在 issue-comments 里找审批
  approval = comments.filter(c ->
    c.user.login in allowlist AND
    first_non_blank_line(strip_quotes_and_fences(c.body)) =~ /^\s*(approve|同意)\s*R_NNN\b/i
  )
  # 3b. 在 branch 上找 amendment commit
  amendment = git log --format='%H %s' main..HEAD -- constitution.md |
              grep -E "^\S+ docs\(constitution\): add R_NNN "

  case (approval, amendment):
    (yes, yes): continue  # 一切正常
    (no, _):    abort "R-NNN proposed in PR body but no 'approve R-NNN' / '同意R-NNN' comment found from an admin/maintainer. ..."
    (yes, no):
      if --defer "<rationale>": record single PR comment, continue
      else: abort "R-NNN approved by @<login> but no 'docs(constitution): add R-NNN ...' commit on this branch. ..."
```

### `--defer` 单-sink 审计

被 approved-no-commit 触发时（且只在这一个场景），Step 0 校验 rationale 合法后（≤ 200 char 单行），在 Step 2.5 —— CHANGELOG rewrite 之后、`gh pr merge` 之前 —— 追加一条 PR comment，格式：

```
<!-- ai-driver-defer:R-NNN -->
Governance deferral (R-NNN): <escaped rationale>
Follow-up: a constitution-only PR will land the amendment commit matching
`docs(constitution): add R-NNN — approved by @<approver> in PR #<N>`.
```

注释包含 `<!-- ai-driver-defer:R-NNN -->` marker 做重跑幂等（gh pr comment 前先 grep 已有 comment 避免重复）。不写 CHANGELOG 段、不写 merge-commit trailer —— 一个 sink 足以复盘，避免 Round 5 的 "三 sink" scope 膨胀。

### AGENTS.md Governance 小节模板

```markdown
## Governance (constitution amendments)

修宪走现有 AI-driver 三门流程，但 merge-pr 会在 preflight 强制以下三条件：

1. PR body 含 `R-NNN: <text>` 提议块
2. issue-comment 里有 admin/maintainer 身份的 `approve R-NNN` 或 `同意R-NNN`
3. branch 上有 `docs(constitution): add R-NNN — approved by @<login> in PR #<n>` 的 commit（改 constitution.md + 模板镜像）

三条件缺一，merge-pr fail-closed。若修宪改动大、适合单独 PR 审查，可传 `--defer "<rationale>"` 延迟（当且仅当审批有、commit 无时生效）。
```

## References

- v0.3.6 R-008 amendment (PR #8) — 正常合并样本
- v0.3.8 R-009 amendment (PR #11) — **事故样本**：审批在 comment 里但 merge-pr 没看，v0.3.9 补发
- plugins/ai-driver/commands/merge-pr.md — 新增 Step 0.10
- plugins/ai-driver/commands/review-pr.md — 保持现状（stage-then-read + subagent 已足）
- constitution.md §Governance — "Amending this constitution requires explicit human approval"

## Needs Clarification

None.
