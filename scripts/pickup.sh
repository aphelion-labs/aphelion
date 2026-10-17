#!/usr/bin/env bash
# One tick of the local pickup driver (ADR 0010; Blueprint, "The loop").
#
# usage: scripts/pickup.sh [--dry-run]
#          Dispatch: start a PROPOSE run for each open issue labelled
#          status:needs-spec and an APPLY run for each labelled status:ready,
#          oldest first, up to the concurrency cap. Each run is
#          scripts/pickup-run.sh in the background.
#        scripts/pickup.sh --reconcile [--dry-run]
#          Remove each .worktrees/ worktree, and its local branch, whose PR is
#          merged or closed. Claude -p runs never remove worktrees
#          (local/headless.md, local/worktrees.md), so this is the only cleanup.
#
# Only the owner moves issues into needs-spec or ready (ADR 0010). The driver
# owns every status label after that: in-progress on start, then spec-review,
# in-review or blocked (set by pickup-run.sh).
#
# Environment:
#   APHELION_REPO      owner/repo; default aphelion-labs/aphelion (ADR 0012)
#   APHELION_MAX_RUNS  runs at once on this machine; default 2, the
#                        Blueprint's "at most two runs at a time". Open decision
#                        (ADR 0010) until week one measures the Max plan.
# State: <git-common-dir>/aphelion/<issue>.json per issue, run logs under
# <git-common-dir>/aphelion/runs/ (Blueprint, "State").
set -euo pipefail

repo=${APHELION_REPO:-aphelion-labs/aphelion}
max_runs=${APHELION_MAX_RUNS:-2}
dry_run=0
mode=dispatch
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=1 ;;
    --reconcile) mode=reconcile ;;
    -h|--help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
    *) echo "pickup: unknown argument $arg" >&2; exit 2 ;;
  esac
done

for tool in git gh jq; do
  command -v "$tool" >/dev/null || { echo "pickup: $tool not found" >&2; exit 1; }
done

# Work from the main checkout of the clone this script lives in, so a systemd
# timer or a call from inside a worktree behaves the same.
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
common_dir=$(git -C "$script_dir" rev-parse --path-format=absolute --git-common-dir)
root=$(dirname "$common_dir")
state_dir="$common_dir/aphelion"
mkdir -p "$state_dir/runs"
cd "$root"

log() { printf 'pickup: %s\n' "$*"; }

# True if the state file records a run whose process is still alive. The
# command line check guards against a reused pid after a reboot.
run_alive() {
  local file=$1 pid
  [ -f "$file" ] || return 1
  [ "$(jq -r '.status // ""' "$file")" = running ] || return 1
  pid=$(jq -r '.pid // ""' "$file")
  [ -n "$pid" ] && [ -r "/proc/$pid/cmdline" ] || return 1
  tr '\0' ' ' <"/proc/$pid/cmdline" | grep -q 'pickup-run\.sh'
}

