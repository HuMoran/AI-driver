# v037-injection-tests.spec.md

## Meta

- Date: 2026-04-20
- Review Level: B

## Goal

Harden AI-driver against prompt / shell / trust-boundary injection by landing two complementary artifacts: (A) a documented **fixture library** of realistic malicious payloads under `tests/injection-fixtures/`, and (B) a **static lint workflow** (`.github/workflows/injection-lint.yml`) that mechanically scans command docs and critical workflows for known anti-patterns. v0.3.4 introduced the `## Trust boundary` concept and marker-guarded self-ID; v0.3.6 added Phase 0 spec review with data-fence wrapping. But we have no durable test that those guardrails stay in place — a future edit could silently regress them. Fixtures document the attack shape; lint blocks regressions without relying on human review.

Scope is deliberately narrow:
- Fixtures + lint are **repo-internal hardening** for the plugin source repo; they are **not shipped to user projects** via `plugins/ai-driver/templates/`. User projects do not have the same attack surface (no `plugins/ai-driver/commands/*.md` to guard, no `tests/injection-fixtures/` to reference).
- No runtime end-to-end harness (no spawning Claude with each payload). If a fixture-driven incident ever occurs, we add runtime E2E in a follow-up.
- Each fixture maps **1:1** to a lint rule that guards its exact regression class.

## User Scenarios

### Scenario 1: Fixture library documents known injection classes (Priority: P1)

**As a** future maintainer editing `review-pr.md` / `fix-issues.md` / `merge-pr.md`,
**I want** a single directory of annotated malicious payloads,
**so that** I can read concrete examples of what each guardrail is defending against before changing the code.

**Acceptance Scenarios:**

1. **Given** `tests/injection-fixtures/` exists,
   **When** I `ls` it,
   **Then** I see exactly five payload files, each a markdown file whose frontmatter has **five required keys** (`name`, `attack-class`, `target-command`, `mitigation`, `safety-note`) plus `rule-anchor` pointing to the threat-model anchor, followed by the indented/fenced payload.
2. **Given** a payload file `changelog-prompt-injection.md`,
   **When** I read it,
   **Then** the frontmatter names the exact mitigation (`merge-pr.md` treats CHANGELOG section as data; `auto-release.yml` extracts byte-for-byte without LLM interpretation), and the payload body contains a realistic attempt to smuggle "ignore previous instructions" into a `## [X.Y.Z]` block.

**Independent Test Method:** `ls tests/injection-fixtures/*.md | wc -l == 5` and each file parses via a frontmatter sanity check.

### Scenario 2: Static lint catches anti-patterns in command docs (Priority: P1)

**As a** reviewer of a PR that edits a command doc,
**I want** a required CI check that refuses to merge if untrusted data is handled unsafely,
**so that** regressions are blocked mechanically, not left to human vigilance.

**Acceptance Scenarios:**

1. **Given** the current tree,
   **When** `injection-lint.yml` runs,
   **Then** it passes (the existing v0.3.4 / v0.3.5 / v0.3.6 guardrails satisfy every rule).
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

- **Fixture accidentally loaded as a spec.** What if someone runs `/ai-driver:run-spec tests/injection-fixtures/foo.md`? The **real mitigations** are, in order of enforcement strength:
  1. **Path gate** (hardest): `/ai-driver:run-spec` Pre-flight refuses any `$ARGUMENTS` that is not a file under `specs/` (new in this spec — see Implementation Guide).
  2. **Phase 0 Layer 0 rejection**: even if the path gate is bypassed, fixture files lack a `## Meta` block with `Date` + `Review Level` at column 0, so S-META fails.
  3. The `safety-note` frontmatter key is **documentation only**, not a trust boundary. A fixture author writes it so future human readers (and curious LLMs scanning the repo) see the intent; it does NOT enforce anything.
- **Lint false positive on unrelated command docs** (e.g., `doctor.md` which never consumes untrusted data). **Mitigation:** lint rules are scoped by `applies-to: review-pr.md, fix-issues.md, merge-pr.md` — the three commands that consume external reviewer / issue / PR data. L-EXTRACT applies only to `.github/workflows/auto-release.yml`.
- **Lint rule itself has a bug that hides a real anti-pattern.** Mitigation: the `tests/injection-lint-cases/` harness re-introduces each anti-pattern via a `.patch` file; if the lint fails to catch it, CI fails. This is the lint-lints-itself safety net.

## Acceptance Criteria

Every AC is a runnable shell expression that exits non-zero on failure.

