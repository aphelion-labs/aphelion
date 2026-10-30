# Spec Delta

## Purpose

The daemon is the per-machine process that observes every local coding-agent session, through one adapter per agent and without owning any terminal, and emits the agent-neutral `aphelion.session.v0` session feed that the hub, the TUI and the MCP tools consume (ADR 0008, ADR 0009).

## ADDED Requirements

### Requirement: Daemon command writes the feed to stdout

The `aphelion daemon` subcommand SHALL run until it is interrupted and SHALL write the session feed to standard output as NDJSON, one event per line. It SHALL first write one `snapshot` event per listed session, then one event per meaningful change.

#### Scenario: Start with two live sessions

- **WHEN** `aphelion daemon` starts while two Claude Code sessions are live
- **THEN** it writes two lines of `type` `snapshot`, one per session, before any other line

#### Scenario: A change after start

- **WHEN** a listed session's status changes after the snapshot lines were written
- **THEN** the daemon writes one further line for that session

#### Scenario: Interrupt

- **WHEN** the daemon receives an interrupt signal
- **THEN** it stops and exits without writing a partial line

### Requirement: Observation never controls a session

The daemon SHALL observe sessions only by reading files the agent already writes and by receiving hooks. It SHALL NOT own, wrap, attach to or type into any terminal, and SHALL NOT create, modify or delete any file under the agent's own directories (for Claude Code, `~/.claude`).

#### Scenario: Claude Code directory untouched

- **WHEN** the daemon runs against a Claude Code directory and then stops
- **THEN** no file under that directory was created, modified or deleted by the daemon

### Requirement: Claude Code sessions are discovered from the registry

The Claude Code adapter SHALL list every session that has a parseable `*.json` entry in `~/.claude/sessions/` backed by a live process, whatever started it: an interactive terminal session, a `claude -p` run or a background session.

#### Scenario: Interactive session

- **WHEN** a registry entry has `entrypoint` `cli` and `kind` `interactive`, and its process is live
- **THEN** the session is listed

#### Scenario: Headless run

- **WHEN** a `claude -p` run is live, which registers with `kind` `interactive` and an `entrypoint` starting with `sdk`
- **THEN** the session is listed

#### Scenario: Background session

- **WHEN** a registry entry has `kind` `bg` and its process is live
- **THEN** the session is listed

### Requirement: Session kind is derived from entrypoint then registry kind

The Claude Code adapter SHALL set `kind` as PoC 01 does: `headless` when the registry `entrypoint` starts with `sdk`; otherwise `interactive` when the registry `kind` is empty or `interactive`; otherwise the registry `kind` passed through verbatim.

#### Scenario: claude -p reads headless

- **WHEN** a registry entry has `entrypoint` `sdk-cli` and `kind` `interactive`
- **THEN** the session's `kind` is `headless`

#### Scenario: Terminal session reads interactive

- **WHEN** a registry entry has `entrypoint` `cli` and `kind` `interactive`
- **THEN** the session's `kind` is `interactive`

#### Scenario: Background kind passes through

- **WHEN** a registry entry has `entrypoint` `cli` and `kind` `bg`
- **THEN** the session's `kind` is `bg`

### Requirement: Registry secret files are never opened

The Claude Code adapter SHALL read only `*.json` files in the registry directory and SHALL NOT open, read or stat the contents of any `*.key` file there, because those files are secrets (ADR 0008).

#### Scenario: Key file beside a registry entry

- **WHEN** the registry directory holds `4266.json` and `4266.key`
- **THEN** the adapter opens `4266.json` and never opens `4266.key`

### Requirement: Liveness is checked against the recorded process start

On Linux the Claude Code adapter SHALL treat a registry entry as live only when its `pid` is running and, when the entry records `procStart`, field 22 of `/proc/<pid>/stat` equals `procStart`. Open decision: liveness on other operating systems (ADR 0002 leaves the OS matrix open).

#### Scenario: Stale file after a crash

- **WHEN** a registry entry's `pid` is not running
- **THEN** the entry is not live

#### Scenario: Reused PID

- **WHEN** a registry entry's `pid` is running but `/proc/<pid>/stat` field 22 differs from its `procStart`
- **THEN** the entry is not live

### Requirement: Transcripts are read whole once, then by appended bytes

The Claude Code adapter SHALL find a session's transcript at `~/.claude/projects/<slug>/<sessionId>.jsonl`, falling back to a search by session id when the slug does not match. It SHALL read a transcript whole the first time and afterwards read only bytes appended since the last read.

#### Scenario: Appended record

- **WHEN** a transcript already read gains one new line
- **THEN** the adapter reads only the appended bytes and applies the new record

#### Scenario: Slug mismatch

