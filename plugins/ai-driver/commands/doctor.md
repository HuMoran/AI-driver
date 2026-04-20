---
description: Read-only health check for an AI-driver project — detects drift, misconfiguration, and version skew
allowed-tools: Read, Glob, Grep, Bash(git status:*), Bash(git log:*), Bash(jq:*), Bash(diff:*), Bash(cmp:*), Bash(find:*)
---

# /ai-driver:doctor: Project health check (read-only)

Usage: `/ai-driver:doctor`

Prints a report of every check with `[✓]` / `[⚠]` / `[✗]` and an exact copy-paste fix command for anything that's not green. **Never modifies a file. Never calls the network.**

## Preflight

1. If `$ARGUMENTS` contains `--fix`, print: `"--fix is not supported. Doctor is read-only; run the suggested commands yourself."` and exit 0 WITHOUT running any check.
2. If neither `./constitution.md` nor `./AGENTS.md` exists (exact case-sensitive filename check — see §"Filename case-sensitivity" below), print: `"Not an AI-driver project — run /ai-driver:init first"` and exit 0 WITHOUT running any check.

### Filename case-sensitivity

macOS's default filesystem is case-insensitive. To keep doctor's behavior identical on macOS / Linux / Windows CI, all control-file existence checks (`constitution.md`, `AGENTS.md`, `CLAUDE.md`) must require an EXACT-CASE match. Use:

```bash
find . -maxdepth 1 -type f -name 'constitution.md' | grep -qx ./constitution.md
```

or equivalently: list the directory and grep for the exact basename. Do NOT use `test -f ./constitution.md` alone — that returns true for `./Constitution.md` on a case-insensitive FS.

### Symlinks

`CLAUDE.md`, `AGENTS.md`, `constitution.md`, and files under `specs/` must be regular files (not symlinks) for the checks to be authoritative. If a symlink is detected, emit a `[⚠]` symlink warning for that file and SKIP further inspection of it.

### Line-ending / BOM normalization

For any read-and-match check against a Markdown file (`CLAUDE.md`, etc.), normalize before matching:

1. Strip a leading UTF-8 BOM (`\xef\xbb\xbf`) if present.
2. Normalize line endings: `\r\n` → `\n`.
3. Ignore leading blank lines when "first non-blank line" is required.

## Checks

Run every check. Accumulate `ERROR_COUNT`, `WARN_COUNT`, `PASS_COUNT`. Print each result immediately; don't batch.

### Check 1 — `constitution.md` present (exact-case)

- PASS if `./constitution.md` exists as a regular file with exact basename.
- If a symlink → WARN: `"[⚠] constitution.md is a symlink. Fix: replace with a regular file — cp \"$(readlink constitution.md)\" constitution.md"`.
- Otherwise ERROR: `"[✗] constitution.md missing. Fix: /ai-driver:init"`.

### Check 2 — `AGENTS.md` present (exact-case)

- PASS if `./AGENTS.md` exists as a regular file.
- Symlink → WARN with the same pattern as Check 1.
- Otherwise ERROR: `"[✗] AGENTS.md missing. Fix: /ai-driver:init"`.

### Check 3 — `CLAUDE.md` imports `AGENTS.md` (first non-blank line)

After normalizing (BOM + CRLF + leading blanks), define FIRST as the first non-blank line.

- If `./CLAUDE.md` missing → WARN: `"[⚠] CLAUDE.md missing. Claude Code reads CLAUDE.md, not AGENTS.md. Fix: printf '@AGENTS.md\\n' > CLAUDE.md"`.
- If symlink → WARN with Check 1's pattern.
- If no line in the file matches the regex `^@(\./)?AGENTS\.md$` → ERROR: `"[✗] CLAUDE.md does not import AGENTS.md. Fix: printf '@AGENTS.md\\n\\n%s' \"$(cat CLAUDE.md)\" > CLAUDE.md.new && mv CLAUDE.md.new CLAUDE.md"`.
- If the import exists but FIRST is not `@AGENTS.md` / `@./AGENTS.md` → WARN: `"[⚠] CLAUDE.md imports AGENTS.md but not as the first non-blank line. For correct precedence, the import must come first. Fix: move the import line to the top of CLAUDE.md (or rewrite: awk 'NR==1 && /^@(\\.\\/)?AGENTS\\.md\$/{found=1} {print}' and reorder manually)."`.
- Otherwise PASS.

