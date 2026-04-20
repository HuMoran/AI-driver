#!/usr/bin/env bash
# run.sh — regression harness for injection-lint.
# For each .patch file in this directory:
#   1. Apply the patch to a clean working tree (creates the anti-pattern).
#   2. Run injection-lint.sh. Must exit non-zero.
#   3. Stderr must contain the matching rule-id token.
#   4. Revert the patch (git checkout -- .). Tree must be clean again.
# If every rule catches its anti-pattern, exit 0. Otherwise exit non-zero.
#
# The script REQUIRES a clean working tree and refuses to run with uncommitted
# changes — it does not stash/restore. A trap handler always reverts the last
# applied patch on exit (normal, Ctrl-C, or CI timeout) so an interrupted run
# never leaves the tree dirty.

set -u
HERE=$(cd -- "$(dirname -- "$0")" && pwd -P)
REPO=$(git -C "$HERE" rev-parse --show-toplevel)
cd "$REPO"
cleanup() { git checkout -- . 2>/dev/null || true; }
trap cleanup EXIT INT TERM

# Require a clean tree so apply/restore doesn't eat the user's work.
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: working tree has uncommitted changes — commit or stash first" >&2
  exit 1
fi

fail=0
cases=0

for patch in "$HERE"/*.patch; do
  [ -f "$patch" ] || continue
  rule=$(basename "$patch" .patch)
  cases=$((cases+1))
  echo "=== Case: $rule ==="

  # Apply the patch. If it doesn't apply, that itself is a failure.
  if ! git apply "$patch" 2>/dev/null; then
    echo "  FAIL: patch $patch does not apply — underlying file may have changed. Regenerate the patch." >&2
    fail=1
    continue
  fi

  # Run the lint. Capture stderr.
  errout=$(bash "$REPO/.github/scripts/injection-lint.sh" 2>&1 >/dev/null)
  rc=$?

  # Revert the patch regardless of lint outcome.
  git checkout -- . 2>/dev/null

  if [ "$rc" -eq 0 ]; then
    echo "  FAIL: lint exited 0 with $rule anti-pattern introduced — rule is not catching its regression" >&2
    echo "$errout" | head -5 >&2
    fail=1
    continue
  fi

  if ! echo "$errout" | grep -Fq "rule-id=$rule"; then
    echo "  FAIL: lint exited non-zero but stderr did not contain 'rule-id=$rule' — wrong rule fired?" >&2
    echo "$errout" | head -5 >&2
    fail=1
    continue
  fi

  echo "  PASS: lint correctly caught $rule regression"
done

if [ "$cases" -eq 0 ]; then
  echo "ERROR: no .patch files found in $HERE" >&2
  exit 1
fi

if [ "$fail" -eq 0 ]; then
  echo "=== All $cases regression cases pass ==="
fi
exit "$fail"
