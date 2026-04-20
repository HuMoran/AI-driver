# Spec Review — v036-spec-review.spec.md (bootstrap)

## Meta
- Spec: `specs/v036-spec-review.spec.md`
- Date: 2026-04-20
- Mode: bootstrap (feature not yet implemented; Layer 0 run by hand, Layer 1 by Claude in-session, Layer 2 by Codex)

## Layer 0 — Mechanical pre-check

| Rule | Result | Notes |
|---|---|---|
| S-META | pass | Date + Review Level present |
| S-GOAL | pass | non-empty Goal block |
| S-SCENARIO | pass | 9 Given lines |
| S-AC-COUNT | pass | 13 ACs |
| S-AC-FORMAT | pass | 0 malformed |
| S-CLARIFY | **pass (after rule refinement)** | Raw grep returned 3 matches, but all were inside inline code. Refinement: S-CLARIFY must strip inline-code spans before matching. Folded into implementation. |
| S-PLACEHOLDER (Meta+Goal) | pass | 0 unresolved |

**Layer 0 verdict:** pass.

## Layer 1 — Claude in-session adversarial (self-review)

| Severity | Rule | Location | Message | Fix hint |
|---|---|---|---|---|
| Medium | gap-trace | Scenarios | No scenario exercises `--accept-high` escape hatch | Add Edge Case or Scenario |
| Medium | ac-executability | AC-006 | Regex `critical.*stop\|...` fragile | Tighten to `grep -Fq 'exit 2'` + add runtime synthetic test |
| Medium | coverage | MUSTNOT-001 | No AC verifies spec-content-as-data handling | Cross-reference v0.3.7 fixture |
| Low | ambiguity | Scenario 2 §3 | "cost-sensitive" vague | Replace with "offline or rate-limited" |
| Low | naming-consistency | Layer IDs | Mixes Layer 0/1/2 with Pass 1/2 | Standardize on Layer 0/1/2 |
| Info | scope | AC-012 | AGENTS.md update in-scope but flagged | Keep |

## Layer 2 — Codex external adversarial

| Severity | Rule | Location | Message | Fix hint |
|---|---|---|---|---|
| **Critical** | CONTRA-001 | MUST-001 vs AC-007 / Scenarios 1.3–1.4 | MUST-001 says "no file write before Phase 0 passes" but Phase 0 itself writes `logs/<slug>/spec-review.md` — logically impossible | Narrow MUST-001 to exclude the review-log artifact itself |
| High | CONTRA-002 | Goal vs Edge Cases + MUSTNOT-003 | Goal says "mandatory two-pass" but degraded mode allows Phase 1 without Codex | Rewrite Goal: Claude mandatory, Codex best-effort with explicit degraded rules |
| High | AC-EXEC-001 | AC-002..AC-006 | Pseudo-shell `>=` / `==` not runnable | Rewrite as `grep -q` / `test "$(…)" -ge N` |
| High | COVERAGE-001 | MUST-004, MUST-005, MUSTNOT-004 | No AC references these | Add one AC per constraint OR remove |
| High | SEC-001 | MUST-003, MUSTNOT-001, MUSTNOT-003 | Security rules uncovered by ACs | Add explicit greps |
| High | SCOPE-001 | Goal vs Scenario 4 + AC-011/012/013 + SHOULD-003 | Mixes feature with docs/CI/v0.3.7 dogfood/governance | Keep docs/CI ACs (standard ship cycle); drop Scenario 4 live-dogfood |
| High | DOGFOOD-001 | AC-009/010 | Live-model severity judgments are nondeterministic | Remove AC-009/010; move dogfood to PR-body artifact |
| Medium | AC-EXEC-002 | AC-008, AC-011, AC-012, AC-013 | Manual assertions | Add exact grep commands |
| Medium | OVERSPEC-001 | Implementation Guide | Dictates exact prompt/model/env var/UX | Trim to invariants |
| Medium | EDGE-001 | Edge Cases | Missing: Claude unavailable, malformed output, parser failure | Add edge cases |
| Low | AMBIG-001 | MUST-004, standalone flags | "stable schema" undefined; `--accept-high` meaningless on standalone | Define schema, remove flag from standalone |

## Consensus

**Dual-raised (higher confidence, severity upgraded one notch):**

| Rule | L1 severity | L2 severity | Consensus |
|---|---|---|---|
| ac-executability / AC-EXEC-001 | Medium | High | **High** (dual → would upgrade to Critical but defer) |
| coverage / SEC-001 / COVERAGE-001 | Medium | High | **High** |
| gap-trace / AMBIG-001 (--accept-high on standalone) | Medium | Low | Medium |
| ambiguity / AMBIG-001 (Scenario 2) | Low | Low | Low |

## Gating decision

**STOP — Critical finding.** Per spec gating rule: Critical (any layer) → exit 2, not overridable.

Action: revise `specs/v036-spec-review.spec.md` before resuming implementation. Critical + all High findings must be resolved. Medium will be fixed opportunistically.

Re-review of the revised spec: Layer 0 + Layer 1 in-session. Second Codex Layer 2 run is deferred unless the revision is structurally substantial (≥30% content change).
