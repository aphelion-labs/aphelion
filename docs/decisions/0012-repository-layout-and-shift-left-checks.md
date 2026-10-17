---
title: "Repository layout and shift-left checks"
status: proposed
date: 2026-10-17
deciders: product owner
consulted: Claude research 2026-10-14..17
---

# 0012 Repository layout and shift-left checks

## Context and problem statement

The owner's lecture notes on AI-native development (2026-10-14) recommend a meta repository with no shipping code (hooks, `settings.json`, a project-wide CLAUDE.md, architecture and policy docs), a separate skills repository published as a team plugin marketplace, feedback to coding agents as early as possible ("shift left") with a time budget per stage, files kept under 1,500 lines, deterministic linters, and evals for skills. On 2026-10-14 the owner put the reviewer bot in its own repository; on 2026-10-15 the owner said: "we should have a skills repo, and skip the meta repo". How are the repositories laid out, and which checks run where?

## Decision drivers

- Agents should learn about a failure during the coding loop, not minutes later from CI.
- Deterministic tools check AI-written code.
- Skills are code too and need tests.
- As few repositories as the work needs, for one maintainer.
- Free tiers only.

## Considered options

1. Three repositories (product, bot, skills marketplace) with staged checks: PostToolUse, pre-commit, pre-push, CI.
2. The lecture's layout: a meta repository plus the three.
3. One repository holding product, bot and skills.
4. CI as the only check.

## Decision outcome

Chosen option: 1, because it follows the lecture's skills-marketplace and shift-left advice while leaving out a meta repository that two shipping repositories do not yet need.

- Repositories, all public in the aphelion-labs GitHub organization: `aphelion`, the product (daemon, hub, TUI, tooling; Go module `github.com/aphelion-labs/aphelion`), which also holds its own `.claude/` settings and hooks, CLAUDE.md, specs (ADR 0004) and these ADRs; `aphelion-pr-bot`, the reviewer (ADR 0011); and `aphelion-skills`, project-wide skills and plugins as a Claude Code plugin marketplace with `.claude-plugin/marketplace.json` at its root.
- Meta repository: rejected for now. With two shipping repositories it would add a checkout and a second place for docs to drift. It can be revisited if shipping repositories multiply.
- Check stages, each with a time budget:
  1. A Claude Code PostToolUse hook after each edit lints and formats the edited file in under 100 ms, and squashes the tool output before Claude sees it.
  2. git pre-commit runs in under 2 s, including the commit-message check (Conventional Commits, terse and lowercase; ADR 0010).
  3. git pre-push runs in under 100 s, including unit tests and the rebase check (ADR 0005).
  4. Full CI runs after the push.
- The budgets come from the owner's lecture notes, an example pipeline from another team, not from measurement on aphelion. They are open to revision once measured.
- Files over 1,500 lines are flagged; the lecture calls the figure "just a suggestion". Open decision: whether the flag warns or fails, and which tool raises it.
- Deterministic linters: golangci-lint including `mnd` (ADR 0001), shellcheck for shell scripts, hadolint for Dockerfiles, and gitleaks for secrets.
- Skill evals: `claude plugin eval` runs the `aphelion-skills` eval suites in CI. Every eval run and judge call is a real model call. Open decision: the pass threshold and trial count (the lecture's example used a 90% pass rate over N trials), and which credential pays for CI evals.
- Open decision: the exact tool at each stage (for example gofmt or goimports after an edit, and the scope of golangci-lint at pre-commit).
- Open decision: how git hooks are distributed (committed `.githooks/` with `core.hooksPath`, as in the 04 PoC, or a hook manager).

### Consequences

- Good, because most failures reach the agent within seconds of the edit that caused them.
- Good, because the product repository is self-contained for anyone who clones it.
- Good, because skills are shared across repositories through the marketplace and tested like code.
- Bad, because the budgets are unmeasured and a stage may exceed its budget once real tests exist.
- Bad, because local hooks run only where installed, so CI must repeat every check.
- Bad, because three repositories must be kept in step (license, CI conventions, versions).
- Bad, because skill evals spend model usage on every run.

### Confirmation

- CI repeats every check from the local stages, so a skipped hook cannot skip a check.
- `aphelion-skills` CI runs `claude plugin eval` with JSON output and fails below the agreed threshold, and validates the marketplace manifest.
- The commit-message check runs in pre-commit and again in CI.

## Pros and cons of the options

### Three repositories with staged checks

- Good, because each repository has one purpose.
- Bad, because a change that spans product and skills needs two PRs.

### Meta repository plus the three

- Good, because one checkout would hold every repository and shared guidance.
- Bad, because it is a repository with no code that two shipping repositories do not need yet.

### One repository

- Good, because there is one place to look.
- Bad, because the owner wanted the bot separate, and the lecture's marketplace pattern is its own repository.

### CI only

- Bad, because in the lecture's example a full build takes 5 to 10 minutes, which wastes agent time and tokens.

## More information

- Lecture notes, `onenote-ai-native-sdlc.pdf`, 2026-10-14 (budgets on page 2: "< 100ms", "< 2secs", "<100 secs"; full build "5 to 10 mins").
- Owner decisions, 2026-10-14 and 2026-10-15, in the setup session.
- Plugin marketplace layout: https://code.claude.com/docs/en/plugins/marketplace-reference (checked 2026-10-15).
- Plugin evals, Claude Code v2.1.269 or later, CI gating: https://code.claude.com/docs/en/plugin-evals (checked 2026-10-17).
- Linters: https://golangci-lint.run/docs/linters/configuration/, https://github.com/koalaman/shellcheck, https://github.com/hadolint/hadolint, https://github.com/gitleaks/gitleaks (checked 2026-10-17).
