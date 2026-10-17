---
title: "Session state is observed, never inferred"
status: proposed
date: 2026-10-17
deciders: product owner
consulted: Claude research 2026-10-14..17
---

# 0008 Session state is observed, never inferred

## Context and problem statement

The executive view (ADR 0007) shows what every session is doing. An earlier PoC showed a "blocked" state inferred from timing and text. On 2026-10-17 the owner asked what separated blocked from idle: "If it is minimal, given blocked is inferred which could lead to false positives, maybe it would be better to just have 'idle' instead?", and asked whether a session waiting on an AskUserQuestion prompt can be detected. The 01 PoC was rebuilt so every state comes from an observed fact, and the owner approved the result on 2026-10-17: states are working, waiting: question, waiting: permission, idle, idle 60s+ and exited, observed and never inferred.

## Decision drivers

- A state shown to a human must be true, or people stop trusting the board.
- "Waiting on a human" is the most valuable signal and must be split by cause.
- Claude Code's files are internal and change between versions.
- Every state must say which facts produced it.

## Considered options

1. Observed states only, from the session registry, the transcript and hooks, with the facts attached.
2. Inferred states (timeouts, text heuristics, screen scraping).
3. Registry and transcript only, with no hooks.

## Decision outcome

Chosen option: 1, because it never shows a state it cannot back with a fact, and the 01 PoC showed questions and permission prompts appearing within about a second.

Rules, first match wins:

| State | Produced by |
|---|---|
| waiting: question | transcript: an AskUserQuestion tool_use with no tool_result; or hook: PreToolUse or PermissionRequest for AskUserQuestion, not yet cleared |
| waiting: permission | hook: PermissionRequest for any other tool, or a `permission_prompt` Notification while no question is open, not yet cleared; or registry: `status "waiting"` with `waitingFor "permission prompt"` |
| waiting: <value> | registry: `status "waiting"` with any other `waitingFor`, passed through verbatim |
| working | registry: `status "busy"` and no waiting fact |
| idle 60s+ | registry: `status "idle"` plus an `idle_prompt` Notification after the registry's last status change |
| idle | registry: `status "idle"` |
| exited | no live registry entry, and the transcript was written recently |

- Sources: the session registry (`~/.claude/sessions/<pid>.json`: liveness, status, waitingFor, name, cwd), the transcript (`~/.claude/projects/<slug>/<sessionId>.jsonl`), and hooks: PreToolUse, PermissionRequest, Notification, PostToolUse, PostToolUseFailure, Stop and UserPromptSubmit. A waiting fact is cleared by PostToolUse, PostToolUseFailure, Stop, UserPromptSubmit, or a newer registry status that is not `waiting`.
- Hooks are required for reliable detection. Without a PreToolUse hook, a pending AskUserQuestion is not written to the transcript while it waits (observed: 45 s with nothing written). On a machine without hooks, aphelion shows what the registry and transcript support and nothing more.
- AskUserQuestion also fires PermissionRequest and, about 6 s later, a `permission_prompt` notification, so the tool name decides between question and permission.
- The registry's `waiting` status was first seen on Claude Code 2.1.302 and is undocumented. It is one source among others, never the only one.
- The transcript format is documented as internal and changing between versions. Parsers treat every field as optional, skip unparseable lines (including a half-written last line), ignore unknown record types, and never crash. The `*.key` files beside registry entries are secrets and are never opened.
- `working` has no timeout: aphelion cannot tell progress from a slow tool and does not pretend to.
- The 60 seconds in "idle 60s+" is Claude Code's, not ours: it sends `idle_prompt` about 60 seconds after Claude finishes responding, only if the user has not typed and no background agent is running.
- Every row and feed event carries its `status_facts`.

Open decisions, from the 01 PoC constants table: the rescan interval (2 s in the PoC); how long exited sessions stay listed (2 min); the hook receiver's port (8787) and authentication (none, localhost only, in the PoC); hook log pruning (never pruned in the PoC); applying the brief's 60-rune Bash excerpt cap to every tool input; column widths; KIND labels; age units; row order; colours; keeping whole histories in memory or paging them; whether `agent_needs_input` maps to a state; and whether running subagents are shown, which needs the SubagentStart and SubagentStop hooks. The PoC's 500 ms event coalescing and 80-rune last-message excerpt came from the assistant's brief, not from the owner, so they need owner confirmation too (ADR 0001).

### Consequences

- Good, because a human can trust "waiting: question" enough to act on it.
- Good, because every status explains itself.
- Bad, because every machine needs aphelion's hooks installed for full fidelity.
- Bad, because a question asked in plain prose, without the tool, shows as idle.
- Bad, because internal formats can change in any Claude Code release, as the registry did between 2.1.300 and 2.1.302 during the PoC.
- Bad, because a manual "No" to a permission prompt fires no hook; the fact clears only on the next registry change or clearing hook.

### Confirmation

- Parser tests replay recorded transcripts, registry files and hook logs, including unknown record types and a truncated last line.
- Rule tests cover every state and precedence case, including AskUserQuestion firing PermissionRequest.
- No state rule depends on elapsed time, apart from how long exited sessions stay listed.

## Pros and cons of the options

### Observed states only

- Good, because there are no false positives by construction.
- Bad, because it needs hooks, and some waits are invisible without them.

### Inferred states

- Good, because it works with no setup.
- Bad, because it produces false positives, which the owner rejected.
- Bad, because screen scraping needs constant upkeep; herdr ships remotely updated regex manifests to keep up with Claude Code's UI.

### Registry and transcript only

- Good, because it needs no setup.
- Bad, because it misses pending questions, and permission prompts on versions whose registry lacks `waiting`.

## More information

- Owner statements, 2026-10-17, in the setup session.
- 01 PoC, verified on Claude Code 2.1.300 and 2.1.302: `~/DEV/aphelion-poc/01-session-board/README.md` (2026-10-17).
- Transcript location and "the entry format is internal": https://code.claude.com/docs/en/sessions (checked 2026-10-15).
- Hook events, Notification types and `idle_prompt` timing: https://code.claude.com/docs/en/hooks (checked 2026-10-14).
- herdr's Claude detection manifest: https://github.com/herdrdev/herdr/blob/v0.9.5/src/detect/manifests/claude.toml (checked 2026-10-15).