- **WHEN** the transcript is not under the slug derived from the session's `cwd` but exists under another project folder
- **THEN** the adapter finds it by session id

### Requirement: Parsers tolerate unknown and malformed input

Every parser of agent files (registry entries, transcripts, hook logs) SHALL treat every field as optional, skip lines it cannot parse, ignore record types it does not know, and never crash or stop the daemon because of file content (ADR 0008).

#### Scenario: Unknown record type

- **WHEN** a transcript contains a record whose type the adapter does not know
- **THEN** the record is ignored and the remaining records are applied

#### Scenario: Truncated last line

- **WHEN** a transcript's last line is half-written
- **THEN** the line is skipped without error
- **AND** once the rest of the line is written, the complete record is applied

#### Scenario: Missing fields

- **WHEN** a registry entry lacks `status`, `name` and `cwd`
- **THEN** the session is still listed and the missing fields are empty

### Requirement: Subagent count comes from subagent transcripts

The Claude Code adapter SHALL report in `subagents` the number of subagent transcripts (`<sessionId>/subagents/agent-*.jsonl`) the session has written, finished ones included. Open decision: whether running subagents are reported instead, which needs the `SubagentStart` and `SubagentStop` hooks (ADR 0008).

#### Scenario: Two subagent transcripts

- **WHEN** a session's folder holds two `agent-*.jsonl` subagent transcripts
- **THEN** the session's `subagents` is 2

### Requirement: Hook receiver never makes a decision

The daemon SHALL receive Claude Code `http` hooks and answer each with an empty success response that carries no decision, so a hook can never change what a session does. A request without a session id or event name SHALL be rejected and not recorded. Open decision: the receiver's address, port and authentication.

#### Scenario: PermissionRequest hook

- **WHEN** the receiver gets a `PermissionRequest` hook for `Bash`
- **THEN** it answers with a success status and an empty body
- **AND** it appends one record to the session's hook log

#### Scenario: Malformed hook body

- **WHEN** the receiver gets a body that is not a hook JSON object with a session id and event name
- **THEN** it answers with a client error and records nothing

### Requirement: Hook log stores no tool input and no prompt text

Each hook log record SHALL hold only the time received (UTC), the hook event name, the session id, the tool name and the notification type. It SHALL NOT hold tool input, tool output, prompt text or any other field of the hook body. Open decision: the hook log's location and pruning.

#### Scenario: PreToolUse with tool input

- **WHEN** the receiver gets a `PreToolUse` hook whose body carries `tool_input`
- **THEN** the stored record holds the tool name and no part of `tool_input`

#### Scenario: UserPromptSubmit with prompt

- **WHEN** the receiver gets a `UserPromptSubmit` hook whose body carries `prompt`
- **THEN** the stored record holds no part of the prompt

### Requirement: Status rules apply in a fixed order

The Claude Code adapter SHALL derive a live session's `status` by testing these rules in order and taking the first that matches (ADR 0008): `waiting: question`, `waiting: permission`, `waiting: <value>`, `working`, `idle 60s+`, `idle`. A session with no live registry entry SHALL read `exited`.

#### Scenario: Question beats permission

- **WHEN** a session has both an open question fact and an open permission fact
- **THEN** its status is `waiting: question`

#### Scenario: Waiting beats busy

- **WHEN** the registry says `busy` and a permission fact is open
- **THEN** its status is `waiting: permission`

### Requirement: Waiting on a question

A session SHALL read `waiting: question` when its transcript has an `AskUserQuestion` tool_use with no matching tool_result, or when a `PreToolUse` or `PermissionRequest` hook for `AskUserQuestion` has arrived and not been cleared.

#### Scenario: AskUserQuestion fires PermissionRequest

- **WHEN** hooks `PreToolUse` and then `PermissionRequest` arrive for `AskUserQuestion`, followed by a `permission_prompt` Notification
- **THEN** the status is `waiting: question`, not `waiting: permission`

#### Scenario: Transcript only, no hooks

- **WHEN** no hook log exists and the transcript ends with an `AskUserQuestion` tool_use with no tool_result
- **THEN** the status is `waiting: question`

### Requirement: Waiting on a permission

A session SHALL read `waiting: permission` when a `PermissionRequest` hook for any tool other than `AskUserQuestion`, or a `permission_prompt` Notification while no question is open, has arrived and not been cleared; or when the registry says `status` `waiting` with `waitingFor` `permission prompt`.

#### Scenario: Tool approval from a hook

- **WHEN** a `PermissionRequest` hook for `Bash` arrives and no clearing hook follows
- **THEN** the status is `waiting: permission`

#### Scenario: Tool approval from the registry only

