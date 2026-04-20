# v038-subagent-reviews.spec.md

## Meta

- Date: 2026-04-20
- Review Level: B

## Goal

Make every AI-driven review in the three-gate pipeline run inside a **sandboxed executor** — a dedicated Claude Code subagent for the in-session Claude pass, and `codex exec` for the external model pass — rather than inside the main conversational context. The main session never interpolates raw untrusted content into its own prompt; it either (a) passes the content directly to the subagent's prompt, or (b) **stages** the content to a file via `gh ... > /tmp/<path>` redirect (main session's Bash tool sees only the exit code, never the bytes) and hands the path to the subagent. This is the **stage-then-read** pattern; it's what makes the "payload never touches the main session" claim actually true at the tool layer, not just as prose.

This removes three latent problems that the current architecture has:

1. **Injection contamination.** Untrusted content (spec bodies, PR diffs, existing reviewer comments) currently enters the main session's context. The data-fence wrapping introduced in v0.3.4 / v0.3.6 is defense-in-depth, but a subagent is a stronger boundary: the payload never touches the main session at all.
2. **Implementer-reviewer role conflict.** Gate 1 and Gate 3's Claude pass today runs in the same session that is about to implement (Gate 1) or just implemented (Gate 3) the change. Fresh-context review catches classes the implementer is biased to miss.
3. **Gate 2 asymmetry.** Plan review (v0.3.0) is Codex-only; Gate 1 and Gate 3 are dual-LLM. Adding a Claude subagent pass to Gate 2 restores symmetry and unblocks dual-consensus severity upgrades at the plan layer.

The change also codifies the principle as a new operational rule (proposed amendment `R-009: Review Runs In A Sandbox Executor`), governing any future review-flavored command.

Scope: three gates × two axes (Claude subagent + Codex external) = uniform 2×3 matrix. Codex half is unchanged in kind; Claude half moves from "main agent applies checklist" to "main agent spawns a subagent that applies the checklist and returns structured findings".

## User Scenarios

### Scenario 1: Gate 2 plan review becomes dual-LLM (Priority: P0)

**As a** user running `/ai-driver:run-spec specs/foo.spec.md` with `Review Level: B`,
**I want** Phase 1 plan review to run both Claude (via subagent) and Codex (external) adversarially,
**so that** plan-layer defects are caught by the same dual-consensus mechanism as spec and PR layers.

**Acceptance Scenarios:**

1. **Given** a spec with `Review Level: B` and a generated `plan.md`, **When** Phase 1 plan review runs, **Then** two findings tables are written — one from Claude subagent, one from Codex — and a consensus table marks entries raised by both as `dual-raised`.
2. **Given** a spec with `Review Level: A`, **When** Phase 1 runs, **Then** plan review is skipped (both Claude and Codex), consistent with prior behaviour.

**Independent Test Method:** grep `run-spec.md` for two distinct review invocations inside `### Codex Plan Review` (renamed to `### Plan Review` or similar), and verify both are gated behind Review Level ≥ B.

### Scenario 2: Gate 1 Layer 1 migrates to subagent (Priority: P0)

**As a** user running `/ai-driver:run-spec` or `/ai-driver:review-spec`,
**I want** the Claude spec-review pass to run in a subagent, not in the main session,
**so that** hostile spec content cannot contaminate the main session's context via prompt-injection, even if the data-fence wrapping is imperfect.

**Acceptance Scenarios:**

1. **Given** the command docs for `run-spec.md` and `review-spec.md`, **When** Layer 1 runs, **Then** the spec body is passed to a Claude Code subagent (via the `Agent` tool / equivalent), NOT applied directly in the current session's prompt.
2. **Given** a malformed or corrupt spec, **When** Layer 1 runs and the subagent returns non-structured output, **Then** the finding is wrapped as a single Medium `parse-error` entry and the review continues (unchanged from v0.3.6 parser-robustness rule).

**Independent Test Method:** grep for an explicit `Agent` / subagent spawn in the Layer 1 section of both command docs, and assert the main session never quotes raw spec content to Claude except within the subagent prompt.

### Scenario 3: Gate 3 Pass 1 migrates to subagent (Priority: P0)

**As a** user running `/ai-driver:review-pr <N>`,
**I want** the Claude Pass 1 review to run in a subagent,
**so that** a malicious PR author cannot inject instructions into my main session by posting a hostile review comment, PR body, or diff comment — the attack surface that fixture `review-body-approval-hijack.md` documents.

