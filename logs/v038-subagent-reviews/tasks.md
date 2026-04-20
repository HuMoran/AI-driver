# Tasks — v038-subagent-reviews

## Gate 1 (spec review) — subagent migration

- [ ] T001 [AC-001,002,003,019] Rewrite `run-spec.md` §Phase 0 Layer 1: replace inline prompt with `Agent(subagent_type=general-purpose, ...)` spawn. Subagent `allowed-tools: Read, Grep, Glob` exactly. Literal prompt block preserved under `### Layer 1 prompt (literal, audited)`. Main session passes `$SPEC_PATH` by path only. | Files: plugins/ai-driver/commands/run-spec.md
- [ ] T002 [AC-002,003,036] Rewrite `review-spec.md` §Layer 1: same subagent pattern. Exact `allowed-tools`. Bounded-read prompt ("Do NOT read any file outside this list.") | Files: plugins/ai-driver/commands/review-spec.md
- [ ] T003 [AC-003,010] Ensure Gate 1 Codex pass (Layer 2) uses `codex exec` + `-s read-only` + `Bash(run_in_background=true)` pattern, in both `run-spec.md` and `review-spec.md`. | Files: same two files
- [ ] T004 [AC-014,015] Canonical degraded-mode strings (`CLAUDE-PASS: UNAVAILABLE (<reason>)`, `CLAUDE-PASS: PARSE_ERROR`, `rule_id=parse-error`) + log locations (`logs/<spec-slug>/spec-review.md`) present in both Gate 1 docs. | Files: same two files

## Gate 2 (plan review) — dual LLM

- [ ] T005 [AC-005,006] Rewrite `run-spec.md` Phase 1 plan review: add subagent pass alongside Codex. Rename "Codex Plan Review" → "Plan Review". Claude subagent reads `plan.md` by path; Codex `exec` runs same-flavor prompt. Both gated by Review Level ≥ B. | Files: run-spec.md
- [ ] T006 [AC-005,016] Phase 1 log at `logs/<spec-slug>/plan-review.md`; consensus table keyed by `(rule_id, normalized_location)` with the same `dual-raised` rule as Gate 1. | Files: run-spec.md

## Gate 3 (PR review) — stage-then-read + subagent

- [ ] T007 [AC-007,008,009,010,011,012,013,034] Rewrite `review-pr.md` Step 2–3: remove inline `gh pr view` body capture; add `STAGE=$(mktemp -d)` + `chmod 700` + `trap rm -rf` + `set +x` + `fetch()` helper with stdout+stderr redirect + fail-closed. Pass 1 becomes Agent spawn with `allowed-tools: Read, Grep, Glob`, bounded to `$STAGE/*`. | Files: plugins/ai-driver/commands/review-pr.md
- [ ] T008 [AC-012,012a,025] Spec-body artifact: if PR body names a spec path, run the v0.3.7 path gate on it (reject `..`, `pwd -P`, under `specs/`, `*.spec.md`), then stage only the validated path. | Files: review-pr.md
- [ ] T009 [AC-010,014,015,033] Pass 2 uses `codex exec -s read-only` via `Bash(run_in_background=true)`. Degraded-mode strings. No `nohup`. | Files: review-pr.md

## Return-channel sanitization

- [ ] T010 [AC-030,031,032] Add a "Return-channel sanitization" subsection to each Claude-pass gate doc: document the parser's cell caps (`message` ≤ 200, `fix_hint` ≤ 200, others ≤ 100), `|`/`` ` `` escaping, and the fixed `parse-error` message literal. | Files: all three command docs

## No-nested-spawn enforcement

- [ ] T011 [AC-013] Subagent prompts explicitly state "you MUST NOT spawn nested subagents" AND `allowed-tools` excludes `Agent`/`Task`/`Subagent`. | Files: all three command docs

## Docs + template + threat model

- [ ] T012 [AC-037,038] Update README.md + README.zh-CN.md: Gate 2 workflow becomes dual-LLM ("subagent + Codex"); no "Codex-only" wording. | Files: README.md, README.zh-CN.md
- [ ] T013 [AC-039] Update AGENTS.md three-gate paragraph to name subagent isolation + stage-then-read as the enforcement mechanism. | Files: AGENTS.md
- [ ] T014 [AC-040] CHANGELOG `[Unreleased]` with bullets covering: Gate 1/2/3 subagent migration, Gate 3 stage-then-read, return-channel sanitization, tracked-background Codex, R-009 proposal. | Files: CHANGELOG.md
- [ ] T015 [AC-?] `docs/security/injection-threat-model.md` gets `<a id="R-009"></a>` anchor describing the stage-then-read mitigation for review-body-approval-hijack. | Files: docs/security/injection-threat-model.md

## Acceptance

- [ ] T016 [all] Run full AC sweep (41 ACs). All must pass. | Files: logs/v038-subagent-reviews/acceptance-report.md
- [ ] T017 [all] injection-lint + regression harness green. | Files: (verification only)
- [ ] T018 Write implementation.log with R-009 proposal text, deferred Round 5 Medium disposition, and R-007 final status. | Files: logs/v038-subagent-reviews/implementation.log