# A state file that says running but whose process is gone: the run died
# without recording a result (crash, reboot). Mark it and hand the issue to
# the owner, never retrying on its own (Blueprint, "Failure").
reap_dead_runs() {
  local file issue tmp
  for file in "$state_dir"/*.json; do
    [ -e "$file" ] || continue
    [ "$(jq -r '.status // ""' "$file")" = running ] || continue
    run_alive "$file" && continue
    issue=$(jq -r .issue "$file")
    log "#$issue: run $(jq -r .run_id "$file") died without a result; labelling blocked"
    [ "$dry_run" -eq 1 ] && continue
    tmp=$(mktemp "$file.XXXXXX")
    jq '.status = "died"' "$file" >"$tmp" && mv "$tmp" "$file"
    gh issue edit "$issue" --repo "$repo" --add-label status:blocked --remove-label status:in-progress >/dev/null
    gh issue comment "$issue" --repo "$repo" --body \
      "Run $(jq -r .run_id "$file") on $(hostname) ended without recording a result. Worktree left at $(jq -r .worktree "$file") for inspection." >/dev/null
  done
}

count_running() {
  local file n=0
  for file in "$state_dir"/*.json; do
    run_alive "$file" && n=$((n + 1))
  done
  echo "$n"
}

# Open issues (not PRs) with a label, oldest first. Open decision: dispatch
# order; oldest first is a placeholder. --paginate reads every page, so no
# result cap is needed.
issues_with_label() {
  gh api --paginate "repos/$repo/issues?state=open&labels=$1&sort=created&direction=asc" \
    --jq '.[] | select(.pull_request == null) | [.number, ([.labels[].name] | join(","))] | @tsv'
}

new_run_id() {
  if command -v uuidgen >/dev/null; then uuidgen; else cat /proc/sys/kernel/random/uuid; fi
}

# Starts one run: label in-progress, comment, launch pickup-run.sh detached.
start_run() {
  local run_mode=$1 issue=$2 from_label=$3 run_id log_file
  run_id=$(new_run_id)
  log "#$issue: starting $run_mode run $run_id"
  [ "$dry_run" -eq 1 ] && return 0
  gh issue edit "$issue" --repo "$repo" --add-label status:in-progress --remove-label "$from_label" >/dev/null
  gh issue comment "$issue" --repo "$repo" --body \
    "${run_mode^^} run started on \`$(hostname)\`, run id \`$run_id\`." >/dev/null
  log_file="$state_dir/runs/$issue-$run_id.log"
  # Detached, so the run outlives this tick and the terminal or timer that
  # started it. pickup-run.sh records its own pid in the state file at once.
  APHELION_RUN_ID=$run_id APHELION_REPO=$repo \
    setsid nohup "$script_dir/pickup-run.sh" "$run_mode" "$issue" >"$log_file" 2>&1 </dev/null &
}

# Worktrees for an issue, matched by the <issue>- prefix of the directory.
worktrees_for() {
  local issue=$1 dir
  for dir in "$root/.worktrees/$issue"-*; do
    [ -d "$dir" ] && echo "$dir"
  done
  return 0
}

dispatch() {
  local running label run_mode issue labels file wts list
  reap_dead_runs
  running=$(count_running)
  log "$running of $max_runs runs active"
  for label in status:needs-spec status:ready; do
    if [ "$label" = status:needs-spec ]; then run_mode=propose; else run_mode=apply; fi
    # Captured first, so a failed listing stops the tick under set -e.
    list=$(issues_with_label "$label")
    while IFS=$'\t' read -r issue labels; do
      [ -n "$issue" ] || continue
      if [ "$running" -ge "$max_runs" ]; then
        log "concurrency cap $max_runs reached; stopping this tick"
        return 0
      fi
      case ",$labels," in
        *,status:in-progress,*) log "#$issue: already in progress; skipped"; continue ;;
        *,status:blocked,*) log "#$issue: blocked; skipped"; continue ;;
      esac
      file="$state_dir/$issue.json"
      if run_alive "$file"; then
        log "#$issue: a run is alive; skipped"
        continue
      fi
      wts=$(worktrees_for "$issue")
      if [ -n "$wts" ]; then
        # The only worktree a run may reuse is the one a successful PROPOSE
        # left for the APPLY of the same issue (one issue, one branch, one PR).
        if [ "$run_mode" = apply ] && [ -f "$file" ] \
          && [ "$(jq -r '.mode + ":" + .status' "$file")" = "propose:succeeded" ]; then
          :
        else
          log "#$issue: worktree exists ($wts); skipped"
          continue
        fi
      fi
      start_run "$run_mode" "$issue" "$label"
      running=$((running + 1))
    done <<<"$list"
  done
}

reconcile() {
  local wt branch prs open_count done_pr done_state pr_number local_oid issue tmp
  while IFS=$'\t' read -r wt branch; do
    case "$wt" in "$root/.worktrees/"*) ;; *) continue ;; esac
    [ -n "$branch" ] || { log "$wt: detached HEAD; left alone"; continue; }
    prs=$(gh pr list --repo "$repo" --head "$branch" --state all --json number,state)
    open_count=$(jq '[.[] | select(.state == "OPEN")] | length' <<<"$prs")
    done_pr=$(jq -c 'first(.[] | select(.state == "MERGED" or .state == "CLOSED")) // empty' <<<"$prs")
    if [ "$open_count" -gt 0 ] || [ -z "$done_pr" ]; then
      continue
    fi
    done_state=$(jq -r '.state | ascii_downcase' <<<"$done_pr")
    pr_number=$(jq -r .number <<<"$done_pr")
    # Never drop commits GitHub does not have: the local tip must be part of
    # the PR's final head. The responder may have pushed after it, so equal is
    # not required; refs/pull/<n>/head survives branch deletion.
    local_oid=$(git rev-parse "refs/heads/$branch")
    git fetch --quiet origin "refs/pull/$pr_number/head"
    if ! git merge-base --is-ancestor "$local_oid" FETCH_HEAD; then
      log "$branch: PR #$pr_number $done_state but local commits are not on GitHub; left alone"
      continue
    fi
    log "$branch: PR #$pr_number $done_state; removing worktree and branch"
    [ "$dry_run" -eq 1 ] && continue
    # No --force: a worktree with uncommitted changes stays for the owner.
    if ! git worktree remove "$wt"; then
      log "$wt: has uncommitted changes; left alone"
      continue
    fi
    # -D because a squash merge leaves the branch unmerged in git's terms.
    git branch -D "$branch" >/dev/null
    issue=${branch%%-*}
    if [ -f "$state_dir/$issue.json" ]; then
      tmp=$(mktemp "$state_dir/$issue.json.XXXXXX")
      jq --arg s "$done_state" '.status = $s' "$state_dir/$issue.json" >"$tmp"
      mv "$tmp" "$state_dir/$issue.json"
    fi
  done < <(git worktree list --porcelain | awk '
    function flush() { if (path != "") printf "%s\t%s\n", path, branch }
    /^worktree / { flush(); path = $0; sub(/^worktree /, "", path); branch = "" }
    /^branch refs\/heads\// { branch = $0; sub(/^branch refs\/heads\//, "", branch) }
    END { flush() }')
}

if [ "$mode" = reconcile ]; then reconcile; else dispatch; fi