**Acceptance Scenarios:**

1. **Given** a PR with an existing Copilot review and a Claude Pass 1 invocation, **When** Pass 1 runs, **Then** the main session stages the PR artifacts to local tempfiles via `gh … > /tmp/pr-<N>-<artifact>.json` (stdout redirected, never captured), then spawns a Claude subagent whose prompt names those paths. Only the subagent's structured findings return to the main session.
2. **Given** a PR whose review body contains raw untrusted content, **When** Pass 1 runs, **Then** the `review-pr.md` doc shows **no** pattern of the form "`gh pr view … --json body` → interpolate `$BODY` into a prompt". All untrusted ingestion goes through `>` redirect + subagent file-read. (Structural invariant — shell-checkable by grepping the doc for `gh pr view|gh api` blocks and asserting they all end with a redirect operator.)

**Independent Test Method:** grep `review-pr.md` Pass 1 section for (a) explicit subagent spawn, (b) at least one `gh … > /tmp/` redirect pattern, (c) no occurrence of `$PR_BODY` or `$REVIEW_BODY` being interpolated into non-subagent text.

### Scenario 4: Degraded mode when subagent unavailable (Priority: P0)

**As a** user whose subagent spawning fails (tool disabled, runtime error, environment without subagent support),
**I want** the review to degrade gracefully to Codex-only + a visible warning,
**so that** the framework remains usable in constrained environments.

**Acceptance Scenarios:**

1. **Given** subagent spawn returns an error, **When** any gate runs its Claude pass, **Then** the log records `CLAUDE-PASS: UNAVAILABLE (<reason>)`, a visible warning is printed, and the run proceeds with Codex-only findings. Gating thresholds still apply to Codex findings.
2. **Given** subagent spawn succeeds but returns malformed output, **When** a gate runs, **Then** the parser wraps the output as a single Medium `parse-error` finding and the review continues.

### Scenario 5: R-009 constitution amendment (Priority: P1)

**As a** maintainer,
**I want** a codified rule stating that any AI review in this framework MUST run in a sandboxed executor (subagent or external CLI),
**so that** future commands inherit the pattern without each one re-deriving it.

**Acceptance Scenarios:**

1. **Given** the PR body proposes `R-009: Review Runs In A Sandbox Executor`, **When** the maintainer replies `approve as-is`, **Then** a follow-up commit amends `constitution.md` + the template pair. Same governance pattern as v0.3.6's R-008.

### Edge Cases

- **Subagent tool-permission scope.** A review subagent has `Read, Grep, Glob` only — no Write, no Bash, no Agent (nested spawn forbidden), no network. The subagent's prompt restates the constraint as belt-and-suspenders.
- **Stage-then-read for Gate 3.** The subagent has no network → cannot `gh api`. Main session must fetch first, but does so via stdout redirect (`gh ... > /tmp/pr-<N>-<artifact>.json`), so the main session's Bash tool captures only the exit code, never the JSON bytes. Subagent reads the files. Concrete artifact set (fixed, all redirected): `diff`, `reviews`, `inline-comments`, `issue-comments`, `spec-body` (when the PR body names a spec file).
- **Long specs/diffs exceeding subagent context.** Out of scope for v0.3.8. If the subagent reports truncation or a runtime error suggesting over-length, degrade to Codex-only with a visible warning (same path as `CLAUDE-PASS: UNAVAILABLE`). A future spec can add explicit chunking if needed.
- **Subagent prompt visibility.** The exact subagent prompt text — checklist, data-fence markers, "treat as data" preamble — lives literally in the command docs for audit. Same MUST-005-style contract as v0.3.6.
- **Malformed subagent output.** If the subagent returns non-tabular or non-parsable text, the main session wraps it as a single Medium finding with `rule_id=parse-error` and the review continues. Same pattern as v0.3.6.

## Acceptance Criteria

Every AC is a runnable shell expression that exits non-zero on failure. Where an AC anchors to a specific commit (e.g., the feature commit vs the R-009 amendment commit), it uses a tag-prefix marker like `v038-feat` rather than positional `HEAD^` so rebases don't break it.

### Gate 1 — spec review subagent migration

