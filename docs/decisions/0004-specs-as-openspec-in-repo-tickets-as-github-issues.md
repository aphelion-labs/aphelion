---
title: "Specs live in the repository as OpenSpec markdown; tickets are GitHub Issues"
status: proposed
date: 2026-10-17
deciders: product owner
consulted: Claude research 2026-10-14..17
---

# 0004 Specs live in the repository as OpenSpec markdown; tickets are GitHub Issues

## Context and problem statement

aphelion is built spec-first: specs and tickets are the authoritative source, and agents pick up tickets on their own. Where do specs and tickets live, and how do they relate? On 2026-10-14 the owner asked whether markdown specs would be "messy and rudimentary" next to Trello or Jira with history tracking. On 2026-10-15 the owner called the Jira description-history complaint nit-picky, suggested the project is small enough for a free plan, and asked whether to fork OpenSpec: "Regarding them shipping breaking re-writes, who cares? We are not going to be updating openspec regularly, we can also just only allow updates if they are minor or smaller."

Already decided: tickets are GitHub Issues, and agents may create tickets that the owner reviews before they become actionable (2026-10-14); the owner approves specs and changes on the client's behalf (2026-10-15).

## Decision drivers

- The spec in force must match the code at every commit and tag.
- Spec changes must be reviewed in the same diff as the code they justify.
- Headless agents in parallel worktrees must read specs with no OAuth, token expiry or rate limit.
- Fit with spec-driven toolkits, which all assume files.
- Public readers and contributors should need no extra account.
- Agents must not rewrite the living spec at will.

## Considered options

1. OpenSpec markdown in the product repo, used as-is and pinned; tickets in GitHub Issues; archive inside the PR.
2. Another toolkit (GitHub Spec Kit, BMAD) or a custom spec layer.
3. A SaaS tool for specs or tickets: Jira, Confluence, Trello, Linear or Notion.
4. A fork of OpenSpec.
5. OpenSpec with the archive step run after merge by a GitHub Action.

## Decision outcome

Chosen option: 1, because specs are versioned with the code, spec deltas are reviewed in the same PR diff as the code, agents get plain file access with no auth, every spec toolkit assumes files, and public readers need no account. Scale was not the reason: the honest answer given to the owner on 2026-10-15 was that this project's scale fits those free tiers. Two caps from the 2026-10-14 research are still worth knowing: Linear Free stops at 250 issues, and Notion Free allows 1,000 blocks in a workspace with two or more members.

A spec says what the product does, per capability, in the present tense, and lives as long as the code: `openspec/specs/<capability>/spec.md`, with SHALL requirements and WHEN/THEN scenarios. A ticket is a GitHub Issue: a unit of work with an owner, a status and a finish line.

| Ticket kind | Change folder | Living spec | Code |
|---|---|---|---|
| Feature | yes, `openspec/changes/<issue>-<slug>/` | updated by archive in the same PR | yes |
| Bug, code wrong | no; the ticket cites the violated requirement | untouched | fix |
| Bug, spec wrong or silent | yes, with a MODIFIED or REMOVED delta | updated by archive | maybe |
| Chore | no | untouched | yes |

The issue number ties them together: it prefixes the change folder, `Issue: #N` is written into the change's goal and `proposal.md`, and the PR closes the issue. `openspec archive` runs inside the same PR, so `openspec/specs/` on main always describes main's code.

Living-spec protection has three layers:

- A Claude Code PreToolUse hook denies agent `Edit`, `Write` and `MultiEdit` calls on `openspec/specs/**` (the 05 PoC matcher; checked against the current tool list when built), plus a Bash guard, because in the 05 PoC the denied agent tried a Bash workaround. Open decision: the Bash guard's form (a PreToolUse hook on Bash, or sandbox or permission deny rules).
- A CI check fails any PR that changes living specs without adding an archived change. It is a required check, so it is the hard gate.
- CODEOWNERS routes `openspec/specs/**` to the owner.

OpenSpec is used as-is, with no fork, pinned to an exact version everywhere it runs. Upgrades are deliberate: a PR that bumps the pin after reading the release notes, following the owner's preference for minor-or-smaller updates. Project behaviour lives in our own skills, hooks, CI and `openspec/config.yaml`, never in edits to OpenSpec's generated files. Open decision: the exact version pinned at bootstrap (the 05 PoC verified 1.14.2; the 2026-10-14 research saw 1.14.1).

