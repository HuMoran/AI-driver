# Plan — v038-subagent-reviews

## Architecture

```
v0.3.6-7 (current)                        v0.3.8 (target)
============================================================================

Gate 1 (spec review)                      Gate 1
 ┌────────────────────┐                    ┌──────────────────────────────┐
 │ main session       │                    │ main session                 │
 │  reads $SPEC_PATH  │                    │  validates $SPEC_PATH        │
 │  applies checklist │                    │     │                         │
 │  INLINE            │       ──►          │     └─► subagent_type=...    │
 │                    │                    │         allowed-tools:        │
 │                    │                    │           Read, Grep, Glob   │
 │                    │                    │         prompt bounds reads  │
 │                    │                    │         returns table text   │
 └────────────────────┘                    └──────────────────────────────┘

Gate 2 (plan review)                      Gate 2
 ┌────────────────────┐                    ┌──────────────────────────────┐
 │  Codex only        │       ──►          │  subagent + Codex (both)     │
 │  (Level ≥ B)       │                    │  (Level ≥ B, unchanged gate) │
 └────────────────────┘                    └──────────────────────────────┘

Gate 3 (PR review)                        Gate 3
 ┌──────────────────────────┐              ┌──────────────────────────────┐
 │ main session             │              │ main session                 │
 │  gh pr view (capture)    │              │  STAGE=$(mktemp -d)          │
 │  ingests untrusted text  │   ──►        │  set +x; trap rm…            │
 │  INLINE Claude Pass 1    │              │  fetch diff/reviews/etc      │
 │                          │              │    > $STAGE/  2> $STAGE/*.err│
 │                          │              │    fail-closed on error      │
 │                          │              │     │                         │
 │                          │              │     └─► subagent reads       │
 │                          │              │         $STAGE/*             │
 │                          │              │         (prompt-bounded)     │
 └──────────────────────────┘              └──────────────────────────────┘

Codex invocations (all gates): Bash(run_in_background=true) + BashOutput
  NOT `nohup codex exec … &`

Return channel (subagent → main session): sanitized parser
  - cell length caps (message/fix_hint ≤ 200, others ≤ 100)
  - escape  |  and  `  in cells
  - parse-error: fixed literal message, log pointer only
```

## Reuse Analysis

- **v0.3.6 Phase 0 structure** in `run-spec.md` stays — only the Layer 1 body changes from inline-prompt to subagent spawn.
- **v0.3.6 `## Trust boundary` sections** in `review-pr.md` / `fix-issues.md` / `merge-pr.md` stay — they document the attack surface and remain the first thing a reader sees.
- **v0.3.6 path gate** (`case "$ARGUMENTS" in / case "$SPEC_PATH" in ... specs/*/... && pwd -P && cd specs`) stays verbatim; the same gate now covers PR-body-derived spec paths (MUST-008) — just reinvoked from Gate 3.
- **v0.3.6 degraded mode pattern** (`UNAVAILABLE (<reason>)` + `PARSE_ERROR`) formalized across all three gates.
- **v0.3.7 injection-lint** remains authoritative for L-TRUST / L-QUOTE / L-SELF-ID / L-BOT / L-EXTRACT. AC-027 + AC-028 enforce no regression.
- **Existing Codex `-s read-only` invocation shape** from v0.3.6 review-spec + v0.3.7 injection-lint — same flag set, just reordered into the new gate structure and dispatched via `run_in_background`.

## Risks & Dependencies

| Risk | Mitigation |
|---|---|
| Subagent `allowed-tools: Read, Grep, Glob` may not be hermetic (read can access any file under `$PWD`) | MUST-009 belt-and-suspenders: subagent prompt explicitly lists allowed paths + says "Do NOT read any file outside this list". AC-036 checks the literal phrase is present per gate. |
| Subagent returns crafted findings containing attacker bytes | MUST-010 sanitization at the parser boundary (length caps, `\|`/` escape, fixed parse-error literal). AC-034/AC-035 enforce. |
| `nohup codex &` regression (my own workflow bug) | MUST-011 + AC-033 — every Codex site uses `run_in_background`, no `nohup codex`. Lint could be added in v-next. |
| Command docs become longer / harder to read | Structure-preserving edits (Layer 1 body replace, Pass 1 body replace, Phase 1 body append). No section renumbering. |
| The R-008/R-009 approval workflow depends on user comment on the PR | Same pattern as v0.3.6 R-008 — spec MUSTNOT-004 forbids amending constitution in feature commit; R-009 lands as a separate commit post-approval. |

## Data Flow

### Gate 1 (spec review)
```
$ARGUMENTS ──► path-gate ──► $SPEC_PATH (validated, under repo/specs/, *.spec.md)
                                │
               Layer 0 grep ────┤──► pass/fail (sub-second, no LLM)
                                │
                     Layer 1 ───┤──► Agent(subagent_type=..., prompt=literal + $SPEC_PATH)
                                │      subagent Reads $SPEC_PATH, returns table
                                │      main session parses via sanitization
                                │
                     Layer 2 ───┤──► Bash(run_in_background=true): codex exec -s read-only
                                │      < $SPEC_PATH
                                │      notification on next turn, BashOutput reads
                                │
              logs/<slug>/spec-review.md (Gate 1 log; includes degraded-mode notes)
```

### Gate 2 (plan review, Review Level ≥ B)
```
plan.md on disk (already written by Phase 1)
      │
      ├─► Agent subagent Reads plan.md, returns findings table (sanitized on parse)
      │
      └─► Bash(run_in_background=true): codex exec -s read-only < plan.md
            notification → BashOutput

   both outputs merged into logs/<slug>/plan-review.md (Gate 2 log)
   consensus by (rule_id, normalized_location) ±3 lines
```

### Gate 3 (PR review)
```
gh pr resolve  ──► $PR
  │
  ├─► STAGE=$(mktemp -d) + chmod 700 + trap rm -rf + set +x
  │
  ├─► fetch() helper:
  │     gh pr diff $PR                               > "$STAGE/diff.txt"           2> "$STAGE/diff.txt.err"
  │     gh api --paginate /pulls/$PR/reviews         > "$STAGE/reviews.json"       2> "$STAGE/reviews.json.err"
  │     gh api --paginate /pulls/$PR/comments        > "$STAGE/inline-comments.json" 2> "…"
  │     gh api --paginate /issues/$PR/comments       > "$STAGE/issue-comments.json"  2> "…"
  │     (if PR body names a spec) path-gate → "$STAGE/spec-body"  (copy only)
  │     non-zero exit → fail-closed, no subagent spawn
  │
  ├─► Pass 1: Agent subagent (allowed-tools: Read, Grep, Glob)
  │     prompt lists $STAGE/* as the only readable paths, forbids reading outside
  │     returns findings table → sanitized parser → main session
  │
  └─► Pass 2: Bash(run_in_background=true): codex exec -s read-only
        feeds $STAGE/diff.txt and any other $STAGE/* as needed
        notification → BashOutput

   both outputs merged into the PR review comment body
   Degraded-mode notes section if either pass is UNAVAILABLE
```

## Out of scope (per spec scope note + v0.3.6 precedent)

- Runtime integration tests for the tracked-background notification (Scenario 5 AC-037 is doc-only; adequate for this release).
- Chunking subagent input when over-length — deferred.
- Constitution amendment commit — awaits explicit user approval per governance; MUSTNOT-004.