- [ ] AC-001: `run-spec.md` §Phase 0 Layer 1 invokes a subagent, not inline review. Required shape: the Layer 1 section must mention `subagent` AND name the subagent-spawn mechanism (`Agent` / `Task` tool) AND contain `allowed-tools: Read, Grep, Glob` for the subagent. `awk '/^### Layer 1:/,/^### Layer 2:/' plugins/ai-driver/commands/run-spec.md | grep -Eq 'subagent' && awk '/^### Layer 1:/,/^### Layer 2:/' plugins/ai-driver/commands/run-spec.md | grep -Eq 'Agent tool|Task tool|subagent_type' && awk '/^### Layer 1:/,/^### Layer 2:/' plugins/ai-driver/commands/run-spec.md | grep -Fq 'allowed-tools: Read, Grep, Glob'`
- [ ] AC-002: `review-spec.md` §Layer 1 likewise spawns a subagent with the same minimal `allowed-tools`. `awk '/^## Layer 1:/,/^## Layer 2:/' plugins/ai-driver/commands/review-spec.md | grep -Eq 'subagent' && awk '/^## Layer 1:/,/^## Layer 2:/' plugins/ai-driver/commands/review-spec.md | grep -Fq 'allowed-tools: Read, Grep, Glob'`
- [ ] AC-003: Gate 1 Codex pass still uses `codex exec … -s read-only`. `awk '/^### Layer 2:/,/^### Write review log/' plugins/ai-driver/commands/run-spec.md | grep -Fq '-s read-only' && awk '/^## Layer 2:/,/^## Consensus/' plugins/ai-driver/commands/review-spec.md | grep -Fq '-s read-only'`

### Gate 2 — plan review becomes dual-LLM

- [ ] AC-004: Phase 1 plan review invokes BOTH a Claude subagent AND Codex. `awk '/^### Plan Review|### Codex Plan Review/,/^## Phase 2:/' plugins/ai-driver/commands/run-spec.md | grep -Eq 'subagent' && awk '/^### Plan Review|### Codex Plan Review/,/^## Phase 2:/' plugins/ai-driver/commands/run-spec.md | grep -Fq 'codex exec' && awk '/^### Plan Review|### Codex Plan Review/,/^## Phase 2:/' plugins/ai-driver/commands/run-spec.md | grep -Fq '-s read-only'`
- [ ] AC-005: plan review gated by `Review Level >= B` (both passes skip at Level A). `awk '/^### Plan Review|### Codex Plan Review/,/^## Phase 2:/' plugins/ai-driver/commands/run-spec.md | grep -Eq 'Review Level.*(B|>=)'`

### Gate 3 — PR review Pass 1 subagent + stage-then-read

- [ ] AC-006: `review-pr.md` Pass 1 spawns a subagent with minimal `allowed-tools`. `awk '/^## Step 3|^## Pass 1/,/^## Step 4|^## Pass 2/' plugins/ai-driver/commands/review-pr.md | grep -Eq 'subagent' && awk '/^## Step 3|^## Pass 1/,/^## Step 4|^## Pass 2/' plugins/ai-driver/commands/review-pr.md | grep -Fq 'allowed-tools: Read, Grep, Glob'`
- [ ] AC-007: PR artifacts are fetched via stdout redirect (stage-then-read). `grep -Eq 'gh (pr|api)[^|\n]+>[[:space:]]*/tmp/pr-' plugins/ai-driver/commands/review-pr.md`
- [ ] AC-008: Gate 3 Codex pass still `-s read-only`. `awk '/^## Step 4|^## Pass 2/,/^## Step 5|^## Step 6/' plugins/ai-driver/commands/review-pr.md | grep -Fq '-s read-only'`
- [ ] AC-009: `review-pr.md` never interpolates raw reviewer/PR body text into main-session prompts — all ingestion goes through `> /tmp/…` redirects. Structural check: no `--jq '.body'` or `$PR_BODY` / `$REVIEW_BODY` interpolation outside of a `> …` pipeline. `! grep -nE '\$(PR_BODY|REVIEW_BODY|COMMENT_BODY)([^A-Za-z0-9_]|$)' plugins/ai-driver/commands/review-pr.md | grep -v '>[[:space:]]*/tmp'`

### Literal prompts + degraded mode

