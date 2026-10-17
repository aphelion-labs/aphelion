---
title: "Knowledge base is a property graph in SQLite with hybrid retrieval and agent-authored links"
status: proposed
date: 2026-10-17
deciders: product owner
consulted: Claude research 2026-10-14..17
---

# 0006 Knowledge base is a property graph in SQLite with hybrid retrieval and agent-authored links

## Context and problem statement

The client wants "global graph-based context with search/retrieval functionality for long term/persistent knowledge" that many agents read and write. On 2026-10-15 the owner rejected an earlier "start with a lesser prototype" framing and asked for grounded research on whether a graph is the most effective design. Claude Code's own memory is machine-local and not shared across machines, so this is a gap aphelion fills. What does the knowledge base store, and how do agents write and find knowledge? The owner approved agent-authored links, with no LLM extraction, in the 03 PoC review on 2026-10-17.

## Decision drivers

- Long-lived, multi-writer knowledge: stale facts and contradictions must stay visible, not be overwritten.
- Retrieval quality on engineering text full of identifiers, paths and error strings.
- No hub-side LLM pipeline on the Max plan: Anthropic's terms point products to API keys, and the API budget belongs to the reviewer bot.
- Single static binary, no cgo, no graph database server (ADR 0002).
- Agents rarely query memory voluntarily, so delivery matters as much as storage.
- Later additions should be justified by measurement.

## Considered options

1. An agent-authored property graph in SQLite with hybrid retrieval.
2. Notes, tags and full-text search only.
3. An LLM-extracted entity graph (GraphRAG, LightRAG, Graphiti or HippoRAG 2 style).
4. A graph database server (Neo4j or FalkorDB behind Graphiti).

## Decision outcome

Chosen option: 1, because typed notes with typed links already are a property graph, the links that matter here are known exactly by the agent that writes the note, and independent benchmarks show LLM-extracted graphs lose to plain retrieval on lookup questions while writing far more slowly.

