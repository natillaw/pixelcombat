# TACTICAL SUMMONERS — LITE CONTEXT
PACK_VERSION: 1.7
STATE_HASH: 20c12560f902
BUILT: 2026-10-29 00:26

For the AI: this is all you need to start. Do NOT ask for other docs unless the task requires one (name the exact file). State the STATE_HASH, your task and a 5-line plan. At the end give: 1 log entry (Did/Verified/Next) + only the changed lines of CURRENT_STATE (no full files).

---
# Rules (lite) — binding, 1 min read
Repo (Git) is the source of truth, not chat memory. Authority: DECISIONS > specs > BIBLE > ROADMAP > chat.
- Game: Tactical Summoners, Godot 4, 2D pixel art, hybrid RTS, real time, NO pause/time-slow.
- 5-hero squad (final). Keys 1-5 focus hero, Tab group, G squad. Permanent death, no resurrection.
- Direct orders are never randomly refused. Heroes never re-roll on load. Procedural worlds deferred (fixed map).
- Trust, Obedience, Composure are separate persistent fields; changes are deterministic.
- Script-first: generators, @tool EditorScripts, CLI. Give exact paths + minimal run steps. Manual editor steps only if unavoidable.
- NO-HANDS GODOT (D-019): the owner will NOT edit Godot manually. The AI does everything via scripts: .gd/.tscn/.tres generation, @tool EditorScripts, headless Godot CLI, PowerShell (.ps1, Windows) for files, git, imports and tooling. This includes character animations (SpriteFrames/AnimationPlayer built by script from sprite sheets). Never answer with "open the editor and click..."; give a script + one command to run + expected output. Owner only runs commands and reports results.
- Inspect real code before editing; do not rewrite what exists. Never claim "implemented/tested" unless you ran it.
- Never write secrets. Do not contradict DECISIONS.md; propose a new D-xxx instead.
- Token economy: work ONE task per session; ask for only the files you need; do not re-read docs already given; keep replies short.

---
# Current State

**Updated:** 2026-10-28  
**Pack version:** 1.7  
**Status:** Real Godot project (Drop B) audited and extended; verified headless on Godot 4.4.1  
**Phase:** 1 — real-time control sandbox (started)  
**Next task (owner priority, 2026-10-28): VISUAL FIRST.** Owner prefers seeing animations, map and enemies while testing over placeholder squares. Order: (0) owner runs `tools\Run-Tests.ps1` on Drop C and returns `tools\last_test_run.txt`; then T-022 asset inbox -> T-023 animations in code (no assets needed) -> T-025 tileset/map -> T-024 enemy sprites -> T-026 UI -> T-027 effects -> T-028 audio -> T-029 font. Only after that resume the normal order: close T-007..T-011/T-013 with test results, T-001 Git, Phase 3B (T-014..T-020), T-030 equipment. Owner must supply: tileset pack, enemy pack, EULA text of the hero pack (see ASSET_MANIFEST).

## Verified design decisions
- First prototype uses **2D pixel art**; previous 3D/low-poly direction is superseded.
- Control is **hybrid RTS**: autonomous heroes plus direct player orders and direct skill activation.
- Camera is **top-down group/map view** by default; keys **1–5** focus/select the corresponding deployed hero and show their command/skill interface; **Tab** returns to group view and **G** selects the squad.
- Simulation runs in **real time without pause**.
- Mission squad is **five heroes** (D-017). This is final; the first vertical slice also uses five.
- Mission maps combine exploration and combat. Objectives can include investigation, rescue, defense, survival, recovery and extraction; not every mission requires wiping out all enemies.
- Heroes' basic navigation and attacks are autonomous. Player orders should be reliable; no random order-denial roll.
- Personality and relationships can affect behavior and narrative, but must not make routine control frustrating. Trust, Obedience and Composure are separate; MVP changes are deterministic and direct orders are not randomly refused.
- Bosses should use mechanics/phases/telegraphs/arena interactions rather than HP inflation alone.
- Death is **permanent** in the prototype; no resurrection. Preserve a memorial/chronicle record.
- Priority: procedural hero identity, personality, backstory, skills and persistent identity.
- At least six generated heroes in the test roster (five deployed + one reserve); fixed curated mission map. A detailed summons/hero-generation specification now defines persistent IDs, traits, summon configuration, Trust, Obedience, Composure and bonds.
- Procedural world generation is deferred/undecided; use a fixed test map.
- Free-first, original IP and script-first Godot workflow remain constraints.

## Multi-agent workflow
All agents follow `AGENTS.md`; coordination via `TASK_BOARD.md`, `HANDOFF_LOG.md` and `tools/sync/ts_sync.py`. Chat-only agents use `CONTEXT_BUNDLE.md`.

## Core specification files
- `CONTROL_AND_REALTIME_MISSIONS.md`: controls, 1–5 hero focus, camera, HUD, orders and mission flow.
- `SUMMONS_AND_HERO_GENERATION.md`: summon flow, persistent hero schema, traits, Trust/Obedience/Composure and bonds.
- `COMBAT_AND_STATS.md`: real-time combat and provisional attributes.

