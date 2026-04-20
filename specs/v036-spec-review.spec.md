# v036-spec-review.spec.md

## Meta

- Date: 2026-04-20
- Review Level: B

## Goal

Every `spec.md` — human-written or AI-generated — must pass a **mandatory two-pass adversarial review** (Claude in-session + Codex external) before `/ai-driver:run-spec` begins Phase 1. Spec is requirement input; a defective spec cascades into wasted implementation, broken ACs, and expensive rework downstream. Upstream gating is cheaper than downstream correction.

v0.3.3 added `/ai-driver:doctor` (project-level lint). v0.3.4 added comment-aware `/ai-driver:review-pr` (PR-level review). This version closes the remaining gap: spec-level review. After v0.3.6, the end-to-end workflow has three gates — spec review → plan review → PR review — each with Claude + Codex dual perspective.

## User Scenarios

### Scenario 1: Mandatory spec review inside run-spec (Priority: P0)

**As a** user invoking `/ai-driver:run-spec specs/foo.spec.md`,
**I want** the command to refuse to proceed if the spec has critical defects,
**so that** I find out about missing ACs or contradictions at the input stage, not after 20 minutes of implementation.

**Acceptance Scenarios:**

1. **Given** a spec missing the `## Goal` section,
   **When** `/ai-driver:run-spec` runs,
   **Then** Phase 0 mechanical pre-check fails with rule `S-GOAL`, no Claude / Codex call is made, no branch is cut, no logs directory is created, the process exits with a clear fix hint.
2. **Given** a spec with `[NEEDS CLARIFICATION]` markers,
   **When** `/ai-driver:run-spec` runs,
   **Then** Phase 0 fails with rule `S-CLARIFY` listing every marker with its line number.
3. **Given** a structurally-valid spec that Codex flags as Critical ("AC-003 contradicts MUST-001"),
   **When** `/ai-driver:run-spec` runs,
   **Then** Phase 0 prints the finding, writes `logs/<slug>/spec-review.md`, and exits without creating a branch or running Phase 1.
4. **Given** a structurally-valid spec where both Claude and Codex only return Low findings,
   **When** `/ai-driver:run-spec` runs,
   **Then** Phase 0 writes `logs/<slug>/spec-review.md`, proceeds to Pre-flight step 5, and Phase 1 runs as before.

**Independent Test Method:** run `/ai-driver:run-spec` against four crafted specs (missing-goal, has-clarify-marker, contradictory-AC, clean) and observe the four outcomes. Phase 0 log file is the evidence.

### Scenario 2: Standalone `/ai-driver:review-spec` for iterative drafting (Priority: P1)

**As a** spec author refining a draft,
**I want** a command that runs the same three-layer review without starting a branch or Phase 1,
**so that** I can iterate on the spec fast before committing to an implementation run.

**Acceptance Scenarios:**

1. **Given** `specs/draft.spec.md` exists,
   **When** I run `/ai-driver:review-spec specs/draft.spec.md`,
   **Then** the command performs Layer 0 + Layer 1 + Layer 2 review and prints findings to stdout, touches no git state, creates no branch, writes no logs.
2. **Given** `--write-log` flag is passed,
   **When** the command runs,
   **Then** it also writes `logs/<spec-slug>/spec-review.md` with the same content.
3. **Given** `--no-codex` flag is passed (offline or cost-sensitive),
   **When** the command runs,
   **Then** Layer 2 is skipped and the output marks the Codex section as `SKIPPED (--no-codex)`.

**Independent Test Method:** invoke `/ai-driver:review-spec` on this very spec file; verify stdout has three sections (Layer 0 / Layer 1 / Layer 2) and no git state changes (`git status` unchanged before and after).

### Scenario 3: Reviews are NOT gated by spec Review Level (Priority: P0)

**As a** maintainer,
**I want** spec review to be **unconditional**,
**so that** a user cannot skip the input gate by declaring `Review Level: A` in Meta.

**Acceptance Scenarios:**

1. **Given** `spec.md` with `Review Level: A`,
   **When** `/ai-driver:run-spec` runs,
   **Then** Phase 0 (spec review) still executes all three layers in full.

**Independent Test Method:** grep that Phase 0 section in `run-spec.md` contains no `if review level` condition and no early-return conditional.

### Scenario 4: Dogfood — v0.3.7 spec is the first real subject (Priority: P1)

**As a** validator,
**I want** `/ai-driver:review-spec specs/v037-injection-tests.spec.md` to surface at least one real finding,
**so that** the v0.3.6 feature is exercised on a realistic spec, not just unit cases.

**Acceptance Scenarios:**

