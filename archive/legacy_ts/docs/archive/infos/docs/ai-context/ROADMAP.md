# Tactical Summoners — Roadmap

**Updated:** 2026-10-28. Estimates are planning aids only; no task is complete until verified in the actual project.

## v1.7 notes
Five heroes is final (D-017). Synthesis, sacrifice and promotion added as Phase 3B (D-018). See `REFERENCE_SYSTEMS.md` for inspiration notes and candidate systems.

## Updated control direction (2026-10-28)
The previously documented turn-based/rank-based combat direction is superseded. Current target: hybrid RTS, autonomous heroes with direct player orders and active skills, top-down group camera, continuous real time with no pause. Keys 1–5 select and camera-follow heroes while opening their command/skill interface; Tab returns to group view and G selects the squad. Trust, Obedience and Composure are separate persistent hero dimensions. The squad is five heroes (D-017), including the first vertical slice. See `CONTROL_AND_REALTIME_MISSIONS.md` and `SUMMONS_AND_HERO_GENERATION.md`.

## Phase 0 — Audit and protect
- [x] Confirm Godot installation/version and target platform. (code tested on Godot 4.4.1 headless; project.godot says 4.4, README says 4.7: owner to confirm)
- [ ] Locate project/repository; inspect file tree, Git branch/remotes/status.
- [ ] Back up or commit existing work before changes.
- [ ] Inspect scenes, scripts, plugins, assets and licenses.
- [ ] Run project and record errors/performance.
- [ ] Add/update documentation without overwriting user work.
**Done when:** actual project state and safe next action are documented.

## Phase 1 — Real-time control and navigation sandbox (highest priority)
- [x] Create a minimal Godot project/test scene with pixel-art placeholder sprites.
- [x] Implement `HeroData`, enemy data, skill definitions and five core attributes. (HeroData done with 5 stats hp/atk/mag/def/spd; NOT the FUE/AGI/VIT/INT/TEM set; no enemies/skills yet)
- [ ] Implement a deterministic real-time simulation independent of rendering.
- [x] Implement top-down group camera, individual/multi-select, squad selection, keys 1–5 hero focus, Tab group view and contextual hero panel. (verified headless; panel is minimal: no vitals/skills yet)
- [x] Implement pathfinding, click-to-move and anti-clumping.
- [ ] Implement autonomous basic attacks plus direct target, hold, follow/regroup, interact and retreat orders.
- [ ] Implement one player-triggered active skill per hero, with range/cooldown feedback.
- [x] Implement persistent hero schema and deterministic generation (seed/version/stable ID).
- [x] Add separate Trust, Obedience and Composure fields plus structured memory events; do not let these randomly reject routine orders.
- [ ] Implement enemy perception, readable telegraphs and at least one area hazard.
- [ ] Add an objective that can be completed without defeating every enemy, plus extraction.
- [ ] Add unit tests for navigation/order state, attack timing, skill validation, death and mission outcomes.
**Done when:** the fixed-map mission loop is playable in continuous real time without pausing, and can be tested headlessly where practical.

## Phase 2 — Hero identity, procedural generation and permanent death
- [x] Generate at least six distinct heroes (five deployed + reserve) using stable IDs and reproducible seeds.
- [ ] Generate personality dimensions, a backstory hook, class, compatible skills and growth potential.
- [ ] Keep rarity separate from current power and potential.
- [x] Show a roster/profile screen with stats, personality, story and skills.
- [x] Persist all generated values; verify reload never rerolls a hero.
- [ ] Implement permanent death, memorial/chronicle and explicit equipment-loss rules.
- [ ] Warn before deployment and define retreat/party-wipe consequences.
**Done when:** the player cares who goes into a mission and a dead hero remains dead in saved data.

## Phase 3 — First playable mission loop
- [ ] Refuge/roster → select five of at least six heroes → one fixed mission with objective and extraction → results → return to refuge.
- [ ] Add XP and one level-up choice, without complex skill trees.
- [ ] Add a second skill per hero and three enemy archetypes after one-skill control is stable.
- [ ] Add basic consumable or defensive action only if needed for tactical testing.
- [ ] Save/load roster, inventory/equipment, mission result and memorial.
**Done when:** a complete mission can be finished and resumed after restarting the game.

