# /ai-driver:run-spec: Execute a spec from plan to PR

Usage: `/ai-driver:run-spec <path-to-spec-file>`

You are an AI engineer executing a spec-driven development workflow. Read the spec file provided as `$ARGUMENTS` and execute it end-to-end.

## Spec slug convention

Throughout this command `<spec-slug>` is the filename basename of the spec with `.spec.md` stripped. Examples:

| Spec path | `<spec-slug>` |
|---|---|
| `specs/user-auth.spec.md` | `user-auth` |
| `specs/fix-issue-42.spec.md` | `fix-issue-42` |
| `specs/v035-copilot-backlog.spec.md` | `v035-copilot-backlog` |

Use `<spec-slug>` as the stable identifier for: log directory paths, default branch names, and PR-body spec-path links. The `Meta` section only contains `Date` and `Review Level` — no identity fields. Everything identity-related flows from the filename.

## Pre-flight

1. Read the spec file at `$ARGUMENTS`.
2. Read `${CLAUDE_PLUGIN_ROOT}/rules/*.md` files relevant to this project's language.
3. Validate the spec has required fields: `Goal`, `Acceptance Criteria` (at least one AC-xxx bullet), `Meta` section (with `Date` and `Review Level`). If any are missing or still contain template placeholders, STOP and report to the user.
4. Check for `[NEEDS CLARIFICATION]` markers in the spec — if any exist, STOP and report them. Do not proceed until they are resolved.
5. Compute `SPEC_SLUG` from `$ARGUMENTS` (see convention above).

## Phase 0: Prepare

- Check `git status` — if there are uncommitted changes, STOP and ask user to commit or stash first.
- Check if `gh auth status` succeeds — if not, warn user but continue (PR creation will fail later).
- **Default branch name**: `feat/<spec-slug>` if the primary intended commit type is `feat`, else `fix/<spec-slug>`. Pick by reading the spec's Goal and User Scenarios — if they describe a new capability, use `feat`; if they describe a bug fix / regression, use `fix`. If ambiguous, default to `feat`.
- Check if the branch already exists:
  - If it does AND has commits beyond `main`: ask user whether to resume from existing branch or start fresh.
  - If it does with no extra commits: switch to it.
  - If it doesn't exist: `git checkout -b <branch-name>` from main.
- Run: `mkdir -p logs/<spec-slug>/`.
- If `logs/<spec-slug>/tasks.md` exists with checked items: this is a resume. Show progress and ask user whether to continue from where it left off.

## Phase 1: Design Action Plan

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

### Codex Plan Review (if review level >= B)

If the spec's `Review Level` (from Meta) is `B` or `C`, request a Codex adversarial review:

- Run: `codex exec "Review this implementation plan for gaps, risks, and feasibility issues. Be terse. Output findings with severity." -s read-only`.
- Fix any critical/high severity findings.
- Medium findings: fix if effort is low, otherwise note in `plan.md`.

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
  - **Spec**: relative link to the spec file (e.g., `[specs/<spec-slug>.spec.md](specs/<spec-slug>.spec.md)`).
  - The acceptance report from Phase 3.
  - Summary of changes.

Write `logs/<spec-slug>/implementation.log`:

- What was implemented.
- What existing code was leveraged.
- Issues encountered.
- Final status: DONE / DONE_WITH_CONCERNS / BLOCKED.

Commit the logs directory: `git add logs/ && git commit -m "docs: add implementation logs for <spec-slug>" && git push`.

Report completion status per R-007.
