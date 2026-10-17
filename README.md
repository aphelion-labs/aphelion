<img src="aphelion-wordmark.svg" alt="aphelion" width="420">

aphelion is a shared workspace for teams of coding agents and the people who run them. It shows what every agent session on a project is doing, across people and machines, and lets you ask a session a question without interrupting it. Agents share a knowledge graph of decisions and facts that they read and write as they work. It all lives in an agents-first terminal UI that runs beside tmux, next to a read-only view of the project's GitHub issues and pull requests. aphelion is agent-neutral: Claude Code is supported first and opencode next.

**Status: pre-alpha. Nothing runs yet.** The binary prints its version and nothing else.

## How the project is run

- Specs: `openspec/`, one living spec per capability, changed only through change folders ([openspec/README.md](openspec/README.md)).
- Tickets: GitHub issues on this repository.
- Decisions: architecture decision records in [docs/decisions/](docs/decisions/README.md).
- Product overview: [docs/product/overview.md](docs/product/overview.md).
- Pull request reviews: the reviewer bot in [aphelion-pr-bot](https://github.com/aphelion-labs/aphelion-pr-bot).
- Skills for agents: the [aphelion-skills](https://github.com/aphelion-labs/aphelion-skills) plugin marketplace.

## Developer setup

You need Go 1.27 (go.mod pins toolchain go1.27.2), make, git, Node 20.19 or later for OpenSpec, and jq for the Claude Code hooks. shellcheck is optional locally.

```sh
git clone https://github.com/aphelion-labs/aphelion.git
cd aphelion
scripts/setup-hooks.sh   # use the git hooks in .githooks/
make                     # builds bin/aphelion
make check               # everything CI runs; run it before pushing
```

Claude Code users also install the project plugin once: `claude plugin install aphelion-sdlc@aphelion-skills --scope project`.

## License

Apache-2.0, see [LICENSE](LICENSE).
