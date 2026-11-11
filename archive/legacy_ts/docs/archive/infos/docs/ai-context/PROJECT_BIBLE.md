# Tactical Summoners — Project Bible

**Baseline date:** 2026-10-28 | **Engine target:** Godot 4.x (exact version unverified) | **Budget:** zero-cost first

## High concept
An original persistent fantasy tactical RPG in 2D pixel art. Players summon individually generated heroes whose personalities, backgrounds and skills make them distinct; build a roster; choose a squad for tower-floor missions; and direct autonomous heroes in real time from a top-down group view. The player issues movement, target, formation and interaction orders and activates skills directly; heroes handle routine movement and combat autonomously. Missions mix combat with exploration, investigation, rescue, defense and extraction. Consequences include relationships, memories, injuries and permanent deaths. Procedural world generation is deferred/undecided and is not required for the first prototype. Inspiration is at the level of broad systems from *Pick Me Up, Infinite Gacha*, dispatch/management games and classic RTS games, not their protected expression.

## Pillars
1. Tactical preparation matters as much as raw hero rarity.
2. Procedural heroes are varied, coherent and persistent; procedural world generation is deferred until the core loop works.
3. Heroes retain identity, relationships, memories and consequences.
4. Base, economy, equipment and expeditions reinforce one another.
5. Core simulation works without an LLM or paid API.
6. Build locally first; online persistence and asynchronous social systems later.
7. Original IP only: no copied names, characters, dialogue, art, maps, logos, music or distinctive story expression.
8. Inspect existing code and preserve work before editing.

## Core loop
Open the refuge/roster → inspect generated heroes, personalities, histories and skills → choose a squad for a tower-floor mission → enter a continuous real-time top-down map → issue squad/individual orders and activate skills while heroes autonomously move, attack and react → complete the mission objective and decide whether to extract or push deeper → return with rewards, injuries, relationships and possible permanent losses → preserve the company chronicle and prepare the next expedition.

## Systems scope
- **Summoning:** configurable rarity, odds, resource cost, history, duplicate choices and stable hero IDs.
- **Heroes:** stats, class/role, skills, equipment, potential, traits, background, personality, origin and persistent history.
- **Combat and control:** hybrid RTS in real time, with no pause. Camera is a top-down view of the squad/map, not a locked single-hero camera. Heroes autonomously navigate, select basic attacks, defend themselves and use only clearly defined autonomous behaviors; player directly issues movement, attack/target, hold, follow, retreat, interact and ability commands. Direct ability use is explicit and reliable. Support squad orders and individual selection, camera focus shortcuts 1–5, group view on Tab and squad selection on G. Readable telegraphs, status effects, line of sight, navigation, aggro and retreat/extraction rules replace turn order and rank-based targeting. Hero UI shows skills, current order, vitals and compact Trust/Obedience/Composure indicators. Simulation must be deterministic and testable without rendering.
- **Consequences:** retreat, injury, permanent death, memorial/history, explicit equipment-loss rules. Never silently delete data on an error.
- **Base/economy:** training, crafting, research, storage, production, expedition board and meaningful building unlocks. Track resource sources, sinks and caps.
- **Tower/content:** floors, difficulty budgets, bosses, dungeons, missions, objectives and events. A floor is a mission space, not necessarily an arena; support combat, exploration, investigation, rescue, defense, survival and extraction. Bosses use readable phases, arena interactions and objective/mechanic changes rather than inflated HP alone.
- **Procedural worlds:** deferred/undecided. Use a fixed test dungeon/encounter sequence for the first prototype; revisit seeded regions, biomes, factions and landmarks after validating the core loop.
- **Procedural heroes (priority):** stable ID/seed, name, origin, class, attributes, growth potential, skill loadout, rarity, personality dimensions, backstory hooks, goals, fears, Trust, Obedience, Composure, relationships and memory log. See `SUMMONS_AND_HERO_GENERATION.md`. Generate from compatible data tables, validate combinations, and persist the resulting snapshot so reloads never reroll identity.
- **Relationships/memory:** structured traits, goals, bonds, rivalries, fears and event memories. LLM may phrase dialogue but must never decide rewards, inventory or game state.
- **Offline progress:** timestamp-based, capped and idempotent. Use trusted server time once online; local device time is not secure.
- **Multiplayer:** begin with cloud saves, themed player groups, visits, asynchronous defenses/invasions, leaderboards and seasonal events. Real-time multiplayer is later.
- **AI dialogue:** optional; template-based dialogue remains the free, reliable fallback. Validate output and treat player-provided text as untrusted.

## Procedural generation rules
1. Seed and version the generator.
2. Generate world profile and theme palette.
3. Generate biome/region graph, factions and tensions.
4. Generate resources, enemy families, encounters and events.
5. Assemble visuals from compatible modular assets and procedural dressing.
6. Validate navigation, combinations, difficulty and missing content.
7. Persist the generated result. Do not rely on regenerating old content using a future version of the generator.