- [ ] AC-010: all three gates store literal subagent/Codex prompt blocks in-repo (auditable). `for f in plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-spec.md plugins/ai-driver/commands/review-pr.md; do grep -Eq '(subagent prompt|Pass 1 prompt|Layer 1 prompt|Plan review prompt) \(literal\)' "$f" || exit 1; done`
- [ ] AC-011: degraded-mode contract present in each gate — the literal string `CLAUDE-PASS: UNAVAILABLE` AND fallback behavior described. `for f in plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-spec.md plugins/ai-driver/commands/review-pr.md; do grep -Fq 'CLAUDE-PASS: UNAVAILABLE' "$f" || exit 1; done`
- [ ] AC-012: `rule_id=parse-error` fallback for malformed subagent output present. `for f in plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-spec.md plugins/ai-driver/commands/review-pr.md; do grep -Fq 'parse-error' "$f" || exit 1; done`
- [ ] AC-013: `dual-raised` matching key explicitly defined as `rule_id + normalized location`. `grep -Fq 'rule_id + normalized location' plugins/ai-driver/commands/review-spec.md`

### Non-weakening / regression guards

- [ ] AC-014: Trust boundary heading intact across all untrusted-data-consuming commands. `for f in plugins/ai-driver/commands/review-pr.md plugins/ai-driver/commands/fix-issues.md plugins/ai-driver/commands/merge-pr.md plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-spec.md; do grep -Fq '## Trust boundary' "$f" || exit 1; done`
- [ ] AC-015: v0.3.7 injection-lint still passes. `bash .github/scripts/injection-lint.sh >/dev/null`
- [ ] AC-016: regression harness passes (5 L-* rules still catch their anti-patterns). `bash tests/injection-lint-cases/run.sh >/dev/null 2>&1`
- [ ] AC-017: Phase 0 Layer 0 rule set unchanged. `for rule in S-META S-GOAL S-SCENARIO S-AC-COUNT S-AC-FORMAT S-CLARIFY S-PLACEHOLDER; do awk '/^## Phase 0: Spec Review/,/^## Phase 1:/' plugins/ai-driver/commands/run-spec.md | grep -Fq "$rule" || exit 1; done`
- [ ] AC-018: path gates in run-spec.md + review-spec.md intact (v0.3.7 AC-014 shape). `for f in plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-spec.md; do grep -Eq 'case[[:space:]]+"?\$(ARGUMENTS|SPEC_PATH)"?[[:space:]]+in' "$f" && grep -Fq '*..*' "$f" && grep -Fq 'pwd -P' "$f" && grep -Fq 'cd specs' "$f" || exit 1; done`
- [ ] AC-019: `review-spec.md` `allowed-tools` still excludes Write / mkdir (v0.3.6 TOOLS-001 fix stays). `grep -q '^allowed-tools:' plugins/ai-driver/commands/review-spec.md && ! awk '/^---$/{c++; next} c==1' plugins/ai-driver/commands/review-spec.md | grep -E '^allowed-tools:' | grep -iE '\b(Edit|NotebookEdit|WebFetch|WebSearch|MultiEdit|Write|Bash\(mkdir)' | grep -q .`
- [ ] AC-020: no pre-existing guardrail tokens deleted in any command doc (same shape as v0.3.7 AC-016). `for tok in 'Trust boundary' 'SELF_LOGIN' 'user.type' '-s read-only' '--paginate' 'BEGIN SPEC'; do for f in plugins/ai-driver/commands/review-pr.md plugins/ai-driver/commands/fix-issues.md plugins/ai-driver/commands/merge-pr.md plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-spec.md; do if git show "origin/main:$f" 2>/dev/null | grep -Fq "$tok"; then grep -Fq "$tok" "$f" || exit 1; fi; done; done`

### Docs sync

- [ ] AC-021: README.md + README.zh-CN.md workflow diagram shows Gate 2 as dual-LLM (no longer "Codex-only"). `! grep -Fq 'Codex-only' README.md && ! grep -Fq 'Codex-only' README.zh-CN.md`
- [ ] AC-022: AGENTS.md names subagent / sandbox-executor in the three-gate paragraph. `grep -Eiq 'subagent|sandbox executor' AGENTS.md`
- [ ] AC-023: CHANGELOG `[Unreleased]` has ≥1 bullet mentioning subagent / sandbox / R-009. `awk '/^## \[Unreleased\]/{f=1;next} /^## \[/{f=0} f' CHANGELOG.md | awk '/^### /{s=1;next} s && /^- /{print;n++} END{exit !(n>=1)}' | grep -Eiq 'subagent|sandbox|R-009'`

