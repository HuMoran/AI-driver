#!/usr/bin/env bash
# assert-format.sh — verify the output-format contract (MUST-003).
# Usage: bash tests/injection-lint-cases/assert-format.sh <RULE_ID>
# Applies the patch for <RULE_ID>, runs the lint, and checks that stderr
# contains all four contract tokens: rule-id=<ID>, a file:line reference,
# fix:, and #<ID> (threat-model anchor).
# Reverts the patch on exit.

set -u
RULE="${1:-}"
if [ -z "$RULE" ]; then
  echo "Usage: $0 <RULE_ID>" >&2
  exit 1
fi

HERE=$(dirname "$(readlink -f "$0")")
REPO=$(git -C "$HERE" rev-parse --show-toplevel)
cd "$REPO"
PATCH="$HERE/$RULE.patch"
[ -f "$PATCH" ] || { echo "ERROR: no patch for $RULE at $PATCH" >&2; exit 1; }

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: working tree has uncommitted changes" >&2
  exit 1
fi

git apply "$PATCH" || { echo "ERROR: patch did not apply" >&2; exit 1; }
errout=$(bash "$REPO/.github/scripts/injection-lint.sh" 2>&1 >/dev/null)
git checkout -- .

fail=0
for tok in "rule-id=$RULE" "fix:" "#$RULE"; do
  if ! printf '%s' "$errout" | grep -Fq "$tok"; then
    echo "FAIL: missing token '$tok' in lint stderr" >&2
    fail=1
  fi
done
# file:line — a line with at least one colon after a likely path.
if ! printf '%s' "$errout" | grep -Eq '[A-Za-z0-9_./-]+(:[0-9]+)?'; then
  echo "FAIL: no file-reference token in stderr" >&2
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS: $RULE output format matches MUST-003 contract"
fi
exit "$fail"
