#!/usr/bin/env bash
# Living specs under openspec/specs/ may change only in a range that also adds an
# archived change under openspec/changes/archive/ (ADR 0004). Adapted from the 05 PoC.
#
# usage: scripts/check-specs.sh [base-ref] [head-ref]
#   defaults: origin/main and HEAD. CI passes the PR's base and head; the range is
#   base...head (from the merge base), so the clone needs enough history for
#   git merge-base (actions/checkout with fetch-depth: 0).
#
# Limit (from the 05 PoC): any added file under changes/archive/ counts as proof;
# the script does not check that the archive matches the spec diff.
set -euo pipefail

base="${1:-origin/main}"
head="${2:-HEAD}"

for ref in "$base" "$head"; do
  if ! git rev-parse --verify --quiet "$ref^{commit}" >/dev/null; then
    echo "check-specs: unknown ref '$ref'" >&2
    exit 1
  fi
done
if ! git merge-base "$base" "$head" >/dev/null; then
  echo "check-specs: no merge base between $base and $head (shallow clone?)" >&2
  exit 1
fi

specs=$(git diff --name-only "$base...$head" -- 'openspec/specs/' | grep -v '\.gitkeep$' || true)
archived=$(git diff --name-only --diff-filter=A "$base...$head" -- 'openspec/changes/archive/' | grep -v '\.gitkeep$' || true)

if [ -z "$specs" ]; then
  echo "check-specs: pass, no living spec changes in $base...$head"
  exit 0
fi
if [ -n "$archived" ]; then
  echo "check-specs: pass, living specs changed together with an archived change"
  printf '%s\n' "$specs" | sed 's/^/  spec:    /'
  printf '%s\n' "$archived" | sed 's/^/  archive: /'
  exit 0
fi
echo "check-specs: fail, living specs changed without an archived change in $base...$head:" >&2
printf '%s\n' "$specs" | sed 's/^/  /' >&2
echo "Living specs are updated only by 'openspec archive <change>'." >&2
echo "Create openspec/changes/<issue>-<slug>/ with delta specs (/aphelion-sdlc:issue-propose), then archive it in this PR." >&2
exit 1
