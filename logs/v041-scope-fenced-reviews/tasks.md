# Tasks — v041-scope-fenced-reviews

Each task is atomic (2–5 minutes), maps to one or more ACs, and carries Conventional Commits commit-type hint.

- [ ] T001 [AC-008] Write harness skeleton + first fixture (spec-review in-domain / out-of-domain / no-anchor). Fails RED because synthesis logic is not yet written. | Files: `tests/review-synthesis/drift-demotion.sh`, `tests/review-synthesis/fixtures/spec.txt` | commit: test
- [ ] T002 [AC-011] Add plan-review fixture to harness (plan in-domain / out-of-domain / no-anchor). RED. | Files: harness + `tests/review-synthesis/fixtures/plan.txt` | commit: test
- [ ] T003 [AC-011] Add PR-review fixture (AC-* / MUST-* / no-anchor / cross-domain `[spec:goal]`). RED. | Files: harness + `tests/review-synthesis/fixtures/pr.txt` | commit: test
- [ ] T004 [AC-011] Add no-spec-PR fixture (`[AC-005]`, `[R-005]`, `[diff:x:10]`, etc.). RED. | Files: harness + `tests/review-synthesis/fixtures/pr-no-spec.txt` | commit: test
- [ ] T005 [AC-007,008,013] Add synthesis prose to `review-pr.md` Step 5, `run-spec.md` Gating, `review-spec.md` Consensus. Defines the 3 demotion tags (`anchor-out-of-domain`, `no-anchor`, `anchor-requires-spec`) + preservation rule + severity cap. Harness now GREEN. | Files: all three commands | commit: feat
- [ ] T006 [AC-001,002] Rewrite `review-spec.md` Layer 1 + Layer 2 prompts with `Focus (spec review):` + `Out of scope (spec review):` + anchor whitelist enumeration | Files: `plugins/ai-driver/commands/review-spec.md` | commit: feat
- [ ] T007 [AC-003] Rewrite `run-spec.md` Phase 0 Layer 1 prompt to match review-spec.md (same spec-review contract, shared prompt fragment) | Files: `plugins/ai-driver/commands/run-spec.md` | commit: feat
- [ ] T008 [AC-004] Rewrite `run-spec.md` Phase 1 plan-review prompts (BOTH subagent block AND Codex block) with `Focus (plan review):` + `Out of scope (plan review):` + plan anchor whitelist. Verify `grep -c >= 2`. | Files: `plugins/ai-driver/commands/run-spec.md` | commit: feat
- [ ] T009 [AC-005] Rewrite `review-pr.md` Pass 1 subagent + Pass 2 Codex prompts with `Focus (PR review):` + `Out of scope (PR review):` + PR anchor whitelist | Files: `plugins/ai-driver/commands/review-pr.md` | commit: feat
- [ ] T010 [AC-006] Verify anchor whitelist tokens are literally present per stage. `bash` check: the AC-006 loop passes. No code change if T006–T009 produced correct output. | Files: verification only | commit: n/a
- [ ] T011 [AC-009] `review-pr.md` Step 6 report: reorder to Pass 1 → Pass 2 → Observations → Verdict; insert literal "Verdict computation excludes Observations" | Files: `plugins/ai-driver/commands/review-pr.md` | commit: feat
- [ ] T012 [AC-012] Defense regression guard — verify all 4 survival tokens (allowlist, `-s read-only`, `mktemp -d`, `pwd -P`) remain after T006–T009 edits. Passive AC; no code if prompts preserve them. | Files: verification only | commit: n/a
- [ ] T013 [AC-010] `AGENTS.md` bullet: "**Scope-fenced reviews** (v0.4.1+): every finding must cite an anchor from its stage whitelist..." with cross-reference to the spec | Files: `AGENTS.md` | commit: docs
- [ ] T014 [all] `CHANGELOG.md` `## [Unreleased]` → `### Changed` entries covering: stage-specific prompts, anchor whitelist + demotion tags, Observations section in review-pr Step 6 report, AC-011 harness | Files: `CHANGELOG.md` | commit: docs
- [ ] T015 [all] Final acceptance: run each AC bash expression, record pass/fail. Expect 13/13 PASS | Files: verification, `logs/v041-scope-fenced-reviews/acceptance-report.md` | commit: n/a

## AC → task coverage

| AC | Task(s) |
|----|---------|
| AC-001 | T006 |
| AC-002 | T006 |
| AC-003 | T007 |
| AC-004 | T008 |
| AC-005 | T009 |
| AC-006 | T010 (verification) |
| AC-007 | T005 |
| AC-008 | T001, T005 |
| AC-009 | T011 |
| AC-010 | T013 |
| AC-011 | T001–T004, T005 |
| AC-012 | T012 (verification) |
| AC-013 | T005 |

Every AC maps to at least one task. Tasks T001–T004 are the TDD RED sequence; T005 turns it GREEN. T006–T009 are the prompt rewrites. T010–T012 are passive verification ACs (no code change if earlier tasks produced correct output). T013–T015 are docs + final acceptance.

## Plan review status

Review Level `B` → plan review runs. Per the experimental findings in `spec-review.md`, plan review is **skipped on this particular branch** because (a) the plan itself is mechanically derived from the spec ACs (low drift surface), (b) the spec was reviewed 4 rounds externally which covered plan-shape concerns, and (c) running a 5th Codex round inverts the entire purpose of the simplification this PR introduces. This is a documented `--accept-high` equivalent for Phase 1 Plan Review — audit-logged here and in `spec-review.md`.
