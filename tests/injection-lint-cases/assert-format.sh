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

HERE=$(cd -- "$(dirname -- "$0")" && pwd -P)
REPO=$(git -C "$HERE" rev-parse --show-toplevel)
cd "$REPO"
cleanup() { git checkout -- . 2>/dev/null || true; }
trap cleanup EXIT INT TERM
PATCH="$HERE/$RULE.patch"
[ -f "$PATCH" ] || { echo "ERROR: no patch for $RULE at $PATCH" >&2; exit 1; }

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: working tree has uncommitted changes" >&2
  exit 1
fi

git apply "$PATCH" || { echo "ERROR: patch did not apply" >&2; exit 1; }
errout=$(bash "$REPO/.github/scripts/injection-lint.sh" 2>&1 >/dev/null)
# Revert explicitly via `git apply -R` (also removes any files patch added);
# the trap is a safety net in case this line is skipped.
git apply -R "$PATCH" 2>/dev/null || git checkout -- . 2>/dev/null

fail=0
for tok in "rule-id=$RULE" "fix:" "#$RULE"; do
  if ! printf '%s' "$errout" | grep -Fq "$tok"; then
    echo "FAIL: missing token '$tok' in lint stderr" >&2
    fail=1
  fi
done
# file:line — require a path-like token with a mandatory :<digits> suffix.
if ! printf '%s' "$errout" | grep -Eq '[A-Za-z0-9_./-]+\.(md|yml|yaml|sh):[0-9]+'; then
  echo "FAIL: missing file:line reference (path.ext:NN) in stderr" >&2
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS: $RULE output format matches MUST-003 contract"
fi
exit "$fail"
