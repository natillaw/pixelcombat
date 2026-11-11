# Decisions

## Current control and mission decisions (approved 2026-10-28)
- **Control model:** hybrid RTS. Heroes autonomously navigate and perform basic combat; the player gives direct orders and activates skills directly.
- **Camera:** top-down group/map view as the default. Keys 1-5 select a hero and smoothly focus/follow them (see D-015); Tab/G return to group view. The camera is never permanently locked and switching never pauses or changes orders.
- **Time:** real-time simulation with **no pause**. The UI must make orders quick to issue and readable under pressure.
- **Squad fantasy:** the intended mission squad is five heroes. Confirmed final by D-017: the first vertical slice also uses five.
- **Mission structure:** exploration and combat share the same continuous map. Missions may ask for investigation, rescue, defense, survival, recovery or extraction; defeating all enemies is not always required.
- **Hero autonomy:** direct orders should be reliable and never randomly ignored by a hidden obedience roll. Personality influences autonomous preferences, dialogue, relationships and situational behavior. If an obedience/trust system is later added, it must be transparent, context-sensitive and never undermine basic usability.
- **Boss design:** mechanics, phases, telegraphs, arena interactions and objective pressure; not simply more HP.
- **World generation:** remains deferred. Use a fixed curated map until the control and mission loop is validated.

## D-001 — Free-first
**Date:** 2026-10-27. Core gameplay must work without paid APIs, subscriptions or paid assets. Procedural generation and default dialogue are code/data based; optional AI cannot be a core dependency.

## D-002 — Original IP
Use broad genre/system inspiration, not copied protected expression. No copied characters, names, dialogue, art, maps, logos, music or distinctive story content from Pick Me Up: Infinite Gacha.

## D-003 — Procedural heroes are core; procedural worlds deferred
**Updated:** 2026-10-28. Procedural heroes are a core feature: identity, attributes, growth potential, class, skills, personality, background and memories must be generated coherently and persistently. Procedural world generation is **deferred / undecided** until the core loop is playable; use a handcrafted test dungeon or fixed encounter sequence for the first prototype. Do not treat procedural worlds as a launch requirement yet.

## D-004 — Persistent identity
Every hero/world has stable IDs. Appearance, stats, origin and history cannot reroll on reload. Store generated output or a versioned snapshot, not only a seed tied to mutable code.

## D-005 — Local prototype before backend
Build and validate the gameplay loop locally. Keep service boundaries clean for later online persistence.

## D-006 — Async multiplayer first
Start with visits, defense snapshots, invasions, leaderboards and events. Real-time multiplayer is out of initial scope.

## D-007 — Art direction: 2D pixel art
**Updated:** 2026-10-28. Use original 2D pixel art with readable silhouettes, a limited cohesive palette, clear combat telegraphs, legible UI at intended resolution and modular/reusable sprites. The previous stylized 3D/low-poly direction is superseded. Test one hero, one enemy, one tileset sample and one UI panel before producing/importing lots of art.

## D-008 — No bulk assets before art test
First test one hero, enemy, weapon, prop, environment tile and UI icon. Check style, scale, rig, animation, performance and license.


## D-009 — Script-first Godot workflow
**Date:** 2026-10-27. All AI assistants and collaborators should automate scene creation, node setup, project configuration, repetitive asset setup and testing through scripts or CLI tools wherever practical. Keep manual editor work minimal; inspect and preserve existing work; use safe-to-rerun generators and verify results.

## D-010 — Historical combat direction (superseded)
**Date:** 2026-10-28. The earlier turn-based/rank-based combat proposal was superseded by D-014. Do not implement fixed ranks, turn order or turn-based action selection unless the user explicitly reopens this decision.

## D-011 — Permanent death
**Date:** 2026-10-28. A hero who reaches 0 HP during a mission is permanently dead for that save. Preserve their record, history, equipment outcome and memorial entry; never reroll or silently delete the hero on load. No resurrection in the first prototype. Clearly warn the player before deployment and define retreat/mission-loss outcomes.

## D-012 — Initial attributes and combat formulas are provisional
**Date:** 2026-10-28. Core attributes: Fuerza (FUE), Agilidad (AGI), Vitalidad (VIT), Intelecto (INT), Temple (TEM). Proposed prototype baselines: PS = 40 + 10×VIT; physical damage = weapon power + 2×FUE; magic power = focus power + 2×INT; physical defense = armor + floor(VIT/2); initiative = AGI + TEM; energy = 3 + floor(TEM/3); accuracy starts at 85% + AGI%, before target evasion, and must be clamped. Evasion starts at 2×AGI% and must be clamped. These values are placeholders for automated balance tests, not final balance. Stress is a separate combat meter, not a sixth core attribute.

## D-013 — Character identity is the first design priority
**Date:** 2026-10-28. The first prototype prioritizes personality, backstory, skills and persistent memories over world-generation breadth, base simulation or content volume. Personality affects authored reactions, relationship events and limited behavior rules without arbitrarily taking control away from the player during normal turns.


## D-014 — Hybrid RTS control and continuous mission maps
**Approved:** 2026-10-28. Use real-time hybrid RTS controls: autonomous heroes with direct player orders and direct active-skill activation; top-down group camera by default, with 1–5 hero camera focus and Tab group return; continuous real time with no pause. The squad is five heroes, including the first vertical slice (reaffirmed by D-017). Exploration, interactions, combat and extraction share a map. Missions should include objectives beyond defeating all enemies, and bosses should use readable mechanics and counterplay rather than HP inflation alone. Direct orders are reliable and must not be randomly denied by an obedience roll. Procedural world generation remains deferred; use a fixed curated map for the first prototype.


