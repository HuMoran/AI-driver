# v038-subagent-reviews.spec.md

## Meta

- Date: 2026-04-20
- Review Level: B

## Goal

Make every AI-driven review in the three-gate pipeline run inside a **sandboxed executor** — a dedicated Claude Code subagent for the in-session Claude pass, and `codex exec` for the external model pass — rather than inside the main conversational context. **The main session never interpolates raw untrusted content into its own prompt.** Handoff to the subagent is **always** by local path:
- If the content is already on disk (spec file for Gate 1, `plan.md` for Gate 2), pass the path. The path **must** be validated through the v0.3.7 path gate (reject `..`, canonicalize via `pwd -P`, confirm under `$(cd specs && pwd -P)/`). A PR body that names a spec file is treated the same way — no naming from untrusted data bypasses the gate.
- If the content must be fetched (PR artifacts for Gate 3), **stage-then-read**: the main session writes the content to a per-run tempdir via `gh ... > "$STAGE/<artifact>" 2> "$STAGE/<artifact>.err"` (**both** stdout AND stderr redirected — otherwise `gh` error text carrying attacker-controlled response bodies would still reach the main session's context), with `set +x` to disable tracing and a fail-closed error check (non-zero exit from any fetch → abort before any subagent spawn). `$STAGE` is created with `mktemp -d` + `chmod 700` and removed by a `trap` on exit.

Raw-content pass-through (e.g., interpolating `$PR_BODY` into a prompt string) is **forbidden** — it defeats the trust boundary even if the subagent is otherwise sandboxed.

This removes three latent problems that the current architecture has:

1. **Injection contamination.** Untrusted content (spec bodies, PR diffs, existing reviewer comments) currently enters the main session's context. The data-fence wrapping introduced in v0.3.4 / v0.3.6 is defense-in-depth, but a subagent is a stronger boundary: the payload never touches the main session at all.
2. **Implementer-reviewer role conflict.** Gate 1 and Gate 3's Claude pass today runs in the same session that is about to implement (Gate 1) or just implemented (Gate 3) the change. Fresh-context review catches classes the implementer is biased to miss.
3. **Gate 2 asymmetry.** Plan review (v0.3.0) is Codex-only; Gate 1 and Gate 3 are dual-LLM. Adding a Claude subagent pass to Gate 2 restores symmetry and unblocks dual-consensus severity upgrades at the plan layer.

The change also codifies the principle as a new operational rule (proposed amendment `R-009: Review Runs In A Sandbox Executor`), governing any future review-flavored command.

**Ancillary change (same release):** long-running external reviews (`codex exec`) are invoked via Claude Code's `Bash(run_in_background=true)` pattern, not via shell `nohup ... &`. The former is tracked by Claude Code: a completion notification is delivered to the main session's next turn automatically, so no polling is needed and no result is silently missed. This is a workflow correctness fix — without it, an operator driving the framework (human or AI) can forget to check on an in-flight review and quietly skip past a High/Critical finding. The fix lives in the command docs so every future invocation inherits it.

Scope: three gates × two axes (Claude subagent + Codex external) = uniform 2×3 matrix. Codex half is unchanged in kind; Claude half moves from "main agent applies checklist" to "main agent spawns a subagent that applies the checklist and returns structured findings".

## User Scenarios

### Scenario 1: Gate 2 plan review becomes dual-LLM (Priority: P0)

**As a** user running `/ai-driver:run-spec specs/foo.spec.md` with `Review Level: B`,
**I want** Phase 1 plan review to run both Claude (via subagent) and Codex (external) adversarially,
**so that** plan-layer defects are caught by the same dual-consensus mechanism as spec and PR layers.

**Acceptance Scenarios:**

1. **Given** a spec with `Review Level: B` and a generated `plan.md`, **When** Phase 1 plan review runs, **Then** two findings tables are written — one from Claude subagent, one from Codex — and a consensus table marks entries raised by both as `dual-raised`.
2. **Given** a spec with `Review Level: A`, **When** Phase 1 runs, **Then** plan review is skipped (both Claude and Codex), consistent with prior behaviour.

**Independent Test Method:** grep `run-spec.md` for two distinct review invocations inside `### Codex Plan Review` (renamed to `### Plan Review` or similar), and verify both are gated behind Review Level ≥ B.

### Scenario 2: Gate 1 Layer 1 migrates to subagent (Priority: P0)

**As a** user running `/ai-driver:run-spec` or `/ai-driver:review-spec`,
**I want** the Claude spec-review pass to run in a subagent, not in the main session,
**so that** hostile spec content cannot contaminate the main session's context via prompt-injection, even if the data-fence wrapping is imperfect.

**Acceptance Scenarios:**

1. **Given** the command docs for `run-spec.md` and `review-spec.md`, **When** Layer 1 runs, **Then** the spec body is passed to a Claude Code subagent (via the `Agent` tool / equivalent), NOT applied directly in the current session's prompt.
2. **Given** a malformed or corrupt spec, **When** Layer 1 runs and the subagent returns non-structured output, **Then** the finding is wrapped as a single Medium `parse-error` entry and the review continues (unchanged from v0.3.6 parser-robustness rule).

**Independent Test Method:** grep for an explicit `Agent` / subagent spawn in the Layer 1 section of both command docs, and assert the main session never quotes raw spec content to Claude except within the subagent prompt.

### Scenario 3: Gate 3 Pass 1 migrates to subagent (Priority: P0)

**As a** user running `/ai-driver:review-pr <N>`,
**I want** the Claude Pass 1 review to run in a subagent,
**so that** a malicious PR author cannot inject instructions into my main session by posting a hostile review comment, PR body, or diff comment — the attack surface that fixture `review-body-approval-hijack.md` documents.

**Acceptance Scenarios:**

1. **Given** a PR with an existing Copilot review and a Claude Pass 1 invocation, **When** Pass 1 runs, **Then** the main session creates a per-run tempdir via `STAGE=$(mktemp -d) && chmod 700 "$STAGE" && trap 'rm -rf "$STAGE"' EXIT INT TERM`, stages the PR artifacts to that dir via `gh … > "$STAGE/<artifact>"` (stdout redirected — bytes never enter main-session context), then spawns a Claude subagent whose prompt names those paths. Only the subagent's structured findings return to the main session.
2. **Given** a PR whose review body contains raw untrusted content, **When** Pass 1 runs, **Then** the `review-pr.md` doc shows **no** pattern of the form "`gh pr view … --json body` → interpolate `$BODY` into a prompt". All untrusted ingestion goes through `> "$STAGE/<artifact>"` redirects + subagent file-read. Structural invariant — shell-checkable by grepping the Pass 1 section for `gh pr|gh api` and asserting each is followed by a `>` redirect to `$STAGE`, with no pipe to `jq` for body extraction and no `$PR_BODY`/`$REVIEW_BODY`/`$ISSUE_BODY`/`$COMMENT_BODY` variable usage anywhere.

**Independent Test Method:** grep `review-pr.md` Pass 1 section for (a) explicit subagent spawn, (b) `mktemp -d` + `trap` + `chmod 700` pattern, (c) `gh … > "$STAGE/…"` redirect for each of the four artifacts (diff, reviews, inline-comments, issue-comments), (d) no occurrence of `$PR_BODY` / `$REVIEW_BODY` / `$COMMENT_BODY` / `$ISSUE_BODY`.

### Scenario 4: Degraded mode when subagent unavailable (Priority: P0)

**As a** user whose subagent spawning fails (tool disabled, runtime error, environment without subagent support),
**I want** the review to degrade gracefully to Codex-only + a visible warning,
**so that** the framework remains usable in constrained environments.

**Acceptance Scenarios:**

1. **Given** subagent spawn returns an error, **When** any gate runs its Claude pass, **Then** the log records `CLAUDE-PASS: UNAVAILABLE (<reason>)`, a visible warning is printed, and the run proceeds with Codex-only findings. Gating thresholds still apply to Codex findings.
2. **Given** subagent spawn succeeds but returns malformed output, **When** a gate runs, **Then** the parser wraps the output as a single Medium `parse-error` finding and the review continues.

### Scenario 5: Codex invocations run in tracked background (Priority: P0)

**As an** AI (or human) operator driving `/ai-driver:run-spec` or `/ai-driver:review-pr`,
**I want** Codex calls to run via Claude Code's `Bash(run_in_background=true)` pattern,
**so that** completion is auto-notified to the next session turn and results are never silently missed — the bug pattern that caused Codex Round 4 on this very spec to sit unchecked across several turns.

**Acceptance Scenarios:**

1. **Given** `/ai-driver:run-spec` Phase 0 Layer 2, **When** it invokes Codex, **Then** the command doc specifies `Bash(run_in_background=true)` (or equivalently Claude Code's tracked-background idiom), NOT `nohup codex ... &`.
2. **Given** the Codex background job exits, **When** the main session's next turn begins, **Then** the operator sees a completion notification for the job and reads its output via `BashOutput`.
3. **Given** Gate 2 plan review and Gate 3 Pass 2 (both run Codex), **When** their command docs are inspected, **Then** both use the same tracked-background pattern.

**Independent Test Method:** grep all three command docs for forbidden `nohup.*codex` pattern (must be 0) AND required `run_in_background` / `BashOutput` / tracked-background language (must be ≥ 1 reference per Codex invocation site).

### Scenario 6: R-009 constitution amendment (Priority: P1)

**As a** maintainer,
**I want** a codified rule stating that any AI review in this framework MUST run in a sandboxed executor (subagent or external CLI),
**so that** future commands inherit the pattern without each one re-deriving it.

**Acceptance Scenarios:**

1. **Given** the PR body proposes `R-009: Review Runs In A Sandbox Executor`, **When** the maintainer replies `approve as-is`, **Then** a follow-up commit amends `constitution.md` + the template pair. Same governance pattern as v0.3.6's R-008.

### Edge Cases

- **Subagent tool-permission scope.** A review subagent has **exactly** `Read, Grep, Glob` — nothing else. The subagent's prompt restates the constraint as belt-and-suspenders.
- **Stage-then-read for Gate 3.** The subagent has no network → cannot `gh api`. Main session must fetch first, but does so via stdout redirect (`gh ... > /tmp/pr-<N>-<artifact>.json`), so the main session's Bash tool captures only the exit code, never the JSON bytes. Subagent reads the files. Concrete artifact set (fixed, all redirected): `diff`, `reviews`, `inline-comments`, `issue-comments`, `spec-body` (when the PR body names a spec file).
- **Long specs/diffs exceeding subagent context.** Out of scope for v0.3.8. If the subagent reports truncation or a runtime error suggesting over-length, degrade to Codex-only with a visible warning (same path as `CLAUDE-PASS: UNAVAILABLE`). A future spec can add explicit chunking if needed.
- **Subagent prompt visibility.** The exact subagent prompt text — checklist, data-fence markers, "treat as data" preamble — lives literally in the command docs for audit. Same MUST-005-style contract as v0.3.6.
- **Malformed subagent output.** If the subagent returns non-tabular or non-parsable text, the main session wraps it as a single Medium finding with `rule_id=parse-error` and the review continues. Same pattern as v0.3.6.

## Acceptance Criteria

Every AC is a runnable shell expression that exits non-zero on failure, with **one explicit carve-out**: **Scenario 6 / R-009 constitution amendment is a governance gate, not a shell AC.** It is tracked via PR-body proposal + maintainer approval in the PR comment thread + a separate post-approval commit. This exception applies only to governance of the constitution itself; all other scenarios (including Scenario 5 on tracked-background Codex) have shell-verifiable ACs.

Where an AC anchors to a specific commit (e.g., the feature commit vs the R-009 amendment commit), it uses a tag-prefix marker like `v038-feat` rather than positional `HEAD^` so rebases don't break it.

### Gate 1 — spec review subagent migration

- [ ] AC-001: `run-spec.md` §Phase 0 Layer 1 invokes a sandboxed executor (subagent), passes the spec **by path** (not by interpolated content), AND contains no inline-content-capture anti-patterns. `awk '/^### Layer 1:/,/^### Layer 2:/' plugins/ai-driver/commands/run-spec.md | grep -Fq 'subagent' && awk '/^### Layer 1:/,/^### Layer 2:/' plugins/ai-driver/commands/run-spec.md | grep -Fq 'SPEC_PATH' && ! awk '/^### Layer 1:/,/^### Layer 2:/' plugins/ai-driver/commands/run-spec.md | grep -Eq '\$\(cat[[:space:]]+"?\$?SPEC_PATH|<<<[[:space:]]*"?\$\(cat|cat[[:space:]]+"?\$?SPEC_PATH"?[[:space:]]*\|'`
- [ ] AC-002: Layer 1 subagent `allowed-tools` is **exactly** `Read, Grep, Glob` (no trailing `Write` / `Bash` / `Agent`). `awk '/^### Layer 1:/,/^### Layer 2:/' plugins/ai-driver/commands/run-spec.md | grep -E '^[[:space:]]*allowed-tools:' | grep -Eq '^[[:space:]]*allowed-tools:[[:space:]]*Read,[[:space:]]*Grep,[[:space:]]*Glob[[:space:]]*$'`
- [ ] AC-003: `review-spec.md` §Layer 1 likewise spawns a subagent whose `allowed-tools` is **exactly** `Read, Grep, Glob`. `awk '/^## Layer 1:/,/^## Layer 2:/' plugins/ai-driver/commands/review-spec.md | grep -Fq 'subagent' && awk '/^## Layer 1:/,/^## Layer 2:/' plugins/ai-driver/commands/review-spec.md | grep -E '^[[:space:]]*allowed-tools:' | grep -Eq '^[[:space:]]*allowed-tools:[[:space:]]*Read,[[:space:]]*Grep,[[:space:]]*Glob[[:space:]]*$'`
- [ ] AC-004: Gate 1 Codex pass uses `codex exec` AND `-s read-only` on the same invocation. `awk '/^### Layer 2:/,/^### Write review log/' plugins/ai-driver/commands/run-spec.md | grep -Eq 'codex exec[^\n]*-s read-only|-s read-only[^\n]*codex exec' && awk '/^## Layer 2:/,/^## Consensus/' plugins/ai-driver/commands/review-spec.md | grep -Eq 'codex exec[^\n]*-s read-only|-s read-only[^\n]*codex exec'`

### Gate 2 — plan review becomes dual-LLM

- [ ] AC-005: Phase 1 plan review invokes BOTH a Claude subagent AND `codex exec` with `-s read-only`, AND the subagent has `allowed-tools: Read, Grep, Glob`, AND the Claude pass passes `plan.md` **by path** (no `$(cat plan.md)` or similar). `awk '/^### Plan Review|### Codex Plan Review/,/^## Phase 2:/' plugins/ai-driver/commands/run-spec.md | grep -Fq 'subagent' && awk '/^### Plan Review|### Codex Plan Review/,/^## Phase 2:/' plugins/ai-driver/commands/run-spec.md | grep -Eq 'codex exec[^\n]*-s read-only|-s read-only[^\n]*codex exec' && awk '/^### Plan Review|### Codex Plan Review/,/^## Phase 2:/' plugins/ai-driver/commands/run-spec.md | grep -E '^[[:space:]]*allowed-tools:' | grep -Eq '^[[:space:]]*allowed-tools:[[:space:]]*Read,[[:space:]]*Grep,[[:space:]]*Glob[[:space:]]*$' && ! awk '/^### Plan Review|### Codex Plan Review/,/^## Phase 2:/' plugins/ai-driver/commands/run-spec.md | grep -Eq '\$\(cat[[:space:]]+[^)]*plan\.md'`
- [ ] AC-006: plan review gated by `Review Level >= B` (both passes skip at Level A). `awk '/^### Plan Review|### Codex Plan Review/,/^## Phase 2:/' plugins/ai-driver/commands/run-spec.md | grep -Eq 'Review Level.*(B|>=)'`
- [ ] AC-007: Phase 1 section documents two findings tables + a consensus table with `dual-raised` semantics — same shape as Gate 1. `awk '/^### Plan Review|### Codex Plan Review/,/^## Phase 2:/' plugins/ai-driver/commands/run-spec.md | grep -Fq 'dual-raised' && awk '/^### Plan Review|### Codex Plan Review/,/^## Phase 2:/' plugins/ai-driver/commands/run-spec.md | grep -Eq 'consensus table|consensus section'`

### Gate 3 — PR review Pass 1 subagent + stage-then-read

- [ ] AC-008: `review-pr.md` Pass 1 spawns a subagent with exact minimal `allowed-tools`. `awk '/^## Step 3|^## Pass 1/,/^## Step 4|^## Pass 2/' plugins/ai-driver/commands/review-pr.md | grep -Fq 'subagent' && awk '/^## Step 3|^## Pass 1/,/^## Step 4|^## Pass 2/' plugins/ai-driver/commands/review-pr.md | grep -E '^[[:space:]]*allowed-tools:' | grep -Eq '^[[:space:]]*allowed-tools:[[:space:]]*Read,[[:space:]]*Grep,[[:space:]]*Glob[[:space:]]*$'`
- [ ] AC-009: Gate 3 uses `mktemp -d` staging + `chmod 700` + `trap`. `grep -Fq 'mktemp -d' plugins/ai-driver/commands/review-pr.md && grep -Eq "trap[[:space:]]+.rm -rf" plugins/ai-driver/commands/review-pr.md && grep -Fq 'chmod 700' plugins/ai-driver/commands/review-pr.md`
- [ ] AC-010: stderr is also redirected (not just stdout) AND fail-closed on fetch error — covers SEC-STDERR-LEAK. `grep -Eq 'gh (pr|api)[^\n]*>[[:space:]]*"?\$STAGE"?[^\n]*2>[[:space:]]*"?\$STAGE' plugins/ai-driver/commands/review-pr.md || grep -Fq 'fetch diff.txt' plugins/ai-driver/commands/review-pr.md` (either inline `2> "$STAGE/..."` pattern OR a helper function that does both) — AND an explicit `exit 1` / `|| { ... exit` after the fetch block. Check: `awk '/^## Step 3|^## Pass 1/,/^## Step 4|^## Pass 2/' plugins/ai-driver/commands/review-pr.md | grep -Eq '2>[[:space:]]*"?\$STAGE|fetch [a-z.-]+[[:space:]]+gh' && awk '/^## Step 3|^## Pass 1/,/^## Step 4|^## Pass 2/' plugins/ai-driver/commands/review-pr.md | grep -Eq 'exit 1|abort|fail closed'`
- [ ] AC-011: All four PR artifacts are staged via redirect (diff + reviews + inline-comments + issue-comments). `for art in diff reviews inline-comments issue-comments; do grep -Eq "(>[[:space:]]*\"?\\\$STAGE\"?/$art|fetch $art)" plugins/ai-driver/commands/review-pr.md || exit 1; done`
- [ ] AC-012: Gate 3 Codex pass uses `codex exec` AND `-s read-only`. `awk '/^## Step 4|^## Pass 2/,/^## Step 5|^## Step 6/' plugins/ai-driver/commands/review-pr.md | grep -Eq 'codex exec[^\n]*-s read-only|-s read-only[^\n]*codex exec'`
- [ ] AC-013: `review-pr.md` Pass 1 never interpolates raw reviewer/PR body text — enforced by a named-helper convention. The only allowed untrusted-fetch pattern is either `fetch <artifact>` (the named helper) OR `gh … > "$STAGE/<artifact>"` with explicit `2> "$STAGE/<artifact>.err"`. All four expected artifacts must use one of these two forms. `script='for art in diff.txt reviews.json inline-comments.json issue-comments.json; do awk "/^## Step 3|^## Pass 1/,/^## Step 4|^## Pass 2/" plugins/ai-driver/commands/review-pr.md | grep -Eq "(fetch "'$'"{art%.*}|> +\""'$'"STAGE/"'$'"art"'$'"?)" || exit 1; done; exit 0'; bash -c "$script"` (prose + script encoded as a single `bash -c` invocation so the AC is one executable unit)
- [ ] AC-014: no bare `$PR_BODY` / `$REVIEW_BODY` / `$COMMENT_BODY` / `$ISSUE_BODY` variable usage anywhere in Pass 1 section. `! awk '/^## Step 2|^## Step 3|^## Pass 1/,/^## Step 4|^## Pass 2/' plugins/ai-driver/commands/review-pr.md | grep -Eq '\$(PR_BODY|REVIEW_BODY|COMMENT_BODY|ISSUE_BODY)([^A-Za-z0-9_]|$)'`
- [ ] AC-015: if a spec-file path extracted from the PR body is used, it MUST pass the v0.3.7 path gate. `grep -Eq 'path gate|canonicaliz(e|ation)|reject.*\.\.|pwd -P' plugins/ai-driver/commands/review-pr.md` AND explicit mention of the spec-body-artifact path gate near the spec-body handling: `awk '/spec.?body|spec-body/,/^###|^##/' plugins/ai-driver/commands/review-pr.md | grep -Eq 'pwd -P|canonicaliz|cd specs'`
- [ ] AC-016: MUSTNOT-004 enforcement — the subagent prompt explicitly forbids nested spawning, AND the subagent's `allowed-tools` excludes `Agent` / `Task` / `Subagent`. `for f in plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-spec.md plugins/ai-driver/commands/review-pr.md; do grep -Eq 'nested spawn|MUST NOT spawn|must not spawn.*sub|no further subagent' "$f" || exit 1; awk '/^[[:space:]]*allowed-tools:[[:space:]]*/' "$f" | grep -Eq '\b(Agent|Task|Subagent)\b' && exit 1 || true; done`

### Literal prompts + degraded mode

- [ ] AC-017: all three gates store literal subagent/Codex prompt blocks in-repo (auditable). `for f in plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-spec.md plugins/ai-driver/commands/review-pr.md; do grep -Eq '(subagent prompt|Pass 1 prompt|Layer 1 prompt|Plan review prompt) \(literal\)' "$f" || exit 1; done`
- [ ] AC-018: degraded-mode contract present in each gate — the literal `CLAUDE-PASS: UNAVAILABLE` AND `CLAUDE-PASS: PARSE_ERROR` appear, paired with the correct log location. `for f in plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-spec.md plugins/ai-driver/commands/review-pr.md; do grep -Fq 'CLAUDE-PASS: UNAVAILABLE' "$f" && grep -Fq 'CLAUDE-PASS: PARSE_ERROR' "$f" || exit 1; done`
- [ ] AC-019: degraded-mode log locations exactly match MUST-005. `grep -Fq 'logs/<spec-slug>/spec-review.md' plugins/ai-driver/commands/run-spec.md && grep -Fq 'logs/<spec-slug>/plan-review.md' plugins/ai-driver/commands/run-spec.md && grep -Fq 'Degraded-mode notes' plugins/ai-driver/commands/review-pr.md`
- [ ] AC-020: malformed-output mapping is canonical — every Claude-pass gate mentions BOTH the `CLAUDE-PASS: PARSE_ERROR` status line AND the `rule_id=parse-error` finding row. `for f in plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-spec.md plugins/ai-driver/commands/review-pr.md; do grep -Fq 'PARSE_ERROR' "$f" && grep -Fq 'rule_id=parse-error' "$f" || exit 1; done`
- [ ] AC-021: `dual-raised` matching key explicitly defined as `rule_id + normalized location` in BOTH `review-spec.md` (Gate 1 authority) AND `run-spec.md` Phase 1 (Gate 2) — not just one. `grep -Fq 'rule_id + normalized location' plugins/ai-driver/commands/review-spec.md && grep -Fq 'rule_id + normalized location' plugins/ai-driver/commands/run-spec.md`

### Non-weakening / regression guards

- [ ] AC-022: Trust boundary heading intact across all untrusted-data-consuming commands. `for f in plugins/ai-driver/commands/review-pr.md plugins/ai-driver/commands/fix-issues.md plugins/ai-driver/commands/merge-pr.md plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-spec.md; do grep -Fq '## Trust boundary' "$f" || exit 1; done`
- [ ] AC-023: v0.3.7 injection-lint still passes. `bash .github/scripts/injection-lint.sh >/dev/null`
- [ ] AC-024: regression harness passes (5 L-* rules still catch their anti-patterns). `bash tests/injection-lint-cases/run.sh >/dev/null 2>&1`
- [ ] AC-025: Phase 0 Layer 0 rule set unchanged. `for rule in S-META S-GOAL S-SCENARIO S-AC-COUNT S-AC-FORMAT S-CLARIFY S-PLACEHOLDER; do awk '/^## Phase 0: Spec Review/,/^## Phase 1:/' plugins/ai-driver/commands/run-spec.md | grep -Fq "$rule" || exit 1; done`
- [ ] AC-026: path gates in run-spec.md + review-spec.md intact (v0.3.7 path-gate shape). `for f in plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-spec.md; do grep -Eq 'case[[:space:]]+"?\$(ARGUMENTS|SPEC_PATH)"?[[:space:]]+in' "$f" && grep -Fq '*..*' "$f" && grep -Fq 'pwd -P' "$f" && grep -Fq 'cd specs' "$f" || exit 1; done`
- [ ] AC-027: `review-spec.md` `allowed-tools` still excludes Write / mkdir (v0.3.6 TOOLS-001 fix stays). `grep -q '^allowed-tools:' plugins/ai-driver/commands/review-spec.md && ! awk '/^---$/{c++; next} c==1' plugins/ai-driver/commands/review-spec.md | grep -E '^allowed-tools:' | grep -iE '\b(Edit|NotebookEdit|WebFetch|WebSearch|MultiEdit|Write|Bash\(mkdir)' | grep -q .`
- [ ] AC-028: no pre-existing **semantic** guardrail was deleted. Data-fence literal tokens (`BEGIN SPEC` / `BEGIN REVIEWER`) are explicitly exempt per MUSTNOT-001 — path-based subagent handoff supersedes their role. What MUST stay: Trust boundary headings + SELF_LOGIN / user.type / -s read-only / --paginate tokens. Base ref is derived via `git merge-base` so shallow clones / forks / missing-`origin/main` don't false-fail. `BASE=$(git merge-base HEAD "$(git rev-parse --verify origin/main 2>/dev/null || git rev-parse --verify main)" 2>/dev/null); test -n "$BASE" && for tok in 'Trust boundary' 'SELF_LOGIN' 'user.type' '-s read-only' '--paginate'; do for f in plugins/ai-driver/commands/review-pr.md plugins/ai-driver/commands/fix-issues.md plugins/ai-driver/commands/merge-pr.md plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-spec.md; do if git show "$BASE:$f" 2>/dev/null | grep -Fq "$tok"; then grep -Fq "$tok" "$f" || exit 1; fi; done; done`
- [ ] AC-029: the replacement invariant — path-based ingestion — is actually in force. Every command that used to data-fence raw content now either reads from a path or uses `mktemp -d` staging. `grep -Fq 'SPEC_PATH' plugins/ai-driver/commands/review-spec.md && grep -Fq 'SPEC_PATH' plugins/ai-driver/commands/run-spec.md && grep -Fq 'mktemp -d' plugins/ai-driver/commands/review-pr.md`

### Docs sync

- [ ] AC-030: README.md + README.zh-CN.md workflow diagrams show Gate 2 as dual-LLM with **concrete wording**. `! grep -Fq 'Codex-only' README.md && ! grep -Fq 'Codex-only' README.zh-CN.md && grep -Eq 'plan.*(Claude.*Codex|subagent.*Codex)' README.md && grep -Eq 'plan.*(Claude.*Codex|subagent.*Codex)' README.zh-CN.md`
- [ ] AC-031: AGENTS.md three-gate paragraph names subagent isolation as the **enforcement mechanism**, not as a synonym for trust boundary. Check both phrases: `grep -Fq 'subagent' AGENTS.md && grep -Eq 'sandbox.*executor|path-based|stage.then.read|mktemp' AGENTS.md`
- [ ] AC-032: CHANGELOG `[Unreleased]` has ≥1 bullet mentioning subagent / sandbox / stage-then-read. `awk '/^## \[Unreleased\]/{f=1;next} /^## \[/{f=0} f' CHANGELOG.md | awk '/^### /{s=1;next} s && /^- /{print;n++} END{exit !(n>=1)}' | grep -Eiq 'subagent|sandbox|stage.then.read|R-009'`
- [ ] AC-033: `docs/security/injection-threat-model.md` has an `<a id="R-009"></a>` anchor describing the stage-then-read mitigation for the review-body-approval-hijack class. `grep -Fq '<a id="R-009"></a>' docs/security/injection-threat-model.md`

### Return-channel + filesystem-scope safety (Round 4 hardening)

- [ ] AC-034: return-channel sanitization invariant present in each Claude-pass gate. `for f in plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-spec.md plugins/ai-driver/commands/review-pr.md; do grep -Eq 'cell.*escape|length.?cap|length.?limit|≤[[:space:]]*200|truncat' "$f" || exit 1; done`
- [ ] AC-035: `parse-error` message is the fixed string (MUST-010), not a verbatim copy of subagent output. `for f in plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-spec.md plugins/ai-driver/commands/review-pr.md; do grep -Fq 'subagent returned non-table output' "$f" || exit 1; done`
- [ ] AC-036: subagent filesystem scope is bounded in the subagent prompt (MUST-009). `for f in plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-spec.md plugins/ai-driver/commands/review-pr.md; do grep -Fq 'Do NOT read any file outside this list' "$f" || exit 1; done`

### Tracked-background Codex invocation (Scenario 5)

- [ ] AC-037: all Codex invocations use `run_in_background` pattern; no `nohup codex`. `for f in plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-spec.md plugins/ai-driver/commands/review-pr.md; do ! grep -Eq 'nohup[[:space:]]+codex' "$f" && grep -Eq 'run_in_background|BashOutput|tracked background' "$f" || exit 1; done`

### `set +x` (MUST-COVER-SETX)

- [ ] AC-038: `set +x` appears in Gate 3 Pass 1 section BEFORE any `gh pr` / `gh api` invocation. `awk '/^## Step 3|^## Pass 1/,/^## Step 4|^## Pass 2/' plugins/ai-driver/commands/review-pr.md | awk 'BEGIN{seen_setx=0; seen_gh=0} /set \+x/{seen_setx=1} /gh (pr|api)/{if (!seen_setx) { print "fail: gh before set +x"; exit 1 } seen_gh=1} END{exit !(seen_setx && seen_gh)}'`

### Path-gate coverage (MUST-COVER-PATHGATE)

- [ ] AC-039: Gate 1 + Gate 2 + Gate 3 each reference the full path gate shape (reject `..` + `pwd -P` + `*.spec.md` + `cd specs`). For Gate 3 this is the spec-body path derived from the PR body. `for f in plugins/ai-driver/commands/run-spec.md plugins/ai-driver/commands/review-spec.md plugins/ai-driver/commands/review-pr.md; do grep -Fq '*..*' "$f" && grep -Fq 'pwd -P' "$f" && grep -Fq '.spec.md' "$f" && grep -Fq 'cd specs' "$f" || exit 1; done`
- [ ] AC-040: Gate 3 `spec-body` artifact is explicitly staged when (and only when) the validated spec path is derived from the PR body — covers Low finding EDGE-SPECBODY-STAGE. `awk '/spec.?body|spec-body/' plugins/ai-driver/commands/review-pr.md | grep -Eq 'fetch spec-body|> +"\$STAGE/spec-body|gh pr view.*>[[:space:]]*"\$STAGE/spec-body'`

### Base-ref stability (FEAS-BASE-REF)

- [ ] AC-041: the base-ref derivation for AC-028 ("no pre-existing guardrail deleted") uses `git merge-base`, not a literal `origin/main`, so shallow clones / forks / rebase-main setups don't false-fail. Verified by running AC-028's command and confirming it produces a non-empty BASE in a repo where `origin/main` exists: `bash -c 'BASE=$(git merge-base HEAD "$(git rev-parse --verify origin/main 2>/dev/null || git rev-parse --verify main)" 2>/dev/null); test -n "$BASE"'` — no grep on the spec file itself (avoids self-referential false-pass, per Codex Round 5 DOGFOOD-AC041).

### Governance (manual, tracked on the PR not as a mechanical AC)

- **R-009 amendment** is proposed in the PR body. The maintainer's explicit approval (as a PR comment) unlocks a follow-up commit amending `constitution.md` + the template pair. No mechanical AC — the PR description + the comment thread are the audit trail, same pattern v0.3.6 used for R-008. `constitution.md` **not** modified in the feature commit; post-approval amendment is a separate commit on this PR. Verification: after the release, `git log v<NEXT> -- constitution.md` shows exactly one new commit touching the file with a message referencing the approval.

## Constraints

### MUST

- MUST-001: Every gate's Claude pass runs inside a subagent, never inline in the main session.
- MUST-002: Every gate's Codex pass continues to use `codex exec -s read-only`. No change in kind.
- MUST-003: Subagent prompts are stored as **literal audited blocks** in the command docs, same contract as v0.3.6 MUST-005. No runtime construction.
- MUST-004: Subagent `allowed-tools` is **exactly** `Read, Grep, Glob` — no Write, no Bash, no network, no Agent (nested spawn forbidden). No exceptions.
- MUST-005: Degraded mode is identical in shape across all three gates. On Claude-pass failure the review log records the literal line `CLAUDE-PASS: UNAVAILABLE (<reason>)`; on malformed subagent output it records `CLAUDE-PASS: PARSE_ERROR` AND appends a Medium `rule_id=parse-error` finding row. A visible warning is printed to stdout with the same prefix. Log location: `logs/<spec-slug>/spec-review.md` for Gate 1, `logs/<spec-slug>/plan-review.md` for Gate 2, and as a PR-comment body section `### Degraded-mode notes` for Gate 3.
- MUST-006: Finding schema stays `severity | rule_id | location | message | fix_hint`. Subagent output is parsed into this schema. Malformed output produces BOTH the `CLAUDE-PASS: PARSE_ERROR` status line AND one Medium finding row — no other parse-failure representations are allowed.
- MUST-007: Gate 3 untrusted-artifact staging uses `mktemp -d` + `chmod 700` + `trap 'rm -rf "$STAGE"' EXIT INT TERM`. No hardcoded `/tmp/pr-*` paths. BOTH stdout AND stderr of every fetch command are redirected to staged files — `>` alone is insufficient. Tracing is disabled (`set +x`). Any non-zero exit from a fetch aborts the run before any subagent is spawned.
- MUST-008: Any spec-file path that enters Gate 1 / Gate 2 / Gate 3 is first run through the v0.3.7 path gate (reject `..`, canonicalize via `pwd -P`, confirm resolved path is under `$(cd specs && pwd -P)/` and matches `*.spec.md`). This applies to paths extracted from PR bodies too — a hostile PR naming `../../etc/passwd` as its "spec" must fail closed at the gate, not quietly get staged.
- MUST-009: **Subagent filesystem scope is bounded, not just the tool set.** A review subagent's prompt explicitly lists the only paths it may Read: for Gate 1 `$SPEC_PATH` (already validated) + language rules under `${CLAUDE_PLUGIN_ROOT}/rules/`; for Gate 2 add `logs/<spec-slug>/plan.md` + `tasks.md`; for Gate 3 only `$STAGE/*` (the mktemp dir) and nothing outside. Subagent prompt contains the literal line "Do NOT read any file outside this list." This is belt-and-suspenders over `allowed-tools` — a prompted scope limit is not a hermetic jail, but combined with tool restrictions and the `$STAGE` being outside the repo it raises the bar meaningfully.
- MUST-010: **Return-channel sanitization.** Subagent findings pass through a fixed-schema parser before entering the main session. Each finding cell is length-capped (`message` ≤ 200 chars, `fix_hint` ≤ 200 chars, others ≤ 100), pipe (`|`) and backtick (`` ` ``) characters in cells are escaped, and for the `parse-error` fallback the `message` is the fixed string `"subagent returned non-table output; see <log-location>:<line-range>"` — never a verbatim copy of attacker-controlled bytes.
- MUST-011: **Codex invocations use tracked background.** Every `codex exec` in `run-spec.md`, `review-spec.md`, and `review-pr.md` is dispatched via Claude Code's `Bash(run_in_background=true)` — the command doc names this pattern literally. `nohup codex … &` is forbidden.

### MUST NOT

- MUSTNOT-001: Do not bypass any existing v0.3.4 / v0.3.5 / v0.3.6 / v0.3.7 **semantic** guardrail — Trust boundary sections, path gates, `-s read-only` Codex calls, `--paginate` on `gh` comment endpoints, `user.type == "Bot"` detection, SELF_LOGIN self-ID, and injection-lint rules all remain in force. The literal `---BEGIN SPEC---` / `---END SPEC---` / `---BEGIN REVIEWER---` fence markers may legitimately disappear from command docs, because path-based subagent handoff supersedes main-session data-fencing for the Claude pass. Semantic guards stay; the data-fence tokens become obsolete only when their role has been taken over by a stronger mechanism.
- MUSTNOT-002: Do not weaken `review-spec.md`'s `allowed-tools` lockdown (still no Write, no mkdir).
- MUSTNOT-003: Do not amend `constitution.md` in this spec's feature commit. R-009 is proposed in the PR body; amendment requires explicit human approval, applied as a separate commit on this PR (same pattern as R-008 in v0.3.6).
- MUSTNOT-004: Do not spawn review subagents recursively — a review subagent must NOT call `Agent` / any nested-spawn tool.

### SHOULD

- SHOULD-001: Use the same subagent type across all three Claude passes where possible (e.g., `general-purpose` or a new `review-runner` definition) to keep the audited prompt structurally consistent.
- SHOULD-002: Each subagent call's output log is written to `logs/<spec-slug>/gate-<N>-claude.md` (Gate 1/2/3) so the review trail is fully reconstructable.
- SHOULD-003: Propose R-009 constitution amendment in the PR body. Approval → follow-up commit updates `constitution.md` + template pair.

## Implementation Guide

Behavioural invariants only. Exact subagent-spawn syntax lives in the command docs.

### Stage-then-read for Gate 3

Subagents have no network (MUST-004 — `Read, Grep, Glob` only, no exceptions). For Gate 3 the main session must therefore fetch PR artifacts first, but crucially **without capturing the content into its own context**. Tempfiles are created in a per-run tempdir with restrictive perms and cleaned up by a `trap`:

```bash
set +x  # disable shell trace so errored commands don't echo untrusted bytes
STAGE=$(mktemp -d -t ai-driver-review-pr.XXXXXX)
chmod 700 "$STAGE"
trap 'rm -rf "$STAGE"' EXIT INT TERM

# Main session, using Bash tool. BOTH stdout AND stderr redirect to staged
# files — otherwise `gh` error text carrying response-body fragments would
# still reach the Bash tool's captured output. Fail closed: any non-zero exit
# from a fetch aborts before we ever spawn the subagent.
fetch() {
  # $1 = output name, $2+ = command
  local out="$STAGE/$1"; shift
  "$@" > "$out" 2> "$out.err" || { echo "ERROR: fetch failed for $out ($?)" >&2; exit 1; }
}
fetch diff.txt            gh pr diff "$PR"
fetch reviews.json        gh api --paginate "/repos/$OWNER/$REPO/pulls/$PR/reviews"
fetch inline-comments.json gh api --paginate "/repos/$OWNER/$REPO/pulls/$PR/comments"
fetch issue-comments.json  gh api --paginate "/repos/$OWNER/$REPO/issues/$PR/comments"

# Then spawn the subagent, passing ONLY the paths + PR number.
# The subagent prompt names "$STAGE" so it can Read those files but
# has no network and no Write, so it cannot exfiltrate or modify.
#   Agent(
#     subagent_type: review-runner,
#     prompt: "Review PR $PR. Read $STAGE/diff.txt, $STAGE/reviews.json, $STAGE/inline-comments.json, $STAGE/issue-comments.json. <literal Pass 1 prompt>"
#   )
```

**Forbidden patterns** (caught by Gate 3 ACs in the Acceptance Criteria section — see AC-011 through AC-014 for stage-then-read + no-bare-body-vars enforcement):
- `gh pr view --json body --jq .body` followed by interpolation into a prompt string.
- Command substitution: `$(gh pr view ...)` inside any main-session prompt.
- Piping `gh` output through `jq`/`awk` to extract fields that then flow into main-session prose.
- Any form where the main session's Bash tool output captures the raw body (which happens unless stdout is redirected).

The subagent reads the files with its `Read` permission. Findings return as structured Markdown table text, which the main session parses into the standard schema. The raw bodies never enter the main session's conversation.

This is what makes the trust boundary **architectural** rather than **prose**: tooling prevents the leak, not discipline.

### Per-gate migration shape

- **Gate 1 (spec review)**: `/ai-driver:run-spec` Phase 0 §Layer 1 and `/ai-driver:review-spec` §Layer 1 both replace "main agent applies checklist" with an `Agent` spawn. The subagent's `allowed-tools` is the literal string `Read, Grep, Glob`. The main session passes the spec path (already validated by the path gate) plus the literal Layer 1 prompt; the subagent reads the spec from disk.
- **Gate 2 (plan review)**: Phase 1 section is renamed from "Codex Plan Review" to "Plan Review" and adds a subagent-Claude pass before the existing Codex pass. Review Level ≥ B gating is unchanged; both passes run together or neither runs.
- **Gate 3 (PR review)**: `/ai-driver:review-pr` Pass 1 becomes a subagent spawn, following the stage-then-read pattern above. The existing-reviewer ingestion, trust-boundary wrapping, and triple-consensus logic all remain; the change is WHERE the Claude pass runs and HOW the data is handed to it.

### Degraded mode — exact strings

On any failure path, write the literal string `CLAUDE-PASS: UNAVAILABLE (<reason>)` to the review log and emit a visible warning to stdout. Reasons: `subagent spawn failed`, `subagent returned error`, `subagent output could not be parsed as findings table`, `input too large` (for future chunking). `<reason>` is prose, not parsed — but the `CLAUDE-PASS: UNAVAILABLE` prefix is literal and checked by AC-014.

On malformed output (parseable as text but not as the expected table), the main session wraps it as a single finding with a **fixed-literal** message — **never** a copy of subagent bytes, per MUST-010. Shape: `{severity: Medium, rule_id: parse-error, location: "<gate>:<log-location>:<line-range>", message: "subagent returned non-table output; see <log-location>:<line-range>", fix_hint: "rerun with --verbose or regenerate the prompt"}`. The raw subagent output is saved to the log file at `<log-location>` for post-hoc inspection, but does not enter the main session's conversation.

### Consensus matching key

`dual-raised` requires matching on **`(rule_id, normalized_location)`**. Normalization rules: lowercase the rule_id; strip surrounding whitespace and trailing punctuation from location; if location is `file:line`, match on file-basename + line-number allowing ±3-line fuzziness for Codex line-offset drift. If Codex and subagent raise the same rule_id but on genuinely different locations, they are **separate rows**, not dual-raised.

### R-009 amendment (proposed text, not applied in feature commit)

```
### R-009: Review Runs In A Sandbox Executor (from P1, P4)
Every AI review in this framework MUST run inside a sandboxed executor — a
Claude Code subagent for the in-session Claude pass, `codex exec` for the
external pass. Main-session inline review is prohibited. When a reviewer
needs untrusted external data (PR bodies, issue threads, reviewer comments),
the main session stages it to files via shell redirects; it never
interpolates the raw content into its own prompt.

Rationale: isolates untrusted-data contamination at the tool layer
(defense-in-depth over the data-fence prose) and separates the
implementer role from the reviewer role so implementation bias does
not mask defects.
```

Governance: amendment requires explicit human approval per `constitution.md` §Governance. Proposed in the PR body; user replies `approve as-is` / `approve with edits: …` / `reject: …`. Approval triggers a follow-up commit on the same PR that amends `constitution.md` + `plugins/ai-driver/templates/constitution.md`. Feature commit does NOT touch `constitution.md`.

### Docs sync

- `README.md` + `README.zh-CN.md` workflow diagram: Gate 2 updated to "subagent (Claude) + Codex" on both sides of the arrow. Remove any "Codex-only" wording. Drop the "optional / Review Level ≥ B" parenthetical from the line — gating stays but the asymmetry story it justified is now symmetric.
- `AGENTS.md`: three-gate paragraph names "subagent isolation" as the enforcement mechanism, not "data fences alone".
- `docs/security/injection-threat-model.md`: add `<a id="R-009"></a>` anchor with a reference to the stage-then-read pattern as the mitigation for Gate 3's review-body-approval-hijack class.

## References

- v0.3.4 comment-aware review: `specs/comment-aware-review.spec.md`
- v0.3.6 spec review: `specs/v036-spec-review.spec.md`
- v0.3.7 injection hardening: `specs/v037-injection-tests.spec.md`
- `tests/injection-fixtures/review-body-approval-hijack.md` — the attack class subagent isolation directly mitigates.
- `docs/security/injection-threat-model.md` — will get an `<a id="R-009"></a>` anchor on merge.

## Needs Clarification

None.
