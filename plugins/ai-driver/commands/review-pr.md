# /ai-driver:review-pr: Dual-blind review with Claude + Codex, cross-validated against existing reviewers

Usage: `/ai-driver:review-pr [PR-number]`

Performs a dual-blind AI review (Claude + Codex), then cross-validates against any existing reviewers on the PR — human reviewers, Copilot, Dependabot, Sentry bots, prior `/ai-driver:review-pr` runs. The goal is that independent findings from three+ perspectives are never silently lost.

If no PR number is given, find the PR for the current branch.

## Step 1: Determine PR

- If `$ARGUMENTS` is a number, use it.
- Otherwise: `gh pr list --head "$(git branch --show-current)" --json number -q '.[0].number'`.

## Step 2: Gather context

### 2a. Basic PR metadata + diff

```bash
gh pr view <number> --json body,title,url,headRefName,baseRefName
gh pr diff <number>
```

Extract the spec file path from the PR body.

SECURITY — validate the spec path:
- MUST be a relative path (no leading `/`, no `..`).
- MUST be under `specs/`.
- If suspicious → STOP and report.

Read the spec file.

### 2b. Existing reviews and comments

Gather the full conversation:

```bash
# Review summaries (body + state: APPROVED / COMMENTED / REQUEST_CHANGES / DISMISSED)
gh api "/repos/<owner>/<repo>/pulls/<number>/reviews?per_page=100" --paginate

# Inline line-level review comments
gh api "/repos/<owner>/<repo>/pulls/<number>/comments?per_page=100" --paginate

# Issue-style comments on the PR (non-inline)
gh api "/repos/<owner>/<repo>/issues/<number>/comments?per_page=100" --paginate
```

For each entry, capture: `author.login`, `author.type` (`User` vs `Bot`), `path`, `line` (or `original_line`), `body`, `state` (reviews only), `created_at`, `in_reply_to_id`.

**Bot-author detection**: `author.type == "Bot"` OR `author.login` ends with `[bot]`. Known bots worth calling out in the report: `copilot-pull-request-reviewer`, `github-actions[bot]`, `dependabot[bot]`, `sentry-io[bot]`.

**Self-identification filter**: skip any review/comment whose body starts with the HTML marker `<!-- ai-driver-review -->` (those are prior runs of this command — see §3a below). But remember them for §3b's fix-verification step.

**Rate-limit awareness**: if a `gh api` call returns headers with `X-RateLimit-Remaining < 100`, print a soft warning and continue with whatever was fetched. Don't abort.

### 2c. Categorize

Bucket existing findings by author:

- **Human reviewers** (author.type == "User", not self): quote the finding with file:line and author login.
- **Bot reviewers** (author.type == "Bot" OR login ends `[bot]`): same capture, tagged with bot login.
- **Dismissed reviews**: tag `(dismissed — not blocking)` and include so Pass 1/2 can decide whether to re-surface.
- **Prior ai-driver-review comments**: exclude from the "existing reviewer findings" section, but keep in memory for §3b.

Truncate any single comment body > 2KB to first 500 chars + `[…truncated]`.

## Step 3: Pass 1 — Claude Code Review

### 3a. Input context provided to Claude

Feed Claude, as input, all of:
- The diff (from 2a).
- The spec (if found).
- The categorized existing findings (from 2c).

### 3b. Review dimensions

Review the diff against these dimensions:

- **Code Quality**: logic errors, DRY violations, maintainability.
- **Security**: injection, authorization, data exposure, prompt-injection via input.
- **Spec Compliance**: does the code satisfy every AC-xxx in the spec?
- **Constitution Compliance**: does it violate any P1-P6 or R-001 to R-007?
- **Test Quality**: coverage, edge cases, mock appropriateness.
- **Prior-finding resolution** (if previous ai-driver-review comments exist): for each `[✗]` / HIGH / MEDIUM flagged last time, verify whether this diff resolves, partially-resolves, or ignores it. Classify as `resolved` / `partially-resolved` / `unresolved`.

