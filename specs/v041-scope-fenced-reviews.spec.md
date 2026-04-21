# Scope-Fenced Reviews

## Meta

- Date: 2026-04-21
- Review Level: B

## Goal

Each of the three review gates (spec review, plan review, PR review) gets a **stage-specific prompt** that fences reviewer focus to that stage's concerns, and every actionable finding must cite an **anchor** from that stage's whitelist. Findings without a whitelisted anchor are routed to a non-blocking `Observations` section — they are visible to the human but do NOT count toward the Verdict. This eliminates review-scope drift (reviewer pushing the PR beyond the spec's stated goal) which has been observed repeatedly: the v0.3.10 spec review looped for 6 Codex rounds, and PR #14 Codex adversarial flagged historical-spec staleness outside the PR's actual scope.

## User Scenarios

### Scenario 1: Spec review fences to spec concerns (Priority: P1)

**As a** spec author running `/ai-driver:review-spec`,
**I want** the reviewer to critique only the spec's structural qualities (goal clarity, scope, MUST coverage, AC executability, ambiguity),
**so that** review findings are actionable at the spec stage and do not propose implementation details or code-level defects that belong to a later gate.

**Acceptance Scenarios:**

1. **Given** a spec with one ambiguous AC ("the system should behave correctly"), **When** `/ai-driver:review-spec` runs, **Then** Claude Pass 1 and Codex Pass 2 each emit at least one finding with anchor prefix `[spec:ac-executable]` or `[spec:ambiguity]`, and NO finding with anchor prefix `[diff:*]`, `[test:*]`, or `[AC-*]`.
2. **Given** an otherwise-clean spec, **When** `/ai-driver:review-spec` runs, **Then** no finding's `message` field discusses code style, architectural preference, or test implementation.

**Independent Test Method:** seed a spec file with a planted ambiguity, run `/ai-driver:review-spec`, grep the generated `logs/<slug>/spec-review.md` for allowed vs forbidden anchor prefixes.

### Scenario 2: PR review fences to diff-vs-spec (Priority: P1)

**As a** PR author running `/ai-driver:review-pr`,
**I want** the reviewer to verify the diff satisfies the spec's AC / MUST / R-NNN, plus flag concrete diff-level bugs,
**so that** unrelated concerns (historical spec staleness, adjacent cleanup, architectural alternatives) do not block a PR whose stated goal is satisfied.

**Acceptance Scenarios:**

1. **Given** a PR whose diff satisfies every AC in its spec, and a historical spec at `specs/v03*/...` references a symbol the diff deleted, **When** `/ai-driver:review-pr` runs, **Then** the historical-spec staleness appears in the `Observations` section (not in `Pass 1 findings` or `Pass 2 findings`), and the Verdict is `APPROVE`.
2. **Given** a PR whose diff fails AC-005, **When** `/ai-driver:review-pr` runs, **Then** at least one HIGH/CRITICAL finding carries anchor prefix `[AC-005]`.

**Independent Test Method:** replay PR #14's scenario (Codex flagged historical spec staleness) — the new prompt must emit those findings as Observations, not HIGH.

### Scenario 3: Out-of-domain anchor demotion (Priority: P2)

**As a** framework maintainer,
**I want** mis-anchored findings to be mechanically demoted, not human-arbitrated,
**so that** a reviewer that ignores the scope fence cannot smuggle out-of-scope findings into the Verdict by picking a plausible-sounding anchor.

**Acceptance Scenarios:**

1. **Given** the PR-review subagent returns a finding with anchor `[spec:goal]` (spec-review anchor, out of domain for PR review), **When** synthesis runs, **Then** the finding is moved to `Observations` with a tag `(anchor-out-of-domain: [spec:goal])` and is NOT counted toward HIGH/CRITICAL tally for Verdict computation.
2. **Given** any reviewer returns a finding with no anchor prefix, **When** synthesis runs, **Then** the finding is moved to `Observations` with tag `(no-anchor)` and capped at severity `Info`.

**Independent Test Method:** feed the synthesis step a synthetic finding table with 3 rows (one in-domain, one out-of-domain, one no-anchor). The synthesized output MUST have 1 row in the main findings table and 2 rows in Observations.

### Edge Cases

- **Legitimate cross-stage observation.** A PR reviewer notices the spec was genuinely under-specified for a case that surfaced during implementation. Handle via `[observation:spec-gap]` — recorded, human can open a follow-up spec PR; does not block current PR.
- **Anchor typo.** Reviewer emits `[AC-7]` (wrong digit count) or `[AC-100500]` (out-of-range). Synthesis treats any `[AC-xxx]` where `xxx` does not match a real AC in the loaded spec as `(anchor-out-of-domain)`, demoted.
- **Spec absent.** `/ai-driver:review-pr` on a PR with no `specs/**/*.spec.md` link in the body (cleanup/chore PR like #14). PR review stage-whitelist still applies; `[AC-*]`, `[MUST-*]`, and `[MUSTNOT-*]` anchors are disallowed (no spec to reference), only `[R-NNN]`, `[P-N]`, `[test:*]`, `[diff:*]`, `[observation:*]` remain valid.

## Acceptance Criteria

Each item is a runnable shell expression; exit 0 = pass, non-zero = fail.

- [ ] AC-001: Spec-review Layer 1 prompt contains the stage-specific Focus list (goal, scope, MUST coverage, AC executability, ambiguity, contradiction) AND an explicit "Out of scope (spec review)" list that names code / architecture / test implementation. `grep -Fzq 'Focus (spec review):' plugins/ai-driver/commands/review-spec.md && grep -Fzq 'Out of scope (spec review):' plugins/ai-driver/commands/review-spec.md`

- [ ] AC-002: Spec-review Layer 2 (Codex) prompt mirrors AC-001's Focus + Out-of-scope contract. `test "$(grep -c 'Focus (spec review):' plugins/ai-driver/commands/review-spec.md)" -ge 2 && test "$(grep -c 'Out of scope (spec review):' plugins/ai-driver/commands/review-spec.md)" -ge 2`

- [ ] AC-003: `/ai-driver:run-spec` Phase 0 Layer 1 prompt carries the same Focus + Out-of-scope contract as `/ai-driver:review-spec` Layer 1 (the two are semantically equivalent gates). `grep -Fzq 'Focus (spec review):' plugins/ai-driver/commands/run-spec.md && grep -Fzq 'Out of scope (spec review):' plugins/ai-driver/commands/run-spec.md`

- [ ] AC-004: `/ai-driver:run-spec` Phase 1 plan-review is dual-LLM (subagent + Codex), so both prompt blocks MUST carry `Focus (plan review):` + `Out of scope (plan review):`. `test "$(grep -c 'Focus (plan review):' plugins/ai-driver/commands/run-spec.md)" -ge 2 && test "$(grep -c 'Out of scope (plan review):' plugins/ai-driver/commands/run-spec.md)" -ge 2`

- [ ] AC-005: `/ai-driver:review-pr` Pass 1 subagent prompt AND Pass 2 Codex prompt each carry `Focus (PR review):` + `Out of scope (PR review):`. `test "$(grep -c 'Focus (PR review):' plugins/ai-driver/commands/review-pr.md)" -ge 2 && test "$(grep -c 'Out of scope (PR review):' plugins/ai-driver/commands/review-pr.md)" -ge 2`

- [ ] AC-006: Every stage prompt declares its anchor whitelist (exact tokens) inline. `for pair in 'review-spec.md:[spec:goal]' 'review-spec.md:[spec:ac-executable]' 'run-spec.md:[plan:ac-uncovered]' 'run-spec.md:[plan:task-atomic]' 'review-pr.md:[AC-xxx]' 'review-pr.md:[diff:'; do f="${pair%%:*}"; pat="${pair#*:}"; grep -Fq "$pat" "plugins/ai-driver/commands/$f" || { echo "missing: $pair"; exit 1; }; done`

- [ ] AC-007: `/ai-driver:review-pr` Step 5 (synthesis) explicitly specifies the `Observations` section and the three demotion tags (`anchor-out-of-domain`, `no-anchor`, `anchor-requires-spec`). `grep -Fq 'Observations' plugins/ai-driver/commands/review-pr.md && grep -Fq 'anchor-out-of-domain' plugins/ai-driver/commands/review-pr.md && grep -Fq 'no-anchor' plugins/ai-driver/commands/review-pr.md && grep -Fq 'anchor-requires-spec' plugins/ai-driver/commands/review-pr.md`

- [ ] AC-008: `/ai-driver:run-spec` Gating section (Phase 0 + Phase 1) references the same Observations / demotion rule with the `anchor-out-of-domain` and `no-anchor` tags (the third tag `anchor-requires-spec` is PR-only and does not apply inside run-spec). `grep -Fq 'Observations' plugins/ai-driver/commands/run-spec.md && grep -Fq 'anchor-out-of-domain' plugins/ai-driver/commands/run-spec.md && grep -Fq 'no-anchor' plugins/ai-driver/commands/run-spec.md`

- [ ] AC-009: Verdict computation counts only findings with in-domain anchors. PR review report format in `review-pr.md` Step 6 places sections in order `Pass 1` → `Pass 2` → `Observations` → `Verdict`, AND contains the explicit prose "Verdict computation excludes Observations". `awk '/^### Pass 1/{p1=NR} /^### Pass 2/{p2=NR} /^### .*[Oo]bservations/{obs=NR} /^### Verdict/{v=NR} END{exit !(p1 && p2 && obs && v && p1<p2 && p2<obs && obs<v)}' plugins/ai-driver/commands/review-pr.md && grep -Fq 'Verdict computation excludes Observations' plugins/ai-driver/commands/review-pr.md

- [ ] AC-010: AGENTS.md updated to reference the new contract so future contributors (human or AI) understand the anchor discipline. `grep -Fq 'scope-fenced' AGENTS.md || grep -Fq 'anchor whitelist' AGENTS.md`

- [ ] AC-011: Deterministic drift-demotion harness covers all three stages (spec / plan / PR) AND the no-spec PR edge case. For each of the three stages the harness feeds a fabricated reviewer output containing one in-domain finding, one out-of-domain finding (anchor from a different stage's whitelist), and one no-anchor finding, then asserts: (a) in-domain finding appears in the main findings table with its original severity, (b) out-of-domain finding appears in Observations tagged `anchor-out-of-domain: <anchor>` at severity Info, (c) no-anchor finding appears in Observations tagged `no-anchor` at severity Info, (d) original `message` text, source (Claude / Codex / existing reviewer), and original severity + anchor string (or its absence) are preserved byte-for-byte in the Observations rows, (e) Verdict computation excludes Observations — a lone no-anchor Critical input yields APPROVE while a lone in-domain Critical yields REQUEST_CHANGES. Additionally, a fourth fixture covers PR review with NO spec loaded: input contains findings anchored `[AC-005]`, `[MUST-003]`, `[MUSTNOT-001]`, `[R-005]`, `[test:foo]`, `[diff:x.md:10]`; assert that `[AC-*]`, `[MUST-*]`, `[MUSTNOT-*]` are demoted to Observations with tag `anchor-requires-spec` while `[R-*]`, `[test:*]`, `[diff:*]` remain as actionable findings. `bash tests/review-synthesis/drift-demotion.sh` (new deterministic harness under `tests/review-synthesis/`, no LLM invocation).

- [ ] AC-013: Standalone `/ai-driver:review-spec` Consensus-and-gating section mirrors `/ai-driver:run-spec` Phase 0 Observations / demotion contract (third review gate parity). `grep -Fq 'Observations' plugins/ai-driver/commands/review-spec.md && grep -Fq 'anchor-out-of-domain' plugins/ai-driver/commands/review-spec.md && grep -Fq 'no-anchor' plugins/ai-driver/commands/review-spec.md`

- [ ] AC-012: Defense regression guard — v0.4.0 surviving first-line defenses must still be present in the three review commands after this PR. (a) `allowed-tools: Read, Grep, Glob` (exact literal, or the equivalent frontmatter form for `review-spec.md`) appears in each review prompt's subagent-spawn section. (b) `-s read-only` appears wherever `codex exec` is dispatched. (c) `mktemp -d` appears in `review-pr.md` Step 2a (stage-then-read). (d) Path-gate canonicalization `pwd -P` appears in `run-spec.md` AND `review-spec.md` Pre-flight. `for f in plugins/ai-driver/commands/review-spec.md plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-pr.md; do grep -Fq -- 'Read, Grep, Glob' "$f" || exit 1; done && for f in plugins/ai-driver/commands/review-spec.md plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-pr.md; do grep -Fq -- '-s read-only' "$f" || exit 1; done && grep -Fq -- 'mktemp -d' plugins/ai-driver/commands/review-pr.md && for f in plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-spec.md; do grep -Fq -- 'pwd -P' "$f" || exit 1; done`

## Constraints

### MUST

- MUST-001: **Every actionable finding carries an anchor from its stage whitelist.** The whitelist is:
  - Spec review: `[spec:goal]`, `[spec:scope]`, `[spec:must-coverage]`, `[spec:ac-executable]`, `[spec:ambiguity]`, `[spec:contradiction]`, `[spec:over-specification]`
  - Plan review: `[plan:ac-uncovered]`, `[plan:task-atomic]`, `[plan:dependency]`, `[plan:reuse]`, `[plan:risk]`, `[plan:feasibility]`
  - PR review: `[AC-xxx]`, `[MUST-NNN]`, `[MUSTNOT-NNN]`, `[R-NNN]`, `[P-N]`, `[test:<name>]`, `[diff:<file>:<line>]`
  - Always permitted (all stages): `[observation:<short-tag>]` — for non-blocking cross-stage notes

  **Anchor parse rule (normative).** The anchor is the leading bracketed token of the `message` cell, matching the regex `^\[[^\]]+\]` after stripping leading whitespace. A `message` that does not start with `[` has no anchor. If multiple bracketed tokens appear, only the first counts toward domain membership — the remainder are prose. Bracketed text inside backticks, fenced code, or quoted strings within the message body is NOT the anchor. The anchor MUST be a literal `[...]` at message start.
- MUST-002: **Findings are mechanically demoted** to the `Observations` section at synthesis time, capped at severity `Info`, and do NOT contribute to the HIGH/CRITICAL tally the Verdict uses. Three demotion reasons (tags in the Observations row):
  - `anchor-out-of-domain: <anchor>` — **any** bracketed anchor not valid for the current stage. Covers (a) anchors from a different stage's whitelist (e.g. `[spec:goal]` raised during PR review), (b) unknown anchors (e.g. `[security]`, `[plan:oops]`), (c) anchors with malformed or non-existent IDs (e.g. `[AC-7]` wrong digit count, `[AC-100500]` out-of-range, `[MUST-unknown]` no such MUST in the loaded spec)
  - `no-anchor` — `message` cell does not start with a literal `[...]` token
  - `anchor-requires-spec: <anchor>` — anchor is `[AC-*]`, `[MUST-*]`, or `[MUSTNOT-*]` but the PR review loaded no spec (chore/cleanup PR)
- MUST-003: **Stage prompts are isolated.** Each review gate's prompt names only its own Focus list and only its own Out-of-scope list. A spec-review prompt must not **solicit** code-level findings (it may and should list code / architecture / test-implementation in its Out-of-scope list, as explicit exclusions); a PR-review prompt must not **solicit** spec-authorship findings (it may and should list spec re-debate in its Out-of-scope list). The distinction is: listing a concern as Out-of-scope is permitted and expected; framing it as a Focus dimension is forbidden.
- MUST-004: **Observations are recorded, not dropped.** Even when demoted, the original finding text, anchor (or lack thereof), and source (Claude / Codex / existing reviewer) are preserved in the Observations section so the human can see what the reviewer wanted to say.

### MUST NOT

- MUSTNOT-001: Do NOT add new slash commands or new constitutional rules (R-010+) in this PR. The scope fence is a prompt-and-synthesis change, nothing more.
- MUSTNOT-002: Do NOT weaken any first-line defense surviving v0.4.0 (subagent `allowed-tools: Read, Grep, Glob`, `codex exec -s read-only`, stage-then-read handoff, path gates). The scope fence is additive to those defenses, not a replacement.
- MUSTNOT-003: Do NOT require reviewers to emit machine-parseable JSON. The output stays Markdown tables with a human-readable anchor prefix in the `message` cell. Simplicity is the point.

### SHOULD

- SHOULD-001: Prefer tightening existing prompt prose over inventing new sections.
- SHOULD-002: Keep the anchor whitelist under 10 tokens per stage. If a stage legitimately needs more, something else is wrong.
- SHOULD-003: Run `/ai-driver:review-pr` on THIS PR itself (dogfood) — with the new prompts — as the primary validation that the new contract does not regress.

## Known Limitations (accepted scope of the fence)

The scope fence is an **anchor-level** mechanism. It does NOT prevent a reviewer from laundering an out-of-scope complaint behind a plausible in-domain anchor like `[AC-005] the test is fine but the surrounding module structure should change`. A reviewer determined to smuggle unsolicited findings can still do so by picking an in-domain anchor and writing prose that wanders.

This is acknowledged as **residual drift risk**. The mitigation is social, not mechanical: during triage a human reviewer can reject any finding whose `message` body does not actually substantiate the claimed anchor. Making the fence watertight (evidence-anchor matching via diff-chunk quotation and synthesis verification) would roughly double the spec size and prompt complexity — the cost/benefit does not warrant it at v0.4.1 scale.

If laundering becomes a concrete pattern in observed reviews, a follow-up spec can add an evidence-match layer without invalidating the v0.4.1 anchor contract.

## Implementation Guide

Expected shape of changes (AI will refine during Phase 1):

1. **`plugins/ai-driver/commands/review-spec.md`** — rewrite Layer 1 and Layer 2 prompt blocks to add `Focus (spec review):` + `Out of scope (spec review):` + anchor whitelist. Replace the generic (a)-(j) checklist with stage-specific items.

2. **`plugins/ai-driver/commands/run-spec.md`** — two prompt blocks to update: Phase 0 Layer 1 (spec review, identical contract to review-spec Layer 1) and Phase 1 plan review prompt (distinct contract). Gating section adds demotion rule.

3. **`plugins/ai-driver/commands/review-pr.md`** — Pass 1 subagent prompt + Pass 2 Codex prompt both gain the PR-review Focus + Out-of-scope + whitelist. Step 5 synthesis documents the Observations demotion. Step 6 report format adds an `### Observations` section between the findings tables and the Verdict.

4. **`tests/review-synthesis/drift-demotion.sh`** (new) — deterministic test that hands the synthesis step a fabricated reviewer output and asserts the demotion. Lives outside the command files so the command docs stay prose-pure.

5. **`AGENTS.md`** — one-line bullet referencing "scope-fenced reviews (v0.4.1+)" and pointing at the anchor whitelist in the spec.

6. **`CHANGELOG.md`** `## [Unreleased]` gets `### Changed` entries describing the new contract.

No changes to `constitution.md`. The scope fence is a behavioural contract at the prompt layer, enforced by the synthesis rule at the tool layer — does not rise to constitutional authority.

## References

- Related issues: v0.3.10 spec review 6-round Codex loop (specs/v0310-governance-workflow.spec.md history); PR #14 Codex historical-spec finding (ai-driver-review comment on PR #14)
- Related files: `plugins/ai-driver/commands/review-spec.md`, `run-spec.md`, `review-pr.md`
- Constitution anchors: P2 (Humans Define What), R-003 (No Scope Creep) — the scope fence is an extension of R-003 to reviewers
