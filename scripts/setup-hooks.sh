#!/usr/bin/env bash
# Points git at the versioned hooks in .githooks/ (ADR 0005) and makes them
# executable. Run once per clone; worktrees of the clone share the setting.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"

git config core.hooksPath .githooks
chmod +x .githooks/*

echo "setup-hooks: core.hooksPath = $(git config core.hooksPath) in $root"
for h in .githooks/*; do
  echo "setup-hooks: executable $h"
done
