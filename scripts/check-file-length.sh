#!/usr/bin/env bash
# Fails if any Go, shell, YAML or Markdown file in the repository is longer than
# MAX_LINES. Checks tracked files plus untracked files that git does not ignore,
# so it gives the same answer before and after a commit.
set -euo pipefail

# ADR 0012: files over 1,500 lines are flagged (the lecture calls the figure
# "just a suggestion"). Open to revision; whether this warns or fails is an open
# decision in ADR 0012, and it fails for now on the owner's instruction.
MAX_LINES=1500

cd "$(git rev-parse --show-toplevel)"

fail=0
while IFS= read -r -d '' f; do
  [ -f "$f" ] || continue
  # awk counts a last line that has no trailing newline; wc -l does not.
  n=$(awk 'END { print NR }' "$f")
  if [ "$n" -gt "$MAX_LINES" ]; then
    echo "check-file-length: $f has $n lines (limit $MAX_LINES, ADR 0012)" >&2
    fail=1
  fi
done < <(git ls-files -z --cached --others --exclude-standard -- \
  '*.go' '*.sh' '*.bash' '*.yml' '*.yaml' '*.md' '.githooks/*')

if [ "$fail" -ne 0 ]; then
  echo "check-file-length: split the files above into smaller ones" >&2
  exit 1
fi
echo "check-file-length: ok (limit $MAX_LINES lines)"
