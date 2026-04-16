# /deploy: Deploy to staging or production

Usage: /deploy <staging|production>

## BEFORE ANYTHING ELSE

1. Read `constitution.md`
2. Read the project's deploy document at `deploy/*.deploy.md`
   - If no deploy document exists, report NEEDS_CONTEXT:
     "No deploy document found. Copy `deploy/_template.deploy.md` to `deploy/<project>.deploy.md` and fill in your build/deploy commands."
3. Read `CLAUDE.md` for additional context

## Locate Deploy Document

Search for `deploy/*.deploy.md` (excluding `_template.deploy.md`).
If multiple deploy docs exist, use the one matching `$ARGUMENTS` or ask the user which to use.

## Build (if needed)

From the deploy doc's "编译构建 (Build)" section:
1. Check dependency environment requirements
2. Execute build steps in order
3. Verify build artifacts exist at the specified path

## Staging Deploy

1. **Gate**: Run `/run-tests --type all` — if any test fails, STOP
2. **Build**: Execute the build steps from the deploy doc (if not already built)
3. **Deploy**: Execute the staging deploy command from the deploy doc
4. **Smoke Test**: Run the smoke test commands from the deploy doc
5. **Health Check**: Run the health check command from the deploy doc
6. **Report**:
```markdown
## Deploy Report: Staging
- Build: SUCCESS/FAILED
- Tests: PASS (X passed, 0 failed)
- Deploy: SUCCESS/FAILED
- Smoke Test: PASS/FAIL
- Health Check: PASS/FAIL
```

## Production Deploy

1. **Gate**: Confirm staging passed (check recent deploy report)
2. **Gate**: Run `/run-tests --type all`
3. **Confirm**: Show change summary to user, wait for explicit confirmation
4. **Build**: Execute the build steps from the deploy doc (if not already built)
5. **Deploy**: Execute the production deploy command from the deploy doc
6. **Health Check**: Run the health check command from the deploy doc
7. **Report**:
```markdown
## Deploy Report: Production
- Build: SUCCESS/FAILED
- Tests: PASS
- Deploy: SUCCESS/FAILED
- Health Check: PASS/FAIL
```
8. **If health check fails**: Print the rollback command from the deploy doc and ask user whether to execute it

## Special Platforms

If the deploy doc has a "特殊平台" section (cross-compilation, firmware flashing, mobile packaging, containerization), follow those steps as part of the build process. Execute them in the order specified.
