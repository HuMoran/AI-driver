# <feature-name>.spec.md

## Meta
- Date: YYYY-MM-DD
- Review Level: B
  A = PR review only
  B = Plan + PR review (default)
  C = Review every step

## Goal
One or two sentences. What changes when this is done.
Write WHAT and WHY only. Do not write HOW.

## Context
Why is this needed? Motivation, related issues, user feedback, etc.

## User Scenarios

### Scenario 1: <title> (Priority: P1)
**As a** [role], **I want** [feature], **so that** [benefit]

**Acceptance Scenarios:**
1. **Given** [initial state], **When** [action], **Then** [expected result]
2. **Given** [initial state], **When** [action], **Then** [expected result]

**Independent Test Method:** [how to verify this scenario alone]

### Scenario 2: <title> (Priority: P2)
(same structure)

### Edge Cases
- What happens when [condition]?
- How to handle [error scenario]?

## Acceptance Criteria
Machine-executable checklist, each item is a boolean check:
- [ ] AC-001: `<command>` succeeds with exit code 0
- [ ] AC-002: Test coverage >= X%
- [ ] AC-003: Zero new lint warnings
- [ ] AC-004: [specific measurable metric]

## Constraints

### MUST
- MUST-001: [non-negotiable constraint]
- MUST-002: [non-negotiable constraint]

### MUST NOT
- MUSTNOT-001: Do not modify <file/directory>
- MUSTNOT-002: Do not introduce new runtime dependencies

### SHOULD
- SHOULD-001: Prefer reusing existing code
- SHOULD-002: Keep single files under 300 lines

## Deploy & Test [optional]

### Dev
- Start command:
- Debug config:
- Hot reload:

### Staging
- Deploy target:
- Test data:
- Smoke test command:

### Production
- Deploy method:
- Health check:
- Rollback plan:

## Implementation Guide [optional]
Your thoughts on implementation. AI will reference but not necessarily follow.

## References
- Related files: path/to/file
- Related issues: #123
- External docs: URL

## Needs Clarification [max 3]
- [NEEDS CLARIFICATION] <question affecting scope/security/UX>
