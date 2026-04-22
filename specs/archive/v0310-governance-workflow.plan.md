# v0.3.10 Governance Workflow — Implementation Plan

Maps each AC to files + atomic tasks. Linear order; each task has a verification command.

## Change surface (4 files)

| File | Why | Scope |
|---|---|---|
| `plugins/ai-driver/commands/merge-pr.md` | Add Step 0.10 governance preflight + `--defer` flag doc + Step 2.5 (PR-comment audit sink, only for defer path) | ~100 lines added |
| `tests/governance-snapshots/check.sh` + `tests/governance-snapshots/pr-{8,11}/*.json` | Standalone regression classifier + two curated snapshots replaying the v0.3.9 incident contrast | New dir; ~80-line script + 6 JSON fixtures |
| `AGENTS.md` | Add **Governance** subsection under "Key workflows" with the canonical `docs(constitution): add R-NNN` template | ~15 lines |
| `CHANGELOG.md` | `## [Unreleased] ### Fixed` bullet | ~2 lines |

No changes to: `review-pr.md`, `run-spec.md`, `review-spec.md`, `constitution.md`, rules/, templates/ (MUSTNOT-002: don't weaken v0.3.4–v0.3.9 guardrails).

## Task list (atomic, one commit each per R-005)

### T1: Create `tests/governance-snapshots/` scaffolding + pr-8 snapshot (positive case)

**Rationale first (TDD RED):** build the snapshot harness before touching merge-pr.md. AC-011 demands it. Having the checker green on PR #8 and red on PR #11 gives us behavioral regression even before the command doc is wired.

- Create `tests/governance-snapshots/pr-8/meta.json` — minimal GitHub-style JSON with PR #8's body (R-008 proposal block), baseRefName `main`, changed files `[constitution.md]`.
- Create `tests/governance-snapshots/pr-8/comments.json` — a single comment from `@HuMoran` (or whoever, admin role) with body `approve R-008 as-is`.
- Create `tests/governance-snapshots/pr-8/branch-commits.json` — one commit whose subject is `docs(constitution): add R-008 — approved by @HuMoran in PR #8`.
- Create `tests/governance-snapshots/pr-8/expected.txt` containing single line `proceed`.

**Verify:**
```bash
test -f tests/governance-snapshots/pr-8/meta.json
test -f tests/governance-snapshots/pr-8/comments.json
test -f tests/governance-snapshots/pr-8/branch-commits.json
jq -e 'has("body") and has("baseRefName") and has("files")' tests/governance-snapshots/pr-8/meta.json
```

Commit: `test(governance): seed PR #8 positive snapshot (R-008 approved and landed)`

### T2: Add pr-11 snapshot (negative case — the real v0.3.9 incident)

- Create `tests/governance-snapshots/pr-11/meta.json` with PR #11's body (R-009 proposal block), `baseRefName: main`, `files: []` (no constitution changes — v0.3.9's bug shape).
- `comments.json`: one admin comment `approve R-009 as-is` at 11:12, another at 11:28 (the two approvals I missed on the live PR).
- `branch-commits.json`: commits from PR #11 (feat changes, no `docs(constitution):` commit — that's what merge-pr failed to catch).
- `expected.txt` contains: `abort: R-009 approved by @HuMoran but no "docs(constitution): add R-009" commit on this branch`

**Verify:**
```bash
test -f tests/governance-snapshots/pr-11/expected.txt
grep -Fq 'abort:' tests/governance-snapshots/pr-11/expected.txt
```

Commit: `test(governance): seed PR #11 negative snapshot (v0.3.9 incident)`

### T3: Write `tests/governance-snapshots/check.sh`

Standalone bash/jq classifier replicating the preflight logic:

1. Read `meta.json`, `comments.json`, `branch-commits.json` from the passed directory.
2. Detect body proposals via regex `^####?\s+R-[0-9]+:|^\*\*R-[0-9]+:`.
3. Detect file trigger: `.files[]` contains `constitution.md` or `plugins/ai-driver/templates/constitution.md`.
4. For each proposed R-NNN: scan comments — first non-blank line after deleting `^\s*>` lines and fenced-block content must match `^\s*(approve|同意)\s*R-NNN\b`. Author must be in the `admin_allowlist` fixture field.
5. Amendment commit: search `branch-commits.json[].subject` for `^docs\(constitution\): add R-NNN `.
6. Decision tree → print `proceed` OR `abort: <message>`.
7. Compare stdout against `expected.txt`; exit 1 on mismatch.

**Verify:**
```bash
bash tests/governance-snapshots/check.sh tests/governance-snapshots/pr-8  # prints proceed, exit 0
bash tests/governance-snapshots/check.sh tests/governance-snapshots/pr-11 # prints abort:..., exit 0
```

RED → GREEN: script exists and both snapshots match expected.

Commit: `test(governance): add snapshot classifier tests/governance-snapshots/check.sh`

### T4: Draft Step 0.10 governance preflight in `merge-pr.md`

Insert new subsection in Step 0 (after existing 0.9, before dry-run guard). Content mirrors the Implementation Guide pseudocode:

- Fetch PR metadata via single `gh pr view <N> --json baseRefName,body,files,comments` call.
- Body trigger regex + file trigger list documented.
- Allowlist command: `gh api --paginate '/repos/{owner}/{repo}/collaborators' --jq '.[] | select(.role_name == "admin" or .role_name == "maintain") | .login'`.
- Per-R-NNN decision tree with exact abort messages from Scenario 1 AC-2/AC-3/AC-5.
- Explicit note: "this step is validation-only; no writes until Step 2.5".

Also document `--defer "<rationale>"` flag in the Flags section, with length (≤200), single-line, and escape rules.

Also document `--merge`-only prerequisite is **implicit** (default `gh pr merge --merge` in Step 4 stays unchanged); squash/rebase would bypass merge-commit trailers, but since single-sink (PR comment) replaces the trailer, no hard precondition is needed.

**Verify (9 AC greps must all pass):**
```bash
for cmd in \
  "grep -Eq 'R-\[0-9\]\+|governance.*check|constitution.*amendment' plugins/ai-driver/commands/merge-pr.md" \
  "grep -Fq 'constitution.md' plugins/ai-driver/commands/merge-pr.md" \
  "grep -Fq 'files' plugins/ai-driver/commands/merge-pr.md" \
  "grep -Eq 'approve.*同意|同意.*approve' plugins/ai-driver/commands/merge-pr.md" \
  "grep -Fq '/repos/{owner}/{repo}/collaborators' plugins/ai-driver/commands/merge-pr.md" \
  "grep -Fq 'role_name' plugins/ai-driver/commands/merge-pr.md" \
  "grep -Fq 'docs(constitution): add R-' plugins/ai-driver/commands/merge-pr.md" \
  "grep -Fq -- '--defer' plugins/ai-driver/commands/merge-pr.md" \
  "grep -Eq '200 char|single.line|escape' plugins/ai-driver/commands/merge-pr.md"; do
  bash -c "$cmd" || { echo FAIL: "$cmd"; exit 1; }
done
```

Commit: `feat(merge-pr): add governance preflight (Step 0.10) detecting R-NNN proposals + amendment commits`

### T5: Add Step 2.5 `--defer` audit comment writer in `merge-pr.md`

Single new subsection describing the PR-comment audit sink:

- Runs only when `--defer` was passed AND preflight's approved-no-commit branch fires.
- Comment body format:
  ```
  <!-- ai-driver-defer:R-NNN -->
  Governance deferral (R-NNN): <escaped rationale>
  Follow-up: a constitution-only PR will land `docs(constitution): add R-NNN — approved by @<login> in PR #<N>`.
  ```
- Idempotent retry: `gh pr view <N> --json comments --jq '.comments[].body'` grepped for the marker before posting; skip if already present.

**Verify:**
```bash
grep -Fq '<!-- ai-driver-defer:' plugins/ai-driver/commands/merge-pr.md
grep -Fq 'Governance deferral' plugins/ai-driver/commands/merge-pr.md
```

Commit: `feat(merge-pr): add Step 2.5 deferral audit comment writer (idempotent via marker)`

### T6: Update `AGENTS.md` Governance subsection

Add a "Governance (constitution amendments)" subsection under **Key workflows**:

- Three preflight conditions listed.
- Canonical commit message template.
- `--defer` usage summary.
- Admin/maintain allowlist note.

**Verify:**
```bash
grep -Fq 'docs(constitution): add R-' AGENTS.md
grep -Fq 'approved by @' AGENTS.md
grep -Fiq 'governance' AGENTS.md
```

Commit: `docs(agents): document governance preflight contract in AGENTS.md`

### T7: Update `CHANGELOG.md [Unreleased]`

```markdown
### Fixed
- **Governance preflight in `/ai-driver:merge-pr`** (v0.3.9 follow-up). merge-pr now detects R-NNN constitution-amendment proposals in PR body AND changes to `constitution.md` / its template mirror, then verifies: (a) admin/maintainer posted `approve R-NNN` or `同意R-NNN` in a comment, (b) branch carries `docs(constitution): add R-NNN …` commit. Missing-approval or missing-commit → fail-closed with recovery hint. `--defer "<rationale>"` allows deliberately deferring an approved amendment to a follow-up constitution-only PR (the v0.3.9 shape), leaving a single idempotent PR comment as audit trail. Closes the workflow gap that caused v0.3.8→v0.3.9.
```

**Verify:**
```bash
awk '/^## \[Unreleased\]/{f=1;next} /^## \[/{f=0} f' CHANGELOG.md | grep -Eiq 'governance|amendment|merge-pr'
```

Commit: `docs(changelog): add unreleased entry for v0.3.10 governance preflight`

### T8: Run full AC suite + guardrails

Run every AC from the spec:

```bash
bash -n plugins/ai-driver/commands/merge-pr.md 2>/dev/null  # sanity: no syntax-adjacent issues
# AC-001 .. AC-011 one by one (copy from spec)
# AC-009: review-pr.md guards preserved
# AC-010: existing injection-lint + harness still pass
```

If any AC fails → fix the relevant file, append commit.

### T9: Final commit: Push branch + open PR

(Once all 11 ACs pass locally.) PR body includes:

- Spec link
- Plan link (this file)
- AC checklist (copy-pastable)
- Governance proposal block **not needed** (this spec is enforcement of R-008/R-009, not a new rule — MUSTNOT-003)

## Not in plan (deferred by design, per Accepted residue)

- No stage-then-read for merge-pr (SEC-TRUST rejected)
- No body-quote stripping (BODY-FP rejected)
- No multi-proposal deferral machinery
- No digest / canonical form
- No triple audit sink

## Risk log

| Risk | Mitigation |
|---|---|
| Dogfood trap: merge-pr change could self-gate its own merge | This spec has no R-NNN in body; no file trigger (no constitution.md edit). Preflight short-circuits on both. Confirmed by snapshot tests. |
| Snapshot drift (if PR #8/#11 are rebased) | Snapshots are static JSON fixtures, not live `gh` calls. Once committed, content is immutable. |
| AGENTS.md edit triggers template-sync CI? | AGENTS.md is not in template-sync PAIRS (only root-level workflows / .codex / specs / deploy). No template changes needed. |

## Completion criteria

- All 11 ACs pass
- `tests/governance-snapshots/check.sh pr-8` prints `proceed`
- `tests/governance-snapshots/check.sh pr-11` prints an `abort:` line matching `expected.txt`
- `.github/scripts/injection-lint.sh` passes (AC-010)
- `tests/injection-lint-cases/run.sh` passes (AC-010)
- PR opened against `main` with spec + plan + AC checklist
