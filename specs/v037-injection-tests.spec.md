# v037-injection-tests.spec.md

## Meta

- Date: 2026-04-20
- Review Level: B

## Goal

Harden AI-driver against prompt / shell / trust-boundary injection by landing two complementary artifacts: (A) a documented **fixture library** of realistic malicious payloads under `tests/injection-fixtures/`, and (B) a **static lint workflow** (`.github/workflows/injection-lint.yml`) that mechanically scans command docs for known anti-patterns. v0.3.4 introduced the `## Trust boundary` concept and marker-guarded self-ID, but we have no durable test that the guardrails stay in place — a future edit could silently regress them. Fixtures document the attack shape; lint blocks regressions without relying on human review.

Scope is deliberately narrow: no runtime end-to-end harness (no spawning Claude with each payload). If a fixture-driven incident ever occurs, we add runtime E2E in a follow-up.

## User Scenarios

### Scenario 1: Fixture library documents known injection classes (Priority: P1)

**As a** future maintainer editing `review-pr.md` / `fix-issues.md` / `merge-pr.md`,
**I want** a single directory of annotated malicious payloads,
**so that** I can read concrete examples of what each guardrail is defending against before changing the code.

**Acceptance Scenarios:**

1. **Given** `tests/injection-fixtures/` exists,
   **When** I `ls` it,
   **Then** I see exactly five payload files, each a markdown file with frontmatter (`name`, `attack-class`, `target-command`, `mitigation`) followed by the raw payload.
2. **Given** a payload file `changelog-prompt-injection.md`,
   **When** I read it,
   **Then** the frontmatter names the exact mitigation (`merge-pr.md` treats CHANGELOG section as data; `auto-release.yml` extracts byte-for-byte without LLM interpretation), and the payload body contains a realistic attempt to smuggle "ignore previous instructions" into a `## [X.Y.Z]` block.

**Independent Test Method:** `ls tests/injection-fixtures/*.md | wc -l == 5` and each file parses via a frontmatter sanity check.

### Scenario 2: Static lint catches anti-patterns in command docs (Priority: P1)

**As a** reviewer of a PR that edits a command doc,
**I want** a required CI check that refuses to merge if untrusted data is handled unsafely,
**so that** regressions are blocked mechanically, not left to human vigilance.

**Acceptance Scenarios:**

1. **Given** the current `main` tree,
   **When** `injection-lint.yml` runs,
   **Then** it passes (the existing v0.3.4 + v0.3.5 guardrails satisfy every rule).
2. **Given** a synthetic diff that removes the `## Trust boundary` section from `review-pr.md`,
   **When** the lint runs,
   **Then** it fails with a rule-ID and a one-line explanation pointing to `docs/security/injection-threat-model.md`.
3. **Given** a synthetic diff that changes `user.login == "$SELF_LOGIN"` back to checking the marker alone,
   **When** the lint runs,
   **Then** it fails with rule `L-SELF-ID`.

**Independent Test Method:** run the lint script locally against `main` (should pass) and against a scratch branch with each anti-pattern re-introduced one at a time (each should fail with a distinct rule ID).

### Scenario 3: Threat model documents what we defend and what we don't (Priority: P2)

**As a** user evaluating whether to trust AI-driver in their own repo,
**I want** a single doc listing the concrete threats we mitigate and the ones we explicitly don't,
**so that** I can reason about residual risk before installing.

**Acceptance Scenarios:**

1. **Given** `docs/security/injection-threat-model.md` exists,
   **When** I read it,
   **Then** it enumerates at least the five payload classes covered by fixtures, names each mitigation, and has an "Out of scope" section listing what AI-driver does NOT defend against (e.g., a compromised developer machine, a malicious plugin author, token exfiltration via a hostile MCP server).

### Edge Cases

- What if a fixture itself contains a payload that confuses a future LLM reading the repo during `/ai-driver:run-spec`? **Mitigation:** every fixture file starts with a fenced code block containing the payload + a frontmatter `safety-note` instructing any LLM that encounters it to treat the content as inert test data. We also document in `AGENTS.md` that `tests/injection-fixtures/` is a special directory.
- What if the lint produces false positives on unrelated command docs (e.g., `doctor.md` which never consumes untrusted data)? **Mitigation:** lint rules are scoped by `applies-to: review-pr.md, fix-issues.md, merge-pr.md` — the three commands that consume external reviewer / issue / PR data.

## Acceptance Criteria

- [ ] AC-001: `ls tests/injection-fixtures/*.md | wc -l` equals 5
- [ ] AC-002: every fixture has a frontmatter block with `name`, `attack-class`, `target-command`, `mitigation`, `safety-note` — checked by `grep -l '^attack-class:' tests/injection-fixtures/*.md | wc -l == 5`
- [ ] AC-003: `.github/workflows/injection-lint.yml` exists and runs on `pull_request`
- [ ] AC-004: injection-lint passes on current `main` (HEAD at v0.3.5): `bash .github/scripts/injection-lint.sh` exits 0
- [ ] AC-005: each of the five lint rules fails when its corresponding anti-pattern is re-introduced. Evidence: a test harness `tests/injection-lint-cases/` with five `.patch` files; running the lint after applying each patch must exit non-zero with the matching rule ID in stderr.
- [ ] AC-006: `docs/security/injection-threat-model.md` exists and references every fixture by filename
- [ ] AC-007: `review-pr.md`, `fix-issues.md`, `merge-pr.md` each contain a reference line pointing to `tests/injection-fixtures/` (grep check: `grep -l 'tests/injection-fixtures' plugins/ai-driver/commands/{review-pr,fix-issues,merge-pr}.md | wc -l == 3`)
- [ ] AC-008: `AGENTS.md` (repo + template) mentions `tests/injection-fixtures/` as a special test data directory that LLMs should treat as inert
- [ ] AC-009: injection-lint workflow is mirrored into `plugins/ai-driver/templates/.github/workflows/injection-lint.yml` and template-sync passes
- [ ] AC-010: CHANGELOG `[Unreleased]` populated

