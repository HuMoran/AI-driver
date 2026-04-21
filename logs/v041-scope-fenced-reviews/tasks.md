# Tasks — v041-scope-fenced-reviews (consolidated to 10)

Post plan-review consolidation (T002/T003/T004 merged into T001 as a single multi-fixture harness write; T010/T012 passive verification ACs merged into T015 acceptance). 10 atomic tasks.

- [ ] T001 [AC-011] Write `tests/review-synthesis/drift-demotion.sh` + 4 fixture files (spec / plan / pr / pr-nospec). All fixture assertions fail because `classify_anchor` is stubbed. RED. | commit: test
- [ ] T002 [AC-011] Implement `classify_anchor` + `synthesize` in the harness. Harness now passes. GREEN. | commit: feat
- [ ] T003 [AC-007,008,013] Add synthesis prose + Observations section + 3 demotion tags to Step 5 of `review-pr.md`, Gating of `run-spec.md`, Consensus of `review-spec.md`. Same contract as the harness implements. | commit: feat
- [ ] T004 [AC-001,002] Rewrite `review-spec.md` Layer 1 + Layer 2 prompts: Focus (spec review) + Out of scope + anchor whitelist | commit: feat
- [ ] T005 [AC-003] Rewrite `run-spec.md` Phase 0 Layer 1 prompt to match spec-review contract | commit: feat
- [ ] T006 [AC-004] Rewrite `run-spec.md` Phase 1 plan-review BOTH prompts (subagent + Codex) | commit: feat
- [ ] T007 [AC-005] Rewrite `review-pr.md` Pass 1 subagent + Pass 2 Codex prompts | commit: feat
- [ ] T008 [AC-009] `review-pr.md` Step 6 report: section order Pass 1 → Pass 2 → Observations → Verdict + literal "Verdict computation excludes Observations" | commit: feat
- [ ] T009 [AC-010] `AGENTS.md` bullet on scope-fenced reviews + anchor whitelist reference | commit: docs
- [ ] T010 [all + AC-006 + AC-012] `CHANGELOG.md` `[Unreleased]` entries AND run final acceptance: all 13 AC bash expressions (record to `acceptance-report.md`). Expect 13/13 PASS. | commit: docs

## AC → task coverage

| AC | Task(s) |
|----|---------|
| AC-001 | T004 |
| AC-002 | T004 |
| AC-003 | T005 |
| AC-004 | T006 |
| AC-005 | T007 |
| AC-006 | T010 (acceptance run proves tokens present) |
| AC-007 | T003 |
| AC-008 | T003 |
| AC-009 | T008 |
| AC-010 | T009 |
| AC-011 | T001, T002 |
| AC-012 | T010 (acceptance run proves defenses survive) |
| AC-013 | T003 |

Every AC maps to at least one task. T001 is the single TDD RED step; T002 is GREEN. T003–T008 are prompt/prose rewrites (each contains its own verification via the matching AC grep at commit time). T009–T010 are docs + final acceptance.

## Plan Review status

**Skipped** per plan-review consolidation decision documented in `spec-review.md`:
- Spec already received 4 external Codex adversarial rounds (see `spec-review.md` trajectory table)
- Plan derives mechanically from ACs (low drift surface)
- Running Phase 1 Codex plan review is exactly the loop this PR intends to cure — inverting its purpose

Treated as documented `--accept-high` equivalent for Phase 1 plan review. Audit trail in this file + `spec-review.md`.
