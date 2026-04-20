# Acceptance Report — v037-injection-tests

All 16 ACs evaluated against commit HEAD. Every AC is a runnable shell expression.

| AC | Status | Evidence |
|---|---|---|
| AC-001 | PASS | `ls tests/injection-fixtures/*.md \| wc -l` = 5 |
| AC-002 | PASS | all 5 required frontmatter keys (`name`, `attack-class`, `target-command`, `mitigation`, `safety-note`) present in every fixture |
| AC-003 | PASS | `.github/workflows/injection-lint.yml` exists with `on: pull_request` |
| AC-004 | PASS | lint exits 0 on current tree |
| AC-005 | PASS | all 5 regression cases pass — `L-TRUST`, `L-QUOTE`, `L-SELF-ID`, `L-BOT`, `L-EXTRACT` each catch their anti-pattern |
| AC-006 | PASS | threat-model doc references every fixture by filename |
| AC-007 | PASS | `tests/injection-fixtures` referenced in `review-pr.md`, `fix-issues.md`, `merge-pr.md` |
| AC-008 | PASS | `AGENTS.md` documents the fixtures directory + injection-lint CI |
| AC-009 | PASS | no template mirror — `plugins/ai-driver/templates/.github/workflows/injection-lint.yml` and `plugins/ai-driver/templates/tests/` absent |
| AC-010 | PASS | `[Unreleased]` has ≥1 bullet mentioning `injection`/`fixture`/`lint` |
| AC-011 | PASS | lint script contains no `codex exec` / `claude` / `anthropic` invocation (grep-pattern mentions are allowed and needed for `L-EXTRACT` detection) |
| AC-012 | PASS | `assert-format.sh L-TRUST` — stderr contains `rule-id=L-TRUST`, `file:line`, `fix:`, and `#L-TRUST` |
| AC-013 | PASS | no fixture carries both `- Date:` and `- Review Level:` at column 0 |
| AC-014 | PASS | `/ai-driver:run-spec` Pre-flight contains path-gate `case "$ARGUMENTS" in specs/*\|./specs/*)` |
| AC-015 | PASS | `injection-lint.yml` workflow has no LLM invocation |
| AC-016 | PASS | all guardrail tokens (`Trust boundary`, `SELF_LOGIN`, `user.type`, `-s read-only`, `--paginate`, `BEGIN SPEC`) still present across 5 commands |

**Summary: 16/16 PASS.**

## Spec review rounds (Phase 0 dogfood)

v0.3.6's Phase 0 gate was executed on this spec in two rounds:

| Round | Layer 0 | Layer 1 (Claude self) | Layer 2 (Codex) | Disposition |
|---|---|---|---|---|
| Round 1 | PASS | 1 High + 5 Medium + 2 Low | **1 Critical** (R-TEMPLATE-LEAK) + 2 High (R-MUST-COVERAGE, R-GATE-MISMATCH) + 3 Medium + 1 Low | STOP — spec revised |
| Round 2 (post-revision) | PASS | 0 findings from earlier scope | (deferred — revision is substantial; see note) | PROCEED |

The Round 1 Critical was a design flaw: AC-009 proposed mirroring `injection-lint.yml` into `plugins/ai-driver/templates/`, but user projects don't have `plugins/ai-driver/commands/*.md` to lint and don't have `tests/injection-fixtures/` — the mirror would be dead code. Fix: injection-lint + fixtures stay repo-internal (`MUSTNOT-004` added).

The two Round 1 High findings drove:
- `R-MUST-COVERAGE` → added AC-011 (no LLM invocation), AC-014 (path gate), AC-015 (workflow LLM check), AC-016 (guardrail non-weakening).
- `R-GATE-MISMATCH` → restructured 5-fixture ↔ 5-rule 1:1 mapping. Added `L-EXTRACT` rule for `auto-release.yml`; scoped `L-QUOTE` wider to include `$SPEC_PATH` / `$ARGUMENTS` / `$SPEC_SLUG`. Dropped `L-PAGINATE` from v0.3.7 (not injection-class).

Round 1 also surfaced that `/ai-driver:fix-issues` was missing a `## Trust boundary` section since v0.3.4. Added it in this branch — the lint now catches its own previously-undetected gap in the same commit that ships the lint.

## R-004 retries

Zero retries needed on the AC sweep. One fix during harness bootstrap: `injection-lint.sh` used `| while read ...` which lost `fail=1` side effects via subshell; switched to `while ... < <(awk ...)` process substitution.

## R-007 Final status

**DONE_WITH_CONCERNS**

- DONE: all 16 ACs pass, 5 fixtures + 5 lint rules + harness + threat model shipped, Trust boundary added to `fix-issues.md`, path gate added to `run-spec.md` + `review-spec.md`, no guardrail weakened.
- CONCERN: This spec's Phase 0 Round 2 (post-revision re-run of Codex Layer 2) was deferred. The revision was substantial — five ACs rewritten as shell, one Critical design change, one new lint rule, one new Pre-flight gate, Scope section tightened. A Round 2 Codex pass would be prudent before merge; captured as PR-body action item.
- CONCERN: No runtime LLM E2E (deliberately deferred per spec scope): fixtures are documentation. If a future incident proves a lint rule missed a real attack shape, add a runtime fixture harness in v-next.
