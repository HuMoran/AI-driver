# Spec Review — v037-injection-tests.spec.md

First real autonomous Phase 0 run (v0.3.6 feature's first live consumer).

## Meta
- Spec: `specs/v037-injection-tests.spec.md`
- Date: 2026-04-20
- Branch: `feat/v037-injection-tests`
- Phase 0 caller: `/ai-driver:run-spec` (via its new §Phase 0)

## Layer 0 — Mechanical pre-check

| Rule | Result |
|---|---|
| S-META | PASS |
| S-GOAL | PASS |
| S-SCENARIO | PASS (Given=6, When=6, Then=6) |
| S-AC-COUNT | PASS (10 ACs) |
| S-AC-FORMAT | PASS (all match `^- \[ \] AC-\d{3}:`) |
| S-CLARIFY | PASS (0 markers outside inline code) |
| S-PLACEHOLDER | PASS (0 unresolved `<…>` in Meta/Goal) |

**Layer 0 verdict:** PASS → proceed to Layer 1.

## Layer 1 — Claude in-session adversarial

| Severity | rule_id | location | message | fix_hint |
|---|---|---|---|---|
| **High** | coverage-must-003 | MUST-003 (spec `## Constraints`) | No AC verifies lint failure output format (rule-id + file:line + fix-hint + threat-model anchor). MUST-003 is the whole UX contract of the feature and is untested. | Add AC that runs a lint rule against a known-fail fixture and greps stderr for `rule-id`, `file:`, a `fix-hint` keyword, and a `#L-` anchor to the threat model. |
| Medium | ac-executability | AC-001 | `ls … \| wc -l` equals 5" is prose, not shell | `test "$(ls tests/injection-fixtures/*.md 2>/dev/null \| wc -l)" -eq 5` |
| Medium | ac-executability | AC-002 | `grep -l … \| wc -l == 5` not shell syntax | `for f in name attack-class target-command mitigation safety-note; do test "$(grep -l "^$f:" tests/injection-fixtures/*.md \| wc -l)" -eq 5 \|\| exit 1; done` |
| Medium | ac-executability | AC-007 | `grep -l … \| wc -l == 3` not shell syntax | `test "$(grep -l 'tests/injection-fixtures' plugins/ai-driver/commands/{review-pr,fix-issues,merge-pr}.md \| wc -l)" -eq 3` |
| Medium | ac-executability | AC-008 | "mentions" is prose | `grep -Fq 'tests/injection-fixtures' AGENTS.md` |
| Medium | coverage | MUST-002 | No AC verifies lint is "mechanical — no LLM invocation" | `! grep -iE 'codex\|claude\|llm' .github/scripts/injection-lint.sh` |
| Medium | security-meta | fixtures | Fixture markdown files could be mistakenly loaded as spec paths by `/ai-driver:run-spec` or `/ai-driver:review-spec`. Phase 0 S-AC-COUNT would reject, but the risk exists. | Either add a hardened filename check (require `.spec.md` suffix) in run-spec, or accept that Phase 0 already rejects (Fixture files lack `AC-NNN:` lines → S-AC-COUNT fails → safe). Document the accident-resistance explicitly. |
| Low | stale-ref | AC-004 | References `HEAD at v0.3.5` but main is now v0.3.6 | Drop the version, say "current main" |
| Low | ambiguity | MUSTNOT-001, MUSTNOT-003 | Not mechanically verifiable | Acceptable — behavioral constraint |
| Info | scope-drift | Implementation Guide | Threat model doc + cross-command refs are standard ship-cycle but broader than the original "A + B" | Accept — matches v0.3.2+ convention |

## Layer 2 — Codex external adversarial

*(running in background, findings appended on completion)*

## Gating

Layer 1 found **1 High** (coverage-must-003). Per the gate: High → STOP unless `--accept-high`. Decision: **fix the spec first** (P1: spec wins; Copilot already flagged the AC pseudo-shell issue on PR #8 as a deferred item, and fixing it now pulls the dependency forward).

Proceeding to spec revision before implementation starts. No branch was mutated beyond the cut from main (branch exists with zero commits). Re-running Phase 0 on the revised spec after edits.
