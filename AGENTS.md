# AI-Driver (Plugin Source Repo)

This repository **is** the AI-driver Claude Code plugin, not a user project of it.

Language-agnostic AI-driven development framework: humans write specs, AI does plan + implement + test + review.

## Repo layout (v0.2)

- `.claude-plugin/marketplace.json` — marketplace catalog (root)
- `plugins/ai-driver/` — the installable plugin
  - `.claude-plugin/plugin.json` — plugin manifest
  - `commands/` — slash commands (`/ai-driver:run-spec` etc.)
  - `rules/` — language-specific format/lint/test/build rules
  - `templates/` — files shipped to user projects by `/ai-driver:init`
- `constitution.md` — project rules (this repo's own, also the template source for users)
- `specs/` — specs for this repo's own development
- `deploy/` / `.github/workflows/` / `.codex/` — this repo's own config

## Dogfooding rule

When developing AI-driver itself, obey `constitution.md` (P1–P6 + R-001 to R-007). Edit specs in `specs/`, not in `plugins/ai-driver/templates/specs/`. Templates are outbound artifacts; edit them deliberately when the framework evolves.

## Key workflows

- Ship v0.X → v0.Y: `/ai-driver:run-spec specs/<feature>.spec.md` → `/ai-driver:review-pr` → `/ai-driver:merge-pr`. That's the plugin developing itself end-to-end, including its own release.
- Keep `CHANGELOG.md`'s `## [Unreleased]` populated while a PR is in flight. `/ai-driver:merge-pr` converts it into the release section on merge.
- Update templates: edit `plugins/ai-driver/templates/*`. Version bumps happen automatically at release time — `/ai-driver:merge-pr` rewrites `.claude-plugin/marketplace.json`'s `metadata.version` and the matching `plugins[].version` fields in the same `chore(release): vX.Y.Z` commit as `CHANGELOG.md`. `.claude-plugin/plugin.json` stays version-less by our convention (see `docs/research/2026-04-17-plugin-interface.md` §3 for the double-writing shadowing issue); `merge-pr` respects that — it only touches `plugin.json` if the field is already present.
- **Template sync CI**: any file that exists at the repo root AND at `plugins/ai-driver/templates/…` (workflows, `.codex/config.toml`, spec/deploy templates) must stay byte-identical. `.github/workflows/template-sync.yml` enforces this on every PR; if you edit one side, `cp` to the other. Intentional divergence → remove the pair from `PAIRS`.

## Local test install

```bash
claude plugin marketplace add /Users/tao/Work/Hertzbio/AI-driver
claude plugin install ai-driver@ai-driver
```

Cache lands at `~/.claude/plugins/cache/ai-driver/ai-driver/<version>/`.
