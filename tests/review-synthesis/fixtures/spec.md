Spec-review stage fixture. Three reviewer rows: in-domain, out-of-domain (anchor from PR stage), no-anchor.

---INPUT---
| Severity | rule_id | location | message | fix_hint |
| --- | --- | --- | --- | --- |
| High | R1 | spec/ACs | [spec:ac-executable] AC-003 is prose not a runnable command. | make it a shell expression |
| High | R2 | diff/x.md:10 | [diff:x.md:10] handler crashes on null input. | add guard |
| Medium | R3 | spec/Goal | The goal reads fuzzy and not actionable. | clarify in one sentence |
---EXPECTED---
## Main findings
| Severity | rule_id | location | message | fix_hint |
| --- | --- | --- | --- | --- |
| High | R1 | spec/ACs | [spec:ac-executable] AC-003 is prose not a runnable command. | make it a shell expression |

## Observations
| Severity | rule_id | location | message | fix_hint | tag |
| --- | --- | --- | --- | --- | --- |
| Info | R2 | diff/x.md:10 | [diff:x.md:10] handler crashes on null input. | add guard | anchor-out-of-domain: [diff:x.md:10] |
| Info | R3 | spec/Goal | The goal reads fuzzy and not actionable. | clarify in one sentence | no-anchor |
