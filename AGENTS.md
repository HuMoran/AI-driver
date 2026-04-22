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
- `.github/workflows/` / `.codex/` — this repo's own config

## Dogfooding rule

When developing AI-driver itself, obey `constitution.md` (P1–P6 + R-001 to R-007). Edit specs in `specs/`, not in `plugins/ai-driver/templates/specs/`. Templates are outbound artifacts; edit them deliberately when the framework evolves.

## Key workflows

- **Three-gate workflow** (v0.3.6+, uniform dual-LLM as of v0.3.8): every change passes through **spec review → plan review → PR review**, each running a Claude **subagent** (sandboxed executor with `Read, Grep, Glob` only — no network, no Write, no nested spawn) + Codex (external adversarial via `codex exec -s read-only` dispatched through `Bash(run_in_background=true)`). Dual-consensus severity upgrades on findings keyed by `rule_id + normalized location`. Spec review (Phase 0 of `/ai-driver:run-spec`, standalone via `/ai-driver:run-spec <spec> --review-only` for draft iteration) is unconditional. Plan review runs in Phase 1 when Review Level ≥ B. PR review runs on the finished diff with existing-reviewer awareness (v0.3.4+) and **stage-then-read** ingestion: untrusted PR bytes are fetched via `gh ... > "$STAGE/<artifact>"` (stdout AND stderr redirected) to a per-run `mktemp -d` tempdir, then the subagent reads those files — the main session's context never contains raw reviewer text or PR diffs. Codex invocations use Claude Code's `Bash(run_in_background=true)` pattern so the completion notification arrives automatically on the next turn — no polling, no silently dropped reviews.
- **Scope-fenced reviews** (v0.4.1+): every actionable finding from the three gates must cite an anchor from its stage's **anchor whitelist** — spec: `[spec:goal|scope|must-coverage|ac-executable|ambiguity|contradiction|over-specification]`; plan: `[plan:ac-uncovered|task-atomic|dependency|reuse|risk|feasibility]`; PR: `[AC-xxx]` / `[MUST-NNN]` / `[MUSTNOT-NNN]` / `[R-NNN]` / `[P-N]` / `[test:<name>]` / `[diff:<file>:<line>]`; `[observation:<tag>]` always permitted. Findings with out-of-domain or no anchor are mechanically demoted to a non-blocking `Observations` section with tag `anchor-out-of-domain` / `no-anchor` / `anchor-requires-spec` (PR-only, chore-PR case). **Verdict computation excludes Observations.** Contract is prose in each review command's synthesis/gating section; reference implementation + regression harness at `tests/review-synthesis/drift-demotion.sh` (4 fixtures × 3 stages + no-spec-PR).
- Ship v0.X → v0.Y: `/ai-driver:run-spec specs/<feature>.spec.md` → `/ai-driver:review-pr` → `/ai-driver:merge-pr`. That's the plugin developing itself end-to-end, including its own release.
- Keep `CHANGELOG.md`'s `## [Unreleased]` populated while a PR is in flight. `/ai-driver:merge-pr` converts it into the release section on merge.
- Update templates: edit `plugins/ai-driver/templates/*`. Version bumps happen automatically at release time — `/ai-driver:merge-pr` rewrites `.claude-plugin/marketplace.json`'s `metadata.version` and the matching `plugins[].version` fields in the same `chore(release): vX.Y.Z` commit as `CHANGELOG.md`. `.claude-plugin/plugin.json` stays version-less by our convention (see `docs/research/2026-04-17-plugin-interface.md` §3 for the double-writing shadowing issue); `merge-pr` respects that — it only touches `plugin.json` if the field is already present.
- **Template sync CI**: any file that exists at the repo root AND at `plugins/ai-driver/templates/…` (workflows, `.codex/config.toml`, spec templates) must stay byte-identical. `.github/workflows/template-sync.yml` enforces this on every PR; if you edit one side, `cp` to the other. Intentional divergence → remove the pair from `PAIRS`.

### Governance (constitution amendments)

When a PR proposes a new `R-NNN` operational rule or touches `constitution.md` / its template mirror, `/ai-driver:merge-pr` runs a governance preflight (Step 0b.3) and fails-closed unless all three conditions are satisfied (v0.3.10+):

1. **PR body** contains an `R-NNN:` proposal block matching `^####?\s+R-NNN:|^\*\*R-NNN:`. (File-changed trigger: any PR touching `constitution.md` or `plugins/ai-driver/templates/constitution.md` must have a body proposal too, or merge-pr aborts — prevents "body lost but file changed".)
2. **Issue-comment** from a GitHub collaborator with `role_name == "admin"` or `"maintain"` contains `approve R-NNN` or `同意R-NNN` (bilingual) as the first substantive line (after deleting `^\s*>` blockquote lines and fenced-code-block content). Bare `approve` without the rule number is commentary.
3. **Amendment commit** on the branch whose subject matches `^docs(constitution): add R-NNN ` (suffix advisory — recommended shape below). Match is evaluated against the PR's base ref via `git log origin/<base>..HEAD`, not hardcoded `main`.

**Canonical amendment commit template**:

```bash
RN=R-010  # the rule number being amended
git add constitution.md plugins/ai-driver/templates/constitution.md
git commit -m "docs(constitution): add $RN — approved by @<login> in PR #<n>"
```

**Deferral escape hatch** — the approved-without-commit case only (mirrors the v0.3.9 shape):

```bash
/ai-driver:merge-pr --defer "constitution change is substantive; splitting into a dedicated R-NNN PR for cleaner review"
```

Rationale ≤ 200 chars, single-line; merge-pr posts one idempotent PR comment with marker `<!-- ai-driver-defer:R-NNN -->` as audit. Follow up with a constitution-only PR carrying the `docs(constitution): add R-NNN …` commit.

**Regression snapshots**: `tests/governance-snapshots/pr-{8,11}/` replay the v0.3.9 incident contrast (PR #8 = R-008 approved and landed → proceed; PR #11 = R-009 approved but commit not landed → abort). `bash tests/governance-snapshots/check.sh <snapshot-dir>` exercises the classifier without a real `gh` call.

## Local test install

```bash
claude plugin marketplace add /Users/tao/Work/Hertzbio/AI-driver
claude plugin install ai-driver@ai-driver
```

Cache lands at `~/.claude/plugins/cache/ai-driver/ai-driver/<version>/`.
