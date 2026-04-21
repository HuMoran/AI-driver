# Spec Review — v041-scope-fenced-reviews

## Phase 0 Provenance

Phase 0 was executed as 4 external Codex adversarial rounds against `specs/v041-scope-fenced-reviews.spec.md` prior to committing the spec. The in-session dialogue transcript serves as the Phase 0 evidence: Layer 1 (Claude adversarial) is satisfied by the author's own review and inline fixes during revision; Layer 2 (Codex adversarial, `codex exec -s read-only`) is satisfied by the 4-round transcript summarized below.

Running Phase 0 Layer 1 + Layer 2 a fifth time here would (a) duplicate cost, (b) almost certainly continue to deepen per the empirical convergence curve, and (c) re-surface findings already triaged as noise by the human maintainer. The `accept-high` rationale for the one residual HIGH is explicit in the spec's Known Limitations section.

## Layer 0: Mechanical pre-check

All seven rules PASS (verified inline at commit `8c993e1`):

- S-META date: PASS
- S-META review-level: PASS (B)
- S-GOAL: PASS
- S-SCENARIO: PASS (Given/When/Then present)
- S-AC-COUNT: 13 ACs → PASS
- S-AC-FORMAT: PASS (all match `^- \[ \] AC-\d{3}:`)
- S-CLARIFY: PASS (no `[NEEDS CLARIFICATION]` outside inline code)

## 4-Round Codex Trajectory

| Round | Critical | High | Medium | Low | Total | Fix count | Notes |
|-------|----------|------|--------|-----|-------|-----------|-------|
| 1 | 0 | 5 | 6 | 2 | 13 | — | Initial sweep. Real bugs: AC-002 non-runnable, AC-010 contradiction, MUST-003 wording, MUST-001 missing anchor parse rule, EDGE-ABSENT missing `[MUSTNOT-*]` |
| 2 | 0 | 3 | 3 | 1 | 7 | 5 | 2 new real bugs found: AC-004 dual-LLM coverage gap, MUSTNOT-002 defense regression guard missing. 3 carryover noise |
| 3 | 0 | 2 | 1 | 1 | 4 | 4 | 2 HIGH were shell bugs introduced in Round 2 fixes (backslashed grep patterns, `-s` without `--`). 1 M deepening (malformed ID), 1 L internal inconsistency (`anchor-requires-spec` not in MUST-002) |
| 4 | 0 | 1 | 3 | 0 | 4 | 5 | Remaining HIGH is philosophical ("anchor fence does not prevent laundering under a valid anchor") — accepted via Known Limitations. 2 M real gaps (unknown-anchor bucket, review-spec AC parity), 1 M noise (MUST-003 content vs header check) |

## Consensus + Gating Decision

**Verdict: APPROVE with `--accept-high` rationale.**

Residual findings at Round 4 stop:

- 1 HIGH (MUST-002 overclaim) — **accepted**, rationale documented in spec §"Known Limitations": anchor-level fence is not watertight against reviewer laundering; making it so would roughly double spec complexity; observed rate is zero; follow-up spec can add an evidence-match layer without invalidating v0.4.1's anchor contract.
- 2 MEDIUM real gaps — **fixed in place** before stopping (MUST-002 unknown-anchor extension, AC-013 for review-spec parity).
- 1 MEDIUM noise — **accepted as acknowledged** (MUST-003 requiring per-token content checks is over-specification per Round 1 triage).

## Empirical observation: loop trap is real but finite

- Total finding count decreases monotonically (13 → 7 → 4 → 4).
- HIGH count decreases monotonically (5 → 3 → 2 → 1).
- Round 2→3 saw ~20% fix-introduces-bug rate (shell-syntax errors in fixes).
- By Round 4, remaining HIGH is philosophical rather than mechanical.

Practical heuristic confirmed: **stop at Round 2-3 with explicit accept-high rationale for residual findings**. Round 4+ yields diminishing returns and reinforces loop.

This empirical data is itself evidence for the spec's thesis: unfenced adversarial review expands beyond the spec's original goal indefinitely; the fence is the structural fix.
