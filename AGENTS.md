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

- Ship v0.2 → v0.3: run `/ai-driver:run-spec` on a spec in `specs/`. That's the plugin developing itself.
- Update templates: edit `plugins/ai-driver/templates/*` and bump version in both `marketplace.json` and `plugins/ai-driver/.claude-plugin/plugin.json` (one place only — see `docs/research/2026-04-17-plugin-interface.md`).

## Local test install

```bash
claude plugin marketplace add /Users/tao/Work/Hertzbio/AI-driver
claude plugin install ai-driver@ai-driver
```

Cache lands at `~/.claude/plugins/cache/ai-driver/ai-driver/<version>/`.
