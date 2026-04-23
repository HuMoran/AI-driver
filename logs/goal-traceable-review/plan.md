# Plan — goal-traceable-review

## Architecture

```
plugins/ai-driver/commands/run-spec.md
├── Layer 1 prompt (literal, ~lines 109-141)
│   └── INSERT: Goal-traceability clause (after Focus + Out-of-scope, before Anchor rule)
├── Layer 2 prompt (literal, ~lines 175-207)
│   └── INSERT: mirrored Goal-traceability clause (same semantics, BSD data-boundary intact)
└── Gating section (~lines 215-250)
    └── INSERT: refinement-loop detection rule + term definitions
        (normalized_location, previous round, resolved/acknowledged markers)

CHANGELOG.md [Unreleased]
└── Changed: one entry documenting prompt + gating semantics change
```

## Reuse

- Existing anchor scope-fence machinery in Gating stays untouched
- Dual-raise severity-notch rule stays untouched
- `tests/review-synthesis/drift-demotion.sh` — regression must remain green (AC-005)

## Risks

- **Prompt mirror drift**: Layer 1 and Layer 2 clauses must stay semantically identical despite subagent vs stdin-fence wording differences. Mitigation: human review of diff.
- **Regression in `drift-demotion.sh`**: the test exercises anchor-based demotion; refinement-loop demotion layers on top. Mitigation: AC-005 catches any break.

## Data flow

No runtime data flow change — this is prompt text + doc edit. All semantic effect materializes at the next `/ai-driver:run-spec` invocation in any repo using the updated plugin.
