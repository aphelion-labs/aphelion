---
title: "Daemon package layout: agent-neutral core, one adapter package per agent"
status: proposed
date: 2026-10-30
deciders: product owner
consulted: Claude, propose run for issue #1, 2026-10-30
---

# 0013 Daemon package layout: agent-neutral core, one adapter package per agent

## Context and problem statement

Issue #1 ports PoC 01 (`~/DEV/aphelion-poc/01-session-board/`) into `aphelion daemon` and says the final package layout goes in the change's design.md. ADR 0009 requires that the hub and the TUI never parse agent internals and that a new agent needs only an adapter. The issue adds: "All Claude Code specifics live in one adapter behind the `Source` interface."

PoC 01 used `internal/board` (the agent-neutral model, the `Source` interface and the fsnotify watcher), `internal/claude` (registry, transcript, hooks, status rules), `internal/feed` (schema and differ) and `internal/hookserver` (the hook receiver). Its `hookserver` imports `internal/claude` and decodes Claude Code's hook body, so Claude Code specifics live in two packages. Where do the daemon's packages go, and how is the adapter boundary kept?

## Decision drivers

- Every Claude Code detail sits in one place, so a Claude Code release that changes a file format touches one package (ADR 0008).
- A second adapter (opencode, ADR 0009) adds a package and changes no agent-neutral code.
- The boundary can be checked by a machine, not only by review (ADR 0001's preference for deterministic checks).
- The hub and the TUI tests can read the golden feed fixtures without importing adapter code (ADR 0009).
- Files stay under 1,500 lines (ADR 0012).

## Considered options

1. Agent-neutral core packages plus one adapter package per agent under `internal/adapter/<agent>`.
2. The PoC 01 layout as it is.
3. One `internal/daemon` package holding everything.
4. Adapters as separate Go modules or plugins loaded at run time.

## Decision outcome

Chosen option: 1, because it is the only option that puts every Claude Code detail, the hook body included, in one package and lets a test check that no other package imports it.

| Package | Holds | Ported from PoC 01 |
|---|---|---|
| `cmd/aphelion` | subcommand dispatch, the `daemon` subcommand and its flags; constructs the adapters and hands them to the daemon | `main.go` (feed mode only) |
| `internal/session` | the agent-neutral `Session` and `Activity` types, status and kind values, the `Source` interface, and an optional interface through which a source offers a hook handler | `internal/board/session.go` |
| `internal/feed` | the `aphelion.session.v0` event type, the snapshot differ, the NDJSON writer, the schema test | `internal/feed/feed.go` |
| `internal/daemon` | the run loop: file watching with coalescing and rescan, the differ and writer wiring, and the hook HTTP listener that mounts each source's handler | `internal/board/watch.go`, the listener half of `internal/hookserver` |
| `internal/adapter/claudecode` | registry, liveness, transcript parser, hook log writer and reader, the hook request handler, the ADR 0008 status rules, and the `Source` implementation; recorded inputs under its `testdata/` | `internal/claude/*`, the decoding half of `internal/hookserver` |
| `testdata/feed/claude-code/` (repository root) | golden NDJSON fixtures for the Claude Code adapter | new |

- The package name `claudecode` matches the feed's `agent` value `claude-code`; Go package names cannot contain a hyphen.
- Only `cmd/aphelion` imports adapter packages. `internal/daemon`, `internal/feed` and `internal/session` import no adapter.
- The golden fixtures sit at the repository root so hub and TUI tests read them as files, with no import of the adapter.
- The PoC TUI (`internal/tui`) is not ported here; it belongs to the `tui-executive-view` ticket.

### Consequences

- Good, because a Claude Code format change touches only `internal/adapter/claudecode`.
- Good, because adding opencode means a new `internal/adapter/opencode` and one line in `cmd/aphelion`.
- Good, because the hub (`hub-store-ingest`) can reuse `internal/feed` without pulling in an adapter.
- Bad, because the hook listener and the hook decoding live in different packages, joined by an interface.
- Bad, because the package names differ from PoC 01, so porting is a rename as well as a copy.

### Confirmation

- A Go test lists the imports of every package (`go list -deps`) and fails if any package other than `cmd/aphelion` and the adapter itself imports `internal/adapter/...`.
- The schema test in `internal/feed` fails if a top-level field name refers to a specific agent (ADR 0009).
- Review checks that no Claude Code file path, field name or hook name appears outside `internal/adapter/claudecode`.

## Pros and cons of the options

### Neutral core plus adapter packages

- Good, because the boundary is a package boundary that a test can check.
- Bad, because it needs one small optional interface for hook handlers.

### PoC 01 layout

- Good, because it is already written and works.
- Bad, because `internal/hookserver` decodes Claude Code's hook body outside `internal/claude`, which breaks the issue's one-adapter rule.
- Bad, because `board` names a UI concept for a package the daemon and the hub use.

### One package

- Good, because there are fewer files to navigate.
- Bad, because neutral and Claude Code code mix, so the boundary is checked only by review.

### Separate modules or plugins

- Good, because adapters could be versioned on their own.
- Bad, because Go plugins need cgo and do not fit one static binary (ADR 0002), and separate modules add release work that one maintainer does not need yet.

## More information

- Issue #1, "Details" and "Acceptance criteria" (2026-10-30).
- PoC 01 code map: `~/DEV/aphelion-poc/01-session-board/README.md`, section "Code map" (2026-10-17).
- Change folder: `openspec/changes/1-daemon-discover-sessions-and-emit-the-agent-neutral-session-feed/design.md`.
