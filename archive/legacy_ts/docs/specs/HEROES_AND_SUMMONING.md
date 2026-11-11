> **Estado (2026-10-30):** Spec CONFIRMADA (D-004, D-016, D-018). Movida intacta desde `SUMMONS_AND_HERO_GENERATION.md`. §11 es un esquema ilustrativo, no el código real. Rarezas: P-09. Estado real: `docs/IMPLEMENTATION_STATUS.md`.

# Summoning, Hero Generation & Social Simulation — Tactical Summoners

**Version:** 1.5 design baseline, 2026-10-28  
**Status:** Specification for implementation; exact balance values are provisional.

## 1. Purpose
Summoning should produce persistent people, not disposable units with a name pasted on top. Each hero has a stable identity, coherent build, personality, history, relationships and a reason to behave differently. Rarity may affect starting resources or potential, but must not replace tactical identity or make low-rarity heroes meaningless.

## 2. Core summon flow
1. Player opens the Summoning Hall and sees available summon banner/pool, cost, published odds and any guarantee/pity rule.
2. Player chooses single summon or multi-summon if supported.
3. Game validates resource cost and banner configuration.
4. Game uses a seeded, versioned random draw to select a rarity/template pool.
5. Generator creates a valid hero from compatible data tables.
6. Validation checks name uniqueness policy, class/role compatibility, stat budgets, skill prerequisites, visual-part compatibility and forbidden combinations.
7. Hero receives a stable unique ID and generation seed; final generated snapshot is saved.
8. Result screen shows rarity, portrait, role, signature traits, one-line background hook, core stats and skills.
9. Hero is added to the persistent roster. The game never rerolls their identity when reloading.
10. The player can inspect, rename only if the design allows it, equip, train, assign relationships, or deploy them to a squad.

## 3. Summon data and fairness
- Banner definitions are data-driven and versioned: ID, start/end condition, available hero pools, rarity odds, cost, currency, featured weighting and guarantee rules.
- Odds must sum to 100% and be displayed clearly before a draw.
- RNG is seeded and logged for reproducible tests. In offline single-player, local seeds are acceptable; online competitive systems later require server authority.
- A guarantee/pity system is optional. If implemented, its counter and reset rules must be visible and saved.
- Do not invent final probabilities yet. Keep them in configuration/resources, test via simulation and tune later.
- No paid API or LLM is required to generate heroes.
- If monetization is ever considered, disclose odds and avoid pay-to-win pressure. Monetization is not part of the first prototype.

## 4. Rarity is not personality
Rarity is a progression/starting-budget label, not a personality label. A common hero can have a rare combination of traits, unusual backstory, excellent team synergy or high growth potential. Rarity must not dictate obedience, trustworthiness, kindness or morality.
Suggested provisional rarity bands: Common, Uncommon, Rare, Epic, Legendary. These labels can change before content lock. Each banner has explicit odds rather than hidden per-hero adjustments.

## 5. Persistent Hero Profile
Every generated hero should store:
- `hero_id` (stable unique ID);
- `generation_seed` and `generator_version`;
- `name`, `callsign` (optional), portrait/sprite part IDs and palette;
- `rarity`, `class_id`, `role_tags`, `origin_id`;
- five core attributes: FUE, AGI, VIT, INT, TEM;
- derived stats snapshot or reproducible formula version;
- `level`, experience, growth potential, injuries and permanent-death state;
- active/passive skill IDs and skill rank;
- equipment IDs;
- personality dimensions and discrete traits;
- backstory hooks, goals, fears, preferences and personal boundaries;
- Trust, Obedience and Composure values;
- pairwise bonds/rivalries with other heroes;
- memory/event log, mission history, kills/rescues/contributions;
- current order/behavior profile only while in a mission, not as permanent identity;
- last save version and migration metadata.

Persist the generated snapshot rather than relying on the current generator to recreate it. Use data schemas and migration tests.

## 6. Personality and traits
Use a mix of bounded numeric dimensions and discrete traits. Suggested dimensions (0–100, provisional):
- **Courage:** willingness to stay engaged under danger.
- **Discipline:** follows training and formation procedures.
- **Curiosity:** notices/approaches discoveries when not under a direct order.
- **Empathy:** prioritizes rescue and reacts to ally suffering.
- **Independence:** prefers acting without constant supervision.
- **Caution:** evaluates risk and keeps distance from threats.
- **Ambition:** seeks recognition or high-value objectives.
- **Sociability:** forms bonds and communicates readily.

Do not give every dimension independent, noisy random values. Generate a coherent personality archetype, then add controlled variation and 1–3 distinctive traits. Example archetypes: Scout, Guardian, Duelist, Scholar, Survivor, Idealist, Cynic, Perfectionist. Archetypes are starting patterns, not fixed classes.

