#!/usr/bin/env bash
# injection-lint.sh — static lint for injection-class anti-patterns.
# See specs/v037-injection-tests.spec.md and docs/security/injection-threat-model.md.
#
# Each rule fails with:
#   rule-id=<ID>  <file:line>  fix: <hint>  #<ID>
# The trailing #<ID> is a direct anchor into docs/security/injection-threat-model.md.
#
# Exit 0 on clean tree. Exit 1 with structured messages on any violation.

set -u
fail=0

# Output helper. Prints the exact contract line per MUST-003.
emit() {
  # $1 rule-id  $2 file:line  $3 fix
  printf 'rule-id=%s  %s  fix: %s  #%s\n' "$1" "$2" "$3" "$1" >&2
  fail=1
}

THREE_CMDS=(
  plugins/ai-driver/commands/review-pr.md
  plugins/ai-driver/commands/fix-issues.md
  plugins/ai-driver/commands/merge-pr.md
)

# L-TRUST — Trust boundary heading + data-fence preamble + BEGIN/END markers.
for f in "${THREE_CMDS[@]}"; do
  [ -f "$f" ] || continue
  if ! grep -Fq '## Trust boundary' "$f"; then
    emit L-TRUST "$f" "add '## Trust boundary' section declaring reviewer/PR content UNTRUSTED DATA; see review-pr.md for the canonical pattern"
  fi
done

# L-QUOTE — no bare untrusted vars inside fenced bash blocks.
# Variables of concern:
#   $ARGUMENTS  $SPEC_PATH  $SPEC_SLUG  $PR_TITLE  $REVIEWER_LOGIN
#   $ISSUE_BODY  $COMMENT_BODY  $BRANCH_NAME  $TAG_NAME
# Bare means: appears unquoted (no surrounding "..." or ${...}), and not in `[...]`
# test expressions with -z / -n (those are safe).
L_QUOTE_CMDS=(
  plugins/ai-driver/commands/review-pr.md
  plugins/ai-driver/commands/fix-issues.md
  plugins/ai-driver/commands/merge-pr.md
  plugins/ai-driver/commands/run-spec.md
  plugins/ai-driver/commands/review-spec.md
)
VARS='ARGUMENTS|SPEC_PATH|SPEC_SLUG|PR_TITLE|REVIEWER_LOGIN|ISSUE_BODY|COMMENT_BODY|BRANCH_NAME|TAG_NAME'
for f in "${L_QUOTE_CMDS[@]}"; do
  [ -f "$f" ] || continue
  # Scan only inside ```bash ... ``` fences. Use process substitution so
  # the `emit` side-effects hit this shell's `fail`, not a subshell's.
  while IFS=$'\t' read -r _ path lineno content; do
    emit L-QUOTE "$path:$lineno" "double-quote or \${} the untrusted variable in: $(echo "$content" | head -c 120)"
  done < <(awk -v vars="$VARS" -v file="$f" '
    /^```bash$/ {in_fence=1; next}
    /^```$/ {in_fence=0; next}
    in_fence {
      line=$0
      gsub(/"[^"]*"/, "", line)
      gsub(/\$\{[^}]+\}/, "", line)
      if (match(line, "\\$(" vars ")([^A-Za-z0-9_]|$)")) {
        printf "FOUND\t%s\t%d\t%s\n", file, NR, $0
      }
    }
  ' "$f")
done

# L-SELF-ID — review-pr.md self-ID filter must require BOTH marker AND login check.
f=plugins/ai-driver/commands/review-pr.md
if [ -f "$f" ]; then
  has_marker=0
  has_login=0
  grep -Fq '<!-- ai-driver-review -->' "$f" && has_marker=1
  # login check heuristic: look for SELF_LOGIN or user.login comparison or gh api /user --jq .login
  if grep -Eq 'SELF_LOGIN|user\.login *==|gh api +/user +--jq +\.login' "$f"; then
    has_login=1
  fi
  if [ "$has_marker" -eq 1 ] && [ "$has_login" -eq 0 ]; then
    emit L-SELF-ID "$f" "self-ID filter must require BOTH the <!-- ai-driver-review --> marker AND a user.login comparison — marker alone is spoofable"
  fi
fi

# L-BOT — bot detection must use user.type or [bot] suffix; must NOT use copilot-* / dependabot-* prefix heuristic.
for f in plugins/ai-driver/commands/review-pr.md plugins/ai-driver/commands/fix-issues.md; do
  [ -f "$f" ] || continue
  # Find any bot-detection heuristic using a prefix like "copilot-" or "dependabot-"
  if grep -nE 'startsWith\("(copilot|dependabot)-' "$f" >/dev/null 2>&1; then
    line=$(grep -nE 'startsWith\("(copilot|dependabot)-' "$f" | head -1 | cut -d: -f1)
    emit L-BOT "$f:$line" "replace startsWith('copilot-'/'dependabot-') with user.type == \"Bot\" OR user.login ends with [bot]"
  fi
  # Affirmative check: the file must mention user.type or [bot] suffix somewhere
  if ! grep -Eq 'user\.type|\[bot\]' "$f"; then
    emit L-BOT "$f" "bot detection absent — add user.type == \"Bot\" OR login-endsWith [bot] check"
  fi
done

# L-EXTRACT — auto-release.yml uses deterministic extraction only; no LLM invocation.
f=.github/workflows/auto-release.yml
if [ -f "$f" ]; then
  if grep -iE 'codex exec|claude|anthropic|gpt-|openai' "$f" >/dev/null 2>&1; then
    line=$(grep -niE 'codex exec|claude|anthropic|gpt-|openai' "$f" | head -1 | cut -d: -f1)
    emit L-EXTRACT "$f:$line" "auto-release.yml must extract release notes via awk/sed; no LLM invocation — CHANGELOG is trusted data only if we never ask a model to interpret it"
  fi
  # Affirmative: must contain an awk or sed section extractor
  if ! grep -Eq 'awk |sed ' "$f"; then
    emit L-EXTRACT "$f" "auto-release.yml must use awk/sed to extract the [X.Y.Z] section deterministically"
  fi
fi

exit "$fail"
