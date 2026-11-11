# Tactical Summoners — Starter Pack

Portable project memory for ChatGPT, Claude, and future collaborators. **v1.7: five heroes final, synthesis/sacrifice/promotion, reference systems.**

## Files
- `docs/ai-context/PROJECT_BIBLE.md`: vision, systems, architecture and constraints.
- `docs/ai-context/ROADMAP.md`: phases, tasks and acceptance criteria.
- `docs/ai-context/CHANGELOG.md`: verified work history.
- `docs/ai-context/CURRENT_STATE.md`: current verified state and next action.
- `docs/ai-context/DECISIONS.md`: decisions and rationale.
- `docs/ai-context/ASSET_MANIFEST.md`: candidate asset sources and license register.
- `docs/ai-context/COMBAT_AND_STATS.md`: real-time combat, provisional stats, skills, enemy roles and permanent-death rules.
- `docs/ai-context/CONTROL_AND_REALTIME_MISSIONS.md`: hybrid RTS control, 1–5 hero focus/camera, contextual command panel, order semantics, no-pause readability and mission design.
- `docs/ai-context/SUMMONS_AND_HERO_GENERATION.md`: summon flow, procedural hero identity, traits, persistent data, Trust, Obedience, Composure, bonds and event memory.
- `docs/ai-context/REFERENCE_SYSTEMS.md`: inspiration systems matrix, statuses, naming rules.
- `docs/ai-context/AGENT_SYNC.md`, `TASK_BOARD.md`, `HANDOFF_LOG.md`: multi-agent protocol.
- `docs/ai-context/DESIGN_GAPS.md`: decisions still needed and acceptance criteria.
- `docs/art/ART_DIRECTION.md`: visual direction and procedural art rules.
- `SESSION_HANDOFF_PROMPT.md`: reusable prompt for changing AI accounts.
- Script-first workflow is a binding rule in the Bible, Decisions and handoff prompt: automate Godot work with code wherever practical.

## Multi-agent sync (v1.6)
- `AGENTS.md`: the one protocol every agent follows (`CLAUDE.md` points to it).
- `docs/ai-context/AGENT_SYNC.md`, `TASK_BOARD.md`, `HANDOFF_LOG.md`: rules, task claims, append-only session log.
- `tools/sync/ts_sync.py`: `start`, `claim`, `release`, `log`, `bundle`, `check`, `install-hooks` (Python 3.8+, no dependencies).
- Chat-only agents: run `python tools/sync/ts_sync.py bundle`, upload `CONTEXT_BUNDLE.md`, and have the agent confirm the `STATE_HASH`.

## Low-usage mode (v1.7.1)
`python tools/sync/ts_sync.py lite [--spec SUMMONS COMBAT CONTROL]` builds `CONTEXT_LITE.md` (~10 KB). Attach only that file + the Lite prompt from `SESSION_HANDOFF_PROMPT.md` when switching AI accounts. Do not upload `CONTEXT_BUNDLE.md` unless needed.

## Start
1. Extract this ZIP into the root of your game repository (keep `AGENTS.md`, `docs/` and `tools/`).
2. Commit the docs to Git.
3. Ask the AI to read the Bible, current state, roadmap, decisions and relevant code before editing.
4. At the end of a session update `CURRENT_STATE.md`, `CHANGELOG.md`, and `ROADMAP.md`.
5. Never store API keys, passwords, tokens or `.env` contents here.

This pack is planning documentation (plus the Drop B code state in CURRENT_STATE.md). It specifies a 2D pixel-art hybrid RTS prototype with autonomous heroes, direct orders and skills, a top-down group camera plus 1–5 hero focus shortcuts, real-time without pause, permanent death and personality/backstory/skills-first procedural heroes. Trust, Obedience and Composure are separately modeled. Procedural world generation is deferred/undecided. The Godot project is separate (see CURRENT_STATE.md for what is verified).