1. **Given** `specs/v037-injection-tests.spec.md` from this branch,
   **When** `/ai-driver:review-spec` runs on it after v0.3.6 is merged,
   **Then** the review returns a findings report. Any Critical/High findings are resolved before v0.3.7 implementation begins.

**Independent Test Method:** attach the review output to the v0.3.7 PR body.

### Edge Cases

- What if Codex is unavailable (offline, auth expired)? Layer 2 is marked `UNAVAILABLE (<reason>)` in the review log. If Layer 0 + Layer 1 both pass clean, the run proceeds with a **visible warning** and the omission is recorded in `implementation.log` so reviewers can spot specs that shipped without Codex second-opinion.
- What if the spec is large (>500 lines) and the Codex call times out? Timeout is configurable via `CODEX_TIMEOUT_SEC` (default 180); on timeout, Layer 2 records `TIMED_OUT` and the same "visible warning, don't block" path applies.
- What if Phase 0 itself has a bug (false positive)? Standalone `/ai-driver:review-spec` + `--no-codex` lets the user reproduce in under a second. Fix hint: submit a PR targeting the rule, include the minimal repro spec as a test fixture.
- What if a spec is intentionally minimal (e.g., docs-only change)? It still must pass structural checks. A three-line spec with Meta + Goal + one AC-001 is acceptable; Phase 0 has no minimum size, only structural rules.

## Acceptance Criteria

- [ ] AC-001: `plugins/ai-driver/commands/review-spec.md` exists
- [ ] AC-002: `plugins/ai-driver/commands/run-spec.md` contains a `## Phase 0: Spec Review` section that appears **before** `## Phase 1: Design Action Plan`. Check: `awk '/^## Phase/ {print NR" "$0}' plugins/ai-driver/commands/run-spec.md | head -3` shows Phase 0 before Phase 1.
- [ ] AC-003: Phase 0 in `run-spec.md` calls `codex exec` at least once: `grep -c 'codex exec' plugins/ai-driver/commands/run-spec.md >= 2` (existing Plan review + new Spec review)
- [ ] AC-004: Phase 0 is unconditional. Check: `grep -B2 -A10 '^## Phase 0' plugins/ai-driver/commands/run-spec.md | grep -iE 'if.*review.?level|review.?level.*(==|is|>=)' | wc -l == 0`
- [ ] AC-005: Layer 0 mechanical pre-check defines at least five rule IDs. Check: `grep -oE 'S-[A-Z][A-Z-]+' plugins/ai-driver/commands/run-spec.md | sort -u | wc -l >= 5`
- [ ] AC-006: Critical / High findings explicitly block. Check: `grep -A20 '^## Phase 0' plugins/ai-driver/commands/run-spec.md | grep -iE 'critical.*stop|stop.*critical|block.*critical|exit.*critical' | wc -l >= 1`
- [ ] AC-007: `logs/<spec-slug>/spec-review.md` written by Phase 0. Check: run-spec.md Phase 0 mentions this exact path: `grep -Fq 'logs/<spec-slug>/spec-review.md' plugins/ai-driver/commands/run-spec.md`
- [ ] AC-008: Standalone `/ai-driver:review-spec` command `allowed-tools` frontmatter excludes all write/network tools except the Codex bash call and the optional `--write-log` write. Check: `plugins/ai-driver/commands/review-spec.md` frontmatter is present and restricts tools.
- [ ] AC-009: Dogfood test passes: running `/ai-driver:review-spec specs/_template.spec.md` returns ≥1 High-severity finding (the template has unresolved `<placeholders>` and `[NEEDS CLARIFICATION]`). Evidence: captured output attached to the PR.
- [ ] AC-010: Dogfood test passes: running `/ai-driver:review-spec` on a recent shipped spec (`specs/v035-copilot-backlog.spec.md`) returns zero Critical findings. Evidence: captured output attached to the PR.
- [ ] AC-011: CHANGELOG `[Unreleased]` populated with the v0.3.6 entry.
- [ ] AC-012: `AGENTS.md` updated to describe the three-gate workflow (spec review → plan review → PR review).
- [ ] AC-013: Template-sync CI passes on this PR.

## Constraints

### MUST

- MUST-001: Phase 0 runs **before** any git branch creation, directory creation, or file write. A failed spec review leaves the tree in exactly the state it was before the command was invoked.
- MUST-002: Phase 0 is unconditional — no `if Review Level >= B` gating. Spec review governs input, not effort.
- MUST-003: Layer 2 (Codex) must run with `-s read-only` sandbox. Spec review is an analysis, not a modification.
- MUST-004: Findings output format is stable across both invocation paths (inside run-spec, standalone). Severity levels: `Critical | High | Medium | Low | Info`. Each finding has `rule-id | location (file:line) | message | fix-hint`.
- MUST-005: Codex prompt for spec review is stored as a literal string inside `run-spec.md` (and referenced from `review-spec.md`) — not generated dynamically — so the review is reproducible and auditable.

