PR-review stage with spec loaded. In-domain AC / out-of-domain spec-anchor / no-anchor.

---INPUT---
| Severity | rule_id | location | message | fix_hint |
| --- | --- | --- | --- | --- |
| High | R1 | diff/review-pr.md:50 | [AC-005] Pass 2 prompt is missing Focus list. | add Focus (PR review) |
| Medium | R2 | spec/Goal | [spec:goal] the spec goal could be tighter. | rewrite Goal |
| Medium | R3 | diff/run-spec.md:120 | This block should be refactored for clarity. | none |
---EXPECTED---
## Main findings
| Severity | rule_id | location | message | fix_hint |
| --- | --- | --- | --- | --- |
| High | R1 | diff/review-pr.md:50 | [AC-005] Pass 2 prompt is missing Focus list. | add Focus (PR review) |

## Observations
| Severity | rule_id | location | message | fix_hint | tag |
| --- | --- | --- | --- | --- | --- |
| Info | R2 | spec/Goal | [spec:goal] the spec goal could be tighter. | rewrite Goal | anchor-out-of-domain: [spec:goal] |
| Info | R3 | diff/run-spec.md:120 | This block should be refactored for clarity. | none | no-anchor |