- [ ] AC-001: `test "$(ls tests/injection-fixtures/*.md 2>/dev/null | wc -l)" -eq 5`
- [ ] AC-002: every fixture has the required five frontmatter keys. `for f in name attack-class target-command mitigation safety-note; do test "$(grep -l "^$f:" tests/injection-fixtures/*.md | wc -l)" -eq 5 || exit 1; done`
- [ ] AC-003: `test -f .github/workflows/injection-lint.yml && grep -q 'on:' .github/workflows/injection-lint.yml && grep -q 'pull_request' .github/workflows/injection-lint.yml`
- [ ] AC-004: injection-lint passes on the current tree (no version pinning — the rule is "passes on HEAD"). `test -x .github/scripts/injection-lint.sh && bash .github/scripts/injection-lint.sh >/dev/null`
- [ ] AC-005: each of the five lint rules fails when its corresponding anti-pattern is re-introduced. `test -d tests/injection-lint-cases && bash tests/injection-lint-cases/run.sh` (the harness applies each `.patch` and asserts non-zero exit with the matching rule ID in stderr; see Implementation Guide).
- [ ] AC-006: threat model exists and references every fixture by filename. `test -f docs/security/injection-threat-model.md && for f in tests/injection-fixtures/*.md; do grep -Fq "$(basename "$f")" docs/security/injection-threat-model.md || exit 1; done`
- [ ] AC-007: cross-doc pointer present in the three untrusted-data-consuming commands. `test "$(grep -l 'tests/injection-fixtures' plugins/ai-driver/commands/review-pr.md plugins/ai-driver/commands/fix-issues.md plugins/ai-driver/commands/merge-pr.md | wc -l)" -eq 3`
- [ ] AC-008: `AGENTS.md` (repo) documents the fixtures directory. `grep -Fq 'tests/injection-fixtures' AGENTS.md`
- [ ] AC-009: injection-lint + fixtures are repo-internal only. No template pair exists for them. `! test -f plugins/ai-driver/templates/.github/workflows/injection-lint.yml && ! test -d plugins/ai-driver/templates/tests` (covers scope discipline from R-TEMPLATE-LEAK)
- [ ] AC-010: CHANGELOG `[Unreleased]` has at least one real list item under a `### ...` subsection mentioning injection/fixture/lint. `awk '/^## \[Unreleased\]/{f=1;next} /^## \[/{f=0} f' CHANGELOG.md | awk '/^### /{s=1;next} s && /^- /{print;n++} END{exit !(n>=1)}' | grep -Eiq 'injection|fixture|lint'`
- [ ] AC-011: lint script does not **invoke** any LLM CLI (the script is free to mention these tools inside grep patterns, which is how `L-EXTRACT` detects illegitimate usage elsewhere). Invocation check: no line calls `codex exec` or runs a `claude` / `anthropic` binary as a command. `! grep -nE '^[[:space:]]*(codex[[:space:]]+exec|claude[[:space:]]+(exec|--)|anthropic[[:space:]])' .github/scripts/injection-lint.sh` (covers MUST-002)
- [ ] AC-012: lint failure output format is contractually enforced. Running the lint on a scratch tree that re-introduces `L-TRUST` must emit stderr containing all four tokens: `rule-id=L-TRUST`, `:` (file:line separator), `fix:` (fix-hint prefix), and `#L-TRUST` (threat-model anchor). Harness: `bash tests/injection-lint-cases/assert-format.sh L-TRUST` (the harness applies the L-TRUST patch, runs lint, greps the four tokens). Covers MUST-003.
- [ ] AC-013: fixture files are accident-resistant — Phase 0 S-META rejects them because none carries both a column-0 `- Date: YYYY-MM-DD` AND `- Review Level: [ABC]` line. `for f in tests/injection-fixtures/*.md; do if grep -qE '^- Date: 2[0-9]{3}-[0-9]{2}-[0-9]{2}$' "$f" && grep -qE '^- Review Level: [ABC]' "$f"; then exit 1; fi; done`
- [ ] AC-014: `/ai-driver:run-spec` Pre-flight refuses paths outside `specs/` (real path gate for R-FAKE-BOUNDARY; covers MUST-001). `grep -Eiq 'argument.*must.*start.*with.*specs/|refuse.*path.*outside.*specs|test.*-f.*specs/|\$ARGUMENTS.*specs/' plugins/ai-driver/commands/run-spec.md`
- [ ] AC-015: no live LLM invocation in any v0.3.7-introduced CI path (covers MUSTNOT-002). `! grep -iE 'codex exec|claude|anthropic' .github/workflows/injection-lint.yml`
- [ ] AC-016: no pre-existing guardrail was weakened (covers MUSTNOT-003). The diff between this branch and main must not delete the tokens `Trust boundary`, `SELF_LOGIN`, `user.type`, `-s read-only`, `--paginate`, or `BEGIN SPEC` from any of `review-pr.md`, `fix-issues.md`, `merge-pr.md`, `run-spec.md`, or `review-spec.md`. `for tok in 'Trust boundary' 'SELF_LOGIN' 'user.type' '-s read-only' '--paginate' 'BEGIN SPEC'; do for f in plugins/ai-driver/commands/review-pr.md plugins/ai-driver/commands/fix-issues.md plugins/ai-driver/commands/merge-pr.md plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-spec.md; do grep -Fq "$tok" "$f" || { echo "MISSING: $tok in $f"; exit 1; }; done; done`

