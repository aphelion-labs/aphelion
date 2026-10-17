# aphelion product overview

This page explains aphelion to someone new to the project. Every statement here comes from an architecture decision record in [docs/decisions/](../decisions/README.md); the ADR numbers in brackets say which one. aphelion is pre-alpha and nothing runs yet, so this describes what is being built, not what exists.

## Purpose

When several people each run several coding agents on one project, nobody sees the whole team. Which session is working on what? Which one is stuck waiting for a human? Which branches are changing the same files? What did another session decide yesterday? Claude Code's own cross-session messaging reaches only your own sessions, and reaches other machines only through Remote Control on the same account [0009]. Its memory stays on one machine [0006]. aphelion fills that gap: a shared workspace where people and agents see the team's state and share what they learn.

## Who it is for

Teams whose members sit at separate computers, each with their own agent plan, working on one repository. Later the same team may include other agents such as opencode, or fully autonomous agents with no human in the loop [0009]. The first team using it works spec-first: specs in the repository, tickets as GitHub issues, one agent per ticket in its own worktree [0004, 0010].

## What it does

**Shows every session.** One row per agent session, across people and machines, with its status, ticket, branch, current activity and an overlap count. A detail pane shows the session's full history [0007]. Status is observed, never inferred: working, waiting: question, waiting: permission, idle, idle 60s+ and exited. Each state carries the facts that produced it, so a "waiting: question" can be trusted enough to act on. The 60 seconds belong to Claude Code, which reports an idle prompt after that long [0008]. The overlap count comes from the hub, which lists the files touched by more than one pushed branch [0005].

**Asks a session a question without interrupting it.** From the detail pane you can put a question to another session. The answer comes from a fork of that session, so the session itself keeps working [0007].

**Shares knowledge.** Agents write notes and decisions into a knowledge graph as they work, linked to the files, issues, pull requests and sessions they concern. Every entry records who wrote it and when it held. Nothing is deleted: a newer fact supersedes an older one, and contradictions stay visible. Search combines full-text, vector and graph retrieval, and hooks bring the relevant entries into a session, for example when an agent opens a file that a past decision covers [0006].

**Puts issues and pull requests beside the agents.** A read-only panel shows the project's GitHub issues and pull requests next to the sessions working on them. GitHub Issues stays the ticket system [0004, 0007].

## How you use it: a TUI beside tmux

The terminal UI is a workplace you use while doing your own work, not a window you tab to now and then [0007]. It leans on tmux for everything tmux already does:

- The board lists agents first, with issues and pull requests alongside. Navigation is vim-style.
- Jump: press enter on one of your own sessions and tmux switches to its pane.
- Launch: start a ticket and a new tmux window opens running `claude` in that ticket's worktree.
- Popup: a tmux key binding opens the board over whatever you are doing, and one key closes it.
- Status line: a segment in every Claude Code session shows the team's state.
- In-session tools: a skill and an MCP tool let your own agent ask the hub what the team is doing.

Without tmux you can still launch a session; the TUI pauses while it runs in the foreground. Jump and popup need tmux, so tmux is a v1 dependency [0007].

## The parts

- A daemon on each machine observes local agent sessions through one adapter per agent. For Claude Code the adapter reads the session registry, the transcript and aphelion's hooks. It sends events in aphelion's own agent-neutral format, so the hub and the TUI never parse agent internals [0008, 0009]. A daemon is useful on its own machine before any hub exists.
- The hub collects events from every daemon, computes the overlap view and owns the knowledge base, a SQLite database [0005, 0006, 0009].
- The TUI, the MCP tools and the command line are clients of the hub.
- All of it ships as one static Go binary with no runtime to install [0002].

## Where it runs

1. Same machine. One developer runs several sessions; the daemon and the hub run side by side.
2. Local network. A team runs one self-hosted hub, and each teammate's daemon connects to it.
3. Different networks. Collaboration across networks is a roadmap item, not a day-one need; the client compared it to Visual Studio Code's remote development. Until it exists, a remote team reaches its self-hosted hub through its own VPN or SSH. Tailscale's free plan is for non-commercial use only, so it is not the default path [0009].

How daemons connect to the hub, and how they authenticate, is still an open decision [0009].

## What it deliberately is not

- Not a terminal multiplexer. aphelion hosts no terminals and manages no panes or scrollback; tmux does that [0007].
- Not a ticket system. GitHub Issues holds the tickets, and nothing in the TUI writes to them [0004, 0007].
- No file locks or claims. Each agent works on its own branch in its own worktree. A pre-push hook refuses a push only when main changed the same files since the branch began, and the agent rebases. No agent ever picks a lease duration [0005].
- No Kafka or other message broker. A broker is an extra service to run for a few messages a minute, against the single-binary goal [0009].
- No language model inside the knowledge base in v1. Agents write the links themselves; extraction is added only if measurement shows it helps [0006].
- Not tied to one agent. Claude Code is supported first and opencode second, through the same agent-neutral events [0009].

## Read next

- [docs/decisions/](../decisions/README.md) for every decision and the alternatives rejected.
- [openspec/README.md](../../openspec/README.md) for how specs and tickets fit together.
- [CLAUDE.md](../../CLAUDE.md) for the rules agents follow in this repository.
