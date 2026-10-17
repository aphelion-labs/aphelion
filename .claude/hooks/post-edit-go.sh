#!/usr/bin/env bash
# PostToolUse (Edit|Write|MultiEdit): after a .go edit, runs gofmt -l on the file and golangci-lint on its package, and returns the findings to Claude as context, never as a block (ADR 0012 stage 1, ADR 0001 for mnd).
set -u

# Open decision: how many lines of findings Claude sees after one edit. This value
# is a placeholder set by the scaffolding agent, not by the owner (ADR 0001).
# Claude Code separately caps additionalContext at 10,000 characters (hooks reference).
MAX_LINES=30

# This hook only informs, so without jq it stays silent rather than blocking.
command -v jq >/dev/null 2>&1 || exit 0

f=$(jq -r '.tool_input.file_path // empty')
f="${f//\\//}"
case "$f" in *.go) ;; *) exit 0 ;; esac
[ -f "$f" ] || exit 0

dir=$(dirname "$f")
root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || exit 0

findings=""
if [ -n "$(gofmt -l "$f" 2>&1)" ]; then
  findings="gofmt: $f is not gofmt-formatted (make fmt fixes it)"$'\n'
fi

# Same golangci-lint version as the Makefile, read from it so the two cannot drift.
version=$(sed -n 's/^GOLANGCI_LINT_VERSION[[:space:]]*=[[:space:]]*//p' "$root/Makefile" 2>/dev/null)
if [ -z "$version" ]; then
  findings+="post-edit-go: GOLANGCI_LINT_VERSION not found in $root/Makefile, so golangci-lint did not run"$'\n'
else
  # --allow-serial-runners: several agents on one machine queue on golangci-lint's
  # lock instead of failing with "parallel golangci-lint is running".
  if ! lint=$(cd "$dir" && go run "github.com/golangci/golangci-lint/v2/cmd/golangci-lint@$version" \
    run --allow-serial-runners . 2>&1); then
    # Drop go run's own "exit status N" trailer; it carries no finding.
    findings+="$(printf '%s\n' "$lint" | grep -v '^exit status ')"$'\n'
  fi
fi

[ -n "$findings" ] || exit 0

total=$(printf '%s' "$findings" | awk 'END { print NR }')
context="Lint findings for $f after this edit:"$'\n'$(printf '%s' "$findings" | head -n "$MAX_LINES")
if [ "$total" -gt "$MAX_LINES" ]; then
  context+=$'\n'"($MAX_LINES of $total lines shown; make lint prints all of them)"
fi

jq -n --arg c "$context" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
exit 0