## D-015 — Number-key hero camera focus and contextual command panel
**Approved:** 2026-10-28. Keys 1–5 select the corresponding deployed hero and smoothly focus/follow that hero with the camera. The focused hero's portrait, vitals, skills and command controls appear/update. The simulation never pauses, and other heroes continue acting. `Tab` returns to group view; `G` selects the squad and group view. Empty/dead slots give clear feedback rather than silently selecting a different hero.

## D-016 — Trust, Obedience and Composure are separate
**Approved:** 2026-10-28. Add persistent Trust (long-term relationship to commander/company), Obedience (long-term command discipline) and Composure (short-term mission state), plus pairwise hero bonds/rivalries. Store/display these from the beginning. During the MVP, use only deterministic, scripted changes and no random refusal of ordinary direct orders. More complex behavioral effects are deferred until the real-time control loop is reliable.

## D-017 — Five-hero squad is final
**Approved:** 2026-10-28 (user, explicit). The mission squad is five heroes, including the first vertical slice. Do not propose a three-hero slice. Scope is controlled by keeping one skill per hero, placeholder behaviors and a fixed map, not by cutting the squad. The test roster needs at least six heroes (five deployed + one reserve). Keys 1-5 are all required.

## D-018 — Synthesis, Sacrifice and Promotion (direction approved, numbers open)
**Approved:** 2026-10-28 (user). Add three hero-growth systems; full spec in `SUMMONS_AND_HERO_GENERATION.md` section 14.
- **Synthesis:** consume a source hero to improve a target hero. Deliberately lossy; irreversible.
- **Sacrifice:** consume a hero to produce materials instead of improving another hero. (Agent interpretation of "sacrificio"; user to confirm.)
- **Promotion:** raise a hero's tier using materials; unlocks new capabilities (skill slot, class option, higher level cap, growth potential).
- **Memory unlock on promotion:** **MAYBE.** Undecided; do not implement until the user approves (see DESIGN_GAPS 24).
- Identity never changes: ID, name, seed, personality and history are preserved. A sacrificed hero is retired to the memorial with cause "sacrificed", never silently deleted.
- Original naming only; no PMU terms (see `REFERENCE_SYSTEMS.md`). All numbers configurable and versioned.

## D-019 — No-hands Godot: AI implements everything by script (owner-approved 2026-10-28)
The owner does not want to operate the Godot editor. All agents implement scenes, nodes, resources, imports and character animations through scripts (GDScript, @tool EditorScripts, headless Godot CLI) and PowerShell for file/git/tooling work, then wire them into the project themselves. The owner only runs a single command and reports the output. Extends D-009.

## D-020 — Missing hero animations are made in code, no new art (owner-approved 2026-10-28)
The Tiny Pixel Fantasy sheet (576x384 per layer, 12x8 frames of 48 px) has: 4-direction movement, a 4-frame side melee lunge (rows 5-6, cols 2-5), a 2-frame lying-down pose per side (rows 5-6, cols 0-1), and loose poses (point, raise hand, crouch). It has NO hit-react, cast, bow, up/down attack, multi-frame death, run, block, interact or victory.
- Agents build the missing ones in code from existing frames: hit = white flash + recoil tween; death = lying-down frames + fall/fade tween; cast/bow = the point / raised-hand poses + separate projectile or effect sprite; attack up/down = reuse the side lunge with a movement tween.
- No new hand-drawn frames are required. Hand-drawn extra rows only as a later optional polish, and only if the EULA allows modifications (every new frame must be drawn for ALL layers).
- Owner does not need to do anything. Task: T-023.

## D-021 — Equipment direction: many weapons/armor from several packs; base look has no stats (owner 2026-10-28)
- Many more classes and many weapon/armor variants (different stats) will come later, from additional asset packs, not only the current pack.
- Base clothes/hair from the generator are cosmetic only and carry NO stats. All equipment stats come from items given later.
- Equipped armor hides (replaces) the matching base layer; it is not drawn on top of it. The saved base look is never changed (see DESIGN_GAPS EQUIPMENT).
- Open for the owner: whether new heroes start with plain default underclothes (agent suggestion) or only the bare body layer.
- Every extra pack needs: same 48 px grid or a per-pack frame map, matching art style, a license entry in ASSET_MANIFEST, and a per-item data entry (id, slot, layer file, stats, class limits). Task: T-030.

## D-022 — Skill library (owner request 2026-10-28)
- All skills live in one generated library: `tools/gen_skill_library.py` -> `scripts/data/skill_library_data.gd` + `docs/SKILL_LIBRARY.md` (copy in docs/ai-context). Edit the Python table, re-run, commit both outputs. Never hand-edit the outputs.
- Lookup API: `SkillLibrary` (scripts/sandbox/skill_library.gd). A hero never hardcodes a skill: `SandboxHero.equip_skill(id)` and `SkillTables.for_class` read the library.
- Rules: each hero fights with 4 actives + 1 ultimate. A skill needs the hero's class in its `classes` list and level >= `min_level` (1..70). Class-only skills plus shared skills: every combat class can learn >= 30 skills and has >= 20 class-only ones (Mage exactly 30 available).
- Every skill carries: what it does, how it plays in real time, synergy, enemy tags it is good/weak against (tags in ENEMY_TAGS), cooldown, range class, status (implemented / spec).
- Only the 5 existing signature skills (Second Breath, Cleave, Quick Slash, Lunge, Piercing Shot, Fire Burst) run in the engine today; the rest are specifications (T-031). Numbers are provisional (D-012).
- OPEN CONFLICT for the owner: the code has 5 stars with level caps 10/20/40/60/80 (HeroTables.STAR_DATA), but the owner describes 7 stars and 70 levels (1 star per 10 levels). The library uses levels 1..70 and star_gate = ceil(level/10). Decide and update STAR_DATA/MAX_STARS in a separate task.
