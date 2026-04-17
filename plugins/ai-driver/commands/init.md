# /ai-driver:init: Scaffold AI-driver into the current project

Usage: `/ai-driver:init [--with-ci] [--with-deploy] [--with-codex] [--lang en|zh-CN] [--force]`

Sets up AI-driver files in the current working directory. **Merge-safe by default**: existing files are left untouched unless `--force` is passed.

## Flags

- `--with-ci` — also copy `.github/workflows/{auto-release,ci}.yml`
- `--with-deploy` — also copy `deploy/_template.deploy.md` (and `.zh-CN.md`)
- `--with-codex` — also copy `.codex/config.toml`
- `--lang en|zh-CN` — language preference (default: `en`). Currently only affects whether `*.zh-CN.md` template copies are the primary example in the summary.
- `--force` — overwrite existing files. The original is backed up to `<path>.bak` first. Never overwrite without `--force`.

## Preconditions

1. `jq` must be available (used to merge `.claude/settings.json`). If missing, abort with: `"jq not found. Install jq before running /ai-driver:init."`
2. Current working directory must be writable.

## Steps

### 1. Parse flags from `$ARGUMENTS`

Treat unknown flags as an error and abort with a clear message listing valid flags. The `--lang` value must be exactly `en` or `zh-CN`; reject anything else.

### 2. Locate the template source

The templates live inside the plugin at `${CLAUDE_PLUGIN_ROOT}/templates/`. Confirm this directory exists before proceeding. If it does not, abort with:
`"Plugin templates not found at ${CLAUDE_PLUGIN_ROOT}/templates/. Reinstall the ai-driver plugin."`

### 3. Copy core files (always)

For each `<src, dst>` pair below, apply the **merge-safe copy** rule (defined in §5):

| Source (inside plugin) | Destination (project root) |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/templates/constitution.md` | `./constitution.md` |
| `${CLAUDE_PLUGIN_ROOT}/templates/AGENTS.md` | `./AGENTS.md` |
| `${CLAUDE_PLUGIN_ROOT}/templates/specs/_template.spec.md` | `./specs/_template.spec.md` |
| `${CLAUDE_PLUGIN_ROOT}/templates/specs/_template.spec.zh-CN.md` | `./specs/_template.spec.zh-CN.md` |

Create the `./specs/` directory if it does not exist.

### 4. Handle `CLAUDE.md` specially (import-aware)

`CLAUDE.md` is the one file that does NOT use the merge-safe copy rule. Instead:

- If `./CLAUDE.md` **does not exist**: write a single line `@AGENTS.md` followed by a newline.
- If `./CLAUDE.md` **exists** and already contains a line matching `^@AGENTS\.md$`: leave it alone.
- If `./CLAUDE.md` **exists** but does NOT import `AGENTS.md`: append two lines to the end: a blank line, then `@AGENTS.md`. Do not modify any existing content.

This preserves user-authored CLAUDE.md content while ensuring Claude Code loads `AGENTS.md`.

### 5. Merge-safe copy rule (the only copy rule used elsewhere)

For a given `<src, dst>`:

- If `dst` does not exist: copy `src` to `dst`.
- If `dst` exists and `--force` is NOT set: print `"SKIP: <dst> already exists"` and continue.
- If `dst` exists and `--force` IS set:
  1. Copy the current `dst` to `<dst>.bak` (overwrite any prior `.bak`).
  2. Copy `src` to `dst`.
  3. Print `"OVERWRITE: <dst> (backup at <dst>.bak)"`.

Never delete a file. Never move a file out of the project root.

### 6. Optional copies

If `--with-deploy` is set, apply merge-safe copy for:
- `${CLAUDE_PLUGIN_ROOT}/templates/deploy/_template.deploy.md` → `./deploy/_template.deploy.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/deploy/_template.deploy.zh-CN.md` → `./deploy/_template.deploy.zh-CN.md`

If `--with-ci` is set:
- `${CLAUDE_PLUGIN_ROOT}/templates/.github/workflows/auto-release.yml` → `./.github/workflows/auto-release.yml`
- `${CLAUDE_PLUGIN_ROOT}/templates/.github/workflows/ci.yml` → `./.github/workflows/ci.yml`

If `--with-codex` is set:
- `${CLAUDE_PLUGIN_ROOT}/templates/.codex/config.toml` → `./.codex/config.toml`

Create intermediate directories as needed.

### 7. Merge `.claude/settings.json`

Compute the default settings block:

```json
{
  "extraKnownMarketplaces": {
    "ai-driver": {
      "source": {
        "source": "github",
        "repo": "HuMoran/AI-driver"
      }
    }
  },
  "enabledPlugins": {
    "ai-driver@ai-driver": true
  }
}
```

Write it using this rule:

- If `./.claude/settings.json` does not exist: create `./.claude/` and write the block above as the file. Print `"CREATE: .claude/settings.json"`.
- If `./.claude/settings.json` exists: deep-merge the defaults **into** the existing file, with **existing keys winning on conflict**. Use `jq`:

  ```bash
  # Only overwrite file atomically after a successful merge
  jq -s '.[0] * .[1] | .[0]' ./.claude/settings.json <(echo "$DEFAULTS") > ./.claude/settings.json.new \
    && mv ./.claude/settings.json ./.claude/settings.json.bak \
    && mv ./.claude/settings.json.new ./.claude/settings.json
  ```

  Wait — the merge order in `jq -s '.[0] * .[1]'` makes the right side win. That is the opposite of "existing wins". Correct form: `jq -s '.[1] * .[0]'` (defaults first, existing file second, right-wins-rule means existing wins on conflict). Print `"MERGE: .claude/settings.json (backup at .claude/settings.json.bak)"`.

  If the existing file is not valid JSON, abort with: `"ERROR: .claude/settings.json is not valid JSON. Fix it and rerun."` Do not write the `.bak` in this case.

### 8. Print summary

Output the list of actions taken, grouped as:

- **Created**: new files
- **Skipped (already present)**: files left untouched
- **Overwritten (--force)**: files replaced (with `.bak` paths)
- **Merged**: `.claude/settings.json`

End with the next steps:

```
Next steps:
  1. Edit constitution.md to match your project constraints.
  2. Write your first spec:   cp specs/_template.spec.md specs/<your-feature>.spec.md
  3. Run the spec:            /ai-driver:run-spec specs/<your-feature>.spec.md
  4. Review the PR:           /ai-driver:review-pr
```

## Error handling

- Any fatal error (missing jq, bad flag, invalid JSON in existing settings.json, unreadable plugin templates dir) must halt execution, print a clear one-line error, and leave all files untouched. Never leave the project in a half-initialized state.

## Out of scope

- Does not git-init the project.
- Does not write `.gitignore`.
- Does not install the plugin itself (that happened before the command could run).
- Does not rewrite existing `CLAUDE.md` content other than appending `@AGENTS.md`.
