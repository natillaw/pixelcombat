# Lite prompt (DEFAULT — use this, attach only CONTEXT_LITE.md)
Tactical Summoners (Godot 4). Attached CONTEXT_LITE.md has everything you need; do not ask for other docs unless the task needs one (name the file). Tell me the STATE_HASH, the task you take and a 5-line plan. Work only that task. I will NOT touch the Godot editor: do everything with scripts (GDScript/@tool/headless Godot/PowerShell), including animations, and give me one command to run. Keep answers short and give exact file paths. At the end: one log entry (Did/Verified/Next) + only the changed lines of CURRENT_STATE. Don't claim anything is implemented unless you ran it.

# Short prompt (full mode)
I'm working on Tactical Summoners (Godot 4). Follow AGENTS.md in the repo. If you have shell access run `python tools/sync/ts_sync.py start`; otherwise I attached CONTEXT_BUNDLE.md. First tell me the STATE_HASH you read, which task you are claiming, and your plan in 5 lines. At the end, give me the log entry and any doc changes as a SESSION_END_PATCH. Do not claim anything is implemented unless you ran it.

# Full prompt
I am working on Tactical Summoners, an original Godot 4 game inspired by broad systems from Pick Me Up: Infinite Gacha, dispatch/management games and classic RTS games, not an unauthorized adaptation.

Read:
- docs/ai-context/PROJECT_BIBLE.md
- docs/ai-context/CURRENT_STATE.md
- docs/ai-context/ROADMAP.md
- docs/ai-context/DECISIONS.md
- docs/ai-context/CHANGELOG.md
- docs/ai-context/ASSET_MANIFEST.md
- docs/art/ART_DIRECTION.md
- docs/ai-context/COMBAT_AND_STATS.md

Current approved prototype direction:
- 2D pixel art.
- Hybrid RTS: heroes autonomously navigate and use basic attacks; player gives direct orders and directly activates active skills.
- Top-down group/map camera by default. Keys 1–5 select and camera-follow the corresponding deployed hero and update the hero command/skill panel; Tab returns to group view; G selects the squad. Camera switching never pauses or changes orders.
- Continuous real-time simulation **without pause**. Do not add tactical pause or time-slow.
- Five heroes is the mission squad (D-017, confirmed by the user). Do not propose reducing it to three; build/test incrementally inside a five-hero scene.
- Shared map for exploration and combat. Mission objectives can include investigation, rescue, defense, survival, recovery, bypass and extraction; not every mission requires defeating all enemies.
- Bosses use telegraphed mechanics, phases, arena interactions and counterplay—not just inflated HP.
- Permanent death; no resurrection in the first prototype; memorial/chronicle persists.
- Priority: procedural hero identity, personality, backstory, skills and persistent identity. Read `docs/ai-context/SUMMONS_AND_HERO_GENERATION.md`: Trust, Obedience and Composure are separate persistent fields, with deterministic event changes and no random refusal of routine direct orders.
- Procedural world generation is deferred/undecided; use a fixed curated map unless the user re-approves it.
- Five initial attributes: FUE, AGI, VIT, INT, TEM; formulas remain provisional.
- Read `docs/ai-context/CONTROL_AND_REALTIME_MISSIONS.md`, `docs/ai-context/COMBAT_AND_STATS.md` and `docs/ai-context/SUMMONS_AND_HERO_GENERATION.md` before implementation.

Inspect the actual repository and relevant code before editing. The current ZIP is planning documentation, not a verified implemented Godot project. Preserve existing work. Use script-first Godot automation, safe-to-rerun generators, stable IDs, versioned saves and tests. Do not claim code was executed or features implemented unless verified. At session end update CURRENT_STATE.md, CHANGELOG.md and ROADMAP.md based on evidence. Keep core gameplay free-first and original-IP-safe. Never put secrets in documentation. Ask only if an essential design choice blocks implementation.

## Mandatory workflow rule
Prefer complete scripts/generators, `@tool` EditorScripts/EditorPlugins and CLI automation to manual scene/node/inspector work. Inspect existing files/assets first; make backups/checkpoints; verify the Godot version and actual asset paths; give exact file paths and minimal run steps. Manual editor actions are only for steps that genuinely require human interaction or visual verification. Read this rule in `docs/ai-context/PROJECT_BIBLE.md` and treat it as binding across all AI accounts and collaborators.
