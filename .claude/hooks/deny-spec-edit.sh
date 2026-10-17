#!/usr/bin/env bash
# PreToolUse (Edit|Write|MultiEdit): denies agent edits to living specs under openspec/specs/, which change only by archiving a change folder inside the PR (ADR 0004). From the 05 PoC.
set -u

if ! command -v jq >/dev/null 2>&1; then
  # Fail closed: without jq this guard cannot read the tool call.
  echo "deny-spec-edit: jq is required by this repository's Claude Code hooks; install jq" >&2
  exit 2
fi

f=$(jq -r '.tool_input.file_path // empty')
# Paths arrive absolute; on Windows with backslashes (hooks reference), so normalise.
f="${f//\\//}"

case "$f" in
  */openspec/specs/* | openspec/specs/*)
    jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny",
      permissionDecisionReason: "Living specs under openspec/specs/ are read-only for agents (ADR 0004). Create a change folder openspec/changes/<issue>-<slug>/ with proposal.md, tasks.md and a delta spec (ADDED/MODIFIED/REMOVED Requirements), for example with /aphelion-sdlc:issue-propose, and archive it inside the PR."}}'
    ;;
esac
exit 0
