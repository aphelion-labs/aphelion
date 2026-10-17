---
title: "Record decisions as ADRs and forbid unexplained constants"
status: proposed
date: 2026-10-17
deciders: product owner
consulted: Claude research 2026-10-14..17
---

# 0001 Record decisions as ADRs and forbid unexplained constants

## Context and problem statement

aphelion is built mostly by coding agents that work from specs and tickets, with one human, the product owner, reviewing and merging. On 2026-10-17 the owner reviewed a proof of concept whose detail pane showed only "the last 20 events". Nobody had asked for 20; the number came from a brief the assistant wrote. The owner's response:

> Do NOT make arbitrary design decisions like that on your own. Do not inject 'magic numbers' anywhere without justification or bringing it up with me first. [...] We must incorporate some kind of ADR to record decisions and keep track of why they were implemented as such.

The owner named the risk: silent choices are how an implementation drifts away from the client's requirements. How do we keep every limit, timeout, threshold, size and default in aphelion traceable to a reason, when most of the code is written by agents that will readily pick a plausible-looking number?

## Decision drivers

- Drift between the client's requirements and the code starts with silent choices.
- Agents write most of the code, so a rule that lives only in a prompt or in someone's memory is not enforced.
- One human reviews every merge; review time should go to design, not to hunting for constants.
- Later agents, including the fresh review responder (ADR 0010), need the reasons in the repository, not in a chat log.
- Rejected alternatives must survive, so an option is not proposed again without new evidence.

## Considered options

1. MADR files in `docs/decisions/`, a deterministic lint for unnamed numbers, and a reporting rule for subagents.
2. Decisions recorded only in PR descriptions and commit messages.
3. Decisions recorded in GitHub Issues or Discussions.
4. Code comments only.

## Decision outcome

Chosen option: 1, because it is the only option that keeps reasons versioned with the code, reviewable in the same diff, readable by agents as local files, and partly enforced by a machine rather than by memory.

The rule. Before it is built, every design choice that introduces a constant or a non-obvious default is one of:

- traced to a spec requirement (ADR 0004), cited next to the constant;
- derived from a stated constraint and recorded in an ADR, with the ADR number cited next to the constant;
- a documented configuration knob whose default is itself traced or recorded; or
- asked of the owner first. Until the owner answers it is labelled "Open decision" wherever it appears (ADR, PR body, PoC README) and is never presented as design.

Spec requirements are the first source of numbers, an ADR is the second, and the owner is the third. A value that came from an assistant's brief is not a decision by itself.

Mechanics:

- One decision per file, named `NNNN-kebab-title.md`, in MADR layout, including the rejected alternatives. A new ADR starts as `proposed`; only the owner sets `accepted`. A decision that changes gets a new ADR that supersedes the old one.
- Go code is linted by golangci-lint with the `mnd` (magic number detector) linter enabled, so an unnamed number literal fails the lint.
- Every subagent brief forbids unexplained constants and requires a "decisions I made" list in the report. A placeholder value in a PoC is labelled as a placeholder and listed as an open decision.

### Consequences

- Good, because every number has a findable reason or is visibly open.
- Good, because the reviewer bot and the fresh responder can read the reasons (ADR 0010, ADR 0011).
- Good, because the commonest failure, a bare literal in Go, is caught without a human.
- Bad, because every change carries more ceremony; small choices still need a sentence somewhere.
- Bad, because `mnd` only forces a number to be named; it cannot judge whether the name is justified. It does not see numbers inside strings (for example a port inside an address string), it always ignores 0, 1, 0.0 and 1.0, and it always skips `_test.go` files. Review remains the check for those.
- Bad, because open decisions accumulate and need the owner's time.

### Confirmation

- CI runs golangci-lint with `mnd` enabled on every PR to a Go repository. Open decision: the `mnd` settings (enabled checks, ignored numbers, ignored functions), which are recorded once chosen.
- A named constant's doc comment cites a spec requirement, an ADR number, or "Open decision". Reviewers, human and bot, check this.
- A subagent report without a "decisions I made" list is sent back.
- Each PoC README carries a constants table that marks every value as justified or open, as the 01 PoC README does.

## Pros and cons of the options

### MADR files, lint and subagent rule

- Good, because the files are versioned with the code and reviewed in the same PR diff.
- Good, because agents read them as local files with no authentication or rate limit.
- Good, because MADR is a published format that uses exactly this file naming and folder.
- Bad, because writing them takes discipline, and the lint covers Go only.

### PR descriptions and commit messages only

- Good, because no extra files exist.
- Bad, because squash merge keeps one message per PR, and rejected alternatives end up lost in review threads.
- Bad, because there is no index, so an agent cannot find a decision by topic.

### GitHub Issues or Discussions

- Good, because comment threads suit debate.
- Bad, because they are not versioned with the code and not part of the PR diff.
- Bad, because agents need API calls and a token to read them.

### Code comments only

- Good, because the reason sits next to the code.
- Bad, because there is no place for rejected alternatives or for decisions that are not code, such as the license or the repository layout.

## More information

- Owner feedback, 2026-10-17, in the setup session; summarised in the project memory note "feedback-no-magic-numbers-record-decisions".
- MADR 4.0.0 (released 2024-09-17), file pattern `NNNN-title-with-dashes.md` in `docs/decisions`: https://adr.github.io/madr/ (checked 2026-10-14).
- golangci-lint `mnd` settings and defaults ("An analyzer to detect magic numbers"; default checks argument, case, condition, operation, return, assign): https://golangci-lint.run/docs/linters/configuration/ (checked 2026-10-17).
- First application of the rule: the constants table in `~/DEV/aphelion-poc/01-session-board/README.md` (2026-10-17).
