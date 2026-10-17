---
title: "License Apache-2.0, copyright held by the product owner"
status: proposed
date: 2026-10-17
deciders: product owner
consulted: Claude research 2026-10-14..17
---

# 0003 License Apache-2.0, copyright held by the product owner

## Context and problem statement

aphelion is client-commissioned and public from its first commit, meant as production-ready open source for public use. Copies released under a permissive license cannot be recalled, so the license and the copyright holder must be settled before the first push. The owner decided on 2026-10-15: "Apache2.0, I hold copyright". It applies to every aphelion repository (aphelion, aphelion-pr-bot, aphelion-skills; ADR 0012).

## Decision drivers

- Public, reusable open source with low adoption friction.
- Protection for users and contributors against patent claims.
- Compatibility with the dependencies in use (MIT Charm libraries, BSD-3-Clause `modernc.org/sqlite`, Apache-2.0 tools).
- Low friction for outside contributors.
- One human maintainer, so little license administration.

## Considered options

1. Apache-2.0.
2. MIT.
3. MPL-2.0.
4. AGPL-3.0.

## Decision outcome

Chosen option: 1, Apache-2.0 for every aphelion repository, because it is permissive, carries an explicit patent grant from contributors, is compatible with every dependency named in the 2026-10-14 research, and is the license of much of the agent tooling surveyed (herdr, the Agent Client Protocol, A2A, coder/acp-go-sdk, hugot).

- Copyright is held by the product owner, not the client.
- No contributor license agreement.
- DCO sign-off (`Signed-off-by`) is optional; no check enforces it.
- Contributions are received under Apache-2.0 itself (section 5 of the license).
- Open decision: whether a written note from the client confirming the copyright arrangement is kept before the first public commit, as the 2026-10-14 research advised.
- Open decision: whether releases generate third-party license notices, and what the NOTICE file contains.

### Consequences

- Good, because users and contributors get an express patent license, which MIT lacks.
- Good, because companies can adopt aphelion without copyleft obligations.
- Good, because the contribution path stays a normal PR with no CLA.
- Bad, because anyone may build a closed fork, including a hosted commercial service, without sharing changes.
- Bad, because without a CLA, relicensing contributed code later needs the contributors' agreement.
- Bad, because the text is longer than MIT and NOTICE handling adds a small release duty.

### Confirmation

- Each repository's first commit contains `LICENSE` with the Apache-2.0 text.
- The dependencies-and-supply-chain reviewer persona (ADR 0011) checks the license of every new dependency against Apache-2.0.

## Pros and cons of the options

### Apache-2.0

- Good, because of the explicit patent grant and the patent-termination clause.
- Good, because it is widely used and understood in Go and agent tooling.
- Bad, because it is longer than MIT and has NOTICE obligations.

### MIT

- Good, because it is the shortest permissive text.
- Bad, because it has no express patent grant.

### MPL-2.0

- Good, because file-level copyleft keeps changes to aphelion's own files open while allowing combination with closed code.
- Bad, because anyone shipping modified files takes on source-disclosure duties, which adds friction for adopters.
- Bad, because it gives the project nothing it needs that Apache-2.0 lacks.

### AGPL-3.0

- Good, because network-use copyleft would force a hosted hub's modifications to be published.
- Bad, because AGPL is commonly restricted by corporate open-source policies, which works against public adoption.
- Bad, because its main lever, network use, matters little for a tool that runs on developers' own machines.

## More information

- Owner decision, 2026-10-15, in the setup session.
- Research recommendation (Apache-2.0, no CLA, optional DCO, copyright line agreed in writing): Blueprint and critics notes, 2026-10-14.
- Licenses of surveyed tools (herdr, ACP, A2A, coder/acp-go-sdk and hugot are Apache-2.0): session-visibility and knowledge-base research notes (checked 2026-10-15).
- Apache License 2.0: https://www.apache.org/licenses/LICENSE-2.0 (checked 2026-10-17).
- Mozilla Public License 2.0: https://www.mozilla.org/en-US/MPL/2.0/ (checked 2026-10-17).
- GNU AGPL v3: https://www.gnu.org/licenses/agpl-3.0.html (checked 2026-10-17).
- Developer Certificate of Origin: https://developercertificate.org/ (checked 2026-10-17).
