---
title: "TUI is a hybrid workplace with tmux as a v1 dependency"
status: proposed
date: 2026-10-17
deciders: product owner
consulted: Claude research 2026-10-14..17
---

# 0007 TUI is a hybrid workplace with tmux as a v1 dependency

## Context and problem statement

The client's wish list asked for UX "similar to herdr", "tmux like capabilities", vim-like keybindings and a basic timestamped ticket system. On 2026-10-15 the owner set two limits: if tmux-like capabilities bring no genuine benefit they "should not be shoe-horned in to the final product", and the ticket view should not replicate Jira or GitHub Issues but be a read-only frontend over existing issues or an executive view of every connected agent's status. The 06 PoC combined both, and the owner approved it on 2026-10-17. The owner then asked whether the TUI would just "sit idle as an observability window that I would have to tab into every now and then", and whether it would make more sense to do one's own work through it. The owner accepted the hybrid below on 2026-10-17: "Yes to the hybrid, and tmux is fine".

## Decision drivers

- The view must be useful while the developer does their own work, not only when they tab to it.
- Sessions started any way (terminal, `claude -p`, background) must be visible.
- No second ticket store; GitHub Issues stays the source (ADR 0004).
- aphelion must not become a terminal multiplexer, which is a product in itself.
- Keyboard-first, vim-style navigation.

## Considered options

1. Hybrid workplace: an agents-first board plus jump, launch, popup, status line and in-session tools, relying on tmux.
2. A passive observability window only.
3. herdr-style hosting: aphelion owns the PTYs and multiplexes sessions.
4. tmux-like pane management inside the TUI.
5. A built-in ticket store.

## Decision outcome

Chosen option: 1, because it puts team state in front of developers inside their own sessions, keeps every session visible however it was started, and leaves terminal management to tmux, which Claude Code itself relies on for split-pane agent teams.

- Executive view, agents first: one row per session across people and machines, with status (ADR 0008), ticket, branch, current activity and an overlap count (ADR 0005), and a detail pane with the session's full, scrollable history read from its transcript. Open decision: the row sort order.
- Issues and PRs appear beside the agents as a read-only panel fetched from GitHub. Nothing in the TUI writes tickets.
- Ask: the detail pane can put a question to another session without interrupting it, using the fork-based Q&A approved with the 02 and 06 PoCs on 2026-10-17.
- Jump: enter on one of your own sessions switches tmux to the pane recorded in Claude Code's session registry. The registry carries a `tmux` field such as `poc-p:@30.%35` (observed on 2.1.300 and 2.1.302; undocumented).
- Launch: a start action opens a new tmux window running `claude` in the ticket's worktree.
- Popup: a tmux keybinding opens the board over whatever you are doing, through `display-popup`, and one key closes it. Open decision: the default key.
- Status line: a segment in every Claude Code session shows team state. Claude Code runs the status-line command on session events, debounced at 300 ms, plus an optional `refreshInterval` timer. Open decision: the segment's content and whether to set `refreshInterval`.
- In-session tools: a skill and an MCP tool let your own Claude ask the hub what the team is doing, and hooks inject team facts, for example when you open a file another branch touches.
- Fallback without tmux: the TUI launches `claude` in the foreground through Bubble Tea's `ExecProcess`, which pauses the TUI until the command exits. Jump and popup need tmux.
- tmux is a v1 dependency for jump and popup.
- Vim-style navigation (j/k, gg/G, h/l, /, ?, enter, esc) is kept because it is cheap. Open decision: the full keymap and whether it is user-configurable in v1.

Rejected and recorded here: a passive observability window, herdr-style PTY hosting and multiplexing, tmux-like pane management, and a built-in ticket store.

### Consequences

- Good, because team state reaches the developer without a context switch.
- Good, because sessions launched elsewhere stay visible, which a PTY host cannot offer.
- Good, because aphelion writes no terminal emulator, scrollback or detach logic.
- Bad, because users without tmux get launch but not jump or popup.
- Bad, because jump depends on an undocumented registry field that may change.
- Bad, because a status-line segment runs often and must stay fast and cheap.

### Confirmation

- TUI tests cover the board, the detail pane and the overlay layouts at a fixed terminal size.
- An integration test launches a session in a tmux window, finds its pane through the registry, and jumps to it.
- No TUI code path writes to GitHub Issues; the GitHub client used by the TUI is read-only.

## Pros and cons of the options

### Hybrid workplace

- Good, because each piece (jump, popup, status line, tools) reuses something tmux or Claude Code already provides.
- Bad, because it adds a dependency on tmux.

### Passive observability window

- Good, because it is the smallest build.
- Bad, because a board you must tab into gets ignored, which is the owner's objection.

### herdr-style PTY hosting

- Good, because it would allow live terminal views and input for hosted sessions.
- Bad, because owning PTYs, a terminal emulator, scrollback and detach semantics is a product in itself (herdr vendors portable-pty and its own ghostty-vt crate).
- Bad, because sessions started outside the host are invisible, and herdr reads Claude Code state by screen-scraping with regex manifests it updates remotely.

### tmux-like pane management

- Bad, because tmux already does it, and the owner ruled out shoe-horning it in.

### Built-in ticket store

- Bad, because it would drift from GitHub Issues and duplicate state GitHub already records.

## More information

- Owner statements, 2026-10-15 and 2026-10-17, in the setup session.
- 06 PoC: `~/DEV/aphelion-poc/06-exec-view-tui/README.md` (2026-10-15); registry `tmux` field: `~/DEV/aphelion-poc/01-session-board/README.md` (2026-10-17).
- herdr architecture and Claude detection manifest: https://github.com/herdrdev/herdr and https://github.com/herdrdev/herdr/blob/v0.9.5/src/detect/manifests/claude.toml (checked 2026-10-15).
- Claude Code agent teams use tmux or iTerm2 for split panes: https://code.claude.com/docs/en/agent-teams (checked 2026-10-14).
- Claude Code status line (event-driven, 300 ms debounce, `refreshInterval`): https://code.claude.com/docs/en/statusline (checked 2026-10-17).
- tmux 3.6 on megatron provides `display-popup` (`man tmux`, checked 2026-10-17).
- Bubble Tea v2 `ExecProcess`: https://pkg.go.dev/charm.land/bubbletea/v2 (checked 2026-10-17).
