---
title: "The hook receiver runs inside the daemon and keeps a hook log on disk"
status: proposed
date: 2026-10-30
deciders: product owner
consulted: Claude, propose run for issue #1, 2026-10-30
---

# 0014 The hook receiver runs inside the daemon and keeps a hook log on disk

## Context and problem statement

ADR 0008 makes hooks a required source for reliable session state: without a `PreToolUse` hook a pending `AskUserQuestion` is not on disk while it waits. Issue #1 asks for a hook receiver for Claude Code `http` hooks that returns no decision and stores only time, event, session, tool name and notification type. The issue names one subcommand, `aphelion daemon`, and asks for parser tests that replay recorded hook logs.

PoC 01 ran the receiver as its own mode (`sessionboard hookserver`) that appended records to per-session log files under `$XDG_RUNTIME_DIR/sessionboard/hooks/`. The board and feed modes read those files like any other source, so facts survived a board restart and several boards could run at once. In which process does the receiver run, and how do hook facts reach the status rules?

## Decision drivers

- One process per machine for the user to start and keep running.
- Hook facts reach the status rules within the same snapshot cycle as other file changes (ADR 0008: questions appear within about a second).
- Hook facts survive a daemon restart, so a question asked before the restart still reads `waiting: question`.
- The issue's parser tests replay recorded hook logs.
- A hook can never change what a session does.

## Considered options

1. The receiver runs inside `aphelion daemon`, appends each record to a hook log on disk, and the adapter reads the log like its other files.
2. A separate `aphelion hookserver` subcommand, as in PoC 01.
3. The receiver inside the daemon, with hook facts kept only in memory.
4. `command` hooks that run a small aphelion command per hook to append to the log.

## Decision outcome

Chosen option: 1, because it keeps one process to run while keeping PoC 01's file-based path, which survives restarts and gives the replayable hook logs the tests need.

- The daemon owns one local HTTP listener. Each source that handles hooks offers a handler, and the daemon mounts it at `POST /hooks/<agent>`; for Claude Code that is `POST /hooks/claude-code`. The path carries the agent name so a second adapter (ADR 0009) adds its own route on the same listener.
- The handler answers every valid hook with an empty 2xx body, which Claude Code reads as "no decision", and rejects a body without a session id or event name with a client error.
- Each record is appended to the session's hook log, and the hook log directory is watched like the transcripts, so a new record triggers a snapshot.
- If the daemon is not running, Claude Code's connection is refused and the session carries on (observed in PoC 01). Hooks sent while the daemon is down are lost.
- Open decision: the listener's address, port and authentication. PoC 01 used `127.0.0.1:8787`, an arbitrary port, with no authentication.
- Open decision: the hook log's location and pruning. PoC 01 used `$XDG_RUNTIME_DIR`, never pruned while the machine is up.
- Installing the hooks into Claude Code's settings is not part of this decision; it belongs to the `hooks` and `install` capabilities.

### Consequences

- Good, because the user runs one process.
- Good, because a daemon restart keeps every hook fact recorded before it.
- Good, because the hook log format is the test fixture format.
- Bad, because hooks that fire while the daemon is down are lost, where PoC 01's separate receiver could outlive a board restart.
- Bad, because every hook is a disk write as well as a localhost request.

### Confirmation

- A test posts recorded hook bodies to the handler and checks the response is an empty 2xx and the log record holds only the five allowed fields.
- Parser tests replay recorded hook logs through the status rules.

## Pros and cons of the options

### Inside the daemon, with a hook log

- Good, because it is one process and keeps restart safety.
- Bad, because hooks are lost while the daemon is down.

### Separate hookserver subcommand

- Good, because the receiver can keep running while the daemon restarts.
- Bad, because the user starts and supervises two processes, and the issue names only `aphelion daemon`.
- Bad, because PoC 01's reason, several boards reading at once, does not apply to one daemon per machine.

### Inside the daemon, in memory only

- Good, because there is no disk write per hook.
- Bad, because a restart loses every open question and permission fact.
- Bad, because the issue's hook log replay tests would have no log to replay.

### Command hooks

- Good, because nothing listens on a port.
- Bad, because the issue specifies `http` hooks.
- Bad, because it starts a process for every tool call.

## More information

- Issue #1, "Details" (2026-10-30).
- PoC 01 hook path and constants: `~/DEV/aphelion-poc/01-session-board/README.md`, sections "Hook path" and "Constants and decisions" (2026-10-17).
- Hook events and `http` hooks: https://code.claude.com/docs/en/hooks (checked 2026-10-14, per ADR 0008).
- Change folder: `openspec/changes/1-daemon-discover-sessions-and-emit-the-agent-neutral-session-feed/design.md`.
