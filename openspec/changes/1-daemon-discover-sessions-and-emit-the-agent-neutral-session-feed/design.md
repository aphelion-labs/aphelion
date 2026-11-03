# Design

## Context

See proposal.md for why. The repository has no runtime code yet: `cmd/aphelion/main.go` prints the version and nothing else. PoC 01 (`~/DEV/aphelion-poc/01-session-board/`, verified on Claude Code 2.1.300 and 2.1.302) already does what the issue asks: a Go program that reads the registry, transcripts and a hook log, applies the ADR 0008 rules and writes the `aphelion.session.v0` feed. It is throwaway code: Linux only, no lint, a few unit tests, and constants chosen from a brief. This change ports it under aphelion's rules: `mnd` lint (ADR 0001), files under 1,500 lines (ADR 0012), one static binary with cgo off (ADR 0002), and tests for every acceptance criterion.

Constraints that shape the approach:

- Claude Code's registry and transcript formats are internal and change between releases (ADR 0008).
- Every value the issue lists under "Open decisions" stays open until the owner answers (ADR 0001). The spec delta names each one in place.
- The feed is a contract that the hub and the TUI tests consume through golden fixtures (ADR 0009).

## Goals / Non-Goals

**Goals:**

- One adapter package holds every Claude Code detail; the core, the feed and the daemon loop are agent-neutral.
- Every acceptance criterion of issue #1 is a test that runs offline from recorded files, with no live Claude Code.
- Every named constant cites the spec requirement, ADR or open decision it comes from.

**Non-Goals:**

- Sending the feed to a hub (`hub-store-ingest`), the TUI (`tui-executive-view`), the history pane and its memory model.
- Installing hooks into Claude Code settings (`hooks`, `install`).
- Any adapter other than Claude Code.
- Liveness on operating systems other than Linux until the owner answers that open decision.

## Decisions

### D1. Package layout and adapter boundary (draft ADR 0013)

| Package | Holds |
|---|---|
| `cmd/aphelion` | subcommand dispatch with the standard library `flag` package (as `main.go` uses today), the `daemon` subcommand, adapter construction |
| `internal/session` | agent-neutral `Session`, `Activity`, status and kind values, the `Source` interface, an optional hook-handler interface |
| `internal/feed` | the v0 event type, the differ, the NDJSON writer, the schema test |
| `internal/daemon` | fsnotify watching with coalescing and rescan, differ and writer wiring, the hook HTTP listener |
| `internal/adapter/claudecode` | registry and liveness, transcript parser, hook log, hook handler, status rules, `Source`; recorded inputs in `testdata/` |
| `testdata/feed/claude-code/` | golden NDJSON fixtures at the repository root |

Only `cmd/aphelion` imports an adapter; a test checks this. Alternatives (the PoC layout as it is, one package, separate modules or plugins) and why each was rejected are in ADR 0013.

### D2. The hook receiver runs inside the daemon (draft ADR 0014)

`aphelion daemon` owns one local HTTP listener and mounts each adapter's handler at `POST /hooks/<agent>` (`/hooks/claude-code`). The handler appends a five-field record to the session's hook log, and the adapter reads that log as it does in PoC 01, so facts survive a daemon restart and the hook logs are the test fixtures. Alternatives (a separate `hookserver` subcommand, memory-only facts, `command` hooks) are in ADR 0014.

## Approach

These follow from the issue, the ADRs or PoC 01 and need no new decision.

**Porting map.**

| PoC 01 | Goes to | Changes on the way |
|---|---|---|
| `internal/board/session.go` | `internal/session` | `LastMessage` and `History` dropped: ADR 0009's field list has no last message, and the history pane is the TUI's ticket |
| `internal/board/watch.go` | `internal/daemon` | coalescing window and rescan interval become open-decision constants |
| `internal/feed/feed.go` | `internal/feed` | `last_message` dropped from the event; `last_message` dropped from the meaningful-change list |
| `internal/claude/registry.go` | `internal/adapter/claudecode` | file access through an injectable file system (below) |
| `internal/claude/transcript.go` | `internal/adapter/claudecode` | split so no file nears 1,500 lines; history building removed |
| `internal/claude/hooks.go` | `internal/adapter/claudecode` | log directory becomes an open-decision constant |
| `internal/claude/source.go` | `internal/adapter/claudecode` | status rules moved to their own file with table tests |
| `internal/hookserver/server.go` | listener to `internal/daemon`, decoding to `internal/adapter/claudecode` | route `/hooks/claude-code` (ADR 0014) |
| `main.go` feed mode | `cmd/aphelion` `daemon` subcommand | the `watch`, `snapshot` and `hookserver` modes are not ported |

**Status rules as a pure function.** The rules take the parsed registry entry, the transcript's open tool calls and the hook facts, and return a status with its facts. They take no clock; only the exited-retention check in the source compares times. A table test feeds every ADR 0008 state and precedence case, which also checks that no rule depends on elapsed time.