### Check 4 — `specs/` directory present

- PASS if `./specs/` exists and is a directory (not symlink).
- WARN otherwise: `"[⚠] specs/ missing. Fix: mkdir specs && cp \"\${CLAUDE_PLUGIN_ROOT}/templates/specs/_template.spec.md\" specs/"`.

### Check 5 — No legacy v0.1 spec filenames (top-level only)

Scope: **`./specs/` top level only** (`find ./specs -maxdepth 1 -type f -name 'p[0-9]*_*.spec.md'`). Nested directories (`specs/archive/*`, `specs/drafts/*`) are not flagged so projects can preserve legacy naming in historical subdirs.

- PASS if no match.
- WARN per matching file: `"[⚠] Legacy v0.1 filename: <path>. Fix: git mv <path> specs/<slug-without-pNN-prefix>.spec.md && edit the file to remove the 'ID: pNN' line from Meta"`.

### Check 6 — `constitution.md` drift from plugin template

- If `${CLAUDE_PLUGIN_ROOT}/templates/constitution.md` is readable:
  - PASS if `cmp -s ./constitution.md ${CLAUDE_PLUGIN_ROOT}/templates/constitution.md`.
  - WARN otherwise, printing the first 10 lines of the unified diff and: `"Fix (review): diff -u constitution.md \${CLAUDE_PLUGIN_ROOT}/templates/constitution.md   # then reconcile manually"`.
- If the template is unreadable (plugin cache missing / reinstall needed) → WARN: `"[⚠] Plugin template cache not accessible — skipping drift checks. Fix: claude plugin update ai-driver@ai-driver"`.

### Check 7 — `.claude/settings.json` enables ai-driver

- If `./.claude/settings.json` missing → WARN: `"[⚠] .claude/settings.json missing. Fix: /ai-driver:init"`.
- If present but `jq -r '.enabledPlugins[\"ai-driver@ai-driver\"] // false' ./.claude/settings.json` is not `true` → WARN: `"[⚠] .claude/settings.json does not enable ai-driver@ai-driver. Fix: jq '.enabledPlugins[\"ai-driver@ai-driver\"]=true' .claude/settings.json > .claude/settings.json.new && mv .claude/settings.json.new .claude/settings.json"`.
- Otherwise PASS.

### Check 8 — Plugin version skew (best-effort)

Determine INSTALLED version from `${CLAUDE_PLUGIN_ROOT}` path — it's the `<version>` component in `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`. Compare against the sibling `marketplace.json` in the same cache (which may have been `plugin marketplace update`-ed to a newer version).

- If INSTALLED < known → WARN: `"[⚠] Plugin v<installed> installed, v<latest> available. Fix: claude plugin update ai-driver@ai-driver"`.
- If the cache is unreadable or the version cannot be parsed → SKIP silently (no print).
- Otherwise PASS.

### Check 9 — Plugin-publishing project manifest validity

- If `./.claude-plugin/` directory does not exist → mark `[—]` (N/A). Non-plugin-publishing project, nothing further to check.
- Otherwise (`.claude-plugin/` exists — we assume publishing intent):
  - If `./.claude-plugin/marketplace.json` missing → ERROR: `"[✗] .claude-plugin/ exists but marketplace.json missing. Fix: follow docs/research/2026-04-17-plugin-interface.md §2 to create it, or remove .claude-plugin/ if not publishing."`.
  - If present but `jq -e . ./.claude-plugin/marketplace.json >/dev/null` fails → ERROR: `"[✗] .claude-plugin/marketplace.json is invalid JSON. Fix: open the file and fix the syntax (or restore from git: git checkout .claude-plugin/marketplace.json)"`.
  - Same rules for `./.claude-plugin/plugin.json` IF it exists. Absence of `plugin.json` is OK (our relative-path-plugin convention).

### Check 10 — `CHANGELOG.md` Keep-a-Changelog shape

- If `CHANGELOG.md` missing → mark `[—]` N/A (not required for non-publishing projects).
- If exists and has zero `## [X.Y.Z]` sections → WARN: `"[⚠] CHANGELOG.md has no release sections in Keep-a-Changelog format. Fix: open CHANGELOG.md and add at least one '## [Unreleased]' section; see https://keepachangelog.com/en/1.1.0/"`.
- Otherwise PASS.

## Report

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
- Does not check MCP servers or hooks.
