#!/usr/bin/env bash
# Governance preflight classifier (snapshot-regression harness).
# Reads a snapshot directory containing:
#   meta.json         — {baseRefName, body, files[], admin_allowlist[]}
#   comments.json     — [{author, createdAt, body}]
#   branch-commits.json — [{sha, subject}]
#   expected.txt      — the expected stdout (single line)
#
# Prints one of:
#   proceed
#   abort: <message>
# and exits 0 iff stdout matches expected.txt.

set -eu
set -o pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <snapshot-dir>" >&2
  exit 2
fi

DIR=$1
for f in meta.json comments.json branch-commits.json expected.txt; do
  [ -f "$DIR/$f" ] || { echo "ERROR: missing $DIR/$f" >&2; exit 2; }
done

META=$DIR/meta.json
COMMENTS=$DIR/comments.json
COMMITS=$DIR/branch-commits.json

BODY=$(jq -r '.body' "$META")
FILES=$(jq -r '.files[]' "$META")

# 1. Body proposal detection: regex ^####?\s+R-[0-9]+:|^\*\*R-[0-9]+:
PROPOSALS=$(printf '%s\n' "$BODY" | grep -Eo '^####?[[:space:]]+R-[0-9]+:|^\*\*R-[0-9]+:' | grep -Eo 'R-[0-9]+' | sort -u || true)

# 2. File trigger: constitution.md or templates/constitution.md changed
FILE_TRIGGER=no
if printf '%s\n' "$FILES" | grep -qxE '(plugins/ai-driver/templates/)?constitution\.md'; then
  FILE_TRIGGER=yes
fi

# Non-governance PR short-circuit
if [ -z "$PROPOSALS" ] && [ "$FILE_TRIGGER" = no ]; then
  run() { echo "proceed"; }
# File trigger but no body proposal: reverse-incident guard
elif [ -z "$PROPOSALS" ] && [ "$FILE_TRIGGER" = yes ]; then
  run() {
    echo "abort: this PR changes constitution.md but PR body has no R-NNN proposal block"
  }
else
  # Per-proposal decision tree
  run() {
    for R in $PROPOSALS; do
      # 3. Find rule-scoped approval from admin/maintain author
      APPROVER=$(
        jq -r --arg R "$R" --argjson allow "$(jq '.admin_allowlist' "$META")" '
          .[]
          | select(.author as $a | $allow | index($a))
          | . as $c
          | ($c.body
             | split("\n")
             # Delete fenced-code blocks (triple-backtick or triple-tilde)
             | reduce .[] as $line (
                 {out: [], in_fence: false};
                 if ($line | test("^[[:space:]]*(```|~~~)"))
                 then .in_fence = (.in_fence | not)
                 elif .in_fence then .
                 else .out += [$line]
                 end
               )
             | .out
             # Delete blockquoted lines (^\s*>)
             | map(select(test("^[[:space:]]*>") | not))
             # First non-blank line
             | map(select(test("^[[:space:]]*$") | not))
             | .[0] // ""
             | ascii_downcase
             | gsub("^[[:space:]]+|[[:space:]]+$"; "")
            ) as $first
          | select($first | test("^(approve|同意)[[:space:]]*" + ($R | ascii_downcase) + "\\b"))
          | $c.author
        ' "$COMMENTS" | head -n 1
      )

      # 4. Amendment commit detection (subject prefix, suffix advisory)
      HAS_COMMIT=no
      if jq -r '.[].subject' "$COMMITS" | grep -Eq "^docs\(constitution\): add $R "; then
        HAS_COMMIT=yes
      fi

      if [ -z "$APPROVER" ]; then
        echo "abort: $R proposed in PR body but no \"approve $R\" / \"同意$R\" comment found from an admin/maintainer"
        return
      fi

      if [ "$HAS_COMMIT" = no ]; then
        echo "abort: $R approved by @$APPROVER but no \"docs(constitution): add $R ...\" commit on this branch"
        return
      fi
    done
    echo "proceed"
  }
fi

ACTUAL=$(run)
EXPECTED=$(sed -n '1p' "$DIR/expected.txt")

printf '%s\n' "$ACTUAL"

if [ "$ACTUAL" = "$EXPECTED" ]; then
  exit 0
else
  echo "---" >&2
  echo "MISMATCH in $DIR" >&2
  echo "expected: $EXPECTED" >&2
  echo "actual:   $ACTUAL" >&2
  exit 1
fi
