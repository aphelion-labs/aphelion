# Tasks

Acceptance criteria (AC) are numbered in the order issue #1 lists them: AC1 kinds, AC2 rule tests, AC3 parser replay, AC4 non-empty `status_facts`, AC5 schema test, AC6 no event on `last_activity_at` alone, AC7 `*.key` never opened, AC8 hook log privacy, AC9 golden fixtures, AC10 no elapsed-time rules.

## 1. Open decisions and scaffolding

- [ ] 1.1 Record the owner's answer to each of the 13 open decisions in design.md, in this change's spec delta or in an ADR; verify that every value a constant in the code uses comes from a recorded answer, and that "Open decision" remains only where the owner deferred it
- [ ] 1.2 Add `github.com/fsnotify/fsnotify` pinned to an exact version in go.mod; verify `make build` succeeds with `CGO_ENABLED=0` (ADR 0002)
- [ ] 1.3 Create `internal/session`, `internal/feed`, `internal/daemon` and `internal/adapter/claudecode` with package doc comments (ADR 0013), and an import-boundary test that fails if any package other than `cmd/aphelion` imports `internal/adapter/...`; verify the test passes, and fails when a temporary import is added

## 2. Agent-neutral model and feed

- [ ] 2.1 Port the `Session` and `Activity` types, status and kind values, the `Source` interface and the optional hook-handler interface into `internal/session`, without `LastMessage` or `History`; verify `go vet ./...` and `make lint` pass
- [ ] 2.2 Port the v0 event type into `internal/feed` with exactly the ADR 0009 fields and UTC times; add the schema test (AC5) that fails when a top-level JSON field name contains an agent name; verify it passes, and fails against a test-only event type with a field such as `claude_version`
- [ ] 2.3 Port the differ: `snapshot` on the first call, `started`, `updated` with `changed`, `ended` on exit or when a session is no longer listed; verify with unit tests for each type, including that a change to only `last_activity_at` or only `raw` emits nothing (AC6)
- [ ] 2.4 Port the NDJSON writer; verify a test writes events from several goroutines under `go test -race` and every line parses as one JSON object

## 3. Claude Code adapter: discovery and parsing

- [ ] 3.1 Add recorded inputs to `internal/adapter/claudecode/testdata/`: registry entries for interactive, `claude -p`, background and stale-PID sessions, each with a `.key` neighbour; transcripts including an unknown record type and a truncated last line; hook logs for every state; verify no personal path or secret remains (`grep` for the home directory, and gitleaks in CI)
- [ ] 3.2 Port the registry reader over an injectable file system, reading only `*.json`; verify a recording file-system test fails if any `*.key` path is opened, read or statted (AC7)
- [ ] 3.3 Port Linux liveness (`pid` running and `/proc/<pid>/stat` field 22 equal to `procStart`) behind a Linux build tag; verify tests against a fake `/proc` root for a live, a dead and a reused PID, and that `GOOS=darwin go build ./...` still compiles
- [ ] 3.4 Port kind derivation; verify a table test gives `interactive` for `cli`/`interactive`, `headless` for `sdk-cli`/`interactive` and `bg` for `cli`/`bg` (AC1)
- [ ] 3.5 Port the transcript parser (whole once, then appended bytes) and the slug lookup with its session-id fallback; verify replay tests for appended records, an unknown record type, a truncated last line that is applied once completed, missing fields, and a slug mismatch (AC3)
- [ ] 3.6 Port the subagent transcript count; verify a test with two `agent-*.jsonl` files gives `subagents` 2
- [ ] 3.7 Port identity and context fields (`session_id`, `name` with its `claude-<first group>` fallback, `cwd`, `branch`, `pid`) and keep `entrypoint`, `version`, file paths and `tmux` under `raw`; verify unit tests per field
- [ ] 3.8 Port `activity` (tool name, input excerpt capped by the open-decision value, `at`, `running`); verify tests for a running and a finished tool and for the excerpt cap