**Proving `*.key` files are never opened.** The adapter reads the Claude Code directory through an `fs.FS` (or a small interface over it) rather than calling `os` directly. A test wraps a `fstest.MapFS` holding `<pid>.json` and `<pid>.key` in a recording file system and fails if any open, stat or read touches a `.key` path. The PoC's `filepath.Glob("*.json")` keeps the same behaviour.

**Recorded inputs.** `internal/adapter/claudecode/testdata/` holds registry files, transcripts and hook logs copied from PoC 01 runs and trimmed, with personal paths replaced. They include an unknown record type, a truncated last line, an `AskUserQuestion` that fires `PermissionRequest`, a permission prompt, `input needed`, busy, idle, `idle_prompt`, exited and an unregistered transcript.

**Golden fixtures.** A golden test runs the adapter and the differ over the recorded inputs with a fixed clock, a fixed machine name and a fixed time zone, and compares the NDJSON with `testdata/feed/claude-code/*.ndjson`. An `-update` flag regenerates them, so a change to the feed shows in the PR diff.

**Liveness.** Linux reads `/proc/<pid>/stat` field 22, a format fact rather than a choice (PoC 01 constants table). The build stays `CGO_ENABLED=0`. Until the owner answers the non-Linux open decision, the liveness code sits behind a Linux build tag so other targets still compile.

**Dependency.** `github.com/fsnotify/fsnotify`, pure Go, as the issue's "fsnotify watcher" port requires. PoC 01 pinned v1.10.1; the implementation pins the release current at implementation time in its own commit.

## Open decisions

Each is labelled "Open decision" where it appears in the spec delta and in code (ADR 0001). None is chosen here. The owner answers each before the implementation uses its value, and the answer is recorded in the spec delta of this change or in an ADR.

| # | Open decision | PoC 01 value | Where it lands |
|---|---|---|---|
| 1 | Rescan interval | 2 s | requirement "Changes are noticed from file events and a rescan" |
| 2 | Exited retention, also the discovery window for unregistered sessions | 2 min | requirement "Exited sessions stay listed for a retention window" |
| 3 | Hook receiver address, port and authentication | `127.0.0.1:8787`, no auth | requirement "Hook receiver never makes a decision"; ADR 0014 |
| 4 | Hook log location and pruning | `$XDG_RUNTIME_DIR`, never pruned | requirement "Hook log stores no tool input and no prompt text"; ADR 0014 |
| 5 | Event coalescing window | 500 ms, from the brief | requirement "Changes are noticed from file events and a rescan" |
| 6 | Tool-input excerpt cap, and whether it applies to every input or only shell commands | 60 runes, applied to every non-path input | requirement "Activity reports the latest action" |
| 7 | Last-message excerpt: whether the feed carries one at all and its length | 80 runes, top-level `last_message` | not emitted: ADR 0009's field list has no such field |
| 8 | Whether `agent_needs_input` maps to a state | recorded, maps to nothing | requirement "Agent needs input maps to no state" |
| 9 | Running subagents: transcript count, or `SubagentStart`/`SubagentStop` hooks | transcript count | requirement "Subagent count comes from subagent transcripts" |
| 10 | Ticket number: a new feed field derived in the daemon, or derived in the hub | none | not emitted: ADR 0009's field list has no ticket |
| 11 | What may leave the machine (excerpts, paths) | everything in the feed | affects `activity.target`, `cwd` and `raw`; the feed goes only to stdout in this change |
| 12 | Schema versioning after `v0` | none | no effect on this change; `schema` is `aphelion.session.v0` |
| 13 | Liveness on non-Linux operating systems | Linux only | requirement "Liveness is checked against the recorded process start" |

Rows 7, 8, 9 and 10 follow the ADRs as written. If the owner chooses otherwise, the spec delta gets the matching requirement before implementation starts.

## Risks / Trade-offs

- [Claude Code changes its registry or transcript format in a release] → tolerant parsers (requirement "Parsers tolerate unknown and malformed input"), recorded fixtures per observed version, and every Claude Code detail in one package (ADR 0013).
- [Many open decisions block implementation] → the table above gives the owner one place to answer them; the code names each value as a constant, so an answer changes one line.
- [Hooks are not installed on a machine] → the daemon shows what the registry and transcript support and nothing more (ADR 0008); hook installation is a later ticket.
- [Hooks are lost while the daemon is down] → accepted in ADR 0014; the registry's `waiting` status still shows permission prompts on versions that write it.
- [A manual "No" to a permission prompt fires no hook] → the fact clears on the next registry change or clearing hook (ADR 0008 consequence); covered by a rule test.
- [Golden fixtures depend on machine time zone] → the golden test pins clock, machine name and time zone.
- [The `kind` value `bg` is Claude Code's own word at a top-level field] → it is passed through as PoC 01 does, as the issue asks; the owner may ask for a neutral value in review.

## Migration Plan

None. Nothing runs yet; the new subcommand adds behaviour and changes none.
