# /ai-driver:run-spec: Execute a spec from plan to PR

Usage: `/ai-driver:run-spec <path-to-spec-file>`

You are an AI engineer executing a spec-driven development workflow. Read the spec file provided as `$ARGUMENTS` and execute it end-to-end.

## Spec identifiers

Two related but distinct identifiers, derived deterministically from the spec file:

1. **`<spec-slug>`** — filename basename with `.spec.md` stripped. Used for log directory paths (`logs/<spec-slug>/`). Examples:

| Spec path | `<spec-slug>` |
|---|---|
| `specs/user-auth.spec.md` | `user-auth` |
| `specs/fix-issue-42.spec.md` | `fix-issue-42` |
| `specs/v035-copilot-backlog.spec.md` | `v035-copilot-backlog` |

2. **`<branch-slug>`** — `<spec-slug>` normalized to be a valid git ref: lowercase, replace any character that's not `[a-z0-9]`, `.`, or `-` with `-`, collapse runs of `-`, trim leading/trailing `-`. Example: `user auth` → `user-auth`, `weird Name_42` → `weird-name-42`. Used only for branch names (`feat/<branch-slug>` or `fix/<branch-slug>`). If `<spec-slug>` is already ref-safe (only `[a-z0-9-.]`, no spaces), `<branch-slug>` equals `<spec-slug>`.

3. **`<spec-path>`** — the actual path from `$ARGUMENTS`. Used for the PR-body "Spec" link verbatim, so nested directories (e.g., `specs/2026-04/foo.spec.md`) or filenames with unusual characters are linked without loss.

The `Meta` section only contains `Date` and `Review Level` — no identity fields. Everything identity-related flows from the filename.

## Pre-flight

1. **Path gate.** `$ARGUMENTS` must resolve to a regular file under the project's `specs/` directory whose basename ends in `.spec.md`. A prefix check alone is **not sufficient** — `specs/../etc/passwd` starts with `specs/` but canonicalizes outside the directory. Both rules apply: reject any path containing `..` segments, AND canonicalize with `realpath` before accepting. Enforcement:

   ```bash
   # Reject any path with .. segments or a leading / (absolute).
   case "$ARGUMENTS" in
     /*|*..*) echo "ERROR: spec path must be relative and must not contain '..' (got: $ARGUMENTS)" >&2; exit 2 ;;
   esac
   # Basename must end in .spec.md.
   case "$ARGUMENTS" in
     *.spec.md) ;;
     *) echo "ERROR: spec file must end in .spec.md (got: $ARGUMENTS)" >&2; exit 2 ;;
   esac
   # File must exist.
   [ -f "$ARGUMENTS" ] || { echo "ERROR: spec not found: $ARGUMENTS" >&2; exit 2; }
   # Canonicalize and confirm the resolved path is under $PWD/specs/.
   SPECS_ROOT=$(cd specs && pwd -P) || { echo "ERROR: specs/ directory not found" >&2; exit 2; }
   SPEC_REAL=$(cd "$(dirname "$ARGUMENTS")" && pwd -P)/$(basename "$ARGUMENTS")
   case "$SPEC_REAL" in
     "$SPECS_ROOT"/*) ;;
     *) echo "ERROR: resolved spec path is outside specs/ (resolved: $SPEC_REAL)" >&2; exit 2 ;;
   esac
   ```

2. Read the spec file at `$ARGUMENTS`.
3. Read `${CLAUDE_PLUGIN_ROOT}/rules/*.md` files relevant to this project's language.
4. Compute `SPEC_SLUG` from `$ARGUMENTS` (see convention above). Do not create any directory yet.

## Phase 0: Spec Review (MANDATORY — unconditional)

Phase 0 is required for every run, regardless of the spec's `Review Level`. Review Level governs downstream effort (plan review, per-step review); Phase 0 governs input correctness. The two are independent.