## 4. Hooks and status rules

- [ ] 4.1 Port the hook log writer and reader with the five fields only (UTC time, event, session id, tool name, notification type); verify a replay test over the recorded hook logs, including an unparseable line (AC3)
- [ ] 4.2 Port the hook handler into the adapter (empty 2xx, client error on a body without session id or event name); verify tests that post `PreToolUse` with `tool_input` and `UserPromptSubmit` with `prompt` and assert the stored record contains neither (AC8)
- [ ] 4.3 Move the ADR 0008 status rules into a pure function in their own file; verify table tests for every state and precedence case: question over permission; `AskUserQuestion` firing `PreToolUse`, `PermissionRequest` and then `permission_prompt` reads `waiting: question`; tool `PermissionRequest`; registry-only permission; `input needed` pass-through; working; idle; `idle_prompt` before and after the registry's status change; each clearing hook; a newer non-waiting registry status; `agent_needs_input` changing nothing (AC2)
- [ ] 4.4 Verify the rules take no clock: their signature has no time parameter, and a test applies the same inputs under clocks hours apart and gets the same status and facts; a busy session stays `working` (AC10)
- [ ] 4.5 Port the source's exited handling: `exited` within the retention window, dropped after it, unregistered transcripts reported once as `ended`; verify tests with a fixed clock either side of the window

## 5. Daemon loop and command

- [ ] 5.1 Port the watcher into `internal/daemon` with coalescing and rescan using the recorded open-decision values; verify tests with a fake source that a burst of writes gives one snapshot and that a killed process with its registry file left behind is `ended` within one rescan
- [ ] 5.2 Add the hook listener that mounts each source's handler at `POST /hooks/<agent>` on the recorded address (ADR 0014); verify an `httptest` test reaches `/hooks/claude-code` and gets an empty 2xx
- [ ] 5.3 Add subcommand dispatch and `aphelion daemon` to `cmd/aphelion`, keeping `--version`; verify a test runs the daemon against a copy of the recorded inputs, reads the snapshot lines, sends an interrupt and sees a clean exit with no partial line
- [ ] 5.4 Verify the daemon writes nothing under the Claude Code directory: a test hashes the copied directory tree before and after a run and compares
- [ ] 5.5 Verify every event the daemon writes from the recorded inputs has a non-empty `status_facts` (AC4)
- [ ] 5.6 Document `aphelion daemon` (what it reads, the hook route, the feed fields, the open-decision values) in README.md or `docs/`, and update CLAUDE.md's "nothing runs yet" status line; verify the documented command runs as written

## 6. Golden feed fixtures

- [ ] 6.1 Add the golden test with an `-update` flag, a fixed clock, machine name and time zone, and commit `testdata/feed/claude-code/*.ndjson` covering every status (AC9); verify the test passes, and fails after a fixture line is edited

## 7. Integration checks

- [ ] 7.1 Run `make check` (fmt, vet, golangci-lint with `mnd`, `go test -race`, file length, specs); verify it passes and CI shows the coverage line
- [ ] 7.2 Review every named constant for a doc comment citing a spec requirement, an ADR or an owner-answered open decision (ADR 0001); verify by listing `const` declarations under `internal/` and `cmd/`
- [ ] 7.3 On megatron, with hooks configured for the receiver, run `aphelion daemon` beside an interactive session, a `claude -p` run and a background session, then trigger an `AskUserQuestion` and a tool approval; verify `kind`, `waiting: question`, `waiting: permission` and `ended` lines appear with their facts, and note the Claude Code version in the PR

## Workflow follow-up

- Tick every task above, then archive this change inside the same PR (`openspec archive`, ADR 0004) with the issue-finish skill.
- Run `openspec validate --all --strict` and `scripts/check-specs.sh` on the archived result.
- Have the owner set ADR 0013 and ADR 0014 to `accepted` or revise them.
