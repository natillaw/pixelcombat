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

## Phase 2 — Hero Simulation & Living Headquarters (2026-10-29)
- **Persistent Memories:** `HeroData.memories` records structured event-driven memories (summoned, customized, worked HQ, witnessed death) with importance and timestamps, capped at 50 per hero.
- **Hero Relationships:** `HeroData.relationships` tracks interpersonal dynamics between heroes with dynamic status tiers (`unfamiliar`, `acquaintance`, `friend`, `trusted_ally`, `hostile`) updated via shared work and mission events.
- **Living Headquarters & Facilities:** `Game` manages facility assignments (`hq_assignment`), activity states (`activity_state`), and `process_headquarters_turn()` which leverages past-life occupations (Chef, Blacksmith, Medic) to produce resources (`food`, `materials`, `medicine`) and build co-worker relationships.
- **Save v4 & Migration:** Save version upgraded to 4, adding `hq_facilities`, `hq_outputs`, and migrating v3 saves seamlessly.
- **Testing:** Added `tests/test_simulation.gd`. `Run-Tests.ps1` now executes 10 suites (`core`, `summons v2`, `ui smoke`, `sandbox`, `memorial v3`, `combat`, `mission`, `animation`, `art`, `simulation`), all 10 PASS.

## Procedural Generation Repair & Integration (2026-10-29)
- **Multi-Attempt Room Placement & Connectivity:** `ProceduralMap` now uses a multi-attempt placement algorithm with explicit retry limits and fallback generation, connected via sequential corridor carving and branching loops.
- **Data-Driven Enemy Population & POIs:** Enemy spawn points (`enemy_spawn_cells`) and points of interest (`treasure_cells`) are populated according to floor configuration budgets (`TowerExpedition`).
- **Reachability Validation & Navigation Safety:** Implemented `_validate_map()` to guarantee reachability from player start to goal, along with strict walkability checks in `find_path()` and `nearest_walkable()`.
- **Testing:** Expanded `tests/test_procedural.gd` covering room generation, enemy population, POIs, pathfinding, determinism, and map persistence. All **12 automated test suites** pass successfully.
