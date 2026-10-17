---
title: "Implementation language Go with Charm v2, single static binary"
status: proposed
date: 2026-10-17
deciders: product owner
consulted: Claude research 2026-10-14..17
---

# 0002 Implementation language Go with Charm v2, single static binary

## Context and problem statement

aphelion has four parts: a per-machine daemon, a hub, a terminal UI, and tooling such as the hook receiver and a CLI. All of it must install on developers' machines and be maintained for years by one human who reviews every agent-written merge. Which language and TUI stack should it use?

The owner set the frame on 2026-10-14: "I recommend against suggesting complex languages like rust initially, as while the perfomance benefits are nice, I don't have experience with it which would make my job harder. We can look later down the line once the project is built to doing something like a re-write/port into rust." On 2026-10-15 the owner confirmed "I have written go" and agreed to Go with Bubble Tea, Bubbles and Lip Gloss.

## Decision drivers

- The owner must be able to review every merge in the language.
- One artifact per OS and architecture, with no runtime to install.
- A runtime suited to long-running daemons: file watching, sockets, signals, concurrency.
- A dependency set that cross-compiles without per-OS C toolchains.
- A mature, keyboard-first TUI library.
- Free tooling only.

## Considered options

1. Go with Charm v2 (Bubble Tea, Bubbles, Lip Gloss), built as one static binary.
2. TypeScript on Bun with Ink, the 2026-10-14 runner-up and planned fallback.
3. Rust with ratatui, the stack herdr uses.

## Decision outcome

Chosen option: 1, because the owner has written Go and can review it, a pure-Go dependency set builds one static binary per target with cgo disabled, and the Charm v2 libraries are out of beta and run Charm's own Crush agent in production.

- Toolchain: Go 1.27.2, the current stable release on 2026-10-14, installed user-locally on megatron.
- TUI: Bubble Tea, Bubbles and Lip Gloss v2 from the vanity import paths `charm.land/bubbletea/v2`, `charm.land/bubbles/v2` and `charm.land/lipgloss/v2`. The PoCs pinned v2.1.0, v2.2.1 and v2.0.6.
- Build: `CGO_ENABLED=0` and one static binary. Storage uses the pure-Go `modernc.org/sqlite` (ADR 0006).
- Rust is excluded for now. A port after the product is built is possible; it is not planned.
- TypeScript was the fallback if a one-week Go spike failed. The owner already writes Go, so the spike and the fallback are both dropped.
- Open decision: the `go` directive in go.mod. The 2026-10-14 research found that `charm.land/bubbletea/v2` and `modernc.org/sqlite` both require Go 1.26, so 1.26.0 is the floor; 1.27.2 is the toolchain.
- Open decision: the supported OS and architecture matrix, and whether there is a binary size budget (research suggested a CI size check; no number is decided).
- Open decision: a CI check that the `modernc.org/libc` version in go.mod matches the one `modernc.org/sqlite` pins, as the 2026-10-14 research suggested.

### Consequences

- Good, because users install one file and need no runtime.
- Good, because `go build`, `go vet` and `go test` give objective pass or fail signals, which suits a human reviewing agent code.
- Good, because golangci-lint, including `mnd` (ADR 0001), is available.
- Good, because Crush is a large open codebase on the same libraries that agents can take idioms from.
- Bad, because Ultraviolet, the renderer under Bubble Tea v2 and Lip Gloss v2, had no tagged release on 2026-10-14 and its README says the API may change, so exact versions must be pinned.
- Bad, because v2 changed APIs that agents may remember in v1 form: `View()` returns a `tea.View`, keys arrive as `tea.KeyPressMsg`, and Lip Gloss `Width` includes border and padding (06 PoC notes).
- Bad, because `modernc.org/sqlite` requires downstream modules to pin the same `modernc.org/libc` version it pins, so an unreviewed `go get -u` can break the build.
- Bad, because a later Rust port would be a rewrite.

### Confirmation

- CI builds with `CGO_ENABLED=0`, so a dependency that needs cgo fails the build.
- go.mod pins exact versions of the three Charm libraries at their `charm.land` paths and carries a `toolchain go1.27.2` line.

## Pros and cons of the options

### Go with Charm v2

- Good, because the owner can review it.
- Good, because the standard library covers HTTP, sockets, JSON, structured logging and process control.
- Good, because PoCs 01, 03 and 06 were built and tested on Go 1.27.2 with these libraries and no cgo.
- Bad, because Bubbles has no split-pane widget, so layout code is hand-written.
- Bad, because the renderer layer is still moving.

### TypeScript on Bun with Ink

- Good, because Ink powers Claude Code and Gemini CLI, and the official MCP TypeScript SDK is the reference SDK.
- Bad, because Bun single-file executables are large: Bun's docs call them "still way too big", and opencode's Bun-built linux-x64 tarball was about 60.7 MB compressed.
- Bad, because Ink 8 drops mouse reports.
- Bad, because it is no longer needed as a fallback once the owner writes Go.

### Rust with ratatui

- Good, because herdr shows a ratatui single binary can run a full agent multiplexer.
- Good, because of its performance.
- Bad, because the owner has no Rust experience and reviews every merge.

## More information

- Owner statements, 2026-10-14 and 2026-10-15, in the setup session.
- Go stable releases 1.27.2 and 1.26.9: https://go.dev/dl/ (checked 2026-10-14).
- Bubble Tea v2.1.0, Bubbles v2.2.1, Lip Gloss v2.0.6; v2 out of beta on 2026-02-23: https://github.com/charmbracelet/bubbletea/releases and https://charm.land/blog/v2/ (checked 2026-10-14).
- Ultraviolet README, "The API may change": https://github.com/charmbracelet/ultraviolet (checked 2026-10-14).
- Crush v0.98.1 on the same libraries: https://github.com/charmbracelet/crush/releases (checked 2026-10-14).
- modernc.org/sqlite changelog (Go 1.26 required, libc pin): https://gitlab.com/cznic/sqlite/-/raw/master/CHANGELOG.md (checked 2026-10-14).
- cgo is disabled by default when cross-compiling: https://pkg.go.dev/cmd/cgo (checked 2026-10-14).
- Bun executables: https://bun.sh/docs/bundler/executables (checked 2026-10-14). Ink 8.0.0: https://github.com/vadimdemedes/ink/releases/tag/v8.0.0 (checked 2026-10-14).
- herdr stack (Rust, ratatui 0.30): https://github.com/herdrdev/herdr (checked 2026-10-14).
- Bubble Tea v2 notes: `~/DEV/aphelion-poc/06-exec-view-tui/README.md` (2026-10-15).
