# Design Gaps — Tactical Summoners

**Updated:** 2026-10-28. These are open questions, not completed features.

## Decide during the first real-time control prototype
1. **Platform/input:** keyboard/mouse first is proposed; confirm target platform before locking bindings.
2. **Pathfinding:** Godot navigation approach, collision avoidance and how heroes spread around a destination.
3. **Order semantics:** exact final bindings and when new orders replace existing orders. Current proposal: 1–5 focus heroes, Tab group view, G squad select; playtest before locking.
4. **Attack tuning:** basic attack range, wind-up, recovery, attack interval, projectile speed and line-of-sight rules.
5. **Skills:** energy vs cooldowns, per-skill targeting, interruption, cast time and whether any skills are channelled.
6. **No-pause readability:** telegraph duration, enemy warning cues, camera zoom bounds and HUD density.
7. **Survival reactions:** whether heroes auto-dodge clearly telegraphed lethal hazards; if enabled, keep it bounded and legible.
8. **Enemy awareness:** line of sight, sound/noise, alert radius and leash/chase distance.
9. **Mission completion:** exact rules for objective completion, extraction, optional enemies, failed extraction and partial rewards.
10. **Death/injury edge cases:** when death is committed to the save, equipment recovery, retreat costs and what happens if the entire squad falls.
11. **Hero autonomy/personality:** which traits affect transparent preferences; direct movement/target orders must not be randomly denied. Trust, Obedience and Composure are separate; implement data/events first, behavior effects later.
12. **Summon economy:** finalize rarity probabilities, summon cost, pity/guarantee, banner pools, duplicate policy and whether rename/release is allowed. Current document intentionally leaves numbers unset.
13. **Stats and growth:** starting attribute budget, growth potential, level-up rules, class/skill compatibility and rarity odds.
14. **Status effects:** duration, stacking, resistance, tick cadence and how crowd control behaves in real time.
15. **Boss readability:** telegraph windows, phase transitions, counterplay and how objectives interact with boss mechanics.

## Hero growth (D-018) — open decisions
21. Synthesis efficiency, which stats or skills transfer, caps and same-class bonus.
22. Sacrifice material types and yields; whether high-tier heroes may be sacrificed.
23. Number of promotion tiers and the unlock table per tier (skill slot, class, level cap, potential).
24. **MAYBE:** memory unlock on promotion. Needs an explicit user decision.
25. Whether sacrifices or deaths change other heroes' Trust, and by how much.
26. Where promotion materials come from after the first prototype (daily-style dungeons, mission rewards, shop).

## Decide before art production expands
16. Internal resolution, sprite dimensions, tile size, palette and animation frame conventions.
17. Portrait style and how procedural visual variation is assembled and persisted.
18. Exact licensed asset sources or original-art production plan.

## Explicitly deferred
19. Procedural world generation and world graph/chunk generation.
20. Full base simulation, elaborate professions/crafting, offline progress, backend/multiplayer, broad elemental matrix and large tower campaign.
20. Real-time multiplayer, local LLMs, paid generative APIs and large-scale asset production.

## Required reference specs
- `SUMMONS_AND_HERO_GENERATION.md` is the source of truth for summon flow, hero schema, traits, Trust, Obedience, Composure and bonds.
- `CONTROL_AND_REALTIME_MISSIONS.md` is the source of truth for keys 1–5, camera focus, command panel and order behavior.

## Acceptance criteria for the first prototype
- Player can select individual heroes and the squad, use keys 1–5 to focus heroes, Tab for group view, G for squad selection, issue move/attack/hold/follow/interact/retreat orders and activate skills in real time without pausing.
- Heroes navigate and use basic attacks autonomously without constant clicking.
- Direct orders provide feedback and never fail silently.
- A mission objective can be completed without killing every enemy.
- At least one enemy has a readable telegraph and counterplay.
- Generated heroes have distinct, persistent personality, backstory and skill combinations, with stable IDs and separate Trust/Obedience/Composure fields.
- A dead hero stays dead after save/load and appears in the memorial.
- No feature is marked complete until run and tests confirm it.

## EQUIPMENT (added 2026-10-28, owner wants weapons and armor later)
Sprite layers already support it: `Held_Item/2..6` are full 576x384 sheets with the weapon drawn on every frame (incl. the attack lunge); `Top`, `Bottom`, `Hat` are style x colour sheets. Equipment = an item id mapped to a layer file; the hero's `appearance` stays the base look and equipped items override a layer at draw time (never rewrite the saved seed look). Needs decisions: slots, which classes may use which weapon type, whether equipment changes stats (D-012), drops/loss on death, and new art for weapon types the pack lacks (only 5 held styles; no bow-specific drawn frames). Armor beyond the 11 Top / 5 Bottom / 5 Hat styles needs new art for ALL frames.
