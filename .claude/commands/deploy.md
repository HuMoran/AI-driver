# /deploy: Deploy to staging or production

Usage: /deploy <staging|production>

## BEFORE ANYTHING ELSE

1. Read `constitution.md`
2. Read `CLAUDE.md` for deploy configuration
3. Check if the current spec has a "Deploy & Test" section

## Deploy Configuration

The deploy commands are project-specific. They must be defined in CLAUDE.md under a `## Deploy` section:

```markdown
## Deploy
- staging command: <command to deploy to staging>
- staging url: <staging URL for health check>
- production command: <command to deploy to production>
- production url: <production URL for health check>
- smoke test command: <command to run smoke tests>
- rollback command: <command to rollback>
```

If no deploy section exists in CLAUDE.md, report NEEDS_CONTEXT and ask the user to configure it.

## Staging Deploy

1. **Gate**: Run `/run-tests --type all` — if any test fails, STOP
2. **Deploy**: Execute the staging deploy command
3. **Smoke Test**: Run the smoke test command against the staging URL
4. **Health Check**: `curl -sf <staging-url>/health` (or configured endpoint)
5. **Report**:
```markdown
## Deploy Report: Staging
- Tests: PASS (X passed, 0 failed)
- Deploy: SUCCESS/FAILED
- Smoke Test: PASS/FAIL
- Health Check: PASS/FAIL (HTTP status, response time)
- URL: <staging-url>
```

## Production Deploy

1. **Gate**: Confirm staging passed (check recent deploy report)
2. **Gate**: Run `/run-tests --type all`
3. **Confirm**: Show change summary to user, wait for explicit confirmation
4. **Deploy**: Execute the production deploy command
5. **Health Check**: `curl -sf <production-url>/health`
6. **Report**:
```markdown
## Deploy Report: Production
- Tests: PASS
- Deploy: SUCCESS/FAILED
- Health Check: PASS/FAIL
- URL: <production-url>
```
7. **If health check fails**: Print the rollback command and ask user whether to execute it
