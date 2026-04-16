# Project Constitution

Load and obey before every operation. Halt and report immediately on any violation.

## Principles

### P1: Spec Is Source of Truth
Code is an implementation of the spec. When code conflicts with the spec, the spec wins.
If the spec is wrong, fix the spec first, then fix the code.

### P2: Humans Define What, AI Delivers How
Humans write specs (what to build and why). AI does plan + implement (how to build it).
AI must not expand or shrink the spec scope on its own.

### P3: Language Agnostic
The framework assumes no programming language, framework, or runtime.
All tools and workflows apply to any tech stack.

### P4: Verifiable First
Acceptance criteria must be machine-executable.
"Good code quality" is not an acceptance criterion. "Zero lint warnings" is.

### P5: Minimal Change
Each implementation does only what the spec requires. No unrequested optimization or refactoring.

### P6: Local Execution
All AI operations run locally in Claude Code.
GitHub Actions are only for post-merge automation.

## Operational Rules

### R-001: Verify Before Claiming Done (from P4)
Do not claim a task is complete without running the verification command and reading its actual output.
Prohibited phrases: "should pass", "looks fine", "probably works".
Required sequence: run command → read output → confirm pass → then mark complete.

### R-002: Test Before Implement (from P4)
Follow RED-GREEN-REFACTOR:
1. Write a failing test (RED)
2. Write minimal implementation to make the test pass (GREEN)
3. Refactor (REFACTOR)
No production code without a failing test first.

### R-003: No Scope Creep (from P2, P5)
If the spec doesn't mention it, don't do it. If you spot something that "should also be done",
log it in implementation.log but do not execute.

### R-004: Root Cause Analysis on Failure (from P4)
When a test fails or acceptance check doesn't pass:
1. Read the error message
2. Locate the root cause
3. Form a hypothesis
4. Verify the hypothesis
Prohibited: blind retry, random code changes.
After 3 failed fix attempts → report BLOCKED status, escalate to human.

### R-005: Atomic Commits (from P5)
One commit per task. Commit messages follow Conventional Commits:
`<type>(<scope>): <description>`
type: feat|fix|docs|style|refactor|perf|test|chore|ci

### R-006: Format Before Commit
Run the language's formatting tool before every git commit.
Specific tools are defined in .claude/rules/<language>.md.

### R-007: Four Completion States
Every task must report one of:
- DONE: fully complete with verification evidence
- DONE_WITH_CONCERNS: complete but with issues worth noting
- NEEDS_CONTEXT: missing information, need human input
- BLOCKED: stuck, need human intervention

## Standards

- Changelog: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
- Versioning: [Semantic Versioning](https://semver.org/)
- Commits: [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
- API design: [OpenAPI 3.0](https://swagger.io/specification/) (when applicable)

## Governance

- Amending this constitution requires explicit human approval
- AI must not modify constitution.md on its own