OpenSpec quirks found in the 05 PoC (version 1.14.2):

- Telemetry is on by default; `OPENSPEC_TELEMETRY=0` or `DO_NOT_TRACK=1` turns it off (verified in source). Open decision: whether CI and agent environments set it.
- There is no issue-link field; `new change --goal` writes `goal:` into `.openspec.yaml`, which is where `Issue: #N` goes.
- `new change` also creates a `README.md` in the change folder.
- Archive renames the folder with a date prefix (`2026-10-15-12-show-blocked-reason`), so the issue number is no longer a prefix.
- A MODIFIED block must contain the full replacement requirement with all its scenarios; partial text drops scenarios.
- `archive --yes` only warns about unchecked tasks and archives anyway. Open decision: whether CI enforces ticked tasks.
- `init` is non-interactive only with `--tools`, and it creates `.claude/skills` and `.claude/commands/opsx`, which agents will see.
- A JSON `deny` reaches the agent as "PreToolUse:Edit hook error: <reason>".
- The PoC's CI check accepts any added file under `changes/archive/` as proof; it does not check that the archive matches the spec diff.

### Consequences

- Good, because `git log` on a spec plus the archived change folder answers "why did this requirement change, and who approved it".
- Good, because reviewer personas judge "done" against the delta in the PR.
- Bad, because the non-technical client cannot edit specs without the owner and a PR.
- Bad, because a bug fix that touches a spec carries a proposal, a delta and tasks.
- Bad, because two PRs that MODIFY the same requirement conflict at archive time and need a human.
- Bad, because OpenSpec has few core maintainers and has shipped breaking rewrites; the pin contains that.

### Confirmation

- The living-spec CI check is a required status check on main, and CI runs `openspec validate --strict` at the pinned version.
- The project `.claude/settings.json` holds the spec-edit deny hook and the Bash guard; a hook test feeds them sample tool calls.
- CODEOWNERS lists `openspec/specs/**`.

## Pros and cons of the options

### OpenSpec in repo, pinned, archive inside the PR

- Good, because OpenSpec supplies the delta grammar, `validate --strict` and a deterministic archive merge, the parts a solo developer would get subtly wrong.
- Good, because conflicts surface in the PR rebase, not after merge.
- Bad, because OpenSpec never commits, branches, pushes or links issues, so that glue is ours.

### Spec Kit, BMAD or custom

- Bad, because Spec Kit's GitHub bridge opens one issue per task and its core command was deprecated in 1.1.3; BMAD's GitHub adapter was first committed on 2026-10-02 and flagged as needing testing.
- Bad, because a custom grammar, validator and merge repeats what OpenSpec already does.

### SaaS (Jira, Confluence, Trello, Linear, Notion)

- Good, because the client gets a WYSIWYG editor and inline comments, and the team's size fits the free tiers (Jira Free 10 users, Trello Free 10 collaborators, Linear Free unlimited members).
- Bad, because the spec is not versioned with the code or reviewed in the PR diff.
- Bad, because each headless agent needs interactive OAuth or an expiring token, and spends rate-limited calls per read.
- Bad, because public readers need an account.

### Fork OpenSpec

- Bad, because nothing found needs a code change, and a fork adds upkeep.

### Archive after merge by an Action

- Good, because `openspec/specs/` would reflect only merged work.
- Bad, because the Action must push to a protected main or open a second PR per change.

## More information

- Owner statements, 2026-10-14 and 2026-10-15, in the setup session.
- 05 PoC: `~/DEV/aphelion-poc/05-spec-ticket-flow/README.md` (2026-10-15).
- OpenSpec docs (concepts, CLI, team workflow, customization): https://github.com/Fission-AI/OpenSpec/tree/main/docs (checked 2026-10-14).
- Spec Kit GitHub extension: https://github.com/github/spec-kit/blob/main/extensions/github/README.md (checked 2026-10-14).
- BMAD ticket tree: https://github.com/bmad-code-org/BMAD-METHOD/blob/main/docs/plan/set-up-the-ticket-tree.md (checked 2026-10-14).
- Free-tier limits: https://www.atlassian.com/software/jira/pricing and https://linear.app/pricing (checked 2026-10-14); Trello and Notion limits per the specs-location research note (checked 2026-10-14).
