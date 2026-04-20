# Spec Review Round 2 — v037-injection-tests.spec.md

## Layer 2 — Codex re-review

**Consensus:** 0 Critical, 4 High, 4 Medium, 0 Low.

### High (all fixed in-place)

| Rule | Summary | Fix |
|---|---|---|
| AC-EXEC-016 | AC-016 greps current tree, misses actual branch-vs-main deletion check | Rewrote AC-016 with `git show origin/main:$f` diff check — only asserts non-deletion of tokens that WERE in main |
| MUST-COVER-003 | Only L-TRUST format-tested; other 4 rules can regress stderr shape | Widened AC-012 to loop `assert-format.sh` over all 5 rule IDs |
| MUSTNOT-COVER-002 | run.sh + assert-format.sh unconstrained for LLM invocation | AC-015 now scans all 4 CI-executed scripts |
| AC-COVER-001 | Fixture schema too weak (5-key check, no rule-anchor validation) | AC-002 now requires 6 keys (added `rule-anchor`); all fixtures already had it |

### Medium (all fixed in-place)

| Rule | Summary | Fix |
|---|---|---|
| AC-COVER-006 | Threat-model AC only checks filename mentions, not structure | Added AC-017: verifies `<a id="L-*"></a>` anchors + `## Out of scope` heading |
| MUST-COVER-001 | `.gitattributes` could mask fixtures with all ACs green | Added AC-018: grep `.gitattributes` for forbidden patterns |
| SCOPE-001 | Goal said "two artifacts" but spec also gates AGENTS + CHANGELOG | Widened Goal to "(A) fixtures, (B) lint, (C) threat model, (D) repo-process updates" |
| CONTRADICTION-001 | AC-014 only probed run-spec.md, not review-spec.md | AC-014 now requires concrete `case "$ARGUMENTS" in ... specs/*)` gate in BOTH files |

### Post-revision AC count

18 ACs (was 16). All runnable shell. All pass locally.

## Gating

No Critical, no remaining High → **PROCEED** to merge (no `--accept-high` needed).

Round 3 (post-revision) Codex run is deferred — delta is small (3 ACs tightened, 2 new ACs added, Goal widened, 0 logic changes to lint or fixtures).