Trait examples and transparent effects:
- **Explorer:** greater perception/reveal radius; gains a bonus for investigation tasks; may suggest scouting in Auto mode.
- **Protective:** favors threats attacking a bonded ally when operating autonomously.
- **Cautious:** prefers safe approach routes and may request regrouping after a danger event.
- **Disciplined:** stronger formation keeping and faster response under pressure.
- **Independent:** more likely to volunteer for optional interactions when in Auto, but respects direct orders.
- **Curious:** finds extra clues or unique dialogue at relevant points of interest.
- **Stubborn:** may need more encouragement after a failed mission, expressed through dialogue/trust rather than refusing ordinary movement commands.
- **Brave:** lower composure loss from danger, not immunity to it.
- **Compassionate:** more affected by abandoning rescued allies; may improve rescue interactions.
- **Rivalrous:** competes with a specific hero and may create dialogue/conflict events.
- **Methodical:** interacts with mechanisms efficiently or reveals extra steps.
- **Pragmatic:** favors extraction when objective is complete and risk is high, as an advisory behavior rather than forcibly extracting.

Traits should have both narrative expression and a small number of gameplay effects. Avoid hidden effects that make the hero feel inconsistent.

## 7. Trust, Obedience, Composure and bonds
These are distinct systems and must not be conflated.

### Trust — relationship with the commander/company
- Scope: per hero, long-term, 0–100.
- Meaning: how strongly the hero believes the commander and company will protect them, keep promises and treat them fairly.
- Increases from: successful rescue, healing/support, keeping explicit promises, recovering a fallen ally, fair reward/recognition, respecting a hero's stated boundary.
- Decreases from: abandoning allies, repeatedly breaking promises, reckless orders that cause avoidable harm, unequal treatment if the game establishes fairness as a value.
- Effects: dialogue openness, volunteering, willingness to share backstory, recovery/relationship scenes, confidence during high-risk missions, and how quickly trust recovers after conflict.
- Trust must not be a simple “good person” score. Different personalities value different actions.
- Never let low trust silently lock ordinary movement, attack, interact or extraction commands.

### Obedience — command discipline
- Scope: per hero, long-term, 0–100; separate from Trust.
- Meaning: training and willingness to follow the chain of command. A trusted hero can still be impulsive; a disciplined hero can follow orders without emotional closeness.
- Increases from: training drills, clear command structure, consistent tactical doctrine, successful coordinated missions and leadership compatible with the hero's temperament.
- Decreases from: contradictory commands, repeatedly changing orders mid-action, lack of training, role conflict or leadership that violates the hero's established principles.
- Effects in MVP: visible stat, formation/command-response flavor and post-mission feedback only. No randomized order rejection.
- Later effects may include a small, deterministic response delay or more/less reliable formation keeping in extreme pressure, but the cause must be shown and basic commands remain dependable.
- Do not implement a hidden obedience chance per click. A failed command is a UI/path/target issue, not a personality dice roll.

### Composure — short-term mission state
- Scope: per hero, 0–100, resets/recovers according to documented mission/rest rules.
- Meaning: moment-to-moment steadiness under danger.
- Decreases from: being isolated, severe damage, ally down/death, ambush, boss phase shock or trait-specific triggers.
- Recovers from: safe regrouping, successful skill use, defeating a threatening enemy, support skills, rest and relevant trait effects.
- Effects: optional telegraphed states such as Shaken, Focused or Panicked at clear thresholds. MVP can show the meter without applying penalties until control is stable.
- Any state must show a warning, effect, duration/exit condition and recovery route.

### Bonds and rivalries — hero-to-hero relationship
- Scope: directed or symmetric pair records; choose one model and document it in code. Recommended MVP: symmetric relationship score plus tags for Bond/Rivalry.
- Increases/decreases through shared missions, rescues, sacrifices, conflicts, trait compatibility and remembered events.
- Effects: contextual dialogue, post-mission scenes and eventually modest combo/protection synergies.
- Do not implement random friendly fire or surprise sabotage as a relationship effect.

### Loyalty — deferred
Do not add a separate Loyalty meter in the first prototype because it overlaps with Trust and Obedience. Revisit only if the design later needs a distinct commitment-to-company system.

## 8. Relationship and memory event model
Store structured events, not just generated prose. Example:
- `event_type`: `rescued_ally`, `abandoned_ally`, `promise_kept`, `promise_broken`, `boss_fear`, `shared_victory`, `rivalry_conflict`;
- participants and mission ID;
- timestamp/mission sequence;
- stat deltas and trait tags;
- short factual summary generated from game state;
- optional dialogue template key.

The simulation decides the event and numeric changes. Optional LLM dialogue may verbalize a validated event but cannot choose outcomes, change stats, invent inventory or overwrite memory facts.

## 9. Summon duplicate policy — decision still open
Do not delete duplicate heroes automatically. Because each summon is an individual persistent character, duplicate draws should be handled by one explicit design:
- **Recommended baseline:** every draw creates a distinct hero ID; duplicate names are disambiguated with callsigns, and identical build seeds are prevented.
- If duplicates are instead converted into shards, fragments or training material, make that a deliberate player choice after the result screen and preserve the original hero if the player wants them.
- Duplicate policy and whether heroes can be released/retired must be decided before implementing the final summon economy.