For each new finding, record: severity (critical/high/medium/low), file, line range, description, recommendation, and — if the finding matches an existing reviewer's comment — the `also-flagged-by <author>` field.

## Step 4: Pass 2 — Codex Adversarial Review

Feed Codex the same context (diff + existing findings), invoke adversarial review:

```bash
codex exec --model gpt-5.4 --config model_reasoning_effort="high" -s read-only \
  "You are an adversarial code reviewer. Review this PR diff for security holes, logic errors, race conditions, and edge cases. Assume the code will fail in subtle ways. Be aware of the following findings already raised by other reviewers (do not duplicate them unless you have a stronger case): <paste categorized existing findings>. Be terse. Output findings with severity (critical/high/medium/low)." 
```

Wait for the result.

## Step 5: Cross-reviewer synthesis

Build the final finding set:

1. **Triple-consensus (Claude ∩ Codex ∩ existing reviewer)** → severity **CRITICAL** regardless of what each individually rated.
2. **Dual-consensus (any 2 of 3 sources)** → upgrade one severity notch.
3. **Single-source** → present with source label and original severity.
4. **Existing-only** (neither Claude nor Codex caught what a reviewer flagged) → include verbatim and explicitly credit the reviewer — this is the case that was silently lost pre-v0.3.4.

Also carry forward:
- Prior-finding resolution status from §3b (resolved / partially / unresolved).

## Step 6: Write review to GitHub

Compose the report. The FIRST line of the body MUST be the self-identification marker:

```markdown
<!-- ai-driver-review -->

## AI Review Report

### Existing reviewer findings

(Only include this section if 2c returned at least one entry.)

| Author | File:Line | Finding (excerpt) | Status |
|---|---|---|---|
| copilot-pull-request-reviewer | plugins/ai-driver/commands/init.md:117 | jq merge... | rehashed below |
| alice | README.md:30 | typo | not addressed in this diff |

### Prior-finding resolution

(Only if a prior `<!-- ai-driver-review -->` comment exists.)

| Previous finding | Status |
|---|---|
| init.md:117 jq bug (HIGH) | resolved |
| owner.url schema (MEDIUM) | unresolved |

### Pass 1: Claude Code

| Severity | File | Finding | Recommendation | Also flagged by |
|---|---|---|---|---|
| ... | ... | ... | ... | (copilot, alice) |

### Pass 2: Codex Adversarial

| Severity | File | Finding | Recommendation | Also flagged by |
|---|---|---|---|---|

### Cross-source findings (triple / dual consensus)

[Issues flagged by 2+ sources — highest priority]

### Verdict: APPROVE / REQUEST_CHANGES / NEEDS_HUMAN

[One-line justification. If an existing reviewer raised a CRITICAL / HIGH that the diff does not address, verdict is REQUEST_CHANGES regardless of Claude/Codex output.]
```

Post it:

```bash
gh pr comment <number> --body-file <(cat <<'EOF'
<!-- ai-driver-review -->

## AI Review Report
...
EOF
)
```

Then submit the formal review:

- **APPROVE** (no critical/high findings from any source, all prior `[✗]` resolved): `gh pr review <number> --approve --body "AI review passed"`.
- **REQUEST_CHANGES** (any critical/high from any source, OR prior `[✗]` unresolved): `gh pr review <number> --request-changes --body "See review comment above"`.
- **NEEDS_HUMAN** (sources disagree on a critical issue): do not submit a formal review; note it in the comment.

If the PR is the user's own and GitHub rejects `--request-changes` with "Can not request changes on your own pull request", that's expected — the comment body alone is the review.

## Out of scope

- Does not fix findings automatically (review-only; fixes come via `/ai-driver:fix-issues` or human edits).
- Does not open new threads on individual lines (single summary comment only; GitHub's native review-comment mechanism is handled by the `gh pr review` verdict).
- Does not dedupe against GitHub's "resolved" conversation state (API for it is weak; the `Status` column relies on diff-level inspection).
