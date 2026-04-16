# /run-spec: Execute a spec from plan to PR

Usage: /run-spec <path-to-spec-file>

You are an AI engineer executing a spec-driven development workflow.
Read the spec file provided as $ARGUMENTS and execute it end-to-end.

## BEFORE ANYTHING ELSE

1. Read `constitution.md` — obey every principle and operational rule
2. Read the spec file at `$ARGUMENTS`
3. Read `CLAUDE.md` for project context
4. Read any `.claude/rules/*.md` files relevant to this project's language
5. Check for `[NEEDS CLARIFICATION]` markers in the spec — if any exist, STOP and report them to the user. Do not proceed until they are resolved.

## Phase 0: Prepare

- Extract the branch name from the spec's Meta section
- Run: `git checkout -b <branch-name>` (from main)
- Run: `mkdir -p logs/<spec-id>/`

## Phase 1: Design Action Plan

Generate `logs/<spec-id>/plan.md`:
- Architecture overview (use ASCII diagrams)
- Reuse analysis: what existing code can be leveraged
- Risks and dependencies
- Data flow

Generate `logs/<spec-id>/tasks.md`:
- Atomic tasks, each 2-5 minutes
- Format: `- [ ] T001 [AC-xxx] description | Files: path/to/file`
- `[P]` marks parallelizable tasks
- `[AC-xxx]` traces back to acceptance criteria
- Every AC-xxx in the spec must have at least one task covering it

### Codex Plan Review (if review level >= B)

If the spec's review level is B or C, request a Codex review of the plan:
- Commit plan.md and tasks.md
- Use `/codex:review` to get structured feedback
- Fix any critical/high severity findings
- Medium findings: fix if effort is low, otherwise note in plan.md

## Phase 2: Implement

Execute each task in tasks.md sequentially. For EVERY task, follow R-002 (TDD):

1. Write a failing test for the task's expected behavior
2. Run the test — confirm it FAILS (RED)
3. Write the minimal implementation to make the test pass
4. Run the test — confirm it PASSES (GREEN)
5. Refactor if needed
6. Run the language's format tool (per .claude/rules/<lang>.md, R-006)
7. `git add` changed files + `git commit` with Conventional Commits message (R-005)
8. Mark the task `[x]` in tasks.md

If review level = C: after each task, use `/codex:review` and fix findings before continuing.

### Self-Review After All Tasks
- Check: does every AC-xxx in the spec have a passing test?
- Check: did any task go beyond the spec? (R-003 violation)

## Phase 3: Acceptance

For each Acceptance Criteria in the spec:
- Run the exact command specified in the AC
- Read the actual output
- Confirm pass/fail (R-001: no guessing, no "should pass")

Generate an acceptance report:
```
## Acceptance Report
- AC-001: [command] → [actual output] → PASS/FAIL
- AC-002: [command] → [actual output] → PASS/FAIL
...
```

- ALL PASS → proceed to Phase 4
- ANY FAIL → apply R-004 (root cause analysis), fix, re-run. Max 3 retries. If still failing after 3 attempts, report BLOCKED.

## Phase 4: Submit PR

```bash
git push -u origin <branch-name>
```

Create PR with `gh pr create`:
- Title: Conventional Commits format matching the primary change type
- Body must include:
  - Link to the spec file (relative path)
  - The acceptance report from Phase 3
  - Summary of changes
  - Spec ID

Write `logs/<spec-id>/implementation.log`:
- What was implemented
- What existing code was leveraged
- Issues encountered
- Final status: DONE / DONE_WITH_CONCERNS / BLOCKED

Report completion status per R-007.
