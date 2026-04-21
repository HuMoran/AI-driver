Plan-review stage fixture. In-domain / out-of-domain (anchor from spec stage) / no-anchor.

---INPUT---
| Severity | rule_id | location | message | fix_hint |
| --- | --- | --- | --- | --- |
| High | R1 | tasks/T004 | [plan:ac-uncovered] AC-004 is not mapped to any task. | add a task covering AC-004 |
| Medium | R2 | spec/Goal | [spec:goal] the spec goal is still unclear. | rewrite Goal section |
| Low | R3 | plan/tasks | Tasks should be more granular. | split large tasks |
---EXPECTED---
## Main findings
| Severity | rule_id | location | message | fix_hint |
| --- | --- | --- | --- | --- |
| High | R1 | tasks/T004 | [plan:ac-uncovered] AC-004 is not mapped to any task. | add a task covering AC-004 |

## Observations
| Severity | rule_id | location | message | fix_hint | tag |
| --- | --- | --- | --- | --- | --- |
| Info | R2 | spec/Goal | [spec:goal] the spec goal is still unclear. | rewrite Goal section | anchor-out-of-domain: [spec:goal] |
| Info | R3 | plan/tasks | Tasks should be more granular. | split large tasks | no-anchor |