- Storage: one SQLite database owned by the hub, through `modernc.org/sqlite`.
- Schema outline (03 PoC): `nodes` holds authored kinds (note, decision, entity) and anchor kinds (file, symbol, issue, pr, session). Anchors are upserted by a unique `canonical_key` such as `file:internal/daemon/watch.go`, so links from different agents meet on one node. `edges` are typed (for example touches_file, relates_issue, decided_in, supersedes, contradicts, depends_on) and weighted. Open decision: the final kind and edge-type lists; the 2026-10-15 research sketch was longer than the PoC's.
- Provenance on every node and edge: agent, session, machine, branch, commit, ticket and source (agent, hook, or a deterministic import).
- Bi-temporal validity on nodes and edges, modelled on Graphiti: `valid_from`/`valid_to` for when a fact held, `recorded_at`/`expired_at` for when it was recorded and retired. Nothing is hard-deleted; supersede and retract close intervals, so "as of" queries work.
- Agent-authored links: a writer passes refs (file, issue, pr, symbol, session, entity) and links (such as supersedes). No LLM extracts entities or relations in v1.
- Retrieval: FTS5 BM25 and vector nearest neighbours, fused with reciprocal rank fusion (RRF), then a one or two hop walk along typed, weighted edges with a recursive CTE. Results are filtered to currently valid facts unless a time or history view is requested. Without an embedder, search continues on BM25 plus the graph.
- Duplicate reporting on write: the hub returns the most similar active notes, and the writing agent decides whether to link, supersede or record a contradiction. Nothing is merged silently, because a naive dedup step can erase contradictions.
- Deterministic GitHub import: merged PRs, issues and ADR files become nodes, with edges from references and changed-file lists. No LLM.
- Hook delivery into Claude Code: SessionStart injects active decisions for the repo, branch and ticket; PreToolUse on file reads and edits injects notes anchored to that file; UserPromptSubmit can add top hits. All stay within Claude Code's 10,000-character `additionalContext` cap; SessionStart accepts only command and mcp_tool hooks.
- Eval harness from day one: a search log plus a hand-labelled query set, comparing BM25, vector, hybrid, and hybrid with hops. An extraction layer, a reranker or tuned fusion is added only if it measures better. Open decision: the size of the labelled set and the recall cut-off (research suggested about 50 queries and recall@10).
- Embeddings: Voyage AI and Cloudflare Workers AI (owner, 2026-10-15), behind a pluggable embedder that stores the model id and dimensions with every vector. Open decision: the default model for each provider, and whether note text may be used for provider training (Voyage may train on API data unless the account opts out, which needs a payment method on file).
- Vectors: `modernc.org/sqlite/vec`, which bundles sqlite-vec v0.1.9 as pure Go and registers `vec0`, behind a `VectorIndex` interface with an exact in-memory scan as the alternative implementation.
- Open decision: the canonical key normaliser, so `file:watch.go` and `file:internal/daemon/watch.go` cannot drift apart.
- Open decision: the 03 PoC retrieval constants: RRF k=60 (the literature's zero-label default), a candidate pool of max(3k, 30) per list, BM25 column weights 3, 1 and 0.5, the per-edge-type hop weights, the default hop count, and five similar notes returned on write.
- Open decision: KB scope (per repo, per project or org-wide), and who may supersede or retract another agent's decision.
- Future ticket: an interactive knowledge-graph view in the TUI behind a keybinding, rendered with braille characters. The owner's note, verbatim: "See `/home/arnav/TEMP/fdg-render-test`". That path was not present on megatron on 2026-10-17. File it as a GitHub issue once the repository exists.

### Consequences

- Good, because "what did we decide about X, and what replaced it" is answered by edges, not guesswork.
- Good, because a write is one transaction with no LLM call, and embeddings cost cents a month or nothing on the free tiers.
- Good, because the eval harness turns later debates into measurements.
- Bad, because link quality depends on agents passing refs, so skills and prompts must ask for them.
- Bad, because multi-hop questions across notes nobody linked are not covered; that is where HippoRAG 2 shows a modest gain.
- Bad, because embeddings add a network dependency and send note text to a third party.
- Bad, because `modernc.org/sqlite/vec` cannot be combined with `RegisterPageCache`, is brute-force only, and its transpiled speed is unbenchmarked.

### Confirmation

- Schema tests check that supersede and retract never delete rows, and that an "as of" query returns the fact valid at that time.
- The eval harness runs in CI against the labelled set and reports recall for each retrieval mode.
- A search test with no embedder configured still returns BM25 and graph results.

## Pros and cons of the options

### Agent-authored property graph in SQLite

- Good, because explicit links lose nothing to extraction, and the whole graph ships inside the single binary.
- Bad, because every write carries some instruction cost for the agent.

### Notes, tags and FTS only

- Good, because it is the simplest.
- Bad, because it has no typed links, provenance or validity, which is what the owner rejected.

### LLM-extracted entity graph

- Good, because it can find relations nobody wrote down; HippoRAG 2 gains about 2.8 F1 on average over a strong dense retriever, mostly on multi-hop sets.
- Bad, because MemoryAgentBench scores BM25 at 41.5 against GraphRAG 23.4, Mem0 21.1 and Cognee 20.6, with memory construction orders of magnitude slower.
- Bad, because only about 65.8% of answer entities reached the extracted graph in Han et al., and on real repository coding tasks VibeMemBench found 11 of 12 memory pairings at or below no memory, mostly because extraction degraded the concrete fix.
- Bad, because it needs an API key and budget; Mem0's open-source v3 removed graph memory altogether.

### Graph database server

- Bad, because Graphiti needs Neo4j, FalkorDB or Neptune plus several LLM calls per write and has no Go SDK, which breaks the single binary.

## More information

- 03 PoC: `~/DEV/aphelion-poc/03-knowledge-graph/README.md` (2026-10-15). Owner approval: setup session, 2026-10-17.
- MemoryAgentBench: https://arxiv.org/html/2507.05257v4; GraphRAG-Bench: https://arxiv.org/html/2506.05690v3; Han et al.: https://arxiv.org/html/2502.11371v3; VibeMemBench: https://arxiv.org/html/2609.23570; HippoRAG 2: https://arxiv.org/html/2502.14802 (all checked 2026-10-15).
- Mem0 v3 migration ("Graph memory is removed from the open-source SDK"): https://docs.mem0.ai/migration/oss-v2-to-v3 (checked 2026-10-15).
- "Delivery, Not Storage" (0 voluntary memory operations in 114 turns): https://arxiv.org/abs/2607.20972; "Governed Shared Memory" (dedup erasing contradictions): https://arxiv.org/abs/2606.24535 (checked 2026-10-15).
- Graphiti edge fields: https://github.com/getzep/graphiti/blob/main/graphiti_core/edges.py; RRF k=60 as the zero-label default: https://arxiv.org/abs/2210.11934 (checked 2026-10-15).
- Voyage pricing and data use: https://docs.voyageai.com/docs/pricing, https://docs.voyageai.com/docs/faq; Cloudflare Workers AI: https://developers.cloudflare.com/workers-ai/platform/pricing/ (checked 2026-10-15).
- `modernc.org/sqlite/vec`: https://pkg.go.dev/modernc.org/sqlite/vec (checked 2026-10-15).
- Claude Code hooks (`additionalContext` cap) and memory: https://code.claude.com/docs/en/hooks, https://code.claude.com/docs/en/memory; usage terms: https://code.claude.com/docs/en/legal-and-compliance (checked 2026-10-15).
