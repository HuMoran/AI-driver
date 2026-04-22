# AI-Driver (Plugin Source Repo)

This repository **is** the AI-driver Claude Code plugin, not a user project of it.

Language-agnostic AI-driven development framework: humans write specs, AI does plan + implement + test + review.

## Repo layout

- `.claude-plugin/marketplace.json` — marketplace catalog (root)
- `plugins/ai-driver/` — the installable plugin
  - `.claude-plugin/plugin.json` — plugin manifest
  - `commands/` — slash commands (`/ai-driver:run-spec` etc.)
  - `rules/` — language-specific format/lint/test/build rules
  - `templates/` — files shipped to user projects by `/ai-driver:init`
- `constitution.md` — project rules (this repo's own, also the template source for users)
- `specs/` — specs for this repo's own development
- `.github/workflows/` / `.codex/` — this repo's own config

## Dogfooding rule

When developing AI-driver itself, obey `constitution.md` (P1–P6 + R-001 to R-009). Edit specs in `specs/`, not in `plugins/ai-driver/templates/specs/`. Templates are outbound artifacts; edit them deliberately when the framework evolves.

## Key workflows

- **Three-gate workflow**: each change passes spec → plan → PR review. Gate 1 = `/ai-driver:run-spec` Phase 0 (unconditional). Gate 2 = `/ai-driver:run-spec` Phase 1 (only when Review Level ≥ B). Gate 3 = `/ai-driver:review-pr`. Each gate runs Claude subagent + Codex dual-blind; sandbox, stage-then-read, and consensus mechanics live in the respective command file.
- **Scope-fenced findings**: every review finding must carry a stage-specific anchor; unanchored or out-of-domain findings demote to `Observations` and do not affect the Verdict. Whitelists + parse rules are canonical in each command's Gating / Step 5a. Regression harness: `tests/review-synthesis/drift-demotion.sh`.
- Ship pipeline: `/ai-driver:run-spec specs/<feature>.spec.md` → `/ai-driver:review-pr` → `/ai-driver:merge-pr`. End-to-end, the plugin develops and releases itself.
- Keep `CHANGELOG.md`'s `## [Unreleased]` populated during PR flight; `/ai-driver:merge-pr` rolls it into the release section on merge.
- Edit templates at `plugins/ai-driver/templates/*`. **`plugin.json` stays version-less by convention** — writing `version` in both the marketplace entry and `plugin.json` causes the manifest to silently shadow the marketplace entry.
- **Template sync CI** (`.github/workflows/template-sync.yml`) enforces byte-identity between repo-root files and their `plugins/ai-driver/templates/…` mirrors. Edit one → `cp` to the other. Intentional divergence → remove the pair from `PAIRS`.

### Governance (constitution amendments)

Any PR that proposes an `R-NNN` rule or edits `constitution.md` (root or template mirror) must satisfy three conditions enforced by `/ai-driver:merge-pr` Step 0b.3: (1) PR body has an `R-NNN:` proposal block, (2) an admin/maintainer posts `approve R-NNN` or `同意R-NNN` as the first substantive line of a comment, (3) the branch carries a `docs(constitution): add R-NNN ...` commit against the PR's base ref. Full algorithm + error recovery: `plugins/ai-driver/commands/merge-pr.md` Step 0b.3.

**Canonical amendment commit** (referenced by merge-pr's preflight error message):

```bash
RN=R-010
git add constitution.md plugins/ai-driver/templates/constitution.md
git commit -m "docs(constitution): add $RN — approved by @<login> in PR #<n>"
```

**Deferral**: if approved but the amendment commit is not yet on-branch, pass `--defer "<rationale ≤ 200 chars>"` to land the feature PR and follow up with a constitution-only PR. Audit trail = one idempotent `<!-- ai-driver-defer:R-NNN -->` PR comment.

**Regression snapshots**: `tests/governance-snapshots/pr-{8,11}/` exercise positive/negative classifier paths offline via `bash tests/governance-snapshots/check.sh <snapshot-dir>`.

## Local test install

```bash
claude plugin marketplace add /Users/tao/Work/Hertzbio/AI-driver
claude plugin install ai-driver@ai-driver
```

Cache lands at `~/.claude/plugins/cache/ai-driver/ai-driver/<version>/`.
