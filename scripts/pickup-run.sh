#!/usr/bin/env bash
# One agent run for one issue (ADR 0010; Blueprint, "Conventions the driver
# enforces"). scripts/pickup.sh starts it in the background after labelling the
# issue status:in-progress; it can also be run by hand.
#
# usage: scripts/pickup-run.sh propose|apply <issue-number>
#   propose  /issue-propose: change folder and draft PR, then stop at
#            status:spec-review for the owner's approval.
#   apply    implement, then /issue-finish: PR ready, status:in-review.
#
# Branch and worktree are both <issue>-<slug>, the worktree under .worktrees/,
# made with plain git from a fresh origin/main (not claude --worktree), so the
# OpenSpec change id equals the branch. An apply after a propose reuses that
# worktree, rebased onto origin/main first. Worktrees are never removed here:
# claude -p runs do not clean them (local/worktrees.md), and
# scripts/pickup.sh --reconcile removes them once the PR is merged or closed.
# On failure the issue is labelled status:blocked with the run's result and the
# worktree stays for inspection.
#
# Environment:
#   APHELION_REPO           default aphelion-labs/aphelion (ADR 0012)
#   APHELION_RUN_ID         run id and Claude session id; default a new UUID
#   APHELION_MAX_TURNS      --max-turns. Open decision: the Blueprint asks for
#                             a turn cap but names no number, so when unset no
#                             cap is passed (Claude Code's default).
#   APHELION_SKILL_NS       namespace of the skills plugin; default
#                             "aphelion-sdlc:", the plugin .claude/settings.json
#                             enables. Plugin skills are invoked as
#                             /<plugin>:<skill> (local/github-actions.md).
#   APHELION_ALLOWED_TOOLS  overrides the --allowedTools list below
set -euo pipefail

usage() { awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; }
[ "$#" -eq 2 ] || { usage >&2; exit 2; }
mode=$1 issue=$2
case "$mode" in propose|apply) ;; *) usage >&2; exit 2 ;; esac
case "$issue" in ''|*[!0-9]*) echo "pickup-run: issue must be a number" >&2; exit 2 ;; esac

repo=${APHELION_REPO:-aphelion-labs/aphelion}
skill_ns=${APHELION_SKILL_NS-aphelion-sdlc:}
run_id=${APHELION_RUN_ID:-$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)}
machine=$(hostname)

for tool in git gh jq claude; do
  command -v "$tool" >/dev/null || { echo "pickup-run: $tool not found" >&2; exit 1; }
done

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
common_dir=$(git -C "$script_dir" rev-parse --path-format=absolute --git-common-dir)
root=$(dirname "$common_dir")
state_dir="$common_dir/aphelion"
state="$state_dir/$issue.json"
run_dir="$state_dir/runs/$issue-$run_id"
mkdir -p "$run_dir"
cd "$root"

log() { printf 'pickup-run #%s: %s\n' "$issue" "$*"; }

# Merges fields into the issue's state file: set_state '{"k": "v"}'.
set_state() {
  local tmp
  tmp=$(mktemp "$state.XXXXXX")
  if [ -f "$state" ]; then
    jq --argjson add "$1" '. + $add' "$state" >"$tmp"
  else
    jq -n --argjson add "$1" '$add' >"$tmp"
  fi
  mv "$tmp" "$state"
}

# Hands the issue to the owner: label blocked, comment, record the failure.
# Never retries (Blueprint, "Failure").
finished=0
block() {
  local reason=$1 detail=${2:-}
  finished=1
  log "blocked: $reason"
  set_state "$(jq -n --arg r "$reason" --arg t "$(date -u +%FT%TZ)" \
    '{status: "failed", reason: $r, finished_at: $t}')" || true
  gh issue edit "$issue" --repo "$repo" --add-label status:blocked \
    --remove-label status:in-progress >/dev/null || true
  local body
  # Backticks below are Markdown code spans, not command substitution.
  # shellcheck disable=SC2016
  body=$(printf '%s run `%s` on `%s` failed: %s\n\nWorktree left for inspection: `%s`\n' \
    "${mode^^}" "$run_id" "$machine" "$reason" "${worktree:-none}")
  if [ -n "$detail" ]; then
    # shellcheck disable=SC2016
    body=$(printf '%s\n\nFinal result of the run:\n\n```text\n%s\n```\n' "$body" "$detail")
  fi
  # GitHub refuses over-long comment bodies; fall back to a pointer to the
  # local run directory rather than cutting the result at a chosen length.
  gh issue comment "$issue" --repo "$repo" --body "$body" >/dev/null \
    || gh issue comment "$issue" --repo "$repo" --body \
      "${mode^^} run \`$run_id\` on \`$machine\` failed: $reason. The result is too long for a comment; see \`$run_dir\`." >/dev/null \
    || true
  exit 1
}
trap 'rc=$?; [ "$finished" -eq 1 ] || [ "$rc" -eq 0 ] || block "pickup-run.sh exited with status $rc before finishing; see $run_dir"' EXIT

