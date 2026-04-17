# /ai-driver:init: Scaffold AI-driver into the current project

Usage: `/ai-driver:init [--with-ci] [--with-deploy] [--with-codex] [--lang en|zh-CN] [--force]`

Sets up AI-driver files in the current working directory. **Merge-safe by default**: existing files are left untouched unless `--force` is passed.

## Flags

- `--with-ci` — also copy `.github/workflows/{auto-release,ci}.yml`
- `--with-deploy` — also copy `deploy/_template.deploy.md` (and `.zh-CN.md`)
- `--with-codex` — also copy `.codex/config.toml`
- `--lang en|zh-CN` — language preference (default: `en`). Currently only affects which template variant is highlighted in the final summary.
- `--force` — overwrite existing files. The original is backed up to `<path>.bak.YYYYMMDDHHMMSS` first. Never overwrites without `--force`.

## Step 1: Preflight (all fatal checks first; make ZERO writes until every check passes)

Do **all** of the following **before** copying anything. If any fails, print a one-line error and abort without touching any file.

1. **Parse flags** from `$ARGUMENTS`. Unknown flags → abort with message listing valid flags. `--lang` must equal `en` or `zh-CN`; reject anything else.
2. **Check `jq`**: `command -v jq >/dev/null` — if missing, abort: `"jq not found. Install jq (brew install jq / apt-get install jq) before running /ai-driver:init."`
3. **Check plugin templates dir**: `test -d "${CLAUDE_PLUGIN_ROOT}/templates"` — if missing, abort: `"Plugin templates not found at ${CLAUDE_PLUGIN_ROOT}/templates/. Reinstall the ai-driver plugin."`
4. **Check CWD is writable**: `test -w .` — if not, abort with a clear message.
5. **If `./.claude/settings.json` exists, verify it is valid JSON** now (not later): `jq -e . ./.claude/settings.json >/dev/null` — if it fails, abort: `"ERROR: ./.claude/settings.json is not valid JSON. Fix it and rerun."`

Only when **all five** pass do you proceed. This guarantees the "leave all files untouched on fatal error" contract.

## Step 2: Copy core files (always)

For each `<src, dst>` pair below, apply the **merge-safe copy** rule (defined in §4):

| Source (inside plugin) | Destination (project root) |
|---|---|
| `${CLAUDE_PLUGIN_ROOT}/templates/constitution.md` | `./constitution.md` |
| `${CLAUDE_PLUGIN_ROOT}/templates/AGENTS.md` | `./AGENTS.md` |
| `${CLAUDE_PLUGIN_ROOT}/templates/specs/_template.spec.md` | `./specs/_template.spec.md` |
| `${CLAUDE_PLUGIN_ROOT}/templates/specs/_template.spec.zh-CN.md` | `./specs/_template.spec.zh-CN.md` |

Create `./specs/` if it does not exist.

## Step 3: Handle `CLAUDE.md` specially (import-aware)

`CLAUDE.md` does NOT follow the merge-safe copy rule. Instead:

- If `./CLAUDE.md` **does not exist**: write a single line `@AGENTS.md\n`.
- If `./CLAUDE.md` **exists** and any line already matches `^@(\./)?AGENTS\.md$` (to catch both `@AGENTS.md` and `@./AGENTS.md`): leave it alone.
- If `./CLAUDE.md` **exists** without an `@AGENTS.md` import: **prepend** `@AGENTS.md\n\n` at the top of the file. Do not modify any existing content.

