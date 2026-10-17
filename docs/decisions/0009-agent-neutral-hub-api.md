---
title: "Hub API is agent-neutral; Claude Code adapter first, opencode second"
status: proposed
date: 2026-10-17
deciders: product owner
consulted: Claude research 2026-10-14..17
---

# 0009 Hub API is agent-neutral; Claude Code adapter first, opencode second

## Context and problem statement

On 2026-10-15 the client clarified that "other people" is flexible: typically people on separate computers with their own Claude plans, and in future other agents such as opencode, or fully autonomous agents without a human in the loop. Collaboration across networks is "not a day one need" and will not block release, but must be recorded as a future item, "somewhat akin to visual studio code's remote development". Claude Code's cross-session messaging reaches only your own sessions, and reaches other machines only through Remote Control on the same account, so aphelion needs its own hub. What contract do the per-machine daemons, the hub and the TUI share?

## Decision drivers

- Agents other than Claude Code must fit without changing the hub or the TUI.
- Agent-specific parsing stays at the edge, on each machine.
- Sessions are observed however they were started.
- Free and self-hostable; no paid relay.

## Considered options

1. Our own agent-neutral NDJSON event schema, fed by per-agent adapters.
2. The Agent Client Protocol (ACP) as the observation protocol.
3. Claude Code's cross-session messaging and Remote Control.
4. A message broker (Kafka, as the client suggested, or NATS or MQTT) as the backbone.

## Decision outcome

Chosen option: 1, because it is the only option that observes running sessions of any agent, keeps every agent-specific detail in one adapter per agent, and needs no extra service.

- Feed: one JSON object per line with schema `aphelion.session.v0` (01 PoC). Field names never mention a specific agent; `agent` names the adapter, and everything agent-specific sits under `raw`. Fields: `schema`, `ts`, `machine`, `type` (snapshot, started, updated, ended), `agent`, `session_id`, `name`, `kind`, `status`, `status_facts`, `pid`, `cwd`, `branch`, `activity` (action, target, at, running), `started_at`, `last_activity_at`, `subagents`, `changed`, `raw`. Machine-readable times are UTC. An event is sent only when a meaningful field changes.
- Adapters: Claude Code first, built on the registry, the transcript and hooks (ADR 0008). opencode second: its TUI is a client of an in-process HTTP server with an OpenAPI description at `/doc` and an SSE event stream at `/event`, and a small JS plugin can forward its bus events to the daemon without port discovery.
- ACP is not the observation protocol. An ACP client must own the agent process over stdio, the protocol has no multi-client or observer role, and `session/load` starts a new instance rather than mirroring a live one. Whether ACP later drives agents that aphelion launches itself is not decided.
- Cross-network collaboration is a roadmap item, filed as an issue once the repository exists.
- Tailscale's free Personal plan "is only suitable for non-commercial use", so it is not the default remote path. Remote use means a self-hosted hub reached through the owner's own VPN or SSH.
- Open decision: the daemon-to-hub transport and its authentication (research suggested an outbound WebSocket from each daemon).
- Open decision: what may leave a machine. The PoC feed carries message excerpts and paths, and the history view shows full tool output.
- Open decision: how the schema is versioned after `v0`.

### Consequences

- Good, because a new agent needs only an adapter; the hub and the TUI do not change.
- Good, because a daemon is useful alone on one machine before any hub exists.
- Bad, because aphelion owns a schema and its compatibility.
- Bad, because each adapter tracks another product's internals; opencode's SQLite schema saw about 30 migrations between 2026-01 and 2026-06, so the adapter uses the SSE stream or a plugin, not the database.
- Bad, because v1 has no built-in cross-network path; a remote team sets up its own VPN or SSH.

### Confirmation

- A schema test fails if a top-level field name refers to a specific agent; agent-specific data appears only under `raw`.
- Each adapter has golden NDJSON fixtures that the hub and the TUI tests consume unchanged.

## Pros and cons of the options

### Own agent-neutral schema

- Good, because the hub and the TUI never touch agent internals, which is also the idea herdr's agent-neutral state vocabulary follows.
- Bad, because it is one more contract to maintain.

### ACP

- Good, because it is an open standard that many agents speak, with a structured `session/update` stream.
- Bad, because it cannot watch a human's already-running TUI session.

### Claude Code messaging and Remote Control

- Good, because they are built in.
- Bad, because they reach only your own sessions and only Claude Code.

### Message broker

- Good, because brokers offer pub/sub and request/reply.
- Bad, because Kafka needs a JVM broker and ongoing operations for a few messages a minute, and any broker is an extra service against the single-binary goal (ADR 0002).

## More information

- Client answers and owner statements, 2026-10-15, in the setup session.
- Feed schema: `~/DEV/aphelion-poc/01-session-board/README.md` (2026-10-17).
- Cross-session messaging and Remote Control: https://code.claude.com/docs/en/cross-session-messaging and https://code.claude.com/docs/en/remote-control (checked 2026-10-15).
- opencode server and plugins: https://opencode.ai/docs/server/ and https://opencode.ai/docs/plugins/ (checked 2026-10-15).
- ACP overview and transports: https://agentclientprotocol.com/protocol/overview and https://agentclientprotocol.com/protocol/transports (checked 2026-10-15).
- Tailscale pricing, non-commercial clause: https://tailscale.com/pricing (checked 2026-10-14).
- herdr socket API: https://herdr.dev/docs/socket-api/ (checked 2026-10-15).