## 10. Initial summon configuration (placeholders only)
Keep values in a resource/config file and mark them as tuning placeholders:
- single summon cost: `SUMMON_COST_SINGLE` (unset);
- multi-summon count/cost: unset;
- rarity probabilities: unset, must sum to 100%;
- guarantee/pity: disabled until specified;
- featured hero pool: data-driven;
- resource source/sink and duplicate conversion: unresolved.
Do not hard-code invented odds or costs into gameplay logic.

## 11. Data schema proposal
Use typed Godot Resources or JSON/ConfigFile data; exact implementation follows the verified Godot version. Suggested logical schema:
```gdscript
class_name HeroProfile
extends Resource

@export var hero_id: String
@export var generation_seed: int
@export var generator_version: int
@export var display_name: String
@export var class_id: String
@export var role_tags: PackedStringArray
@export var rarity_id: String
@export var attributes: Dictionary
@export var skills: Array[String]
@export var trait_ids: Array[String]
@export var personality: Dictionary
@export var trust: int = 50
@export var obedience: int = 50
@export var composure: int = 100
@export var bonds: Dictionary
@export var memory_events: Array[Dictionary]
@export var is_dead: bool = false
```
This is an illustrative schema, not tested code. Prefer explicit typed subresources over unvalidated dictionaries as the project matures. Clamp bounded values and validate required IDs on load.

## 12. First implementation sequence
1. Define a versioned hero data schema and stable ID.
2. Implement deterministic generator from fixed tables; no LLM dependency.
3. Generate at least six heroes with different coherent archetypes, traits, skills and backgrounds.
4. Implement summon cost/odds as configuration with odds validation; leave cost/odds unset until design decision.
5. Persist profiles and test load stability.
6. Add Trust/Obedience/Composure fields and a small event ledger; display them in the roster and selected-hero panel.
7. Apply only simple deterministic Trust/Obedience/Composure changes from scripted mission events; do not yet change core order success.
8. Implement relationships/bonds after basic persistence; add dialogue templates.
9. Later: test whether transparent personality-driven autonomy adds value without reducing player control.

## 13. Acceptance criteria
- Summoning creates a unique stable hero ID and records seed/generator version.
- Generated test heroes are observably different in role, traits, skills and backstory hooks.
- Saving and loading never rerolls identity or relationships.
- Rarity odds are visible and validated; no final odds are assumed by this document.
- Trust, Obedience and Composure are stored separately and visible in the roster/hero panel.
- A low Trust or Obedience value never randomly cancels a routine direct order.
- Mission events update the relationship ledger deterministically and can be audited.
- Dead heroes remain in the memorial and cannot be redeployed.

## 14. Synthesis, Sacrifice and Promotion (D-018)
Source of truth for hero growth through consumption and tiers. Numbers are placeholders in config, not code.

### Rules shared by all three
- Transactional: the whole operation applies or nothing does. Write a save checkpoint before it.
- Explicit confirmation screen shows exactly what is lost and gained. No hidden rolls: any randomness uses a stored seed and the result is saved.
- Hero ID, name, seed, generator version, personality and history never change. Never regenerate a hero.
- Cannot use a dead hero, a hero currently on a mission, or a hero already memorialized.
- Warn if the operation would leave fewer than five deployable heroes.
- Every operation appends structured events to the hero event ledger (`synthesized`, `sacrificed`, `promoted`, `received_synthesis`).
- Trust effects on other heroes (for example witnessing a sacrifice) are optional, deterministic and configurable; default none in the first prototype.

### Synthesis (hero -> hero)
- Input: one target hero + one or more source heroes.
- Output: target gains a portion of the sources' value (stats and/or growth potential). `synthesis_efficiency` is a config value below 1.0 and must be visibly lossy.
- Sources are retired to the memorial with cause `sacrificed` and keep identity, history and bonds.
- Open: which stats transfer, whether skills transfer, caps per target, same-class bonus.

### Sacrifice (hero -> materials)
- Input: one hero. Output: materials from a config table based on tier and class.
- Same retirement and memorial rules as synthesis.
- Open: material types, whether high-tier heroes can be sacrificed at all.

### Promotion (tier up)
- Input: one hero + promotion materials (config).
- Output: tier +1. Each tier has a data-driven unlock table: skill slot, class option, level cap, growth potential. Rarity stays separate from current power and potential.
- **Memory unlock at promotion is MAYBE** (not approved). If approved later it must reveal a structured backstory/memory entry already stored on the hero at generation time, never invent new facts.
- Materials source for the first prototype: fixed mission reward. Daily-dungeon style sources are deferred.

### Data additions to the hero profile (schema v+1)
`tier`, `promotion_history[]`, `synthesis_history[]`, `retired` (bool), `retired_cause` (`killed` | `sacrificed`), `retired_at_mission`. Add to the save format version and write a migration.

### Acceptance
- Headless tests: atomicity, reload stability, memorial entry created, invalid targets rejected, config-driven numbers, identity unchanged after promotion.
