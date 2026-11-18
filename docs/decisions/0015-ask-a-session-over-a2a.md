---
title: "Ask a session over the A2A protocol at the hub"
status: proposed
date: 2026-11-18
deciders: product owner
consulted: Claude research 2026-10-15 and 2026-11-18
---

# 0015 Ask a session over the A2A protocol at the hub

## Context and problem statement

"Ask a session a question without interrupting it" is one of the four things aphelion does (docs/product/overview.md). The hub routes a question to the daemon on the target's machine, the daemon answers from a read-only fork of the session (ADR 0007), and the answer streams back to whoever asked: the TUI, the MCP tool, and in future other agents and other networks (ADR 0009). The question is what contract the asking side uses. ADR 0009 chose an agent-neutral schema for observation and deferred an A2A endpoint. On 2026-11-18 the owner asked why the ask contract should be invented now and replaced with A2A later, rather than built on A2A from the start.

The daemon-to-hub channel is not what this decision is about. Daemons sit behind NAT and dial out to the hub, so that channel is internal and exists for the feed regardless. This decision is about the client-facing ask API on the hub.

## Decision drivers

- The ask feature is request-and-reply with streaming and a waiting state, which is the shape A2A standardises.
- Other agent kinds and other networks must be able to ask without aphelion inventing a second contract (ADR 0009).
- One contract from the start avoids a rewrite of the TUI, the MCP tool and the adapters later.
- Single static binary, no extra service (ADR 0002).
- No unexplained constants or surface beyond what is needed (ADR 0001).

## Considered options

1. Expose the hub's ask API as an A2A server from the first implementation, using the official Go SDK.
2. Our own HTTP or WebSocket ask API now, with an A2A facade added when a second agent kind or cross-network use arrives.
3. Claude Code's native cross-session messaging as the only ask path.

## Decision outcome

Chosen option: 1, because the ask API's external shape is an A2A task in every respect that matters, the official Go SDK exists, is Apache-2.0 and is maintained, and building the facade first costs about the same as building a bespoke API while removing a planned rewrite.

- The hub is the A2A server. It serves one Agent Card at the well-known path. Open decision: one skill per live session, or one "ask a session" skill that takes the session as a parameter.
- Minimum surface in v1: send message, send message with streaming, get task. The card declares push notifications off. List tasks and cancel task are added only when something needs them.
- A2A task states map onto aphelion's session states; a session waiting on a question is reported as `input-required`.
- Transport in v1: JSON-RPC over HTTP, which the SDK supports alongside gRPC. Open decision: whether gRPC is also enabled.
- Authentication is declared as an A2A security scheme on the card, so the hub has one auth mechanism. Which scheme is the open decision carried from ADR 0009.
- The hub forwards a task to the owning daemon over the internal channel; the daemon answers through its adapter. The Claude Code adapter answers from a read-only fork (ADR 0007); an opencode adapter answers its own way. Adapters do not speak A2A.
- Consumers are A2A clients through the SDK's client package: the TUI, the MCP tool, and later other agents and other hubs.
- The SDK is pinned to an exact version and upgraded deliberately, as OpenSpec is (ADR 0004). Version at decision time: github.com/a2aproject/a2a-go/v2 v2.9.0, released 2026-11-17.
- This ADR amends ADR 0009, which deferred an A2A endpoint; everything else in ADR 0009 stands. A2A is not the observation protocol, for the same reason ACP is not: it has no observer role.

### Consequences

- Good, because the TUI, the MCP tool and future agents share one contract from day one.
- Good, because cross-network asking (the roadmap item) reuses a standard, authenticated protocol instead of a bespoke tunnel.
- Good, because MCP and A2A keep distinct roles: MCP is how aphelion's agents reach aphelion's tools; A2A is how any client reaches a session.
- Bad, because the SDK moved through four minor versions in the months before this decision; pinning and deliberate upgrades are required.
- Bad, because a JSON-RPC round trip replaces an in-process call on the same machine, which is negligible for a question answered by a model.
- Bad, because the daemon ticket now depends on the hub carrying a task state, not only a message.

### Confirmation

- The hub's Agent Card is fetched and validated in a test, and the three supported operations have contract tests against the pinned SDK's client.
- A test asserts that no adapter imports the A2A packages.
- The SDK version appears exactly once in `go.mod`; Dependabot proposes upgrades and the owner decides.

## Pros and cons of the options

### A2A at the hub from the start

- Good, because the shape fits and the SDK is official, Apache-2.0 and active.
- Bad, because it adds a dependency on a young specification (v1.0 in 2026-03, v1.0.1 in 2026-05).

### Own ask API, A2A facade later

- Good, because nothing new is learned for the first implementation.
- Bad, because it schedules a rewrite of every consumer, which the owner asked to avoid.

### Native cross-session messaging only

- Good, because it is built in.
- Bad, because it reaches only your own Claude Code sessions, interrupts the live session, and offers nothing to other agents or other networks.

## More information

- Owner's question and decision, 2026-11-18, in the setup session.
- A2A specification and governance: https://tyk.io/learning-center/a2a-protocol-architecture-and-technical-specification/ and https://www.specification.website/spec/agent-readiness/a2a-agent-cards/ (checked 2026-11-18).
- Official Go SDK: https://github.com/a2aproject/a2a-go (module github.com/a2aproject/a2a-go/v2, v2.9.0 on 2026-11-17, Apache-2.0; packages a2asrv, a2aclient, a2agrpc; checked 2026-11-18 via the Go module proxy).
- ADR 0007 (fork-based ask), ADR 0009 (agent-neutral hub API, amended here).
