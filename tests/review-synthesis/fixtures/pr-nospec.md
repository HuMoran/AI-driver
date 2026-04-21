PR-review stage without spec (cleanup/chore PR like #14). Mix of valid R/diff anchors + spec-dependent AC/MUST/MUSTNOT anchors which must demote to anchor-requires-spec.

---INPUT---
| Severity | rule_id | location | message | fix_hint |
| --- | --- | --- | --- | --- |
| High | R1 | diff/README.md:10 | [diff:README.md:10] typo in section title. | fix the typo |
| High | R2 | commit/abc123 | [R-005] commit message is not Conventional Commits format. | rewrite subject |
| High | R3 | diff/cli.md | [AC-005] some AC check would fail on this cleanup. | none (no spec loaded) |
| Medium | R4 | diff/x.md | [MUST-003] should not remove this. | restore |
---EXPECTED---
## Main findings
| Severity | rule_id | location | message | fix_hint |
| --- | --- | --- | --- | --- |
| High | R1 | diff/README.md:10 | [diff:README.md:10] typo in section title. | fix the typo |
| High | R2 | commit/abc123 | [R-005] commit message is not Conventional Commits format. | rewrite subject |

## Observations
| Severity | rule_id | location | message | fix_hint | tag |
| --- | --- | --- | --- | --- | --- |
| Info | R3 | diff/cli.md | [AC-005] some AC check would fail on this cleanup. | none (no spec loaded) | anchor-requires-spec: [AC-005] |
| Info | R4 | diff/x.md | [MUST-003] should not remove this. | restore | anchor-requires-spec: [MUST-003] |