## Phase 3B — Hero growth: synthesis, sacrifice, promotion (D-018)
Prerequisites: hero schema + save/load (Phase 2), event ledger, memorial, mission result with material reward.
- [ ] Add `tier`, histories and `retired` fields; bump save version and write a migration.
- [ ] Config tables: synthesis efficiency, sacrifice yields, promotion cost and unlocks (versioned, no numbers in UI code).
- [ ] `SynthesisService` and `SacrificeService`: pure, deterministic, transactional, headless-testable.
- [ ] `PromotionService` with data-driven unlock table (skill slot, class option, level cap, potential).
- [ ] Memorial entry for sacrificed heroes (cause `sacrificed`); sacrificed heroes keep identity and history.
- [ ] Confirmation UI that shows exact loss and gain before committing.
- [ ] Placeholder promotion material reward from the first mission result.
- [ ] Tests: atomicity, reload stability, invalid targets (dead, deployed, memorialized), identity unchanged.
- [ ] MAYBE (not approved): memory unlock on promotion.
**Done when:** a hero can be synthesized, sacrificed and promoted, survive a save/load, and the memorial shows who was sacrificed.

## Phase 4 — Personality, relationships and memory
- [ ] Implement the eight personality dimensions defined in `SUMMONS_AND_HERO_GENERATION.md` (courage, discipline, curiosity, empathy, independence, caution, ambition, sociability; 0-100).
- [ ] Add event-based memory records (rescue, victory, injury, retreat, death of a companion).
- [ ] Add short deterministic dialogue templates and reactions to history.
- [ ] Let personality influence reactions and limited conditional behaviors, not override normal player actions arbitrarily.
- [ ] Add a minimal relationship value or bond only if it creates visible consequences.
**Done when:** two heroes with different traits react differently to the same event and preserve that history after reload.

## Phase 5 — Pixel-art readability and usability
- [ ] Choose internal resolution, sprite scale and integer scaling after an in-engine test.
- [ ] Test one hero, one enemy, battle backdrop, skill icon, status icon and UI panel.
- [ ] Ensure selection, target, range, telegraph and objective cues are readable without color alone.
- [ ] Track exact asset sources/licenses.
- [ ] Add basic animation states only after simulation rules are stable.
**Done when:** combat state is understandable at normal display size and the visual style is coherent.

## Phase 6 — Tactical depth and balance
- [ ] Refine five core attributes and provisional formulas using automated real-time combat simulations.
- [ ] Add selected status effects, resistances and skill cooldown/cost rules; add stress/resolve only if it serves the real-time loop.
- [ ] Add retreat rules, injury only if distinct from permanent death and worth the scope.
- [ ] Add a boss only after basic encounters are balanced.
- [ ] Use reproducible battle seeds and reports for duration, outcomes, skill use and deaths.
**Done when:** tactical choices matter and losses are explainable rather than arbitrary.

## Phase 7 — Small refuge and progression
- [ ] Add one training/resting function and one basic equipment upgrade.
- [ ] Add XP, level-up and growth potential rules.
- [ ] Add a small chronicle/memorial view.
- [ ] Add relationships only after identity and battle loops work.
**Done when:** mission results change the roster in persistent, understandable ways.

## Deferred — procedural worlds and larger game systems
- [ ] Revisit whether procedural world generation is worth the complexity.
- [ ] If approved later: seed/version rules, region graph, tiles/chunks, navigation validation and saved snapshots.
- [ ] Defer full base simulation, elaborate crafting, offline progression, online/backend, multiplayer, broad elemental matrix, large tower campaign and mass asset production until the vertical slice is validated.

## Current next task
Phase 0: put the existing local Godot project (summons already working) under Git, inspect it and confirm the engine version before implementing any code. Then build Phase 1 real-time control/navigation sandbox, starting with hero data/persistence and camera/order tests.

## Priority if behind schedule
1. Correct deterministic real-time hybrid RTS control, navigation and target rules.
2. Persistent procedural hero identity, personality, backstory and skills.
3. Permanent death, memorial and save integrity.
4. Complete short mission loop.
5. Pixel-art clarity and feedback.
6. Additional content and systems.
