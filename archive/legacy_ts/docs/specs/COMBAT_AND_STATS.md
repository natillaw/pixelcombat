> **Estado (2026-10-30):** Spec CONFIRMADA (D-011, D-012, D-014); números provisionales. Movida intacta. Los atributos FUE/AGI/VIT/INT/TEM aún no están en el código (F-017).

# Combat & Initial Stats — Tactical Summoners

**Version:** 1.5 design baseline, 2026-10-28. Numeric values remain provisional.

## Goals
- Make positioning, target priority, skill timing and mission objectives matter.
- Keep heroes distinct through skills, personality, history and growth.
- Make combat readable in real time without pause or excessive click speed.
- Make permanent death consequential but legible.
- Keep simulation deterministic and testable independently of rendering.

## Combat model
- Hybrid RTS, continuous real time, no pause.
- Heroes autonomously navigate and use basic attacks; active skills are player-triggered in the initial slice.
- Group camera is default; keys 1–5 select/focus the matching hero and show their contextual interface; Tab returns to group view; G selects the squad.
- No fixed combat ranks or turn order. Use world positions, movement, range, line of sight, telegraphs and cooldowns.
- Exploration, interaction, combat and extraction share the same map.
- Five heroes is the squad size (D-017), including the first vertical slice.

## Basic resolution
- Basic attacks have a configured range, wind-up, recovery and attack interval.
- Resolve attacks only if target is alive, in range and satisfies line-of-sight rules.
- Damage and mitigation are data-driven. No rank-based target restrictions.
- Show wind-up/impact feedback and health changes. Telegraph dangerous enemy actions.
- Prevent animation cancelling from creating unintended attack loops.
- Add status effects only after movement, attacks and skills work. Document duration, stacking, resistance and tick timing.
- Retreat is an explicit mission action with extraction requirements, not a free instant escape.
- Avoid critical hits, random damage variance and complex elemental interactions in the first control prototype unless testing proves they are useful.

## Skills
Initial slice: one active skill per deployed hero, activated directly from the focused hero panel or a documented hotkey. Skills may target a unit, point, area or interactable. The UI shows cooldown, cost, range, target validity and feedback. Example roles:
- Scout: reveal route / mark threats / short reposition.
- Guardian: protect an ally / intercept or shield.
- Striker: gap-close / burst damage.
- Arcanist: area control / interrupt.
- Field medic: heal / cleanse / rescue.
These are role examples, not locked classes. Skill effects should support exploration as well as combat where suitable.

## Attributes (provisional)
- **FUE — Fuerza:** physical damage and possibly stagger.
- **AGI — Agilidad:** movement responsiveness, attack speed or evasion; avoid overloading this stat.
- **VIT — Vitalidad:** maximum health and resistance to physical pressure.
- **INT — Intelecto:** skill potency and resource efficiency.
- **TEM — Temple:** resistance to fear, disruption and stress.

Do not finalize derived formulas until attack cadence, movement speed, skill scaling and encounter duration have been tested. Keep balance values in data resources/tables, not UI scripts.

## Hero autonomy and social state
Autonomous behavior is narrow in the first slice: pathfind, avoid hazards, engage reasonable nearby threats and basic attack. Direct skills are player-triggered. Explicit player orders outrank routine AI.

Trust, Obedience and Composure are separate values defined in `SUMMONS_AND_HERO_GENERATION.md`. Store and display them early, but do not implement random order rejection. For the MVP, use scripted events to adjust values; later behavior effects must be transparent and deterministic. Traits may affect preferences (e.g. a cautious hero chooses a safer route; a protective hero favors a threat attacking a bonded ally) without undermining direct control.

## Enemy design
- Melee chaser: closes distance and pressures the group.
- Ranged attacker: maintains distance and telegraphs shots.
- Controller/support: creates zones, calls reinforcements, shields allies or interferes with objectives.
Use perception and alert states rather than perfect knowledge. Noise and line of sight can alter behavior.

## Boss principles
Use phases, telegraphed area attacks, vulnerable windows, arena objects, meaningful adds, objective pressure and extraction decisions. HP is only one tuning variable. Every major attack needs readable warning and counterplay.

## Death, injury and persistence
- Permanent death; no resurrection in first prototype.
- Record death in the persistent memorial/chronicle.
- Define equipment recovery/loss and mission outcomes atomically before implementing saves.
- Save hero identity and skill snapshots; loading must not regenerate a hero.

## First-playable test targets
- The player understands a basic enemy tell and can move out of its danger zone.
- A skill changes a tactical outcome (interrupt, rescue, expose, control area or reveal).
- A mission can be completed with an optional enemy alive.
- Combat is legible at pixel-art resolution with five heroes.
- All numbers remain provisional until playtested in Godot.
