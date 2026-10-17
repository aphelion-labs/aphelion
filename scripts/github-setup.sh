#!/usr/bin/env bash
# Applies aphelion's GitHub configuration: labels, repository merge settings
# and rulesets (Blueprint, "Main branch rules"; ADR 0005, 0010, 0011).
# Idempotent: labels are created or updated with --force, rulesets are created
# or replaced by name, and repository settings are absolute values.
#
# usage: scripts/github-setup.sh [--dry-run] [--only=labels|settings|rulesets] [owner/repo]
#   default repo: aphelion-labs/aphelion (ADR 0012).
#   --dry-run prints every call that would change GitHub without making it.
#   Read-only lookups (the owner's user id, existing ruleset ids) still run,
#   so the printed calls are the ones a real run would make.
#
# Needs: gh authenticated as a repository admin, and jq.
set -euo pipefail

dry_run=0
only=all
repo=aphelion-labs/aphelion
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=1 ;;
    # --only labels|settings|rulesets runs one step. Rulesets require pull
    # requests, so they must come after the first push of main.
    --only=labels|--only=settings|--only=rulesets) only=${arg#--only=} ;;
    -h|--help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0 ;;
    -*) echo "github-setup: unknown option $arg" >&2; exit 2 ;;
    *) repo=$arg ;;
  esac
done

# True when the named step should run under --only.
wants() { [ "$only" = all ] || [ "$only" = "$1" ]; }

# The product owner, the only merger (ADR 0010).
owner_login=arnav-exe

# Required status checks on main: the job ids in .github/workflows/ci.yml plus
# the PR-title lint (Blueprint: "A PR-title lint is a required check so every
# squash commit parses"). Rename a job there and here together.
required_checks=(go lint shell specs file-length secrets pr-title)

for tool in gh jq; do
  command -v "$tool" >/dev/null || { echo "github-setup: $tool not found" >&2; exit 1; }
done

step() { printf '\n== %s\n' "$*"; }

# Runs a command that changes GitHub, or only prints it under --dry-run.
mutate() {
  printf '+ %s\n' "$*"
  [ "$dry_run" -eq 1 ] || "$@" >/dev/null
}

# Sends a JSON body to the REST API: api_json METHOD PATH BODY.
api_json() {
  printf '+ gh api -X %s %s --input - <<JSON\n%s\nJSON\n' "$1" "$2" "$3"
  [ "$dry_run" -eq 1 ] || printf '%s' "$3" | gh api -X "$1" "$2" --input - >/dev/null
}

# ---------------------------------------------------------------------------
if wants labels; then
step "labels on $repo"
# Taxonomy: Blueprint "Label taxonomy" and the 2026-10-17 brief. Colours are
# one per family so families read apart; they are cosmetic placeholders, an
# open decision.
c_type=1D76DB c_status=FBCA04 c_cap=5319E7 c_area=0E8A16 c_size=C5DEF5
c_review=D93F0B c_bot=BFDADC c_origin=F9D0C4 c_safe=006B75

label() { mutate gh label create "$1" --repo "$repo" --force --color "$2" --description "$3"; }

label type:feat "$c_type" "New or changed behaviour (Conventional Commit feat)"
label type:fix "$c_type" "Bug fix (Conventional Commit fix)"
label type:refactor "$c_type" "Code change with no behaviour change"
label type:docs "$c_type" "Documentation only"
label type:test "$c_type" "Tests only"
label type:chore "$c_type" "Maintenance, tooling, no behaviour change"
label type:deps "$c_type" "Dependency update"
label type:ci "$c_type" "CI and workflow change"
label type:perf "$c_type" "Performance improvement"

label status:needs-triage "$c_status" "New; the owner has not reviewed it yet"
label status:needs-spec "$c_status" "Approved; the driver starts a propose run"
label status:spec-review "$c_status" "Proposal and draft PR await the owner's approval"
label status:ready "$c_status" "Approved; the driver starts an apply run"
label status:in-progress "$c_status" "An agent run is working on it"
label status:in-review "$c_status" "PR ready; bot and responder rounds happen here"
label status:blocked "$c_status" "A run failed or stalled; needs the owner"

for cap in hub daemon mcp hooks overlap messaging knowledge tickets tui cli install; do
  label "cap:$cap" "$c_cap" "Capability: $cap"
done

label area:ci "$c_area" "Touches .github/"
label area:docs "$c_area" "Touches docs/"
label area:specs "$c_area" "Touches openspec/"
label area:deps "$c_area" "Touches go.mod or go.sum"

# Size thresholds (lines changed, lockfiles excluded) are an open decision.
for size in xs s m l xl; do
  label "size:$size" "$c_size" "Size $size by lines changed; thresholds are an open decision"
