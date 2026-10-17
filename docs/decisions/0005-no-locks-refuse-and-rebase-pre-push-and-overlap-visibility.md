---
title: "No file locks or claims; refuse-and-rebase pre-push hook plus overlap visibility"
status: proposed
date: 2026-10-17
deciders: product owner
consulted: Claude research 2026-10-14..17
---

# 0005 No file locks or claims; refuse-and-rebase pre-push hook plus overlap visibility

## Context and problem statement

The client asked that an agent can lock files or directories "kind of like a mutex", with a justification and an enforced release. Every agent works in its own worktree on its own ticket branch (ADR 0010), so each already has a private copy of every file; the real hazard is two branches changing the same files and conflicting at merge. The 2026-10-14 research proposed advisory path claims with leases. On 2026-10-15 the owner objected: "I don't want agents to be able to specify an expiry time for the lease, as they can easily over or underestimate", and suggested instead "a git pre-push hook that forces the agent to rebase, or see if master has moved for the particular set of files it is working on, and rebase before pushing to the branch". The 04 PoC built that design, and the owner approved it on 2026-10-17.

## Decision drivers

- No agent-chosen durations anywhere.
- No lock that can be forgotten, held too long, or become a bottleneck.
- Conflicts are resolved by the agent before its PR is updated, not by the owner at merge.
- Agents must not be able to bypass the gate.
- People should see overlapping work early.

## Considered options

1. No locks; a pre-push hook that refuses only on overlapping files, a bypass guard, and an overlap view.
2. Advisory path claims with leases and a PreToolUse deny on claimed paths (the 2026-10-14 proposal).
3. Claims with no lease, released by PR state and session liveness.
4. A strict pre-push hook that refuses whenever main has moved at all.
5. Nothing before merge; let GitHub surface conflicts.

## Decision outcome

Chosen option: 1, because no shipping parallel-agent product surveyed implements path locks, Cursor reported that agent-held locks failed, and agents resolve merge conflicts well when they have to.

- No locks, claims or leases in v1, and no time-based lease ever. If a hard claim is reconsidered, it needs its own ADR, and its life must be bound to PR state and session liveness, never to a duration.
- A versioned pre-push hook, `.githooks/pre-push` (variant B in the research): it fetches `origin/main` and, for each pushed branch, compares the files changed in `merge-base..branch` with the files changed in `merge-base..origin/main`. It refuses the push only when the two sets share a file, prints those files, and tells the agent to fetch, rebase onto `origin/main`, resolve, re-test and push with `--force-with-lease`. It ignores pushes of main and branch deletions, and refuses if the fetch fails. The pickup script sets `core.hooksPath` per clone; worktrees share it.
- A PreToolUse hook on Bash denies `--no-verify`, `-n` on `git commit` and `git push`, and any change to `core.hooksPath`, because `--no-verify` skips git hooks (verified in testing).
- The hub computes an overlap view from pushed branches (`git diff --name-only origin/main...<branch>` for each branch, then the files touched by more than one branch). The TUI shows an overlap count on each agent row and the shared files in the detail pane (ADR 0007).
- Open decision: a warn-only PreToolUse hook that tells an agent, before it edits a file, that another open branch touches it. Support for `additionalContext` on PreToolUse was not verified in the PoC.
- Open decision: how early agents push, since the hook and the overlap view see only pushed branches.
- Open decision: whether file-level overlap is too noisy for widely shared files (README, go.mod, schema files).
- Open decision: main's ruleset beyond squash-only merges, including "require branches to be up to date" (the research advised leaving it off at first) and GitHub's merge queue (available to public repositories owned by an organization).

### Consequences

- Good, because nothing can be left locked, and no agent waits on another.
- Good, because a refused push names the exact files and the exact fix.
- Good, because the hook and the guard are small, deterministic and were tested against a bare remote.
- Bad, because two agents can still do overlapping work; the gate prevents wasted merges, not wasted effort.
- Bad, because the check is file-level: a semantic conflict across different files still needs CI on the rebased head.
- Bad, because the hook needs network access to origin.
- Bad, because a pattern match over command text is a guard, not a sandbox.

### Confirmation

- A test drives the hook against a bare remote, as the 04 PoC did: disjoint files pass, overlapping files are refused, branch deletions pass, and a rebased branch passes.
- A hook test feeds the Bash guard sample commands and checks the deny output.
- A test checks that the pickup script leaves `core.hooksPath` set to `.githooks`.

## Pros and cons of the options

### Refuse on overlap, bypass guard, overlap view

- Good, because only real file overlap costs a rebase.
- Bad, because visibility depends on agents pushing early.

### Path claims with leases

- Good, because it could stop a second edit before work is wasted.
- Bad, because agents choose or inherit durations, which the owner rejected.
- Bad, because Cursor found agents "would hold locks for too long, or forget to release them entirely", and that even working locks became a bottleneck.

### Claims bound to PR state and liveness

- Good, because a crash releases the claim.
- Bad, because a live session sitting on an unmerged PR still blocks others for hours.

### Strict pre-push (refuse whenever behind main)

- Good, because every push is fully up to date.
- Bad, because every merge forces every other agent to rebase, even with disjoint files.

### Nothing before merge

- Bad, because conflicts surface late, at merge time, on the owner's side.

## More information

- Owner statements, 2026-10-15, and approval of the 04 PoC design, 2026-10-17, in the setup session.
- 04 PoC: `~/DEV/aphelion-poc/04-overlap-prepush/README.md` (2026-10-15).
- Cursor, scaling long-running autonomous coding: locks held too long or forgotten, then a bottleneck; workers resolve conflicts themselves: https://cursor.com/blog/scaling-agents (checked 2026-10-15).
- Anthropic, building a C compiler with parallel agents: "Merge conflicts are frequent, but Claude is smart enough to figure that out": https://anthropic.com/engineering/building-c-compiler (checked 2026-10-15).
- arXiv 2607.04697: 33,596 agent PRs in 2,807 repositories; textual conflicts in 41.7% of cross-agent co-active pairs against 19.8% for same-agent pairs; mostly uncoordinated PRs: https://arxiv.org/abs/2607.04697 (checked 2026-10-15).
- Product survey (Claude Code worktrees and agent teams, Cursor, Codex cloud, Jules, Copilot coding agent, Conductor): none implements cross-agent path locks; conflicts research note (checked 2026-10-15).
- `core.hooksPath` and pre-push input: https://git-scm.com/docs/githooks (checked 2026-10-15).
- Merge queue availability: https://github.blog/changelog/2023-07-12-pull-request-merge-queue-is-now-generally-available/ (checked 2026-10-15).