**Gating summary:** Critical findings (any layer) STOP the run with `exit 2` — not overridable. High findings also STOP with `exit 2` unless `--accept-high` is passed. No branch is created and no implementation work begins when Phase 0 blocks.

Phase 0 runs **before any git mutation or implementation write**. Do not create a branch, stage changes, or modify project files during Phase 0. Also, do not create `logs/<spec-slug>/` or write any Phase 0 artifacts until **after Layer 0 passes**. Once Layer 0 passes, the **only** allowed Phase 0 write is the review log under `logs/<spec-slug>/` (including `spec-review.md`). If Phase 0 ultimately fails before Layer 0 completes, no git state has been mutated and no files have been changed; if Phase 0 fails after Layer 0 passes, the only tree change is the review log.

The review has three independent layers (Layer 0 mechanical → Layer 1 Claude → Layer 2 Codex). The same three-layer logic is also exposed as the standalone `/ai-driver:review-spec` command; shared prompts and gating live in that file and this section cross-references it.

### Layer 0: Mechanical pre-check (sub-second, no LLM)

Run each rule against the spec file. Report `[PASS]` / `[FAIL]` with line numbers on failure.

| Rule | Check |
|---|---|
| `S-META` | `## Meta` block contains a `Date: YYYY-MM-DD` line and a `Review Level: [ABC]` line |
| `S-GOAL` | `## Goal` section exists with ≥1 non-empty, non-placeholder line |
| `S-SCENARIO` | ≥1 `**Given**`, ≥1 `**When**`, ≥1 `**Then**` line (scenario structure present) |
| `S-AC-COUNT` | ≥1 line matching `^- \[ \] AC-\d{3}:` |
| `S-AC-FORMAT` | Every `AC-` line strictly matches the three-digit pattern |
| `S-CLARIFY` | Zero `[NEEDS CLARIFICATION]` markers **outside inline code**. Strip inline-code spans before matching — see the fenced example under Layer 0 below. |
| `S-PLACEHOLDER` | Zero unresolved `<…>` placeholders inside `## Meta` or `## Goal` |

If any Layer 0 rule fails → print failures with fix hints, exit 2. **No Layer 1 or Layer 2 call.** No branch created, no logs directory created.

S-CLARIFY strip-inline-code reference implementation:

```bash
sed 's/`[^`]*`//g' "$SPEC_PATH" | grep -Fn '[NEEDS CLARIFICATION]'
# must print nothing (exit 1 from grep) for S-CLARIFY to pass
```

### Layer 1: Claude adversarial review (subagent)

v0.3.8+: the Claude pass runs in a **dedicated subagent**, not the main session. Rationale: hostile spec content cannot contaminate the main session's context if it never enters it, and a fresh subagent context removes implementer bias (main session is about to implement; subagent's only job is to find defects). Main session passes `$SPEC_PATH` as a **path argument** — never by inline content capture.

**Subagent spawn** via the Agent tool with `subagent_type=general-purpose` and the exact tool allowlist:

```yaml
allowed-tools: Read, Grep, Glob
```

Exactly those three, nothing else. No Write, no Bash, no Agent (nested spawn forbidden per MUSTNOT-004), no network.

- Bounded-read scope: the subagent prompt explicitly lists every path it may Read (`$SPEC_PATH` + `${CLAUDE_PLUGIN_ROOT}/rules/*.md` + `constitution.md`). The prompt ends with the literal sentence **"Do NOT read any file outside this list."**
- No nested spawn: the prompt ends with the literal sentence **"You MUST NOT spawn nested subagents. This review is a leaf, not a branch."**

### Layer 1 prompt (literal, audited)

```
You are an adversarial reviewer of an engineering spec. Be terse and direct.

Read only these files: $SPEC_PATH ; ${CLAUDE_PLUGIN_ROOT}/rules/*.md ; ./constitution.md
Do NOT read any file outside this list.

You MUST NOT spawn nested subagents. This review is a leaf, not a branch.

Review checklist:
(a) AC executability — boolean machine check per AC?
(b) MUST/MUSTNOT coverage — every constraint covered by an AC?
(c) Scope discipline — feature mixed with refactor?
(d) Ambiguity — undefined terms, vague verbs.
(e) Contradictions — Goal / Scenarios / AC / MUST inconsistency.
(f) Security — prompt injection, unsafe shell, trust-boundary gaps.
(g) Feasibility — unverifiable or unreachable ACs.
(h) Missing edge cases.
(i) Over-specification — HOW leaking in.

Output a Markdown table with columns: Severity | rule_id | location | message | fix_hint
Severities: Critical | High | Medium | Low | Info.
End with one line: CONSENSUS: N_CRITICAL Critical, N_HIGH High, N_MEDIUM Medium, N_LOW Low.
```

### Layer 2: Codex external adversarial review

Run Codex as a tracked background job so the notification arrives automatically on the next turn (no polling, no silent drops):

```bash
# Tracked background dispatch — NOT `nohup codex ... &`.
# The Bash tool's `run_in_background=true` parameter keeps the process
# tracked by Claude Code; the completion notification is delivered to the
# main session's next turn; BashOutput reads the captured stdout/stderr.

# Invocation (the main agent should use Bash(run_in_background=true) via the
# tool, not a literal shell snippet; shown here as the equivalent shell form
# for audit clarity):
# Wrap stdin in the BEGIN/END SPEC fences the Layer 2 literal prompt expects:
{ printf -- '---BEGIN SPEC---\n'; cat "$SPEC_PATH"; printf -- '\n---END SPEC---\n'; } | \
  codex exec --model gpt-5.4 --config model_reasoning_effort="high" -s read-only "$CODEX_SPEC_REVIEW_PROMPT"
```

Notes:
- `$CODEX_SPEC_REVIEW_PROMPT` is the literal prompt from `review-spec.md` §"Layer 2 prompt (literal)".
- Input is the **spec file path** piped into stdin — the main session never interpolates raw spec bytes into Codex's prompt argument.
- Timeout: `${CODEX_TIMEOUT_SEC:-180}` seconds (applied by the main session as an outer wait bound).

Failure modes (MUSTNOT block on Codex unavailability):
- Codex missing / auth fail / non-zero exit → record `CLAUDE-PASS: UNAVAILABLE (<reason>)` in the review log, continue with a visible stdout warning.
- Timeout → record `CLAUDE-PASS: UNAVAILABLE (timeout ${CODEX_TIMEOUT_SEC}s)`, continue.
- Malformed output → record `CLAUDE-PASS: UNAVAILABLE (parse error)`, continue.

### Write review log

Write `logs/<spec-slug>/spec-review.md` containing three sections (Layer 0 / Layer 1 / Layer 2) + Consensus table + Gating decision. This is the **first file write of the run** and only happens if Layer 0 passes.

**If the directory `logs/<spec-slug>/` does not exist yet, create it solely for this file.** Branch creation is still deferred to Phase 1.

### Gating

Build a consensus table keyed by **`(rule_id, normalized location)`** — lowercase rule_id, whitespace-trimmed location, with ±3-line fuzz on `file:line` positions to absorb Codex line-offset drift. Two findings with the same rule_id but genuinely different locations are separate rows, **not** merged. A finding raised by both Layer 1 and Layer 2 on the same `(rule_id, normalized location)` key is marked `dual-raised` and upgraded one severity notch (same pattern as `review-spec.md` / `review-pr.md`).

| Severity | Action |
|---|---|
| Critical (any layer) | STOP. Print full report, `exit 2`. Not overridable. |
| High (any layer) | STOP with `exit 2` unless `--accept-high` flag is passed to `run-spec`. With the flag: print `ACKNOWLEDGED (--accept-high)` + rationale, continue. |
| Medium | Interactive y/N prompt. Non-TTY → treat as N → `exit 2`. |
| Low / Info | Print, continue. |

On any STOP / exit 2: no branch was created, and no implementation work began. If execution stops **during Layer 0**, the tree is fully unchanged (no log file, no directory). If Layer 0 completed and execution stops at a later gate (Layer 1 / Layer 2 / consensus), the only tree change is the review log at `logs/<spec-slug>/spec-review.md`.

## Phase 1: Prepare + Design Action Plan

### Prepare

Only executed when Phase 0 passed (or was overridden with `--accept-high`). This is the first step that mutates git state.

- Check `git status` — if there are uncommitted changes outside `logs/<spec-slug>/`, STOP and ask user to commit or stash first.
- Check if `gh auth status` succeeds — if not, warn user but continue (PR creation will fail later).
- **Default branch name**: `feat/<branch-slug>` if the primary intended commit type is `feat`, else `fix/<branch-slug>`. `<branch-slug>` is the ref-safe normalization of `<spec-slug>` (see §"Spec identifiers"). Pick `feat` vs `fix` by reading the spec's Goal and User Scenarios; if ambiguous, default to `feat`.
- Check if the branch already exists:
  - If it does AND has commits beyond `main`: ask user whether to resume from existing branch or start fresh.
  - If it does with no extra commits: switch to it.
  - If it doesn't exist: `git checkout -b <branch-name>` from main.
- Ensure `logs/<spec-slug>/` exists (it may already exist from Phase 0's `spec-review.md` write).
- If `logs/<spec-slug>/tasks.md` exists with checked items: this is a resume. Show progress and ask user whether to continue from where it left off.

### Design

Generate `logs/<spec-slug>/plan.md`:

- Architecture overview (use ASCII diagrams).
- Reuse analysis: what existing code can be leveraged.
- Risks and dependencies.
- Data flow.

Generate `logs/<spec-slug>/tasks.md`:

- Atomic tasks, each 2-5 minutes.
- Format: `- [ ] T001 [AC-xxx] description | Files: path/to/file`.
- `[P]` marks parallelizable tasks.
- `[AC-xxx]` traces back to acceptance criteria.
- Every AC-xxx in the spec must have at least one task covering it.

### Plan Review (if review level >= B)

v0.3.8+: Phase 1 plan review is a **dual-LLM gate**, symmetric with Phase 0 (spec review) and Gate 3 (PR review). When the spec's `Review Level` is `B` or `C`, run BOTH a Claude subagent pass AND a Codex external pass against `logs/<spec-slug>/plan.md`. If `Review Level` is `A`, skip both passes — the gate preserves the existing opt-out for light-weight work.

#### Plan review prompt (literal, audited)

Same shape as the Layer 1 spec-review prompt — shared checklist so findings are comparable across gates:

```
You are an adversarial reviewer of an implementation plan. Be terse.

Read only these files: logs/<spec-slug>/plan.md ; logs/<spec-slug>/tasks.md ; $SPEC_PATH ; ./constitution.md
Do NOT read any file outside this list.

You MUST NOT spawn nested subagents. This review is a leaf, not a branch.

Review the plan for: gaps, risks, feasibility issues, scope creep, architectural debt, missing task coverage vs ACs, and tests that will false-pass.

Output a Markdown table with columns: Severity | rule_id | location | message | fix_hint.
Severities: Critical | High | Medium | Low | Info.
End with one line: CONSENSUS: N_CRITICAL Critical, N_HIGH High, N_MEDIUM Medium, N_LOW Low.
```

#### Pass: Claude subagent

Spawn via the Agent tool with the exact tool allowlist (top-level YAML, no indentation):

```yaml
allowed-tools: Read, Grep, Glob
```

Exactly those three, nothing else. Main session passes `plan.md` as a **path argument**; no inline content capture. Malformed subagent output → `CLAUDE-PASS: UNAVAILABLE (parse error)`, continue.

#### Pass: Codex external

- Dispatch via Claude Code's `Bash(run_in_background=true)` — NOT `nohup codex &`. Completion notification arrives on next turn; `BashOutput` reads stdout.
- Invocation (shell form shown for audit; main agent uses the Bash tool with `run_in_background=true`):

  ```bash
  codex exec --model gpt-5.4 --config model_reasoning_effort="high" -s read-only \
    "$PLAN_REVIEW_PROMPT" < logs/<spec-slug>/plan.md
  ```
- `$PLAN_REVIEW_PROMPT` is the literal prompt block above.

#### Consensus + log

Write `logs/<spec-slug>/plan-review.md` with three sections: `## Pass 1 — Claude subagent`, `## Pass 2 — Codex`, `## Consensus`. Consensus is keyed by `rule_id + normalized location` (lowercase rule_id, whitespace-trimmed location, ±3-line fuzz for Codex line-offset drift). A finding raised by both passes is marked `dual-raised` and upgraded one severity notch.

Gating is identical to Phase 0: Critical → STOP exit 2; High → `--accept-high` or STOP; Medium → y/N; Low/Info → continue. Degraded-mode string: `CLAUDE-PASS: UNAVAILABLE (<reason>)`. A pass that degrades does not block when the other pass is clean.

## Phase 2: Implement

Execute each task in `tasks.md` sequentially. For EVERY task, follow R-002 (TDD):

1. Write a failing test for the task's expected behavior.
2. Run the test — confirm it FAILS (RED).
3. Write the minimal implementation to make the test pass.
4. Run the test — confirm it PASSES (GREEN).
5. Refactor if needed.
6. Run the language's format tool (per `${CLAUDE_PLUGIN_ROOT}/rules/<lang>.md`, R-006).
7. `git add` changed files + `git commit` with Conventional Commits message (R-005).
8. Mark the task `[x]` in `tasks.md` and commit the updated `tasks.md`.

If Review Level = `C`: after each task, run `codex exec "Review the last commit for quality issues" -s read-only` and fix findings before continuing.

### Self-Review After All Tasks

- Check: does every AC-xxx in the spec have a passing test?
- Check: did any task go beyond the spec? (R-003 violation)

## Phase 3: Acceptance

SECURITY: Before executing any AC command, validate it:

- Command MUST NOT contain pipes to `curl` / `wget`, network calls to external URLs, `rm -rf`, or `sudo`.
- Command MUST be a standard build/test/lint command (e.g., `cargo test`, `pytest`, `npm test`, `go test`).
- If an AC command looks dangerous or unusual, STOP and ask user for confirmation.

For each Acceptance Criteria in the spec:

- Run the command specified in the AC.
- Read the actual output.
- Confirm pass/fail (R-001: no guessing, no "should pass").

Generate an acceptance report:

```
## Acceptance Report
- AC-001: [command] → [actual output] → PASS/FAIL
- AC-002: [command] → [actual output] → PASS/FAIL
...
```

- ALL PASS → proceed to Phase 4.
- ANY FAIL → apply R-004 (root cause analysis), fix, re-run. Max 3 retries. If still failing after 3 attempts, report BLOCKED.

## Phase 4: Submit PR

```bash
git push -u origin <branch-name>
```

Create PR with `gh pr create`:

- Title: Conventional Commits format matching the primary change type.
- Body must include:
  - **Spec**: markdown link using the actual `<spec-path>` from `$ARGUMENTS` (not reconstructed from slug), so nested dirs / unusual filenames round-trip: `` `[<spec-path>](<spec-path>)` ``.
  - The acceptance report from Phase 3.
  - Summary of changes.

Write `logs/<spec-slug>/implementation.log`:

- What was implemented.
- What existing code was leveraged.
- Issues encountered.
- Final status: DONE / DONE_WITH_CONCERNS / BLOCKED.

Commit the logs directory: `git add logs/ && git commit -m "docs: add implementation logs for <spec-slug>" && git push`.

Report completion status per R-007.