### Governance (manual, tracked on the PR not as a mechanical AC)

- **R-009 amendment** is proposed in the PR body. The maintainer's explicit approval (as a PR comment) unlocks a follow-up commit amending `constitution.md` + the template pair. No mechanical AC — the PR description + the comment thread are the audit trail, same pattern v0.3.6 used for R-008. `constitution.md` **not** modified in the feature commit; post-approval amendment is a separate commit on this PR. Verification: after the release, `git log v<NEXT> -- constitution.md` shows exactly one new commit touching the file with a message referencing the approval.

## Constraints

### MUST

- MUST-001: Every gate's Claude pass runs inside a subagent, never inline in the main session.
- MUST-002: Every gate's Codex pass continues to use `codex exec -s read-only`. No change in kind.
- MUST-003: Subagent prompts are stored as **literal audited blocks** in the command docs, same contract as v0.3.6 MUST-005. No runtime construction.
- MUST-004: Subagent `allowed-tools` is minimal — Read, Grep, Glob only. No Write, no Bash (other than read-only `Bash(cat:*)`/`Bash(grep:*)` if strictly needed), no Agent (nested spawn forbidden).
- MUST-005: Degraded mode is identical in shape across all three gates: `CLAUDE-PASS: UNAVAILABLE (<reason>)` or `PARSE_ERROR`, recorded in the same log location, with a visible warning.
- MUST-006: Finding schema stays `severity | rule_id | location | message | fix_hint`. Subagent output is parsed into this schema; malformed output becomes a single `parse-error` finding.

### MUST NOT

- MUSTNOT-001: Do not bypass any existing v0.3.4 / v0.3.5 / v0.3.6 / v0.3.7 guardrail. Subagent replaces only the **how** of the Claude pass; the trust-boundary language, data fences, path gates, and injection-lint rules all remain.
- MUSTNOT-002: Do not weaken `review-spec.md`'s `allowed-tools` lockdown (still no Write, no mkdir).
- MUSTNOT-003: Do not amend `constitution.md` in this spec's feature commit. R-009 is proposed in the PR body; amendment requires explicit human approval, applied as a separate commit on this PR (same pattern as R-008 in v0.3.6).
- MUSTNOT-004: Do not spawn review subagents recursively — a review subagent must NOT call `Agent` / any nested-spawn tool.

### SHOULD

- SHOULD-001: Use the same subagent type across all three Claude passes where possible (e.g., `general-purpose` or a new `review-runner` definition) to keep the audited prompt structurally consistent.
- SHOULD-002: Each subagent call's output log is written to `logs/<spec-slug>/gate-<N>-claude.md` (Gate 1/2/3) so the review trail is fully reconstructable.
- SHOULD-003: Propose R-009 constitution amendment in the PR body. Approval → follow-up commit updates `constitution.md` + template pair.

## Implementation Guide

Behavioural invariants only. Exact subagent-spawn syntax lives in the command docs.

### Stage-then-read for Gate 3

Subagents have no network (MUST-004 — `Read, Grep, Glob` only). For Gate 3 the main session must therefore fetch PR artifacts first, but crucially **without capturing the content into its own context**:

```bash
# Main session, using Bash tool. `>` redirects stdout to a file;
# the Bash tool's output is just the exit code, so the main session's
# context window never contains the untrusted bytes.
gh pr diff "$PR"                                         > /tmp/pr-$PR-diff.txt
gh api --paginate "/repos/$OWNER/$REPO/pulls/$PR/reviews" > /tmp/pr-$PR-reviews.json
gh api --paginate "/repos/$OWNER/$REPO/pulls/$PR/comments" > /tmp/pr-$PR-inline.json
gh api --paginate "/repos/$OWNER/$REPO/issues/$PR/comments" > /tmp/pr-$PR-issue.json

# Then spawn the subagent, passing ONLY the paths + PR number:
#   Agent(subagent_type: <review-runner>, prompt: "Review PR $PR. Read: /tmp/pr-$PR-*.{txt,json}. <literal checklist>.")
```

The subagent reads those files with its `Read` permission. Its findings return as structured Markdown table text, which the main session parses into the standard schema. The raw JSON bodies never enter the main session's conversation.