## Verified implementation state
- The uploaded ZIP was a planning/documentation pack containing Markdown files, not a Godot game implementation.
- This documentation update does not implement or test any Godot scenes/scripts. The actual project path and engine version remain unknown.

## Reported by the user (not verified by any agent)
- A Godot project already exists on the owner's machine but is **not in Git or this pack**. The owner reports the summon system already works (heroes can be summoned) and that other parts are missing.
- The owner already has a pixel-art hero asset pack with many designs. Name, license and sprite size are not recorded yet.
- **Rule:** do not rewrite summon code from scratch. Ask for the repo or a ZIP, audit it, then extend it.

## Unknown / not verified
- Godot installed/version and project path/repository.
- Git status, existing scripts/scenes/plugins/assets and whether the project runs.
- Target display resolution and pixel-art tile/sprite size.
- Exact real-time combat rules still needing a decision: attack cadence, accuracy/dodge, status durations, skill costs/cooldowns, navigation/formation behavior, command queue rules, retreat and equipment loss.
- Exact stat growth per level, potential range, rarity odds and class/skill tables.
- Art/audio assets and their licenses.

## Next actions
1. Locate the real project folder and confirm Godot version.
2. Back up/commit existing work; inspect scenes, scripts, assets and Git status.
3. Implement and test the real-time simulation/control model before polishing visuals.
4. Build hero generator and persistence around stable IDs and generated snapshots; integrate hero autonomy with personality only after baseline controls are reliable.
5. Validate death/memorial/save-load behavior with automated tests.
6. Only then expand the mission, pixel-art presentation and progression.

## Rules
Never mark a feature complete without verification. Record actual paths, commands and test results. Never include credentials, tokens or secrets.

## Verified implementation (Drop B, 2026-10-28)
Project: `tactical_summoners/` (Godot 4.x, GDScript, UI built in code). Run `tools\Run-Tests.ps1` (4 suites, all PASS on Godot 4.4.1 headless).
- Summons v2: `scripts/data/summon_config.gd` (validated banners; odds/pity/costs as placeholders), `Gacha.roll_stars(rng,p4,p5,banner)`, `Game.pull(count, banner_id)` (atomic: nothing changes if unaffordable), seeded summon log (`summon_log`, capped 200, every seed regenerates its hero), `pull_count`.
- HeroData: separate `trust`, `obedience`, `composure` (old `loyalty` migrated into Trust), `callsign` for duplicate names, `generator_version`, structured event ledger (`add_event`, cap 100; events: summoned, promoted). Look/class/traits of old seeds unchanged.
- Save v2: atomic write (tmp -> verify -> .bak -> swap), fallback to .bak when corrupt, v1->v2 migration. 
- Sandbox (`scripts/sandbox/`, menu button): fixed 40x24 map, AStarGrid2D pathing, 5-hero squad (party if full, else fixed test seeds), LMB select/drag-box, RMB move with formation offsets, keys 1-5 / Tab / G, group/follow camera, anti-clumping, minimal hero panel. No pause/time-slow.
- Walk/idle animations (`walk_*`, `idle_*` in SpriteComposer.ANIMS) are a first reading of the sprite sheet (rows front/left/right/back, cols 0-3 walk); NOT visually verified in-engine (headless has no renderer).
- Not done: FUE/AGI/VIT/INT/TEM attributes, synthesis/sacrifice, mission events changing Trust/Obedience (except ally_fell -2 Trust), duplicate-handling beyond callsigns, UI result screen only shown for the best hero of a pull.

## Drop C (written 2026-10-28, NOT RUN: no Godot available in that session)
- Combat (`scripts/sandbox/combat_rules.gd`, provisional): damage = power - DEF/2 (min 1); hero attack interval from SPD; melee 52 px, ranged 190 px; perception 260 px. Idle heroes pick the nearest enemy and attack; a direct move order always cancels autonomy (D-016).
- Enemies (`sandbox_enemy.gd`): perceive, chase, 0.7 s telegraphed circle strike that can be dodged, 0.8 s recovery. Five placed on the fixed map.
- Skills (`skill_tables.gd`): one active skill per class, player-activated only (Q or panel button); refused only on cooldown / no target.
- Panel: vitals, skill + cooldown, Stop (S), squad strip with HP, FALLEN and RELIC markers.
- Mission "Recover the relic": relic in far room (cell 32,3), carrier extracts at EXIT (36,12); relic drops where its carrier falls; result screen; placeholder reward (100 gems, 1 stone) only for the real saved party.
- Permanent death: `Game.record_death` removes the hero from roster/party, writes `Game.memorial` (never capped), survivors -2 Trust (`ally_fell`). Save v3 adds `memorial` (v2 migrates to empty). `MemorialScreen` from the main menu.
- Tests added: `test_memorial`, `smoke_combat`, `smoke_mission`; `Run-Tests.ps1` now runs 7 suites.

