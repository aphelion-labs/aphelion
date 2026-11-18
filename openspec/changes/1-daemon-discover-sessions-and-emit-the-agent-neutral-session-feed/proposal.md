Issue: #1

# Proposal

## Why

Nobody can see what every coding-agent session on a machine is doing, or which one is waiting on a human. The daemon is the data source for the hub, the TUI and the MCP tools, and it is useful alone on one machine before a hub exists (ADR 0009). PoC 01 showed that every Claude Code session can be observed from files Claude Code already writes plus hooks, with every state backed by a fact (ADR 0008). This change turns that PoC into the first shipped capability.

## What Changes

- New subcommand `aphelion daemon`. It runs until interrupted and writes the `aphelion.session.v0` NDJSON feed to stdout: one `snapshot` line per listed session, then one line per meaningful change. Sending the feed to a hub is out of scope (the `hub-store-ingest` ticket).
- Session discovery for Claude Code from the session registry (`~/.claude/sessions/<pid>.json`; `*.key` files never opened; liveness checked against `procStart`), transcripts (`~/.claude/projects/<slug>/<sessionId>.jsonl`, read whole once and then only appended bytes) and the subagent transcript count (ADR 0008). Interactive, `claude -p` and background sessions all appear.
- A hook receiver inside the daemon for Claude Code `http` hooks. It never returns a decision and stores only time, event, session id, tool name and notification type.
- Session state from the ADR 0008 rules, first match wins, with the clearing hooks. Every state carries `status_facts`. There are no timeouts and no text heuristics; the only elapsed-time rule is how long exited sessions stay listed.
- The feed fields of ADR 0009, with agent-specific data only under `raw`, UTC machine-readable times, and an event only when a meaningful field changes.
- All Claude Code specifics in one adapter behind an agent-neutral source contract, plus golden NDJSON fixtures that hub and TUI tests consume unchanged (ADR 0009).
- Code ported from PoC 01 (`~/DEV/aphelion-poc/01-session-board/`); the PoC TUI is out of scope (`tui-executive-view`).
- Two draft ADRs (status `proposed`): 0013, the daemon's package layout and adapter boundary; 0014, the hook receiver running inside the daemon process.

Every value the issue lists as an open decision (rescan interval, exited retention, coalescing window, hook receiver address and authentication, hook log location and pruning, excerpt caps, non-Linux liveness and the rest) appears in the spec and design as "Open decision" and is not chosen here (ADR 0001). design.md lists them; the owner answers each one before the implementation uses its value.

## Capabilities

### New Capabilities

- `daemon`: the per-machine process that observes local agent sessions through one adapter per agent and emits the agent-neutral session feed (ADR 0008, ADR 0009). This change adds its first requirements: the `aphelion daemon` command, Claude Code session discovery, the hook receiver, the state rules and the feed contract.

### Modified Capabilities

None. No living spec exists yet.

## Impact

- Code: `cmd/aphelion` gains subcommand dispatch and the `daemon` subcommand. New packages under `internal/` for the agent-neutral session model, the feed, the daemon loop and the Claude Code adapter (layout in design.md and draft ADR 0013).
- Dependencies: `github.com/fsnotify/fsnotify` for file events, pure Go so the static `CGO_ENABLED=0` build holds (ADR 0002). PoC 01 pinned v1.10.1.
- Files read: `~/.claude/sessions/*.json`, `~/.claude/projects/**`. Nothing under `~/.claude` is written. The only file the daemon writes is its own hook log.
- Network: one local HTTP listener for hooks; its address, port and authentication are open decisions.
- Test data: recorded registry files, transcripts and hook logs, plus golden NDJSON fixtures committed for later hub and TUI tests.
- Platform: liveness uses Linux `/proc`, as in PoC 01. Other OSes are an open decision (ADR 0002's OS matrix).
- Out of scope: sending the feed to a hub, installing hooks into Claude Code settings, the TUI, and any other agent's adapter.