- **WHEN** no hook log exists and the registry says `status` `waiting`, `waitingFor` `permission prompt`
- **THEN** the status is `waiting: permission`

#### Scenario: Notification only

- **WHEN** a `permission_prompt` Notification arrives while no question is open and no clearing hook follows
- **THEN** the status is `waiting: permission`

### Requirement: Other registry waits pass through

A session SHALL read `waiting: <value>`, with the registry's `waitingFor` passed through verbatim, when the registry says `status` `waiting` with any `waitingFor` other than `permission prompt` and no question or permission fact applies.

#### Scenario: Input needed

- **WHEN** the registry says `status` `waiting`, `waitingFor` `input needed`, and no hook or transcript fact is open
- **THEN** the status is `waiting: input needed`

### Requirement: Working

A session SHALL read `working` when the registry says `status` `busy` and no waiting fact applies. `working` SHALL have no timeout.

#### Scenario: Busy without waiting facts

- **WHEN** the registry says `busy` and no question or permission fact is open
- **THEN** the status is `working`

### Requirement: Idle and idle 60s+

A session SHALL read `idle 60s+` when the registry says `status` `idle` and an `idle_prompt` Notification arrived after the registry's last status change, and `idle` when the registry says `idle` otherwise. The 60 seconds are Claude Code's, which sends `idle_prompt` (ADR 0008); the daemon measures no time.

#### Scenario: Idle prompt after the status change

- **WHEN** the registry says `idle` since 10:00:00 and an `idle_prompt` Notification arrives at 10:01:00
- **THEN** the status is `idle 60s+`

#### Scenario: Idle prompt before the status change

- **WHEN** an `idle_prompt` Notification arrived at 10:01:00 and the registry changed to `idle` again at 10:02:00
- **THEN** the status is `idle`

### Requirement: Waiting facts are cleared by later observations

An open question or permission fact SHALL be cleared by a later `PostToolUse`, `PostToolUseFailure`, `Stop` or `UserPromptSubmit` hook for the session, or by a registry status newer than the fact that is not `waiting` (ADR 0008).

#### Scenario: Question answered

- **WHEN** a `PreToolUse` hook for `AskUserQuestion` is followed by `PostToolUse` for `AskUserQuestion`
- **THEN** no question fact remains open

#### Scenario: Permission approved before a slow tool ends

- **WHEN** a `PermissionRequest` hook for `Bash` is followed by a registry status change to `busy`, with no `PostToolUse` yet
- **THEN** no permission fact remains open and the status is `working`

#### Scenario: Failed tool

- **WHEN** a `PermissionRequest` hook for `Bash` is followed by `PostToolUseFailure`
- **THEN** no permission fact remains open

### Requirement: Agent needs input maps to no state

An `agent_needs_input` Notification SHALL be recorded under `raw` and SHALL NOT change `status`. Open decision: whether it maps to a state (ADR 0008).

#### Scenario: agent_needs_input arrives

- **WHEN** an `agent_needs_input` Notification arrives for an idle session
- **THEN** the status stays `idle`

### Requirement: No state depends on elapsed time

No status rule SHALL depend on elapsed time or on the text of a message, apart from how long exited sessions stay listed (ADR 0008).

#### Scenario: Long busy session

- **WHEN** the registry has said `busy` for many hours with no other fact
- **THEN** the status is still `working`

#### Scenario: Question in prose

- **WHEN** the last assistant message ends with a question mark and no question tool or hook fact exists
- **THEN** the status is derived from the registry alone

### Requirement: Exited sessions stay listed for a retention window

A session with no live registry entry whose transcript was written within the retention window SHALL be listed with status `exited`. When the window has passed it SHALL be dropped with no further event. The same window bounds discovery of sessions that never registered. Open decision: the window's length.

#### Scenario: Process exits

- **WHEN** a live session's registry entry disappears
- **THEN** the daemon writes one `ended` event for it with status `exited`
- **AND** the session stays listed as `exited` until the retention window passes

#### Scenario: Unregistered session

- **WHEN** a transcript was written within the retention window and no registry entry names its session
- **THEN** the session is reported once as `ended` with status `exited`

### Requirement: Every status carries its facts

Every feed event SHALL carry a non-empty `status_facts` list of human-readable strings, each naming its source (registry, transcript or hook) and the fact that produced or supports the status. Consumers SHALL NOT need to parse these strings.

#### Scenario: Permission event

- **WHEN** a session reads `waiting: permission` from a `PermissionRequest` hook for `Bash`
- **THEN** its event's `status_facts` include a hook fact naming `PermissionRequest` and `Bash`

#### Scenario: Exited event

- **WHEN** a session reads `exited`
- **THEN** its event's `status_facts` say which registry and transcript facts produced it

### Requirement: Feed events follow the aphelion.session.v0 schema