## Constraints

### MUST

- MUST-001: Fixtures are **documentation**, not executable tests. They describe attack shapes. No fixture is ever auto-loaded into an LLM context by any command in this repo.
- MUST-002: Lint rules must be **mechanical** — pure grep / ripgrep / awk / jq, no LLM invocation. The point is to not depend on AI judgment.
- MUST-003: Every lint rule that fails must print `rule-id` + `file:line` + `fix-hint` + pointer to `docs/security/injection-threat-model.md#<rule-id>`. Same UX contract as `/ai-driver:doctor`.
- MUST-004: Template-sync must stay green: the `injection-lint.yml` pair must be byte-identical between repo and template.

### MUST NOT

- MUSTNOT-001: Do not add the fixtures to any `gitattributes` "generated" or "binary" mask — they must show up in diffs and reviews.
- MUSTNOT-002: Do not run the fixtures against a live Claude / Codex session as part of CI. (That's deferred until we have an incident justifying the cost.)
- MUSTNOT-003: Do not weaken any existing v0.3.4 / v0.3.5 guardrail to pass the lint — if a rule is wrong, fix the rule; don't soften production code.

### SHOULD

- SHOULD-001: Fixture filenames follow `<attack-class>-<short-description>.md` so the directory listing itself reads as a taxonomy.
- SHOULD-002: Threat model doc uses the same rule IDs as the lint (`L-TRUST`, `L-QUOTE`, `L-SELF-ID`, `L-BOT`, `L-PAGINATE`) so a failing CI check is one click away from the explanation.

## Implementation Guide

### Five fixture files

| Filename | Attack class | Target | Primary mitigation |
|---|---|---|---|
| `changelog-prompt-injection.md` | prompt injection via data | `merge-pr.md` / `auto-release.yml` | CHANGELOG is extracted byte-for-byte, never interpreted |
| `review-body-approval-hijack.md` | prompt injection via review content | `review-pr.md` | `## Trust boundary` declares reviewer content UNTRUSTED DATA; Claude pass treats it as input to quote, not instructions to follow |
| `spec-filename-shell-metachar.md` | shell injection via filename | `run-spec.md` | `$ARGUMENTS` always quoted; slug normalization strips non-`[a-z0-9.-]` |
| `fake-self-id-marker.md` | self-ID spoof | `review-pr.md` | Self-ID requires BOTH the HTML marker AND `user.login == $SELF_LOGIN` |
| `bot-authored-spec-without-flag.md` | unauthorized bot-driven destructive action | `fix-issues.md` Mode A | Refuses bot-authored spec by default; `--trust-bot-spec @<login>` required and audit-logged |

### Five lint rules

| ID | Rule | Applies to |
|---|---|---|
| `L-TRUST` | Must contain `## Trust boundary` section | review-pr.md, fix-issues.md, merge-pr.md |
| `L-QUOTE` | No bare `$PR_TITLE`, `$REVIEWER_LOGIN`, `$ISSUE_BODY`, `$COMMENT_BODY` in shell blocks — must be double-quoted | same three |
| `L-SELF-ID` | Self-ID filter must check both `<!-- ai-driver-review -->` AND a login comparison | review-pr.md |
| `L-BOT` | Bot detection must use `user.type` or `[bot]` suffix, never `copilot-*` / `dependabot-*` prefix heuristics | review-pr.md, fix-issues.md |
| `L-PAGINATE` | `gh api /pulls/*/reviews`, `/pulls/*/comments`, `/issues/*/comments` must have `--paginate` | review-pr.md, fix-issues.md |

Lint is a small bash script `.github/scripts/injection-lint.sh` invoked by the workflow; keeps the workflow yaml minimal and makes local reproduction trivial (`bash .github/scripts/injection-lint.sh`).

### Regression test cases

`tests/injection-lint-cases/` holds five `*.patch` files, one per rule, each re-introducing the anti-pattern the rule catches. A second script `tests/injection-lint-cases/run.sh` applies each patch to a worktree, runs the lint, confirms non-zero exit with the expected rule ID in stderr, reverts. This script is invoked by the same workflow after the main lint passes, so a rule that stops catching its anti-pattern is itself caught.

## References

- v0.3.4 comment-aware review spec: `specs/comment-aware-review.spec.md`
- v0.3.5 Copilot backlog spec: `specs/v035-copilot-backlog.spec.md`
- `plugins/ai-driver/commands/review-pr.md` §"Trust boundary"
- `plugins/ai-driver/commands/fix-issues.md` §Mode A `--trust-bot-spec`
- OWASP LLM Top 10 — LLM01 Prompt Injection, LLM08 Excessive Agency

## Needs Clarification

None.