set_state "$(jq -n --argjson i "$issue" --arg m "$mode" --arg r "$run_id" \
  --argjson p "$$" --arg h "$machine" --arg t "$(date -u +%FT%TZ)" --arg d "$run_dir" \
  '{issue: $i, mode: $m, run_id: $r, pid: $p, machine: $h, status: "running",
    started_at: $t, run_dir: $d}')"

# --- issue, type label, model ------------------------------------------------
issue_json=$(gh issue view "$issue" --repo "$repo" --json number,title,labels,state)
[ "$(jq -r .state <<<"$issue_json")" = OPEN ] || block "issue is not open"
title=$(jq -r .title <<<"$issue_json")
type_label=$(jq -r '[.labels[].name | select(startswith("type:"))] | first // ""' <<<"$issue_json")

# Model by the issue's type label: Opus for implementation work, Sonnet for
# chores (owner decision 2026-10-17).
case "$type_label" in
  type:feat|type:fix|type:refactor|type:perf) model=claude-opus-5-5 ;;
  type:chore|type:docs|type:deps|type:ci|type:test) model=claude-sonnet-5-5 ;;
  *) block "the issue has no type: label the driver knows (found '${type_label:-none}')" ;;
esac

# --- branch and worktree -----------------------------------------------------
# .worktrees/ must stay out of git status. This is local, untracked config.
exclude_file="$common_dir/info/exclude"
mkdir -p "$(dirname "$exclude_file")"
grep -qxF '/.worktrees/' "$exclude_file" 2>/dev/null || echo '/.worktrees/' >>"$exclude_file"

git fetch --quiet origin main

# Reuse a branch this issue already has (from its propose run), else derive
# <issue>-<slug> from the title. Open decision: slug length; none is imposed.
branch=$(git for-each-ref --format='%(refname:lstrip=2)' "refs/heads/$issue-*")
if [ -z "$branch" ]; then
  git fetch --quiet origin "+refs/heads/$issue-*:refs/remotes/origin/$issue-*" || true
  branch=$(git for-each-ref --format='%(refname:lstrip=3)' "refs/remotes/origin/$issue-*")
fi
[ "$(printf '%s\n' "$branch" | grep -c .)" -le 1 ] || block "more than one branch starts with $issue-: $branch"
if [ -z "$branch" ]; then
  slug=$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')
  branch="$issue-${slug:-issue}"
fi
worktree="$root/.worktrees/$branch"

if [ -d "$worktree" ]; then
  [ "$mode" = apply ] || block "worktree $worktree already exists"
elif git show-ref --verify --quiet "refs/heads/$branch"; then
  git worktree add --quiet "$worktree" "$branch"
elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
  git worktree add --quiet --track -b "$branch" "$worktree" "origin/$branch"
else
  # --no-track: the branch must not track origin/main, or a plain push would
  # target main.
  git worktree add --quiet --no-track -b "$branch" "$worktree" origin/main
fi

# An apply may start days after its propose; rebase so it builds on current
# main (Blueprint, "Rebase").
rebased=no
if [ "$mode" = apply ] && ! git -C "$worktree" merge-base --is-ancestor origin/main HEAD; then
  if ! git -C "$worktree" rebase --quiet origin/main; then
    git -C "$worktree" rebase --abort || true
    block "rebase of $branch onto origin/main hit conflicts"
  fi
  rebased=yes
fi

# Versioned git hooks for this clone (ADR 0005); worktrees share the setting.
(cd "$worktree" && scripts/setup-hooks.sh) >"$run_dir/setup-hooks.log" 2>&1 \
  || block "scripts/setup-hooks.sh failed; see $run_dir/setup-hooks.log"