Each feed line SHALL be one JSON object with `schema` `aphelion.session.v0` and the ADR 0009 fields: `schema`, `ts`, `machine`, `type`, `agent`, `session_id`, `name`, `kind`, `status`, `status_facts`, `pid`, `cwd`, `branch`, `activity`, `started_at`, `last_activity_at`, `subagents`, `changed`, `raw`. Machine-readable times SHALL be UTC RFC 3339.

#### Scenario: Line shape

- **WHEN** the daemon writes any event
- **THEN** the line parses as one JSON object whose `schema` is `aphelion.session.v0`
- **AND** every top-level key is one of the ADR 0009 fields

#### Scenario: UTC times

- **WHEN** the machine's local time zone is not UTC
- **THEN** `ts`, `started_at`, `last_activity_at` and `activity.at` are written in UTC

### Requirement: Field names are agent-neutral

No top-level feed field name SHALL refer to a specific agent. `agent` SHALL name the adapter (`claude-code` for Claude Code), and every agent-specific value SHALL sit under `raw` (ADR 0009).

#### Scenario: Schema test

- **WHEN** the schema test checks the top-level field names of the feed event type
- **THEN** none of them contains an agent's name, and the test fails if one does

#### Scenario: Registry details

- **WHEN** a Claude Code session's event is written
- **THEN** its registry `entrypoint`, `version` and file path appear only under `raw`

### Requirement: Session identity and context fields

For Claude Code, `session_id` SHALL be the registry or transcript session id; `name` the registry name, else the transcript title, else `claude-` plus the id's first group (PoC 01); `cwd` the registry's; `branch` the transcript's last git branch; `pid` the registry's; `machine` the host name.

#### Scenario: Unnamed session

- **WHEN** a session has no registry name and no transcript title, and its id is `d29977a1-3cd7-43f5-ac35-12540355414e`
- **THEN** its `name` is `claude-d29977a1`

### Requirement: Activity reports the latest action

`activity` SHALL hold the session's most recent action: `action` (the tool name), `target` (an excerpt of the tool's main input), `at` (UTC) and `running` (true until a result is recorded). Open decision: the excerpt cap, and whether it applies to every input or only to shell commands.

#### Scenario: Running tool

- **WHEN** the transcript's last tool_use is `Read` on `main.go` with no tool_result yet
- **THEN** `activity` is action `Read`, target `main.go`, `running` true

#### Scenario: Finished tool

- **WHEN** that tool_use gains its tool_result
- **THEN** `activity.running` is false

### Requirement: Event types describe the session lifecycle

`type` SHALL be `snapshot` for every session listed when the feed starts, `started` for a session first seen afterwards, `updated` for a change to a listed session, and `ended` when a session becomes `exited` or its source stops listing it. `updated` and `ended` events SHALL list the changed fields in `changed`.

#### Scenario: New session

- **WHEN** a session starts after the snapshot lines were written
- **THEN** the daemon writes one `started` event for it

#### Scenario: Status change

- **WHEN** a listed session goes from `working` to `idle`
- **THEN** the daemon writes one `updated` event whose `changed` includes `status` and `status_facts`

### Requirement: Events only on meaningful change

The daemon SHALL write an event for a listed session only when one of `name`, `kind`, `status`, `status_facts`, `cwd`, `branch`, `activity` or `subagents` differs from its last event. A change to `last_activity_at` or `raw` alone SHALL NOT produce an event.

#### Scenario: Only last activity moved

- **WHEN** a transcript gains records that change only the session's `last_activity_at`
- **THEN** no event is written

### Requirement: Changes are noticed from file events and a rescan

The daemon SHALL take a new snapshot when a watched file changes, coalescing events that arrive within the coalescing window, and on a fixed rescan interval so that a process that died without removing its registry file is noticed. Open decision: the coalescing window and the rescan interval.

#### Scenario: Crash without file removal

- **WHEN** a session's process is killed and its registry file stays on disk
- **THEN** within one rescan interval the daemon writes an `ended` event for it

#### Scenario: Burst of transcript writes

- **WHEN** a transcript is appended to several times within one coalescing window
- **THEN** the daemon takes one snapshot for the burst

### Requirement: Golden feed fixtures for the Claude Code adapter

The repository SHALL hold golden NDJSON fixtures produced by the Claude Code adapter from recorded registry files, transcripts and hook logs, covering every status. A test SHALL fail when the adapter's output for those inputs differs from the fixtures, so hub and TUI tests can consume them unchanged (ADR 0009).

#### Scenario: Adapter output drifts

- **WHEN** a code change alters the feed produced from the recorded inputs
- **THEN** the golden test fails until the fixtures are deliberately regenerated and committed