This is what makes the trust boundary **architectural** rather than **prose**: tooling prevents the leak, not discipline.

### Per-gate migration shape

- **Gate 1 (spec review)**: `/ai-driver:run-spec` Phase 0 §Layer 1 and `/ai-driver:review-spec` §Layer 1 both replace "main agent applies checklist" with an `Agent` spawn. The subagent's `allowed-tools` is the literal string `Read, Grep, Glob`. The main session passes the spec path (already validated by the path gate) plus the literal Layer 1 prompt; the subagent reads the spec from disk.
- **Gate 2 (plan review)**: Phase 1 section is renamed from "Codex Plan Review" to "Plan Review" and adds a subagent-Claude pass before the existing Codex pass. Review Level ≥ B gating is unchanged; both passes run together or neither runs.
- **Gate 3 (PR review)**: `/ai-driver:review-pr` Pass 1 becomes a subagent spawn, following the stage-then-read pattern above. The existing-reviewer ingestion, trust-boundary wrapping, and triple-consensus logic all remain; the change is WHERE the Claude pass runs and HOW the data is handed to it.

### Degraded mode — exact strings

On any failure path, write the literal string `CLAUDE-PASS: UNAVAILABLE (<reason>)` to the review log and emit a visible warning to stdout. Reasons: `subagent spawn failed`, `subagent returned error`, `subagent output could not be parsed as findings table`, `input too large` (for future chunking). `<reason>` is prose, not parsed — but the `CLAUDE-PASS: UNAVAILABLE` prefix is literal and checked by AC-011.

On malformed output (parseable as text but not as the expected table), the main session wraps the output as a single finding `{severity: Medium, rule_id: parse-error, location: "<gate>:<path>", message: <first 200 chars of output>, fix_hint: "subagent returned non-table text; rerun with --verbose or regenerate the prompt"}`.

### Consensus matching key

`dual-raised` requires matching on **`(rule_id, normalized_location)`**. Normalization rules: lowercase the rule_id; strip surrounding whitespace and trailing punctuation from location; if location is `file:line`, match on file-basename + line-number allowing ±3-line fuzziness for Codex line-offset drift. If Codex and subagent raise the same rule_id but on genuinely different locations, they are **separate rows**, not dual-raised.

### R-009 amendment (proposed text, not applied in feature commit)

```
### R-009: Review Runs In A Sandbox Executor (from P1, P4)
Every AI review in this framework MUST run inside a sandboxed executor — a
Claude Code subagent for the in-session Claude pass, `codex exec` for the
external pass. Main-session inline review is prohibited. When a reviewer
needs untrusted external data (PR bodies, issue threads, reviewer comments),
the main session stages it to files via shell redirects; it never
interpolates the raw content into its own prompt.

Rationale: isolates untrusted-data contamination at the tool layer
(defense-in-depth over the data-fence prose) and separates the
implementer role from the reviewer role so implementation bias does
not mask defects.
```

Governance: amendment requires explicit human approval per `constitution.md` §Governance. Proposed in the PR body; user replies `approve as-is` / `approve with edits: …` / `reject: …`. Approval triggers a follow-up commit on the same PR that amends `constitution.md` + `plugins/ai-driver/templates/constitution.md`. Feature commit does NOT touch `constitution.md`.

### Docs sync

- `README.md` + `README.zh-CN.md` workflow diagram: Gate 2 updated to "subagent (Claude) + Codex" on both sides of the arrow. Remove any "Codex-only" wording. Drop the "optional / Review Level ≥ B" parenthetical from the line — gating stays but the asymmetry story it justified is now symmetric.
- `AGENTS.md`: three-gate paragraph names "subagent isolation" as the enforcement mechanism, not "data fences alone".
- `docs/security/injection-threat-model.md`: add `<a id="R-009"></a>` anchor with a reference to the stage-then-read pattern as the mitigation for Gate 3's review-body-approval-hijack class.

## References

- v0.3.4 comment-aware review: `specs/comment-aware-review.spec.md`
- v0.3.6 spec review: `specs/v036-spec-review.spec.md`
- v0.3.7 injection hardening: `specs/v037-injection-tests.spec.md`
- `tests/injection-fixtures/review-body-approval-hijack.md` — the attack class subagent isolation directly mitigates.
- `docs/security/injection-threat-model.md` — will get an `<a id="R-009"></a>` anchor on merge.

## Needs Clarification

None.
