# Tasks — v036-spec-review

- [ ] T001 [AC-001] Create `plugins/ai-driver/commands/review-spec.md` with frontmatter + three-layer review logic + flags (`--write-log`, `--no-codex`, `--accept-high`) | Files: plugins/ai-driver/commands/review-spec.md
- [ ] T002 [AC-008] Lock down `allowed-tools` in review-spec.md frontmatter (Read, Glob, Grep, Bash(codex exec:*), Bash(grep:*), Bash(awk:*), Bash(cat:*), Bash(mkdir:*), Write) | Files: plugins/ai-driver/commands/review-spec.md
- [ ] T003 [AC-002,AC-003,AC-004,AC-005] Insert `## Phase 0: Spec Review` in run-spec.md before existing Phase 1, with Layer 0 rule IDs (S-META, S-GOAL, S-SCENARIO, S-AC-COUNT, S-AC-FORMAT, S-CLARIFY, S-PLACEHOLDER) + Layer 1 literal prompt + Layer 2 codex exec call, unconditional (no Review Level gate) | Files: plugins/ai-driver/commands/run-spec.md
- [ ] T004 [AC-006,AC-007] Gating block in Phase 0: exit 2 on Critical, --accept-high on High, y/N on Medium, continue on Low. Writes logs/<spec-slug>/spec-review.md. | Files: plugins/ai-driver/commands/run-spec.md
- [ ] T005 [AC-003] Fold old Phase 0 "Prepare" (branch checkout + mkdir) into Phase 1 start, so state mutation only happens after spec review passes (MUST-001 enforcement). | Files: plugins/ai-driver/commands/run-spec.md
- [ ] T006 [AC-009,AC-010] Dogfood evidence: capture output of manual review-spec logic against `specs/_template.spec.md` (expect High findings) and `specs/v035-copilot-backlog.spec.md` (expect 0 Critical). Write to logs/v036-spec-review/dogfood-evidence.md | Files: logs/v036-spec-review/dogfood-evidence.md
- [ ] T007 [AC-012] Update AGENTS.md to describe the three-gate workflow (spec review -> plan review -> PR review) | Files: AGENTS.md
- [ ] T008 [AC-012] Mirror AGENTS.md change to `plugins/ai-driver/templates/AGENTS.md` — wait, check INTENTIONAL_EXEMPTIONS: template AGENTS.md is exempted from byte-exact sync. Verify no sync needed or update template separately. | Files: plugins/ai-driver/templates/AGENTS.md (if needed)
- [ ] T009 [AC-011] CHANGELOG `[Unreleased]` entry documenting Phase 0 spec review + standalone review-spec command | Files: CHANGELOG.md
- [ ] T010 [AC-013] Local template-sync dry-run to confirm no drift | Files: none (verification)
- [ ] T011 [acceptance] Run all AC grep/awk checks from the spec, capture outputs in acceptance report | Files: logs/v036-spec-review/acceptance-report.md
- [ ] T012 [docs] `implementation.log` summarizing what was done, scope discipline notes, design refinements from dogfood | Files: logs/v036-spec-review/implementation.log
