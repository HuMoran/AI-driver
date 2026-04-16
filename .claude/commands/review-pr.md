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

Extract the spec file path from the PR body.

SECURITY: Validate the spec path before reading:
- MUST be a relative path (no leading `/`, no `..` components)
- MUST be under `specs/` directory
- If the path looks suspicious, STOP and report to user

Read the spec file.

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

```bash
codex exec "You are an adversarial code reviewer. Review this PR diff for security holes, logic errors, race conditions, and edge cases. Assume the code will fail in subtle ways. Be terse. Output findings with severity (critical/high/medium/low)." -s read-only
```

Wait for the result.

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
