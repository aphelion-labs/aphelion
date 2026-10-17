# openspec

aphelion's specs, managed with [OpenSpec](https://github.com/Fission-AI/OpenSpec) (ADR 0004). A spec says what the product does, per capability, in the present tense. A ticket (a GitHub issue) is a unit of work. The issue number ties them together.

## Layout

- `specs/<capability>/spec.md`: the living spec for one capability, with SHALL requirements and WHEN/THEN scenarios. On main it always describes main's code.
- `changes/<issue>-<slug>/`: one change folder per issue that changes behaviour, for example `changes/12-show-blocked-reason/`. It holds `proposal.md` (first line `Issue: #<issue>`), `tasks.md`, and delta specs under `specs/<capability>/spec.md` with ADDED, MODIFIED or REMOVED requirements. A MODIFIED requirement carries the full replacement text with every scenario; partial text drops scenarios.
- `changes/archive/`: archived changes. `openspec archive` merges the deltas into the living specs and moves the folder here with a date prefix, so the issue number is no longer the first part of the name.
- `config.yaml`: project context that OpenSpec hands to agents when they write a proposal, tasks or a delta.

## Rules

- Nobody edits `specs/` by hand. The change folder is archived inside the same PR as the code, so the delta and the merged spec are reviewed in one diff. Claude Code hooks deny agent edits to `specs/`, and CI fails a PR that changes `specs/` without adding an archived change (`scripts/check-specs.sh`).
- CI runs `openspec validate --all --strict` (`make validate-specs`).
- Which tickets need a change folder (ADR 0004):

| Ticket kind | Change folder | Living spec |
|---|---|---|
| Feature | yes | updated by archive in the same PR |
| Bug, code wrong | no; the issue cites the violated requirement | untouched |
| Bug, spec wrong or silent | yes, with a MODIFIED or REMOVED delta | updated by archive |
| Chore | no | untouched |

- OpenSpec is pinned to 1.14.2 wherever it runs (`OPENSPEC_VERSION` in the Makefile). An upgrade is its own PR, made after reading the release notes.
- Telemetry is off: `OPENSPEC_TELEMETRY=0` is set by the Makefile and by `.claude/settings.json` for agent sessions.
- `archive --yes` archives even when tasks are unticked (05 PoC), so tick `tasks.md` before archiving.

## Commands

```sh
export OPENSPEC_TELEMETRY=0
npx -y @fission-ai/openspec@1.14.2 new change 12-show-blocked-reason --goal "Issue: #12"
npx -y @fission-ai/openspec@1.14.2 validate 12-show-blocked-reason --strict
npx -y @fission-ai/openspec@1.14.2 archive 12-show-blocked-reason --yes
```

OpenSpec 1.14.2 needs Node 20.19.0 or later (its package `engines` field).

## Capabilities

No living spec exists yet; each is created by the first change folder that touches its capability. The scope notes below are a first reading of the ADRs, not decisions; the owner confirms them as the specs arrive.

| Capability | Scope |
|---|---|
| hub | the shared service that collects session events from every daemon and serves the views (ADR 0009) |
| daemon | the per-machine process that observes local agent sessions through adapters (ADR 0008, ADR 0009) |
| mcp | the MCP tools an agent uses to ask the hub about the team and to read and write knowledge (ADR 0006, ADR 0007) |
| hooks | the Claude Code hooks aphelion installs to observe session state and deliver team facts (ADR 0006, ADR 0008) |
| overlap | files touched by more than one pushed branch, and the pre-push refusal (ADR 0005) |
| messaging | asking another session a question without interrupting it (ADR 0007) |
| knowledge | the knowledge graph and its retrieval (ADR 0006) |
| tickets | the read-only view of GitHub issues and PRs (ADR 0004, ADR 0007) |
| tui | the agents-first terminal UI and its tmux integration (ADR 0007) |
| cli | the `aphelion` command line (ADR 0002) |
| install | installing aphelion and its hooks on a machine (ADR 0002, ADR 0008) |