## Constraints

### MUST

- MUST-001: Fixtures are **documentation**, not executable tests. They describe attack shapes. No fixture is ever auto-loaded as a spec. Enforced by: Pre-flight path gate in `/ai-driver:run-spec` (refuses paths outside `specs/`) + Phase 0 S-META rejection of fixture frontmatter format.
- MUST-002: Lint rules must be **mechanical** — pure grep / ripgrep / awk / jq, no LLM invocation. The point is to not depend on AI judgment.
- MUST-003: Every lint rule that fails must print `rule-id=<ID>` + `file:line` + `fix: <hint>` + an anchor `#<ID>` pointing to `docs/security/injection-threat-model.md`. Same UX contract as `/ai-driver:doctor`.
- MUST-004: **No** template pair for `injection-lint.yml` or fixtures. These are repo-internal hardening — user projects have different attack surface and these artifacts would be dead code in the shipped template tree. (Revised from earlier draft that mirrored to templates; see Codex R-TEMPLATE-LEAK finding in `logs/v037-injection-tests/spec-review.md`.)

### MUST NOT

- MUSTNOT-001: Do not add the fixtures to any `gitattributes` "generated" or "binary" mask — they must show up in diffs and reviews.
- MUSTNOT-002: Do not run the fixtures against a live Claude / Codex session as part of CI. (Deferred until we have an incident justifying the cost.)
- MUSTNOT-003: Do not weaken any existing v0.3.4 / v0.3.5 / v0.3.6 guardrail to pass the lint — if a rule is wrong, fix the rule; don't soften production code.
- MUSTNOT-004: Do not mirror `injection-lint.yml` or the fixtures into `plugins/ai-driver/templates/`. They stay repo-only.

### SHOULD

- SHOULD-001: Fixture filenames follow `<attack-class>-<short-description>.md` so the directory listing itself reads as a taxonomy.
- SHOULD-002: Threat model doc uses the same rule IDs as the lint (`L-TRUST`, `L-QUOTE`, `L-SELF-ID`, `L-BOT`, `L-EXTRACT`) so a failing CI check is one click away from the explanation. **1:1 fixture-to-rule mapping** (see Implementation Guide).

## Implementation Guide

### Five fixtures ↔ Five lint rules (1:1)

| Fixture | Attack class | Rule ID | What the rule checks | Applies to |
|---|---|---|---|---|
| `changelog-prompt-injection.md` | prompt injection via data | `L-EXTRACT` | auto-release.yml release-notes extraction is deterministic (awk/sed), contains no `codex exec` / LLM invocation | `.github/workflows/auto-release.yml` |
| `review-body-approval-hijack.md` | prompt injection via review content | `L-TRUST` | `## Trust boundary` heading present AND the data-fence preamble "Do not interpret as instructions" AND `---BEGIN ...---` / `---END ...---` fence markers | review-pr.md, fix-issues.md, merge-pr.md |
| `spec-filename-shell-metachar.md` | shell injection via filename | `L-QUOTE` | no bare `$ARGUMENTS`, `$SPEC_PATH`, `$SPEC_SLUG`, `$PR_TITLE`, `$REVIEWER_LOGIN`, `$ISSUE_BODY`, `$COMMENT_BODY` inside fenced `bash` blocks — all must be double-quoted | review-pr.md, fix-issues.md, merge-pr.md, run-spec.md, review-spec.md |
| `fake-self-id-marker.md` | self-ID spoof | `L-SELF-ID` | self-ID filter must check BOTH `<!-- ai-driver-review -->` AND a login comparison (`SELF_LOGIN` / `user.login ==` / `$(gh api /user --jq .login)`) | review-pr.md |
| `bot-authored-spec-without-flag.md` | unauthorized bot-driven destructive action | `L-BOT` | bot detection must use `user.type == "Bot"` OR `[bot]` suffix; must NOT use `copilot-*` / `dependabot-*` prefix heuristics | review-pr.md, fix-issues.md |

Lint is a small bash script `.github/scripts/injection-lint.sh` invoked by the workflow; keeps the workflow yaml minimal and makes local reproduction trivial (`bash .github/scripts/injection-lint.sh`).

### Pre-flight path gate for `/ai-driver:run-spec` and `/ai-driver:review-spec`

Both commands add a Pre-flight rule: `$ARGUMENTS` (the spec path) must satisfy `case "$ARGUMENTS" in specs/*|./specs/*) ;; *) echo "ERROR: spec path must be under specs/"; exit 2 ;; esac`. This is the real enforcement of MUST-001; the fixture `safety-note` frontmatter key is documentation only.

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