---
## Tasks (not done)
- T-001 [open] (phase 0) Put the existing local Godot project (summons working) under Git, confirm Godot version, audit
- T-022 [open] (phase 1V) VISUAL FIRST. Asset inbox: assets/_inbox/ + Import-Asset.ps1 that registers each file (source URL, author, license, frame size) in ASSET_MANIFEST
- T-024 [open] (phase 1V) VISUAL FIRST. Enemy sprites + enemy type table replacing red circles (needs owner-supplied enemy pack)
- T-026 [open] (phase 1V) VISUAL FIRST. UI art: frames, skill/command icons, health bars, portraits
- T-027 [open] (phase 1V) VISUAL FIRST. Effects: hit sparks, telegraph circle art, skill effects, projectiles
- T-028 [open] (phase 1V) VISUAL FIRST. Audio: hit/summon/death/UI sounds + 1-2 music tracks
- T-029 [open] (phase 1V) VISUAL FIRST. Pixel font set in the UI theme
- T-007 [claimed/Claude (awaiting owner test run)] (phase 1) Autonomous basic attacks
- T-008 [claimed/Claude (awaiting owner test run)] (phase 1) Contextual hero panel (vitals, skills, orders)
- T-009 [claimed/Claude (awaiting owner test run)] (phase 1) One active skill per hero
- T-010 [claimed/Claude (awaiting owner test run)] (phase 1) Enemies, perception, telegraphed attacks
- T-011 [claimed/Claude (awaiting owner test run)] (phase 1) Non-combat objective + extraction + mission result
- T-013 [claimed/Claude (awaiting owner test run)] (phase 2) Permanent death + memorial + save integrity tests
- T-014 [open] (phase 3B) Hero schema v+1: tier, histories, retired fields, save migration
- T-015 [open] (phase 3B) Config tables: synthesis, sacrifice yields, promotion costs and unlocks
- T-016 [open] (phase 3B) SynthesisService + SacrificeService (pure, transactional, headless tests)
- T-017 [open] (phase 3B) PromotionService + unlock table + tests
- T-018 [open] (phase 3B) Memorial entries for sacrificed heroes + ledger events
- T-019 [open] (phase 3B) Confirmation UI showing exact loss and gain
- T-020 [open] (phase 3B) Placeholder promotion material reward from mission result
- T-021 [open] (phase 5) Import owner pixel-art hero pack: record license, sprite size, map designs to generator part IDs
- T-030 [open] (phase 4) Equipment layers per D-021: item data table, slots, multi-pack loader with per-pack frame map, equipped item hides the base layer, stats only from items
- T-031 [open] (phase 3) Skill engine: implement the effect kinds in SKILL_LIBRARY (statuses, dashes, channels, zones, summons, ultimates), loadout of 4 actives + 1 ultimate, skill picking UI; start with 8 per class
- T-032 [open] (phase 1V) Skill VFX + icons: map each skill to an effect/icon from the researched packs (see ASSET_MANIFEST)
---
## Decisions index (full text in DECISIONS.md)
- D-001 — Free-first
- D-002 — Original IP
- D-003 — Procedural heroes are core; procedural worlds deferred
- D-004 — Persistent identity
- D-005 — Local prototype before backend
- D-006 — Async multiplayer first
- D-007 — Art direction: 2D pixel art
- D-008 — No bulk assets before art test
- D-009 — Script-first Godot workflow
- D-010 — Historical combat direction (superseded)
- D-011 — Permanent death
- D-012 — Initial attributes and combat formulas are provisional
- D-013 — Character identity is the first design priority
- D-014 — Hybrid RTS control and continuous mission maps
- D-015 — Number-key hero camera focus and contextual command panel
- D-016 — Trust, Obedience and Composure are separate
- D-017 — Five-hero squad is final
- D-018 — Synthesis, Sacrifice and Promotion (direction approved, numbers open)
- D-019 — No-hands Godot: AI implements everything by script (owner-approved 2026-10-28)
- D-020 — Missing hero animations are made in code, no new art (owner-approved 2026-10-28)
- D-021 — Equipment direction: many weapons/armor from several packs; base look has no stats (owner 2026-10-28)
- D-022 — Skill library (owner request 2026-10-28)
---
## Last handoff entries
## 2026-10-29 00:15 — Gemini
- Did: Added Commoner class and past-life professions for base building bonuses, updated birth classes for all star levels, streamlined skill library for fundamental classes, and verified all 9 test suites
- Verified: Run-Tests.ps1 passed all 9 test suites
- Next: T-024 Enemy sprites or T-022 Asset Inbox
## 2026-10-29 00:26 — Gemini
- Did: Implemented complete Past-Life Occupation System with 20 canonical occupations, serialization, roster inspection UI, and verified all 9 test suites
- Verified: Run-Tests.ps1 passed all 9 test suites
- Next: T-024 Enemy sprites or T-022 Asset Inbox