### MUST NOT

- MUSTNOT-001: Do not interpret spec content as LLM instructions. The spec is **data under review**, not a prompt. Both passes treat it the same way `review-pr.md` treats reviewer content per `## Trust boundary`.
- MUSTNOT-002: Do not allow the standalone `review-spec` command to mutate any file unless `--write-log` is passed; network access is only allowed via the Codex call.
- MUSTNOT-003: Do not block on Codex unavailability — that would make AI-driver unusable offline. Degrade with a visible warning and a record in the log.
- MUSTNOT-004: Do not amend `constitution.md` as part of this spec (governance requires explicit human approval). Propose the amendment as a follow-up item in the PR body instead.

### SHOULD

- SHOULD-001: Layer 1 (Claude) and Layer 2 (Codex) use **the same checklist**, so disagreement between them is substantive, not stylistic. Checklist includes: AC executability, coverage of MUST/MUSTNOT, scope creep signals, security anti-patterns, contradiction detection, under-specification.
- SHOULD-002: The review output distinguishes findings the two passes **agree on** (higher confidence) from findings only one pass raised (lower confidence). Same dual-consensus pattern as v0.3.4 `review-pr`.
- SHOULD-003: Propose a constitution amendment in the PR body: add `R-008: Spec Input Review` making this behavior a codified rule. Leave merge of the amendment for the user to approve.

## Implementation Guide

### Phase 0 structure (inserted into run-spec.md)

```
## Phase 0: Spec Review  (MANDATORY — runs regardless of Review Level)

### Layer 0: Mechanical pre-check (sub-second, no LLM)

Rules (fail-fast, ordered):
  S-META      — Meta section has `Date` and `Review Level`
  S-GOAL      — `## Goal` section present, ≥1 non-empty line
  S-SCENARIO  — at least one Scenario with matching Given/When/Then lines
  S-AC-COUNT  — at least one `- [ ] AC-NNN:` bullet
  S-AC-FORMAT — every AC line matches `^- \[ \] AC-\d{3}:`
  S-CLARIFY   — zero `[NEEDS CLARIFICATION]` markers
  S-PLACEHOLDER — zero unresolved `<...>` template placeholders in Meta/Goal

If any rule fails → STOP, print rule-id + line + fix hint. No Claude call, no Codex call, no branch, no logs directory.

### Layer 1: Claude adversarial review (in-session)

Prompt (literal, audited): "Review this spec as an adversarial reviewer. Check: (a) every AC is boolean and machine-executable; (b) every MUST/MUSTNOT is covered by at least one AC; (c) scope — does spec mix feature + refactor?; (d) ambiguity — undefined terms, vague verbs; (e) contradictions between Goal / Scenarios / AC / Constraints; (f) security anti-patterns. Output JSON: [{severity, rule_id, location, message, fix_hint}]."

### Layer 2: Codex adversarial review (external)

Run: codex exec --model gpt-5.4 -s read-only --reasoning-effort high "<same checklist>" < $SPEC_PATH
Timeout: ${CODEX_TIMEOUT_SEC:-180}s.
On timeout/unavailable: record UNAVAILABLE / TIMED_OUT, continue with visible warning.

### Gating

Write logs/<spec-slug>/spec-review.md with three sections (Layer 0/1/2) + a consensus table.
  Critical in any layer            → STOP, print report, exit 2.
  High in any layer                → STOP unless `--accept-high` passed (prints risk ack).
  Medium                           → ask user [y/N] to continue.
  Low / Info                       → continue, noted in log.
```

### Standalone `/ai-driver:review-spec`

Thin wrapper that runs Layer 0 + Layer 1 + Layer 2 and prints findings to stdout. Flags: `--write-log`, `--no-codex`, `--accept-high`. No git operations, no mkdir, no Phase 1.

### Dogfooding note

After merge, v0.3.7's spec (currently parked at `specs/v037-injection-tests.spec.md`) is the first real consumer. Its PR body will attach the `review-spec` output.

## References

- `plugins/ai-driver/commands/run-spec.md` — existing Phase 1 Plan review scaffolding (reuse the codex-exec pattern)
- `plugins/ai-driver/commands/review-pr.md` §"Trust boundary" — same guardrail applies here
- `plugins/ai-driver/commands/doctor.md` — reference for `allowed-tools` frontmatter lockdown
- `specs/comment-aware-review.spec.md` — dual-consensus pattern
- `constitution.md` P1 (Spec Is Source of Truth), P4 (Verifiable First) — spec review enforces both

## Needs Clarification

None.