The import must come first so Claude-specific notes added later by the user can override imported AGENTS.md instructions (matches the documented pattern in Claude Code's memory docs).

## Step 4: Merge-safe copy rule (used by steps 2 and 5)

For a given `<src, dst>`:

- If `dst` does not exist: create parent dir as needed, copy `src` to `dst`. Print `"CREATE: <dst>"`.
- If `dst` exists and `--force` is NOT set: print `"SKIP: <dst> already exists"` and continue.
- If `dst` exists and `--force` IS set:
  1. Compute a backup path: `<dst>.bak.$(date +%Y%m%d%H%M%S)`.
  2. Copy the current `dst` to that backup path (never clobber a prior `.bak.*`).
  3. Copy `src` to `dst`.
  4. Print `"OVERWRITE: <dst> (backup at <dst>.bak.<timestamp>)"`.

Never delete a file. Never move a file out of the project root.

## Step 5: Optional copies

If `--with-deploy`, apply merge-safe copy:

- `${CLAUDE_PLUGIN_ROOT}/templates/deploy/_template.deploy.md` → `./deploy/_template.deploy.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/deploy/_template.deploy.zh-CN.md` → `./deploy/_template.deploy.zh-CN.md`

If `--with-ci`:

- `${CLAUDE_PLUGIN_ROOT}/templates/.github/workflows/auto-release.yml` → `./.github/workflows/auto-release.yml`
- `${CLAUDE_PLUGIN_ROOT}/templates/.github/workflows/ci.yml` → `./.github/workflows/ci.yml`

If `--with-codex`:

- `${CLAUDE_PLUGIN_ROOT}/templates/.codex/config.toml` → `./.codex/config.toml`

## Step 6: Merge `.claude/settings.json`

Compute the **minimal** default block. It only enables the ai-driver plugin by name — it does NOT declare a marketplace source. The marketplace was added by the user before running `init`, and hardcoding any specific source here would silently repoint forks, internal mirrors, or local-path installs to an upstream they may not want.

```json
{
  "enabledPlugins": {
    "ai-driver@ai-driver": true
  }
}
```

If the team wants teammates to auto-prompt for the marketplace on trust, they can add `extraKnownMarketplaces` manually pointing at whichever fork / mirror they actually use. Document that in the printed summary (see §7).

Write it with this rule (no process substitution — use stdin so it works on any POSIX-ish shell):

- If `./.claude/settings.json` does not exist: create `./.claude/` and write the block above. Print `"CREATE: .claude/settings.json"`.
- If `./.claude/settings.json` exists (we already validated it is valid JSON in preflight): deep-merge defaults **into** the existing file with **existing keys winning on conflict**. The rule `.[1] * .[0]` in jq means "take the second input, then overlay the first on top, right-hand wins on conflict"; so putting defaults FIRST and existing file SECOND gives "existing wins":

  ```bash
  tmp="./.claude/settings.json.new.$$"
  bak="./.claude/settings.json.bak.$(date +%Y%m%d%H%M%S)"
  printf '%s' "$DEFAULTS" | jq -s '.[1] * .[0]' ./.claude/settings.json - > "$tmp"
  cp ./.claude/settings.json "$bak"
  mv "$tmp" ./.claude/settings.json
  ```

  Print `"MERGE: .claude/settings.json (backup at $bak)"`. If any of those three commands fails, remove `$tmp` and abort — but the existing file is untouched (we only `mv` on the last line).

## Step 7: Print summary

Group the actions taken:

- **Created** — new files
- **Skipped (already present)** — files left untouched
- **Overwritten (--force)** — files replaced with `.bak.<timestamp>` backups
- **Merged** — `.claude/settings.json`

Then the next steps:

```txt
Next steps:
  1. Edit constitution.md to match your project constraints.
  2. Write your first spec:   cp specs/_template.spec.md specs/<your-feature>.spec.md
  3. Run the spec:            /ai-driver:run-spec specs/<your-feature>.spec.md
  4. Review the PR:           /ai-driver:review-pr

Optional: if you want teammates to be prompted to install ai-driver automatically
when they trust this repo, add your marketplace source to .claude/settings.json:
  "extraKnownMarketplaces": {
    "<name>": { "source": { "source": "github", "repo": "<owner>/<repo>" } }
  }
Use whichever source (upstream, fork, or internal mirror) you want the team to use.
```

## Error handling

Any fatal error in Step 1 preflight halts execution **before any write**.

After Step 1, the file copies in Steps 2 / 3 / 5 are not transactional across files — if a copy fails mid-flight (e.g., disk full, denied permission on a parent directory), some templates may have landed while others did not. This is recoverable: `/ai-driver:init` is **idempotent for missing files** — re-running it will `SKIP` whatever already landed and `CREATE` what's still missing, with no data loss.

The Step 6 `settings.json` merge always writes via temp-file + rename, so the original file is only replaced on success.

## Out of scope

- Does not git-init the project.
- Does not write `.gitignore`.
- Does not install the plugin itself (that happened before the command could run).
- Does not rewrite existing `CLAUDE.md` content other than prepending `@AGENTS.md`.
- Does not hardcode any specific marketplace source into the team settings.