For the first 2D pixel-art prototype, use curated sprite/portrait parts, palette variants and equipment overlays rather than generating wholly new artwork for every hero. Randomness must obey compatibility rules and visual readability. Persist part IDs and palette choices. Procedural world generation remains deferred.

## Initial original theme families
Ashen/cursed kingdom; Verdant/overgrown wilds; Arcane/fractured reality; Umbral/abyssal depths; Storm/sky-isles; Forge/clockwork empire; Tidal/drowned civilization; Crystal/glass desert. These are working labels, not final lore.

## First prototype scope (updated 2026-10-28)
- 2D pixel-art presentation; one refuge/roster screen and one fixed top-down mission map.
- Choose a squad of five heroes from the roster (D-017). The first vertical slice also uses five; development may test one hero first, but acceptance requires five.
- At least six generated heroes in the roster; five are deployed in the initial vertical slice.
- Hybrid RTS controls: autonomous heroes plus direct orders and direct skill activation; top-down group camera; continuous real-time simulation with no pause.
- One compact fixed mission with a clear non-combat objective and at least one enemy encounter. The objective must be completable without defeating every enemy where mission design allows.
- Basic movement/navigation, autonomous basic attacks, squad movement order, keys 1–5 for hero camera focus, Tab group view, G squad selection, target/attack order, hold/follow/interact/retreat, one active skill per hero, visible Trust/Obedience/Composure, enemy detection/response and extraction/mission completion.
- Procedural hero personality, backstory, skills and persistent identity are higher priority than rarity/visual breadth.
- Permanent death with persistent memorial record; no resurrection in the prototype.
- Save/load for hero identity, stats, skills, mission outcome, equipment and memorial.
- Script-first workflow; Godot version and actual project status remain unverified.
- Procedural world generation remains deferred: use a curated fixed map for the first prototype.

## Mandatory development workflow — script-first Godot automation

**This is a standing project rule for every AI assistant, account and collaborator.** Minimize manual editor work. Whenever practical, implement project setup and repetitive Godot work through code that can be rerun, reviewed and version-controlled.

- Prefer scripts/generators for creating or updating scenes, nodes, resources, project settings, test fixtures, data files and repetitive asset setup. Use `@tool` `EditorScript`/`EditorPlugin` for editor-time generation and Godot's command-line mode for headless imports, validation and tests when suitable.
- Give the user complete, ready-to-save files or a patch with exact paths, plus the shortest possible execution steps. Do not make the user manually create many nodes or click through repetitive inspector settings if a script can do it.
- Prefer idempotent generators: rerunning them should update known generated outputs safely, not duplicate nodes or destroy user work. Before modifying existing files, inspect them and preserve unrelated changes. Do not overwrite scenes, scripts, project settings or assets blindly.
- Keep generated code readable, typed where useful, documented, modular and compatible with the project's verified Godot version. If the version is unknown, first provide the shortest way to check it and avoid relying on version-specific APIs until verified.
- Use real project files, imported asset paths, skeletons and animation names. Never invent asset paths or claim compatibility before inspection. Use a small vertical-slice test before bulk generation/import.
- After generation, provide a clear run/test command and acceptance checks. Distinguish code written from code actually executed and verified. If something fails, fix the error rather than asking the user to manually work around it.
- Manual editor work is acceptable only when it is genuinely necessary (for example, downloading assets, granting permissions, inspecting visual fit, or confirming a UI setting unavailable through code). Keep it minimal and explain why it is needed.
- Build reusable project tools over time, such as `Build Test Scene`, `Generate Hero`, `Validate Assets` and `Run Tests`, so future work becomes increasingly automated.
- This rule applies across all systems: characters, modular armor/weapons, animation setup, combat, procedural generation, UI, data, saves, testing and project configuration. It does not mean blindly generating everything; inspect, test and preserve work first.

## Technical rules
- Separate data, simulation, presentation, persistence and UI.
- Prefer script-first automation for all repetitive Godot/editor work; see the mandatory workflow above.
- Prefer typed GDScript, stable IDs and versioned save schemas.
- Keep balance tables/data out of UI scripts.
- Add tests for deterministic generation, combat, economy, offline rewards and save/load.
- Commit small increments. Record engine/plugin versions.
- Do not add paid dependencies without approval.
- No bulk asset import before a small in-engine art test.

## Out of scope initially
Real-time multiplayer, seamless open world, local LLMs, paid generative APIs, huge handcrafted campaign, monetization, mass asset production before style validation.

## Definition of done
Feature works in the real project, acceptance criteria pass, edge cases are tested, persistence is verified if relevant, documentation is updated, and all assets have compatible licenses.
