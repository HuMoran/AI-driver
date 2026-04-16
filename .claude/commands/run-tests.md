# /run-tests: Run project test suite

Usage: /run-tests [--type unit|integration|e2e|all]

Default: --type all

## Pre-flight

Read `.claude/rules/*.md` to find test commands for this project's language.

## Step 1: Detect Test Commands

From `.claude/rules/<language>.md`, extract:
- Unit test command (e.g., `cargo test`, `pytest`, `npm test`)
- Integration test command (if defined)
- E2E test command (if defined)
- Coverage command (if defined)

If no language rule file matches the project, attempt auto-detection:
- `Cargo.toml` → Rust → `cargo test`
- `pyproject.toml` or `requirements.txt` → Python → `pytest`
- `package.json` → Node.js → `npm test`
- `go.mod` → Go → `go test ./...`
- `pubspec.yaml` → Flutter → `flutter test`

## Step 2: Run Tests

Based on `--type`:
- `unit`: run unit test command
- `integration`: run integration test command
- `e2e`: run e2e test command
- `all`: run all available test types in sequence

For each test type, capture:
- Exit code
- Stdout/stderr output
- Pass/fail count (parse from output)
- Coverage percentage (if available)

## Step 3: Report

Output a structured test report:
```markdown
## Test Report

| Type | Passed | Failed | Coverage | Status |
|------|--------|--------|----------|--------|
| Unit | X | Y | Z% | PASS/FAIL |
| Integration | X | Y | - | PASS/FAIL |
| E2E | X | Y | - | PASS/FAIL |

### Failed Tests
[For each failure: test name, error message, file:line]

### Recommendations
[If failures exist: analysis of likely cause and suggested fix]
```
