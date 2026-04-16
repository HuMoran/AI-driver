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
