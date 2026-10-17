# aphelion: instructions for agents

aphelion is a shared workspace for teams of coding agents: a per-machine daemon, a hub, a Bubble Tea TUI, MCP tools and a knowledge graph.
It is written in Go and ships as one static binary (ADR 0002); the hub API is agent-neutral, Claude Code first (ADR 0009).
Status: pre-alpha, nothing runs yet. docs/product/overview.md explains the product.

## Where truth lives

- What the product does: the living specs, `openspec/specs/<capability>/spec.md` (see openspec/README.md).
- What to do now: the GitHub issue you were given.
- Why things are as they are: the ADRs in `docs/decisions/`. Read the ones your work touches before you design anything.

## Rules

1. Never edit `openspec/specs/**` directly. Behaviour changes go in a change folder `openspec/changes/<issue>-<slug>/`, and `openspec archive` runs inside the same PR (ADR 0004). Hooks deny direct edits, and CI fails a PR that changes living specs without an archived change.
2. No unexplained constants. Every limit, timeout, size, threshold or default cites a spec requirement or an ADR next to it. If neither covers it, ask the owner and label it "Open decision" until answered (ADR 0001). golangci-lint's `mnd` linter fails on unnamed number literals.
3. Every non-obvious decision gets an ADR in `docs/decisions/` (MADR, status `proposed`; only the owner sets `accepted`).
4. Files over 1,500 lines fail CI (`scripts/check-file-length.sh`; ADR 0012, open to revision).
5. Commits: Conventional Commits prefix (feat, fix, docs, chore, refactor, test, perf, ci, build, deps; optional scope; `!` for breaking), subject lowercase and terse with no trailing period, no body unless needed. NEVER add Claude-Session, Co-Authored-By or Signed-off-by lines; the commit-msg hook rejects them.
6. One PR per ticket, squash merge; the owner merges. Branch name `<issue>-<slug>`, for example `12-show-blocked-reason`. The PR title becomes the squash commit, so it follows rule 5.
7. Push early and often; the overlap view sees only pushed branches. The pre-push hook refuses only when main changed the same files as your branch. Then: `git fetch origin && git rebase origin/main`, resolve, re-test, `git push --force-with-lease`. Never `--no-verify`, `--force` or a push to main; hooks deny them.
8. Run `make check` before pushing.
9. Workflow skills come from the `aphelion-sdlc` plugin in the aphelion-skills marketplace: `/issue-propose` (creates the change folder), `/issue-finish`, `/file-bug`, `/triage`. Their full names carry the plugin prefix, for example `/aphelion-sdlc:issue-propose`.
10. When blocked, add the label `status:blocked` to the issue with a comment that says what is missing, then stop. Never guess.
11. Write file content with the Edit and Write tools, not shell heredocs: the Bash guard reads the whole command text and denies text that looks like a hook bypass.

## Commands

- `scripts/setup-hooks.sh` once per clone (sets `core.hooksPath` to `.githooks`).
- `make build`, `make test`, `make lint`, `make fmt`, `make check`.
