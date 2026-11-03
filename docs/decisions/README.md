# Architecture decision records

This folder records aphelion's architecture decisions, one decision per file, in MADR format (`NNNN-kebab-title.md`). Each record gives the context, the options considered and rejected, the outcome and its reasons, the consequences, how we confirm the decision is followed, and the evidence with the date it was checked. Details that are still undecided are written as "Open decision: ..." rather than chosen.

| No. | Title | Status |
|---|---|---|
| [0001](0001-record-decisions-as-adrs-and-forbid-unexplained-constants.md) | Record decisions as ADRs and forbid unexplained constants | proposed |
| [0002](0002-go-with-charm-v2-single-static-binary.md) | Implementation language Go with Charm v2, single static binary | proposed |
| [0003](0003-license-apache-2-0.md) | License Apache-2.0, copyright held by the product owner | proposed |
| [0004](0004-specs-as-openspec-in-repo-tickets-as-github-issues.md) | Specs live in the repository as OpenSpec markdown; tickets are GitHub Issues | proposed |
| [0005](0005-no-locks-refuse-and-rebase-pre-push-and-overlap-visibility.md) | No file locks or claims; refuse-and-rebase pre-push hook plus overlap visibility | proposed |
| [0006](0006-knowledge-base-property-graph-in-sqlite.md) | Knowledge base is a property graph in SQLite with hybrid retrieval and agent-authored links | proposed |
| [0007](0007-tui-hybrid-workplace-with-tmux.md) | TUI is a hybrid workplace with tmux as a v1 dependency | proposed |
| [0008](0008-session-state-observed-never-inferred.md) | Session state is observed, never inferred | proposed |
| [0009](0009-agent-neutral-hub-api.md) | Hub API is agent-neutral; Claude Code adapter first, opencode second | proposed |
| [0010](0010-agent-loop-and-fresh-review-responder.md) | Agent loop: local worktree pickup, one PR per ticket, fresh review responder on GitHub-hosted runners | proposed |
| [0011](0011-pr-reviewer-bot.md) | PR reviewer bot in its own repository on the Anthropic API | proposed |
| [0012](0012-repository-layout-and-shift-left-checks.md) | Repository layout and shift-left checks | proposed |
| [0013](0013-daemon-package-layout-and-adapter-boundary.md) | Daemon package layout: agent-neutral core, one adapter package per agent | proposed |
| [0014](0014-hook-receiver-runs-inside-the-daemon.md) | The hook receiver runs inside the daemon and keeps a hook log on disk | proposed |

## Process

Every design choice that brings a constant or a non-obvious default into aphelion is, before it is built, either traced to a spec requirement, recorded here as an ADR, or asked of the product owner first; until the owner answers, it is written down as "Open decision" and never presented as design (ADR 0001). In Go, golangci-lint's `mnd` linter enforces "no unexplained constants" by failing on unnamed number literals, and each named constant cites the spec requirement, ADR or open decision it comes from. Every subagent brief forbids unexplained constants and requires the subagent to list the decisions it made in its report. New ADRs are written with status `proposed`; the product owner changes the status to `accepted`, and a decision that changes gets a new ADR that supersedes the old one.

Note: the product is named aphelion; the GitHub organisation is aphelion-labs. These records use those names throughout.
