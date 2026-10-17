---
title: "PR reviewer bot in its own repository on the Anthropic API"
status: proposed
date: 2026-10-17
deciders: product owner
consulted: Claude research 2026-10-14..17
---

# 0011 PR reviewer bot in its own repository on the Anthropic API

## Context and problem statement

Every agent PR is reviewed before the owner merges it (ADR 0010). The owner's constraints from 2026-10-14: the reviewer bot runs on the Claude API with about 200 USD a month of credits on the Anthropic Console, Claude Sonnet 5.5 by default, with no cost optimisation yet; it lives in its own repository; two persona reviews per PR; bots post verdicts only, and the owner is the sole merger. On 2026-10-15 the owner asked "Why two fixed personas? I thought we discussed 8?" and proposed a lightweight Haiku model to pick the personas. The owner's lecture notes advise that the reviewer's underlying model should come from a different provider than the implementer's, because shared biases hide problems; the owner answered: "Keep this as anthropic for now, I will look into something like openai models down the line."

## Decision drivers

- Review depth where the change needs it, within a fixed API budget.
- Some areas (security, supply chain) must never be skipped when touched.
- The owner stays the only merge gate.
- Reduce the chance that the reviewer shares the implementer's blind spots.
- Bot reviews must be able to trigger the responder (ADR 0010).

## Considered options

1. Eight personas; a Haiku 5.5 classifier picks the top two, plus deterministic forced rules and a label override; comment-only reviews and check runs.
2. Two fixed personas.
3. Deterministic scoring only (labels, path globs, keywords), as the 2026-10-14 research proposed.
4. All eight personas on every PR.
5. A bot that submits APPROVE or REQUEST_CHANGES reviews.
6. A second model provider now.

## Decision outcome

Chosen option: 1, because a classifier that reads the PR's intent picks the most relevant pair for cents, forced rules guarantee coverage where it matters, the owner can always override, and comment-only output keeps the owner as the only gate.

- Repository: `aphelion-pr-bot`, separate from the product (ADR 0012), Apache-2.0 (ADR 0003). Open decision: how the product repository invokes it (the research proposed a reusable workflow called from a thin caller workflow), and the bot's implementation language (the research proposed TypeScript before Go was chosen for aphelion).
- Eight personas: spec-conformance; correctness-and-tests; security-and-trust-boundaries; concurrency-and-performance; api-and-architecture-consistency; docs-and-developer-experience; dependencies-and-supply-chain; ux-and-tui-behavior.
- Selection: Claude Haiku 5.5 reads the PR title, body, labels and changed-file list and ranks all eight personas with a confidence; the top two run. Deterministic forced rules add a persona regardless of rank, for example security whenever auth, crypto or dependency files change. A label added by the owner overrides the pick. Open decision: the forced-rule path lists, the override label names, and the most personas allowed on one PR when forced rules add to the top two (the research suggested three).
- Output: each persona posts one review with event COMMENT, inline comments bundled, plus one check run named for the persona. The bot never submits APPROVE or REQUEST_CHANGES. Open decision: which personas' check runs may conclude `failure`, and whether any become required checks.
- Merge: the owner merges. Agent PRs are authored by the owner's GitHub account, and GitHub does not let a PR's author approve it, so the merge gate is required status checks plus the owner pressing merge. A separate agent identity is a later option.
- Models: Sonnet 5.5 reviews and Haiku 5.5 classifies, on Anthropic API credits. The reviewer's model family differs from the implementer's, as a partial mitigation of self-preference bias: Panickssery et al. (NeurIPS 2024) found LLM evaluators favour their own outputs, with the effect tracking self-recognition. Partial, because both are Anthropic models and that paper tested summarisation, not code. Anthropic only for now; OpenAI may be added later. Open decision: which model implementers run; no source records it, and it must be recorded so the difference can be checked.
- Posting identity: a GitHub App token or a PAT, so that a bot review starts the responder workflow. Open decision: App or PAT.
- Open decision: the review round cap, deduplication of findings across rounds, and fork PR handling.

### Consequences

- Good, because each PR gets the two most relevant perspectives instead of a fixed pair.
- Good, because classification is cheap: Haiku 5.5 costs 0.10 USD per million input tokens and 0.50 USD per million output tokens.
- Good, because the owner remains the only person who can merge.
- Bad, because the classifier can misjudge; forced rules and labels are the backstop.
- Bad, because models from one vendor may share blind spots; the lecture's different-provider advice is deferred.
- Bad, because comment-only reviews never block a merge, so the owner must read them.
- Bad, because review spend draws on the monthly API budget; the lecture notes' example pipeline paid about 1.04 USD per PR review on another provider's model, which is not a aphelion measurement.

### Confirmation

- A bot test asserts every review it submits uses event COMMENT.
- Each check run's summary records the classifier's ranking, the forced rules that fired and any label override, so a selection can be reproduced.
- main's ruleset has no required-approvals rule; it relies on required status checks.

## Pros and cons of the options

### Haiku classifier, forced rules, label override

- Good, because it reads intent in the PR text, which path globs cannot.
- Bad, because the classifier is a model call that can be wrong.

### Two fixed personas

- Good, because it is the simplest.
- Bad, because six personas would never run; the owner rejected it.

### Deterministic scoring only

- Good, because it is reproducible and free.
- Bad, because it needs globs tuned to a layout that does not exist yet, and misses intent stated in the PR body.

### All eight on every PR

- Good, because nothing is missed.
- Bad, because it costs four times as much and buries the owner in noise.

### APPROVE or REQUEST_CHANGES

- Bad, because whether a bot approval counts toward required approvals is contested, and a bot's REQUEST_CHANGES can leave the merge box blocked until that same reviewer clears it.

### Second provider now

- Good, because a different vendor is a stronger mitigation of shared bias.
- Bad, because the owner deferred it.

## More information

- Owner constraints and decisions, 2026-10-14 and 2026-10-15; lecture notes `onenote-ai-native-sdlc.pdf` (2026-10-14).
- Persona definitions and GitHub mechanics: bots-core and bots-github research notes (checked 2026-10-14).
- Panickssery, Bowman, Feng, "LLM Evaluators Recognize and Favor Their Own Generations", NeurIPS 2024: https://arxiv.org/abs/2404.13076 (checked 2026-10-17).
- PR authors cannot approve their own PRs: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/reviewing-changes-in-pull-requests/approving-a-pull-request-with-required-reviews (checked 2026-10-14).
- Check runs and required status checks: https://docs.github.com/en/rest/checks/runs and https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches (checked 2026-10-14).
- Claude pricing (Haiku 5.5, Sonnet 5.5): https://platform.claude.com/docs/en/about-claude/pricing (checked 2026-10-15).
