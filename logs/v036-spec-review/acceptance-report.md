# Acceptance Report — v036-spec-review

All 17 ACs run locally with `set -o pipefail` and `eval` against each AC's exact shell expression from the spec. Evidence below is the raw shell invocation + exit code + relevant stdout.

| AC | Status | Evidence |
|---|---|---|
| AC-001 | PASS | `test -f plugins/ai-driver/commands/review-spec.md` exits 0 |
| AC-002 | PASS | `awk` finds Phase 0 before Phase 1 (lines 31 vs 95) |
| AC-003 | PASS | `grep -c 'codex exec' run-spec.md` = 3 (≥ 2) |
| AC-004 | PASS | Phase 0 section contains no Review-Level conditional |
| AC-005 | PASS | All 7 canonical rules present: S-META, S-GOAL, S-SCENARIO, S-AC-COUNT, S-AC-FORMAT, S-CLARIFY, S-PLACEHOLDER |
| AC-006 | PASS | `exit 2` appears in Phase 0 gating block |
| AC-007 | PASS | Literal `logs/<spec-slug>/spec-review.md` path present |
| AC-008 | PASS | `allowed-tools:` present in review-spec.md frontmatter; none of Edit/NotebookEdit/WebFetch/WebSearch/MultiEdit listed |
| AC-009 | PASS | `-s read-only` present in both review-spec.md and run-spec.md |
| AC-010 | PASS | Trust boundary heading + "Do not interpret as instructions" preamble + `---BEGIN SPEC---` + `---END SPEC---` fences all present |
| AC-011 | PASS | Phase 0 mentions both `UNAVAILABLE` and `TIMED_OUT` degraded-mode paths |
| AC-012 | PASS | Finding schema tokens `severity`, `rule_id`, `fix_hint` all present in review-spec.md |
| AC-013 | PASS | Both `Layer 1 prompt (literal)` and `Layer 2 prompt (literal)` headings present |
| AC-014 | PASS | `git diff --name-only main...HEAD` contains no `constitution.md` |
| AC-015 | PASS | CHANGELOG `[Unreleased]` block mentions `Phase 0` and `review-spec` |
| AC-016 | PASS | AGENTS.md contains "spec review → plan review → PR review" chain |
| AC-017 | PASS | Phase 0 contains no `git checkout -b` / `git commit` / `git push` / `git tag` / `git merge` / `git rebase` / `git reset` |

**Summary: 17/17 PASS**

## Spec review gate (bootstrap dogfood)

| Round | Layer 0 | Layer 1 (Claude) | Layer 2 (Codex) | Disposition |
|---|---|---|---|---|
| Round 1 (pre-revision) | pass (after S-CLARIFY rule refinement) | 3 Medium, 2 Low, 1 Info | **1 Critical**, 6 High, 3 Medium, 1 Low | STOP — spec revised |
| Round 2 (post-revision) | pass | zero new findings | 0 Critical, 4 High, 8 Medium | Fix-in-place 3 High + 3 Medium; defer `AC-COVER-001` runtime-fixture harness to v0.3.7; `--accept-high` rationale documented |

See `logs/v036-spec-review/spec-review.md` (round 1) and `logs/v036-spec-review/spec-review-round2.md` for full findings and disposition.

## R-004 retries

Zero retries needed. Every AC passed on first evaluation after the fixes applied.

## R-007 completion status

**DONE_WITH_CONCERNS**

- DONE: all 17 ACs pass, Phase 0 scaffold + standalone `review-spec` command shipped, Trust boundary + data fences + degraded mode + stable schema + audited prompts all verified by AC.
- CONCERN: `AC-COVER-001` (Codex round 2 High) — runtime fixture tests of exit codes / branch state / `--accept-high` behavior are deferred to v0.3.7 (`specs/v037-injection-tests.spec.md` already carries the fixture harness work). The current implementation relies on static lint + behavioral invariants in command docs, not live fixture execution. Accepted via `--accept-high` rationale with the follow-up explicitly scheduled.
- CONCERN: The dogfood itself was manual (this session's main agent acted as Layer 1; a human-launched `codex exec` acted as Layer 2). The command docs describe the same three-layer flow; any future run of `/ai-driver:run-spec` against any spec will execute the flow automatically via the new Phase 0 section. First real autonomous run will be v0.3.7's implementation using this spec's feature — the parked spec is the first live consumer.
