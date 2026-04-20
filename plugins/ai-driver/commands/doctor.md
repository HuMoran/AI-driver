---
description: Read-only health check for an AI-driver project — detects drift, misconfiguration, and version skew
allowed-tools: Read, Glob, Grep, Bash(git status:*), Bash(git log:*), Bash(jq:*), Bash(diff:*), Bash(cmp:*), Bash(find:*), Bash(ls:*), Bash(cat:*), Bash(basename:*), Bash(test:*)
---

# /ai-driver:doctor: Project health check (read-only)

Usage: `/ai-driver:doctor`

Prints a report of every check with `[✓]` / `[⚠]` / `[✗]` and a suggested fix command for anything that's not green. **Never modifies a file. Never calls the network.** If you want auto-fix, run the printed commands yourself.

## Preflight

1. If `$ARGUMENTS` contains `--fix`, print: `"--fix is not supported. Doctor is read-only; run the suggested commands yourself."` and exit 0 WITHOUT running any check.
2. If neither `./constitution.md` nor `./AGENTS.md` exists, print: `"Not an AI-driver project — run /ai-driver:init first"` and exit 0 WITHOUT running any check.

## Checks

Run every check below. Accumulate `ERROR_COUNT`, `WARN_COUNT`, `PASS_COUNT`. Print each check's result immediately; don't batch.

### Check 1 — `constitution.md` present

- PASS if `./constitution.md` exists.
- ERROR otherwise: `"[✗] constitution.md missing. Fix: run /ai-driver:init"`.

### Check 2 — `AGENTS.md` present

- PASS if `./AGENTS.md` exists.
- ERROR otherwise: `"[✗] AGENTS.md missing. Fix: run /ai-driver:init"`.

### Check 3 — `CLAUDE.md` imports `AGENTS.md`

- Read `./CLAUDE.md` (if missing → WARN: `"[⚠] CLAUDE.md missing. Claude Code reads CLAUDE.md, not AGENTS.md — create it with a '@AGENTS.md' line."`).
- If CLAUDE.md has NO line matching `^@(\./)?AGENTS\.md$` → ERROR: `"[✗] CLAUDE.md does not import AGENTS.md. Fix: prepend '@AGENTS.md' at the top of CLAUDE.md."`.
- If CLAUDE.md has the import but NOT on the first non-blank line → WARN: `"[⚠] CLAUDE.md imports AGENTS.md but not at the top. For correct precedence, the import should come first. See CLAUDE.md line <N>."`.
- Otherwise PASS.

### Check 4 — `specs/` directory present

- PASS if `./specs/` exists.
- WARN otherwise: `"[⚠] specs/ directory missing. Create one: mkdir specs && cp \${CLAUDE_PLUGIN_ROOT}/templates/specs/_template.spec.md specs/"`.

### Check 5 — No legacy v0.1 spec filenames

- Find any `./specs/p[0-9][0-9]_*.spec.md` pattern (also `p[0-9]_*.spec.md` for single-digit).
- PASS if none.
- WARN per file: `"[⚠] Legacy v0.1 filename: specs/p01_foo.spec.md. Fix: git mv specs/p01_foo.spec.md specs/foo.spec.md && remove the Meta.ID line from the file."`.

### Check 6 — `constitution.md` drift from plugin template

- If `${CLAUDE_PLUGIN_ROOT}/templates/constitution.md` is readable AND `cmp -s ./constitution.md ${CLAUDE_PLUGIN_ROOT}/templates/constitution.md` fails:
  WARN: `"[⚠] constitution.md drifted from plugin template v<version>. Diff preview:"` + first 10 lines of `diff -u`.
  Suggest: `"Run: diff constitution.md \${CLAUDE_PLUGIN_ROOT}/templates/constitution.md"`.
- If the template is unreadable (plugin cache missing): WARN: `"[⚠] Plugin template cache not accessible — skipping drift checks. Run: claude plugin update ai-driver@ai-driver"`.
- PASS otherwise.

### Check 7 — `.claude/settings.json` enables ai-driver

- If `./.claude/settings.json` missing → WARN: `"[⚠] .claude/settings.json missing. Fix: run /ai-driver:init."`.
- If present but `jq -r '.enabledPlugins["ai-driver@ai-driver"] // empty' ./.claude/settings.json` returns empty or `false` → WARN: `"[⚠] .claude/settings.json does not enable ai-driver@ai-driver. Fix: jq '.enabledPlugins[\"ai-driver@ai-driver\"]=true' .claude/settings.json > tmp && mv tmp .claude/settings.json"`.
- Otherwise PASS.

### Check 8 — Plugin version skew (best-effort)

- Determine installed version from `${CLAUDE_PLUGIN_ROOT}` path — it's the `<version>` component in `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`.
- Extract `version` from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` if present (will usually be empty for relative-path plugins by our convention), otherwise from the installed marketplace.json nearby.
- If installed version < max known version → WARN: `"[⚠] Plugin v<installed> installed, v<latest> available. Run: claude plugin update ai-driver@ai-driver"`.
- If check is not possible (unreadable cache) → skip silently.
- Otherwise PASS.

### Check 9 — Plugin-publishing project manifests valid (if `.claude-plugin/` present)

- If `./.claude-plugin/marketplace.json` exists: `jq -e . ./.claude-plugin/marketplace.json >/dev/null` — fail ERROR on parse failure.
- Same for `./.claude-plugin/plugin.json` if present.
- If neither exists (non-plugin project): mark `[—]` (N/A) and continue.

### Check 10 — `CHANGELOG.md` format sanity (best-effort)

- If `CHANGELOG.md` exists:
  - PASS if at least one `## [X.Y.Z]` section is present.
  - WARN otherwise: `"[⚠] CHANGELOG.md has no release sections in Keep-a-Changelog format."`.
- Skip if missing (not required for non-publishing projects).

## Report

After all checks:

```
─────────────────────────────────────────────
Summary: <ERROR_COUNT> errors, <WARN_COUNT> warnings, <PASS_COUNT> checks passed
─────────────────────────────────────────────
```

Exit code:
- 0 if `ERROR_COUNT == 0` (warnings alone do not fail).
- 1 otherwise.

## Out of scope

- Does not auto-fix (v1 is read-only).
- Does not call network / `gh` / `git push` / `git fetch`.
- Does not deeply validate spec file contents (future `/ai-driver:lint-spec` handles that).
- Does not check MCP servers or hooks — out of scope for AI-driver's surface area.