done

label review:security "$c_review" "Force the security-and-trust-boundaries persona (ADR 0011)"
label review:supply-chain "$c_review" "Force the dependencies-and-supply-chain persona (ADR 0011)"
label review:exhausted "$c_review" "Automated review rounds used up; the owner takes over"
label bot:skip "$c_bot" "The reviewer bot skips this PR"
label origin:agent "$c_origin" "Filed by an agent; always lands in needs-triage"
label safe-to-review "$c_safe" "Owner attests a fork PR is safe for the bot to review"
fi

# ---------------------------------------------------------------------------
if wants settings; then
step "repository settings"
# Squash merge only and delete head branches on merge (ADR 0010); auto-merge
# off, so the owner presses merge every time (ADR 0010: the owner is the only
# merger).
mutate gh repo edit "$repo" \
  --enable-squash-merge \
  --enable-merge-commit=false \
  --enable-rebase-merge=false \
  --delete-branch-on-merge \
  --enable-auto-merge=false
# The squash commit is the PR title with an empty body, so the title lint
# covers the whole commit message (ADR 0010).
mutate gh api -X PATCH "repos/$repo" \
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=BLANK
fi

# ---------------------------------------------------------------------------
if wants rulesets; then
step "rulesets"
owner_id=$(gh api "users/$owner_login" --jq .id)
# GitHub Actions' app id, so required checks must come from Actions (Blueprint:
# "with Actions as the expected source"). Looked up, not hard-coded.
actions_app_id=$(gh api apps/github-actions --jq .id)

# Creates the named repository ruleset, or replaces it if it exists.
put_ruleset() {
  local name=$1 body=$2 id
  id=$(gh api "repos/$repo/rulesets" \
    --jq ".[] | select(.source_type == \"Repository\" and .name == \"$name\") | .id")
  if [ -n "$id" ]; then
    api_json PUT "repos/$repo/rulesets/$id" "$body"
  else
    api_json POST "repos/$repo/rulesets" "$body"
  fi
}

checks_json=$(printf '%s\n' "${required_checks[@]}" \
  | jq -R --argjson app "$actions_app_id" '{context: ., integration_id: $app}' | jq -s .)

main_ruleset=$(jq -n \
  --argjson owner "$owner_id" \
  --argjson checks "$checks_json" '{
  name: "main",
  target: "branch",
  enforcement: "active",
  conditions: {ref_name: {include: ["~DEFAULT_BRANCH"], exclude: []}},
  # Bypass list is the owner only, and only by merging a PR (Blueprint: "bypass
  # list is you only"; "require a PR"). Covers PRs whose checks never run, such
  # as a release PR opened with GITHUB_TOKEN.
  bypass_actors: [{actor_id: $owner, actor_type: "User", bypass_mode: "pull_request"}],
  rules: [
    {type: "deletion"},
    {type: "non_fast_forward"},
    {type: "required_linear_history"},
    {type: "pull_request", parameters: {
      # No required approvals: agent PRs are opened under the owner account,
      # which cannot approve its own PR, and the bot never approves (ADR 0011).
      required_approving_review_count: 0,
      dismiss_stale_reviews_on_push: true,
      # CODEOWNERS routes reviews but is not enforced until agents have their
      # own identity (Blueprint, "CODEOWNERS").
      require_code_owner_review: false,
      # Follows from zero required approvals.
      require_last_push_approval: false,
      # Open decision: bot threads are answered per the owner merge checklist,
      # not enforced here.
      required_review_thread_resolution: false,
      # Squash merge only (ADR 0010).
      allowed_merge_methods: ["squash"]
    }},
    {type: "required_status_checks", parameters: {
      # Up-to-date branches not required, so merges do not force rebases
      # (ADR 0005 open decision; the research advised off at first).
      strict_required_status_checks_policy: false,
      required_status_checks: $checks
    }}
  ]
}')
put_ruleset main "$main_ruleset"

# Release tags v* cannot be deleted or moved once created (Blueprint: "Tags
# matching v* are protected").
tags_ruleset=$(jq -n '{
  name: "tags",
  target: "tag",
  enforcement: "active",
  conditions: {ref_name: {include: ["refs/tags/v*"], exclude: []}},
  rules: [
    {type: "deletion"},
    {type: "update", parameters: {update_allows_fetch_and_merge: false}}
  ]
}')
put_ruleset tags "$tags_ruleset"
fi

if [ "$dry_run" -eq 1 ]; then
  printf '\ngithub-setup: dry run, nothing changed\n'
else
  printf '\ngithub-setup: done\n'
fi
