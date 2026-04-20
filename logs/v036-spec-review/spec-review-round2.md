# Spec Review Round 2 — v036-spec-review.spec.md (post-revision)

## Layer 2 — Codex re-review summary

**Consensus:** 0 Critical, 4 High, 8 Medium, 0 Low.

### High findings

| Rule | Summary | Disposition |
|---|---|---|
| AC-COVER-001 | ACs are static greps; runtime promises (exit codes, branch state, `--accept-high`) not fixture-tested | **Defer to v0.3.7** — requires fixture infrastructure that is exactly the parked v0.3.7 scope (`specs/v037-injection-tests.spec.md`). Document in implementation.log; accept via `--accept-high` rationale. |
| COVERAGE-001 | No AC proves Phase 0 contains no git mutators | **Fix** — add AC-018: grep Phase 0 for absence of `git checkout -b`, `git commit`, `git push`, `git tag`, `git merge`. |
| SECURITY-001 | AC-010 too shallow — doesn't verify preamble + data fences | **Fix** — AC-010 split into AC-010a (Trust boundary heading) + AC-010b (preamble + `---BEGIN SPEC---`/`---END SPEC---` fences literal). |
| DOGFOOD-001 | AC-014 (constitution diff) + AC-017 (all PAIRS) depend on ambient repo state | **Partial fix** — drop AC-017 (redundant with template-sync CI which is a required check); keep AC-014 (only local enforcement of MUSTNOT-004). |

### Medium findings

| Rule | Summary | Disposition |
|---|---|---|
| CONTRADICT-001 | MUST-001 says "exactly one file" but Layer 0 fail path writes zero | **Fix** — amend to "zero files on Layer 0 fail; one log file on Layer 0 pass". |
| AC-EXEC-001 | AC-013 uses `\|` — passes if either prompt present | **Fix** — require both literals via `grep && grep`. |
| CONTRADICT-002 | AC-005 counts 5 rules but spec names 7 | **Fix** — AC-005 lists the 7 exact rule IDs. |
| COVERAGE-002 | AC-008 shallow for MUSTNOT-002 | Accept — `--write-log` branching is a behavioral invariant enforced by the command doc; adding a runtime AC pushes into fixture territory (deferred). |
| SCOPE-001 | Goal-vs-docs/CI ACs mix feature with repo-maintenance | **Reject** — ship-cycle ACs (CHANGELOG, AGENTS, template-sync) are project convention from v0.3.2+; dropping them would regress dogfooding. |
| AMBIG-001 | "run proceeds iff Layer 0 + Layer 1 are clean" — Medium needs y/N | **Fix** — Scenario 4 reword to reference severity table explicitly. |
| EDGE-001 | Consensus key only `rule_id` can collapse distinct findings | **Fix** — note in Implementation Guide: consensus key = `rule_id + location`. |
| OVERSPEC-001 | Spec leaks model/version/timeout/heading text | Accept partially — exact headings (`## Phase 0: Spec Review`) are needed for AC greps to work; model/timeout are command-doc concerns not spec. Trim the leaks in Implementation Guide. |

## Gating decision

Using `--accept-high` with rationale:
- **AC-COVER-001** defers to v0.3.7 (injection-fixtures) — that spec already exists as the next scheduled cycle and explicitly owns runtime fixture harness.
- Remaining High + all actionable Medium → **fix in place** in this commit.

Proceeding to spec amendment + implementation after fixes are applied.
