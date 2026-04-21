#!/usr/bin/env bash
#
# drift-demotion.sh — deterministic regression test for v0.4.1 scope-fenced
# review synthesis. No LLM invocation. Exits 0 on pass, non-zero on fail.
#
# For each stage fixture under ./fixtures/<stage>.md:
#   1. Extract ---INPUT--- section (fabricated reviewer output)
#   2. Pipe through synthesize() for that stage
#   3. Diff against the ---EXPECTED--- section
#
# Covers four stages: spec / plan / pr / pr-nospec.
# Fulfils AC-011 of specs/v041-scope-fenced-reviews.spec.md.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
FIXTURE_DIR="$SCRIPT_DIR/fixtures"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

# ---------------------------------------------------------------------------
# Stage anchor whitelists (MUST-001)
#
# Encoded as space-separated prefix tokens. classify_anchor() prefix-matches
# the extracted anchor against these. An anchor matching no prefix in the
# active whitelist is out-of-domain for that stage (with one special-case:
# [AC-*]/[MUST-*]/[MUSTNOT-*] in pr-nospec demotes to anchor-requires-spec).
# ---------------------------------------------------------------------------
SPEC_WL='spec: observation:'
PLAN_WL='plan: observation:'
PR_WL_BASE='R- P- test: diff: observation:'
PR_WL_SPECFUL="$PR_WL_BASE AC- MUST- MUSTNOT-"

# ---------------------------------------------------------------------------
# parse_anchor: extract the leading bracketed token from a message cell.
# $1 = message text
# stdout = anchor text without brackets, or empty string if no anchor
# ---------------------------------------------------------------------------
parse_anchor() {
    local msg="$1"
    # Strip leading whitespace.
    msg="${msg#"${msg%%[![:space:]]*}"}"
    case "$msg" in
        \[*\]*)
            local inner="${msg#\[}"
            inner="${inner%%\]*}"
            printf '%s' "$inner"
            ;;
        *)
            printf ''
            ;;
    esac
}

# ---------------------------------------------------------------------------
# classify_anchor: given stage + anchor, return classification.
# $1 = stage (spec|plan|pr|pr-nospec), $2 = anchor text (no brackets)
# stdout = one of: main | out-of-domain | requires-spec | no-anchor
#
# STUB in T001 (RED): returns UNKNOWN so every fixture fails.
# Real implementation lands in T002 (GREEN).
# ---------------------------------------------------------------------------
classify_anchor() {
    printf 'UNKNOWN'
}

# ---------------------------------------------------------------------------
# synthesize: transform a reviewer output table into main + Observations.
# $1 = stage
# stdin = reviewer Markdown table (5-col: Severity|rule_id|location|message|fix_hint)
# stdout = transformed output with "## Main findings" and "## Observations" sections
# ---------------------------------------------------------------------------
synthesize() {
    local stage="$1"
    local main_rows='' obs_rows=''
    local line
    while IFS= read -r line; do
        # Skip header and separator rows; pass through non-table lines verbatim
        case "$line" in
            '| Severity |'*) continue ;;
            '| ---'*|'|---'*) continue ;;
            '|'*)
                # Extract column 4 (message) — split on " | " with leading "| ".
                local rest="${line#| }"
                # Drop trailing " |"
                rest="${rest% |}"
                # Columns delimited by " | "
                local IFS_SAVE="$IFS"
                IFS='|'
                set -- $rest
                IFS="$IFS_SAVE"
                # Note: splitting on just | (without surrounding spaces) leaves
                # a leading/trailing space on each cell. Strip.
                local sev="${1# }"; sev="${sev% }"
                local rid="${2# }"; rid="${rid% }"
                local loc="${3# }"; loc="${loc% }"
                local msg="${4# }"; msg="${msg% }"
                local fix="${5# }"; fix="${fix% }"
                local anchor
                anchor=$(parse_anchor "$msg")
                local cls
                cls=$(classify_anchor "$stage" "$anchor")
                case "$cls" in
                    main)
                        main_rows+="| $sev | $rid | $loc | $msg | $fix |"$'\n'
                        ;;
                    out-of-domain)
                        obs_rows+="| Info | $rid | $loc | $msg | $fix | anchor-out-of-domain: [$anchor] |"$'\n'
                        ;;
                    requires-spec)
                        obs_rows+="| Info | $rid | $loc | $msg | $fix | anchor-requires-spec: [$anchor] |"$'\n'
                        ;;
                    no-anchor)
                        obs_rows+="| Info | $rid | $loc | $msg | $fix | no-anchor |"$'\n'
                        ;;
                    *)
                        # Stub returns UNKNOWN → route to obs with marker so diff is visible
                        obs_rows+="| Info | $rid | $loc | $msg | $fix | STUB:$cls |"$'\n'
                        ;;
                esac
                ;;
        esac
    done

    printf '## Main findings\n'
    printf '| Severity | rule_id | location | message | fix_hint |\n'
    printf '| --- | --- | --- | --- | --- |\n'
    printf '%s' "$main_rows"
    printf '\n'
    printf '## Observations\n'
    printf '| Severity | rule_id | location | message | fix_hint | tag |\n'
    printf '| --- | --- | --- | --- | --- | --- |\n'
    printf '%s' "$obs_rows"
}

# ---------------------------------------------------------------------------
# Harness: run all fixtures, diff output against expected.
# ---------------------------------------------------------------------------

FAIL=0
for fixture in "$FIXTURE_DIR"/*.md; do
    [ -f "$fixture" ] || { echo "no fixtures found under $FIXTURE_DIR" >&2; exit 2; }
    stage=$(basename "$fixture" .md)

    # Split INPUT and EXPECTED sections.
    awk '
        /^---INPUT---$/   { mode="in";  next }
        /^---EXPECTED---$/{ mode="exp"; next }
        mode=="in"  { print > "'"$TMPDIR/$stage.in"'" }
        mode=="exp" { print > "'"$TMPDIR/$stage.expected"'" }
    ' "$fixture"

    synthesize "$stage" < "$TMPDIR/$stage.in" > "$TMPDIR/$stage.actual"

    if diff -u "$TMPDIR/$stage.expected" "$TMPDIR/$stage.actual" > "$TMPDIR/$stage.diff"; then
        echo "PASS [$stage]"
    else
        echo "FAIL [$stage]"
        cat "$TMPDIR/$stage.diff"
        FAIL=1
    fi
done

if [ "$FAIL" -ne 0 ]; then
    exit 1
fi

echo ""
echo "All fixtures passed."