base_commit=$(git rev-parse origin/main)
set_state "$(jq -n --arg b "$branch" --arg w "$worktree" --arg c "$base_commit" \
  --arg m "$model" '{branch: $b, worktree: $w, base_commit: $c, model: $m}')"
set_state "$(jq -n --arg k "${mode}_session_id" --arg v "$run_id" '{($k): $v}')"

# --- prompt ------------------------------------------------------------------
context="You are an unattended ${mode^^} run started by scripts/pickup-run.sh on $machine for issue #$issue in $repo. Branch: $branch. Worktree: $worktree. The OpenSpec change id, if this issue needs one, is $branch. Nobody can answer questions or permission prompts. Commit messages are Conventional Commits, terse and lowercase, with no trailers. Push early and often to origin $branch; never use --no-verify. If the pre-push hook refuses a push, do what it says."
if [ "$mode" = propose ]; then
  prompt="/${skill_ns}issue-propose $issue"
  context="$context Stop as soon as the draft PR is open and the issue is labelled status:spec-review. Do not implement anything."
else
  prompt="Follow the Start here section of CLAUDE.md before changing anything. Then implement issue #$issue on branch $branch. If openspec/changes/$branch/ exists, implement its tasks.md; otherwise implement the issue's acceptance criteria. Run make check until it passes. Then run /${skill_ns}issue-finish $issue."
  if [ "$rebased" = yes ]; then
    context="$context The branch was rebased onto origin/main before this run; if it was pushed before, push with --force-with-lease."
  fi
fi
printf '%s\n' "$prompt" >"$run_dir/prompt.txt"
printf '%s\n' "$context" >"$run_dir/system-append.txt"

# Tool allowlist. Bare Bash approves every shell command, which covers the gh
# and openspec commands; the PreToolUse guards in .claude/settings.json still
# apply (ADR 0004, ADR 0005).
allowed_tools=${APHELION_ALLOWED_TOOLS:-Read,Edit,Write,Glob,Grep,Bash,Skill}

args=(
  -p "$prompt"
  --append-system-prompt "$context"
  --model "$model"
  --permission-mode acceptEdits
  --permission-prompts none
  --allowedTools "$allowed_tools"
  --output-format json
  --name "issue-$issue"
  --session-id "$run_id"
)
if [ -n "${APHELION_MAX_TURNS:-}" ]; then
  args+=(--max-turns "$APHELION_MAX_TURNS")
fi

# --- run ---------------------------------------------------------------------
# Never --bare: it skips the subscription login, hooks, skills and CLAUDE.md
# (local/headless.md).
log "running claude ($model) in $worktree"
set +e
(cd "$worktree" && claude "${args[@]}") >"$run_dir/result.json" 2>"$run_dir/stderr.log"
rc=$?
set -e

result=$(jq -r '.result // empty' "$run_dir/result.json" 2>/dev/null || cat "$run_dir/result.json")
is_error=$(jq -r '.is_error // false' "$run_dir/result.json" 2>/dev/null || echo true)
cost=$(jq -r '.total_cost_usd // empty' "$run_dir/result.json" 2>/dev/null || true)
set_state "$(jq -n --argjson rc "$rc" --arg c "$cost" '{exit_code: $rc, cost_usd: $c}')"

[ "$rc" -eq 0 ] && [ "$is_error" = false ] \
  || block "claude exited with status $rc (is_error $is_error)" "$result"

pr=$(gh pr list --repo "$repo" --head "$branch" --state open --json number,url,isDraft --jq 'first // empty')
[ -n "$pr" ] || block "the run finished but no open PR has head $branch" "$result"

# The driver owns the status labels after ready (Blueprint, label taxonomy).
if [ "$mode" = propose ]; then next=status:spec-review; else next=status:in-review; fi
gh issue edit "$issue" --repo "$repo" --add-label "$next" --remove-label status:in-progress >/dev/null
set_state "$(jq -n --argjson pr "$pr" --arg t "$(date -u +%FT%TZ)" \
  '{status: "succeeded", pr: $pr.url, pr_number: $pr.number, finished_at: $t}')"
finished=1
log "done: $(jq -r .url <<<"$pr"), issue labelled $next"
