# Agent Sync Protocol (v1.6)

Goal: ChatGPT, Claude and other agents/accounts work on the same project without drifting apart.

## Principles
1. **Git is the memory.** Anything not committed to `docs/ai-context/` does not exist for the next agent.
2. **One owner per task.** Claims live in `TASK_BOARD.md`. Claims older than 48 h with no log entry are stale and may be taken over (note it in the log).
3. **Append-only history.** `HANDOFF_LOG.md` and `CHANGELOG.md` are never rewritten, only appended.
4. **Evidence over claims.** "Done" requires a command and result in the log.
5. **Small, file-scoped tasks.** List the files you will touch in the claim to avoid edit collisions.
6. **State hash.** `STATE_HASH` = first 12 hex chars of the SHA-256 of all `docs/ai-context/*.md` files (except the generated bundle). Any doc change changes it. Agents must state the hash they read.

## Workflows
**With shell/Git access (Codex, Claude Code, Cursor):** run `start`, work, run `log`/`release`/`check`, commit.
**Chat only (ChatGPT/Claude web):** user pastes or uploads `CONTEXT_BUNDLE.md`; agent confirms `STATE_HASH`, works, and ends with a `SESSION_END_PATCH`; user pastes it into the repo and re-runs `bundle`.
**Switching accounts mid-task:** run `log --next "exact next step"` and `release T-xxx --status handoff` before leaving; the new agent starts with `start`.

## Conflict handling
- Two agents edited the same doc: keep both changes, resolve in Git, note in `HANDOFF_LOG.md`.
- Spec vs. code mismatch: code that was run and tested wins for "what exists"; the spec wins for "what should exist". Log the gap.
- Decision disputes: add a proposed `D-xxx` marked `PROPOSED`; only the user approves.

## Commands (`tools/sync/ts_sync.py`, Python 3.8+, stdlib only)
| Command | Purpose |
|---|---|
| `start` | Show version, STATE_HASH, claims, last log entry, Git status |
| `bundle` | Build `CONTEXT_BUNDLE.md` (all docs in one file + hash) for chat-only agents |
| `claim T-xxx --agent A [--files f1,f2]` | Take a task |
| `release T-xxx --status done\|blocked\|handoff` | Free a task |
| `log --agent A --did .. --verified .. --next ..` | Append a handoff entry |
| `check` | Lint docs: versions, stale terms, links, secrets, claims |
| `install-hooks` | Git pre-commit: runs `check` and rebuilds the bundle |
