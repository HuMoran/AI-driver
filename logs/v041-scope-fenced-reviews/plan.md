# Plan — v041-scope-fenced-reviews

## Architecture overview

Prompt-and-synthesis change to the three review gates. Zero new commands, zero constitutional rules, zero new CI jobs, zero new runtime dependencies.

```
 /ai-driver:run-spec         /ai-driver:review-spec     /ai-driver:review-pr
     Phase 0 Layer 1            Layer 1 (subagent)         Pass 1 (subagent)
     Phase 0 Layer 2            Layer 2 (Codex)            Pass 2 (Codex)
     Phase 1 Plan subagent
     Phase 1 Plan Codex
            │                          │                          │
            ▼                          ▼                          ▼
       ┌────────────────────── reviewer output ──────────────────┐
       │    Markdown table: | Severity | rule_id | loc | msg | fix |
       │    (`msg` begins with `[<anchor>]` prefix per MUST-001) │
       └──────────────┬──────────────────────────────────────────┘
                      ▼
               ┌─────────────────────┐
               │ Synthesis layer     │  (prose contract in each
               │  — parse anchor      │   command's synthesis step)
               │  — domain check      │
               │  — demote or keep    │
               └─────────┬────────────┘
                         │
            ┌────────────┼────────────┐
            ▼            ▼            ▼
      Main findings  Observations   Verdict
      (anchored,     (demoted,      (counts
       in-domain)     non-blocking)  main only)
```

## Reuse analysis

Everything below **stays unchanged** — the scope fence is additive to first-line defenses:

- Subagent `allowed-tools: Read, Grep, Glob` allowlist
- `codex exec ... -s read-only` dispatch
- Stage-then-read `mktemp -d` tempfile pattern (review-pr only)
- Path gate canonicalization `pwd -P` (run-spec, review-spec)
- Degraded-mode `CLAUDE-PASS: UNAVAILABLE (<reason>)` contract
- PR-comment self-identification marker `<!-- ai-driver-review -->`
- Existing-reviewer cross-check in review-pr Step 2c (v0.3.4+)
- Template-sync CI (`template-sync.yml`) byte-identity check

## Data flow

1. Main session dispatches subagent / Codex with stage-specific prompt
2. Reviewer returns findings table. Every `message` cell opens with `[<anchor>]` per MUST-001 parse rule
3. Synthesis step reads findings: for each row, anchor is extracted via `^\[[^\]]+\]` regex on leading token of `message`
4. Domain check: is anchor in this stage's whitelist?
   - Yes → row stays in main findings table, original severity
   - No (out-of-domain, no-anchor, or requires-spec) → row moves to Observations with `(tag: <reason>)` appended, severity capped at Info
5. Verdict computed from main findings table only. Observations shown to human, not counted

## Risks and mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Reviewer ignores anchor prefix convention | HIGH — scope fence bypassed | Prompt mandates anchor in `message`. Synthesis demotes no-anchor rows. AC-011 exercises the path |
| "Laundering" — reviewer puts valid anchor + unrelated prose | MEDIUM — known limitation | Known Limitations section accepts this residual. Social triage |
| Prompt rewrite regresses existing defenses | HIGH | AC-012 pins the 4 survival tokens (allowlist, -s read-only, mktemp -d, pwd -P) |
| Synthesis logic bug | HIGH | AC-011 deterministic harness with 4 fixtures, no LLM invocation |
| Review Level A still runs Phase 0 with new prompts | LOW | Phase 0 is unconditional (R-008); already handled by existing flow |

## File-level change plan

| # | File | Change | Est. delta |
|---|------|--------|-----------|
| 1 | `plugins/ai-driver/commands/review-spec.md` | Rewrite Layer 1 + Layer 2 prompt blocks; add Consensus demotion contract | +80 / −30 |
| 2 | `plugins/ai-driver/commands/run-spec.md` | Phase 0 Layer 1 prompt + Phase 1 plan-review subagent prompt + Phase 1 plan-review Codex prompt rewrite; Gating demotion contract | +100 / −50 |
| 3 | `plugins/ai-driver/commands/review-pr.md` | Pass 1 + Pass 2 prompt rewrite; Step 5 synthesis demotion contract; Step 6 report: `### Observations` section between findings and Verdict; literal "Verdict computation excludes Observations" | +120 / −40 |
| 4 | `tests/review-synthesis/drift-demotion.sh` + `fixtures/` | New deterministic harness: 4 fixtures × stage × assertions (in-domain / out-of-domain / no-anchor / no-spec-PR) | +200 |
| 5 | `AGENTS.md` | Scope-fenced reviews bullet with anchor whitelist reference | +3 |
| 6 | `CHANGELOG.md` | `## [Unreleased]` → `### Changed` entries | +25 |

Total: ~650 prose lines, ~200 test-harness lines.

## Dependencies

None. Every change is self-contained.

## Sequencing (build order)

1. **T008 first (TDD RED)**: write the harness + fixtures first. It fails because no synthesis logic exists yet. This is the concrete test for the synthesis contract we're about to write.
2. Then T006 (synthesis prose in all three commands) — makes the harness pass (GREEN).
3. Then T001-T004 (prompt rewrites per stage) — adds Focus / Out-of-scope / whitelist.
4. Then T007 (review-pr Step 6 report format).
5. Then T010-T011 (AGENTS.md + CHANGELOG).
6. Last: T012 acceptance — run AC-001..AC-013 via bash, assert all pass.

## Out of scope (explicit R-003)

- No evidence-match layer (the Known Limitations reservation)
- No constitution change (documented in spec — scope fence is prompt-layer contract, not constitutional authority)
- No new commands
- No removal of v0.4.0 surviving defenses
- No injection-lint revival (v0.4.0 removed this deliberately)
