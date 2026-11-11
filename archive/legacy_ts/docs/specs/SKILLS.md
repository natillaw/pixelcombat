> **Estado (2026-10-30):** **Banco de ideas (P-10, PENDIENTE).** Movido intacto desde `SKILL_LIBRARY.md`. Usa las clases ANTIGUAS (Novice/Warrior/Thief/Spearman/Archer/Mage). Las clases confirmadas son Commoner/Warrior/Rogue/Archer (antes Ranger)/Cleric/Mage (D-028): habrá que reasignar estas habilidades. Escala de niveles 1-70 coherente con D-029. El generador `tools/gen_skill_library.py` y `SkillLibrary` mencionados abajo NO existen en el repo. Las skills en juego hoy están en `scripts/sandbox/skill_tables.gd`.

# Skill Library

Generated from `tools/gen_skill_library.py` (D-022). Edit the table there, not this file.

Rules: each hero uses **4 actives + 1 ultimate** in battle (chosen from skills unlocked for its class and level). `Lv` is the hero level needed (1-70); `Star` = ceil(level/10) is the star tier that corresponds to it. Skills with `Status: implemented` run in the sandbox today; the rest are specifications for T-031.

## Enemy tags

- `armored`: heavy armor, high DEF
- `swarm`: many weak enemies at once
- `ranged`: archers and throwers
- `caster`: spell users, low DEF
- `boss`: large single targets with lots of HP
- `fast`: quick enemies that close distance
- `flying`: airborne enemies
- `undead`: skeletons and the like
- `beast`: animals and monsters
- `shielded`: enemies with shields or guard stances
- `evasive`: dodgy, hard to pin down
- `brute`: slow heavy hitters

## Skills available per class

| Class | Total | Class-only | Actives | Ultimates |
|---|---|---|---|---|
| Novice | 8 | 2 | 8 | 0 |
| Warrior | 39 | 20 | 35 | 4 |
| Thief | 39 | 20 | 35 | 4 |
| Spearman | 41 | 20 | 37 | 4 |
| Archer | 40 | 20 | 36 | 4 |
| Mage | 30 | 20 | 26 | 4 |

## Shared skills

### Second Breath (`skill.second_breath`)
Lv 1 (star 1) - Active - CD 20s - self - heal - Classes: Novice, Warrior, Thief, Spearman, Archer, Mage - Status: implemented
- What: Recover 25% of max HP.
- In real time: Instant, no cast. Player taps it when the squad strip shows a hero low; refused at full HP.
- Synergy: Guard Stance first, then heal while the damage is reduced.
- Good vs: - | Weak vs: swarm

### Power Strike (`skill.power_strike`)
Lv 3 (star 1) - Active - CD 8s - melee - dmg - Classes: Warrior, Thief, Spearman - Status: spec
- What: Next basic attack deals 220% damage.
- In real time: Queued: the next swing is empowered, so it works while chasing.
- Synergy: Armor Break first for bonus on armored foes.
- Good vs: armored | Weak vs: swarm, evasive

### Throwing Knife (`skill.throwing_knife`)
Lv 4 (star 1) - Active - CD 6s - mid - dmg - Classes: Warrior, Thief, Spearman, Archer - Status: spec
- What: Throw a knife 140 px for 110% damage.
- In real time: Backup ranged poke for melee classes.
- Synergy: Pairs with Mark Target.
- Good vs: caster, ranged | Weak vs: armored

### Guard Stance (`skill.guard_stance`)
Lv 5 (star 1) - Active - CD 24s - self - buff - Classes: Novice, Warrior, Thief, Spearman, Archer, Mage - Status: spec
- What: Brace for 4 s: take 40% less damage, cannot move.
- In real time: Root in place while enemies hit you. Great at a chokepoint or while holding the relic spot.
- Synergy: Taunt or Provoke draws enemies into the stance.
- Good vs: brute, boss, fast | Weak vs: ranged, caster

### Backstep (`skill.backstep`)
Lv 6 (star 1) - Active - CD 12s - short - mobility - Classes: Archer, Mage - Status: spec
- What: Retreat 90 px, +20% move speed for 2 s.
- In real time: Kiting tool: step out of melee reach then keep firing.
- Synergy: Snare Shot or Frost Shard to keep them slowed.
- Good vs: fast, brute | Weak vs: ranged

### Shoulder Charge (`skill.shoulder_charge`)
Lv 6 (star 1) - Active - CD 14s - short - cc - Classes: Warrior, Thief, Spearman - Status: spec
- What: Dash 120 px and stun the first enemy hit for 0.8 s.
- In real time: Closes gaps on casters and archers; the dash stops on the first body.
- Synergy: Follow with Power Strike or Cleave on the stunned target.
- Good vs: caster, ranged | Weak vs: brute, boss

### Sprint (`skill.sprint`)
Lv 8 (star 1) - Active - CD 22s - self - mobility - Classes: Novice, Warrior, Thief, Spearman, Archer, Mage - Status: spec
- What: +50% move speed for 3 s.
- In real time: Cancels nothing; use to flee, flank or run the relic to the exit.
- Synergy: Follow with Backstep or Sneak skills to reposition.
- Good vs: - | Weak vs: fast

### Bandage (`skill.bandage`)
Lv 9 (star 1) - Active - CD 25s - self - heal - Classes: Warrior, Thief, Spearman, Archer - Status: spec
- What: Heal 15% max HP over 4 s; cancelled if hit by a big strike.
- In real time: Needs a safe moment: use after retreating.
- Synergy: Smoke Bomb or Disengage first.
- Good vs: - | Weak vs: swarm

### Mark Target (`skill.mark_target`)
Lv 10 (star 1) - Active - CD 18s - mid - debuff - Classes: Thief, Archer - Status: spec
- What: Marked enemy takes +20% damage for 6 s.
- In real time: Squad-wide: every ally benefits from the mark.
- Synergy: Any burst; Exploit Weakness upgrades it.
- Good vs: boss, armored | Weak vs: swarm

### Taunt (`skill.taunt`)
Lv 12 (star 2) - Active - CD 22s - area - cc - Classes: Warrior, Spearman - Status: spec
- What: Enemies within 120 px must target you for 4 s.
- In real time: Pulls aggro off the back row, ideal with Guard Stance.
- Synergy: Guard Stance, Iron Skin, Bulwark.
- Good vs: ranged, swarm | Weak vs: caster

### Steady Aim (`skill.steady_aim`)
Lv 14 (star 2) - Active - CD 18s - self - buff - Classes: Archer, Mage - Status: spec
- What: Stand still for 2 s: next skill deals +40% damage.
- In real time: Rewards protected positions; breaks if the hero is ordered to move.
- Synergy: Guard Stance or a front-liner covering the hero.
- Good vs: boss, armored | Weak vs: fast

### Rally Cry (`skill.rally_cry`)
Lv 15 (star 2) - Active - CD 30s - area - buff - Classes: Novice, Warrior, Thief, Spearman, Archer, Mage - Status: spec
- What: Allies within 150 px gain +10% ATK for 6 s.
- In real time: Centre on the squad before the engagement; the radius follows the caster.
- Synergy: Stacks well with a Warrior banner or Haste Aura.
- Good vs: swarm | Weak vs: -

### Caltrops (`skill.caltrops`)
Lv 16 (star 2) - Active - CD 22s - area - cc - Classes: Warrior, Thief, Spearman, Archer - Status: spec
- What: Scatter spikes: area (r60) slows 40% for 5 s.
- In real time: Place in a corridor chokepoint or behind you when retreating.
- Synergy: Combine with Backstep and Volley.
- Good vs: swarm, fast | Weak vs: flying, boss

### Skirmish (`skill.kiting_step`)
Lv 17 (star 2) - Active - CD 16s - short - mobility - Classes: Spearman, Archer - Status: spec
- What: Strike then reposition 70 px away.
- In real time: Keeps reach classes out of enemy range.
- Synergy: Backstep.
- Good vs: brute | Weak vs: fast

### Parry (`skill.parry`)
Lv 18 (star 2) - Active - CD 20s - self - buff - Classes: Warrior, Thief, Spearman - Status: spec
- What: 1.2 s window: the first melee hit is negated and returned at 150%.
- In real time: Timing skill: activate when a telegraph circle is about to land.
- Synergy: Uses enemy wind-up telegraphs (D-014), so it shines against single big hitters.
- Good vs: brute, boss | Weak vs: ranged, swarm

### Snare Shot (`skill.snare_shot`)
Lv 20 (star 2) - Active - CD 15s - mid - cc - Classes: Archer, Mage - Status: spec
- What: Slow one enemy 40% for 3 s.
- In real time: Cheap crowd control, great on fast chasers.
- Synergy: Backstep, Volley or Fire Burst against slowed targets.
- Good vs: fast | Weak vs: boss

### Poison Coat (`skill.poison_coat`)
Lv 21 (star 3) - Active - CD 26s - self - buff - Classes: Thief, Archer - Status: spec
- What: For 8 s attacks apply poison: 3% max HP per second for 4 s.
- In real time: Pre-fight buff that scales with attack speed.
- Synergy: Slows or roots keep targets in poison longer.
- Good vs: brute, boss, beast | Weak vs: undead

### Disengage (`skill.disengage`)
Lv 22 (star 3) - Active - CD 20s - short - mobility - Classes: Warrior, Thief, Spearman - Status: spec
- What: Leap back 100 px and slow nearby enemies 30% for 2 s.
- In real time: Break melee contact before a telegraph lands.
- Synergy: Tank Taunt keeps pressure while others retreat.
- Good vs: brute, fast | Weak vs: ranged

### Net Throw (`skill.net_throw`)
Lv 24 (star 3) - Active - CD 26s - mid - cc - Classes: Warrior, Thief, Spearman, Archer - Status: spec
- What: Root one enemy for 2 s.
- In real time: Hard lock on a single dangerous target.
- Synergy: Assassinate or Aimed Shot on the rooted target.
- Good vs: fast, brute | Weak vs: boss, shielded

### Adrenaline (`skill.adrenaline`)
Lv 25 (star 3) - Active - CD 28s - self - buff - Classes: Novice, Warrior, Thief, Spearman, Archer, Mage - Status: spec
- What: Basic attacks 35% faster for 5 s.
- In real time: Pure DPS window, best on heroes already in range and not moving.
- Synergy: Pairs with Mark Target or Armor Break.
- Good vs: armored, boss | Weak vs: evasive

### Camouflage (`skill.camouflage`)
Lv 26 (star 3) - Active - CD 35s - self - stealth - Classes: Thief, Archer - Status: spec
- What: Hidden for 5 s: enemies drop aggro unless adjacent; breaks on attack.
- In real time: Reset a lost fight, scout ahead, or set up a sniper shot.
- Synergy: Next attack gains bonus from Backstab or Headshot.
- Good vs: ranged, caster | Weak vs: beast

### Smoke Bomb (`skill.smoke_bomb`)
Lv 28 (star 3) - Active - CD 30s - area - cc - Classes: Warrior, Thief, Spearman, Archer - Status: spec
- What: Area (r70) blinds enemies: they lose their target for 2 s.
- In real time: Break enemy aggro to save a wounded hero or slip past a room.
- Synergy: Camouflage or Vanish inside the cloud.
- Good vs: ranged, caster | Weak vs: boss

### Bulwark (`skill.bulwark`)
Lv 30 (star 3) - Active - CD 34s - area - shield - Classes: Warrior, Spearman - Status: spec
- What: Allies within 100 px take 25% less damage for 6 s.
- In real time: Cast when the group is bunched at a door.
- Synergy: Taunt, Phalanx Stance.
- Good vs: swarm, brute | Weak vs: ranged

### Overcharge (`skill.overcharge`)
Lv 32 (star 4) - Active - CD 40s - self - utility - Classes: Archer, Mage - Status: spec
- What: Reduce all own cooldowns by 3 s and refresh basic attack.
- In real time: Chain two big skills back to back.
- Synergy: Place before an ultimate.
- Good vs: boss | Weak vs: -

### Finisher (`skill.finisher`)
Lv 35 (star 4) - Active - CD 16s - melee - dmg - Classes: Warrior, Thief, Spearman - Status: spec
- What: 250% damage to an enemy under 30% HP, otherwise 110%.
- In real time: Pick off wounded enemies; clean up swarms.
- Synergy: Pairs with Rally Cry and bleed or poison effects.
- Good vs: swarm, caster | Weak vs: boss

### Long Reach (`skill.long_reach`)
Lv 38 (star 4) - Active - CD 30s - self - buff - Classes: Spearman, Archer - Status: spec
- What: +30% attack range for 8 s.
- In real time: Hit from outside enemy telegraph radius.
- Synergy: Pike Wall, Steady Aim.
- Good vs: brute, boss | Weak vs: fast

### Last Stand (`skill.last_stand`)
Lv 40 (star 4) - Active - CD 90s - self - shield - Classes: Novice, Warrior, Thief, Spearman, Archer, Mage - Status: spec
- What: For 4 s this hero cannot drop below 1 HP; afterwards takes 15% max HP recoil.
- In real time: Emergency button against permanent death: buys time for a heal or retreat order, not a full save.
- Synergy: Second Breath or an ally heal during the 4 s window.
- Good vs: boss | Weak vs: -

### Iron Resolve (`skill.iron_resolve`)
Lv 45 (star 5) - Active - CD 40s - self - buff - Classes: Warrior, Spearman - Status: spec
- What: Clear debuffs and gain +15% DEF for 8 s.
- In real time: Counter to slows and stuns before a push.
- Synergy: Titan Slam or Colossus Slam after.
- Good vs: caster | Weak vs: -

## Warrior skills

### Cleave (`skill.cleave`)
Lv 1 (star 1) - Active - CD 12s - short - aoe - Classes: Warrior - Status: implemented
- What: 1.6x damage to every enemy within 75 px.
- In real time: Instant sweep around the warrior; hold the line and swing.
- Synergy: Taunt first to gather enemies.
- Good vs: swarm | Weak vs: boss, evasive

### Shield Bash (`skill.shield_bash`)
Lv 7 (star 1) - Active - CD 15s - melee - cc - Classes: Warrior - Status: spec
- What: 110% damage and stun 1.2 s.
- In real time: Interrupt a telegraphed wind-up (D-014) with perfect timing.
- Synergy: Parry then Bash for double control.
- Good vs: caster, brute | Weak vs: boss

### War Roar (`skill.war_roar`)
Lv 11 (star 2) - Active - CD 24s - area - debuff - Classes: Warrior - Status: spec
- What: Enemies within 120 px deal 20% less damage for 6 s.
- In real time: Defensive opener against a pack.
- Synergy: Taunt, Guard Stance.
- Good vs: swarm | Weak vs: boss

### Ground Slam (`skill.ground_slam`)
Lv 14 (star 2) - Active - CD 18s - short - aoe - Classes: Warrior - Status: spec
- What: 120% damage in r90 and slow 30% for 3 s.
- In real time: Ground ring appears around the warrior; enemies inside are slowed.
- Synergy: Archers focus the slowed.
- Good vs: swarm, fast | Weak vs: flying

### Iron Skin (`skill.iron_skin`)
Lv 17 (star 2) - Active - CD 26s - self - buff - Classes: Warrior - Status: spec
- What: +35% DEF for 6 s.
- In real time: Self-armor, pair with Taunt.
- Synergy: Guard Stance.
- Good vs: brute | Weak vs: caster

### Whirlwind (`skill.whirlwind`)
Lv 21 (star 3) - Active - CD 22s - short - aoe - Classes: Warrior - Status: spec
- What: Spin 3 s, hitting r70 every 0.5 s for 60%; move at half speed.
- In real time: Channel while moving through a pack.
- Synergy: War Roar to reduce incoming damage while spinning.
- Good vs: swarm | Weak vs: ranged

### Hamstring (`skill.hamstring`)
Lv 24 (star 3) - Active - CD 16s - melee - cc - Classes: Warrior - Status: spec
- What: 110% damage and slow 50% for 4 s.
- In real time: Keeps fast enemies from escaping the line.
- Synergy: Archer and Mage skills.
- Good vs: fast, evasive | Weak vs: brute

### Armor Break (`skill.armor_break`)
Lv 28 (star 3) - Active - CD 20s - melee - debuff - Classes: Warrior - Status: spec
- What: 130% damage; target DEF -30% for 8 s.
- In real time: Opens a durable target for the whole squad.
- Synergy: Mark Target, Adrenaline, Power Strike.
- Good vs: armored, boss, shielded | Weak vs: swarm

### Berserk Rage (`skill.berserk_rage`)
Lv 32 (star 4) - Active - CD 40s - self - buff - Classes: Warrior - Status: spec
- What: +40% ATK, -20% DEF, 10% lifesteal for 8 s.
- In real time: High risk, high reward; the Reckless trait loves it.
- Synergy: Bandage, Second Breath.
- Good vs: brute, boss | Weak vs: ranged

### Charge Through (`skill.charge_through`)
Lv 36 (star 4) - Active - CD 24s - mid - mobility - Classes: Warrior - Status: spec
- What: Dash 200 px, 140% damage and knockback to all in the path.
- In real time: Plough through a line of enemies to reach the back row.
- Synergy: Shield Bash after landing.
- Good vs: swarm, ranged | Weak vs: boss

### Bloodthirst (`skill.bloodthirst`)
Lv 40 (star 4) - Active - CD 36s - self - buff - Classes: Warrior - Status: spec
- What: Heal 20% of damage dealt for 6 s.
- In real time: Sustain tool for Cleave and Whirlwind.
- Synergy: Whirlwind.
- Good vs: swarm | Weak vs: undead

### Shockwave (`skill.shockwave`)
Lv 44 (star 5) - Active - CD 20s - cone - aoe - Classes: Warrior - Status: spec
- What: 150% damage in a cone with knockback.
- In real time: Pushes enemies out of the squad.
- Synergy: Disengage.
- Good vs: swarm, brute | Weak vs: boss

### Bastion Aura (`skill.bastion_aura`)
Lv 48 (star 5) - Active - CD 45s - area - shield - Classes: Warrior - Status: spec
- What: Allies within 150 px take 15% less damage for 8 s.
- In real time: Stay near the squad while the aura lasts.
- Synergy: Bulwark, Taunt.
- Good vs: ranged, swarm | Weak vs: -

### Executioner (`skill.executioner`)
Lv 52 (star 6) - Active - CD 18s - melee - dmg - Classes: Warrior - Status: spec
- What: 250% damage vs under 35% HP, otherwise 120%.
- In real time: Closer for wounded elites.
- Synergy: Armor Break first.
- Good vs: boss, armored | Weak vs: swarm

### Unbreakable (`skill.unbreakable`)
Lv 56 (star 6) - Active - CD 70s - self - shield - Classes: Warrior - Status: spec
- What: Immune to CC and take 30% less damage for 5 s.
- In real time: Anchor through a boss telegraph chain.
- Synergy: Taunt.
- Good vs: boss, caster | Weak vs: -

### Skull Splitter (`skill.skull_splitter`)
Lv 60 (star 6) - Active - CD 25s - melee - dmg - Classes: Warrior - Status: spec
- What: 300% damage, ignores 50% DEF.
- In real time: Slow overhead swing, best when the target is rooted or stunned.
- Synergy: Shield Bash.
- Good vs: armored, boss | Weak vs: evasive, fast

### Colossus Slam (`skill.colossus_slam`)
Lv 10 (star 1) - Ultimate - CD 60s - area - aoe - Classes: Warrior - Status: spec
- What: r110 area 240% damage and stun 1 s.
- In real time: Big telegraphed ground impact that hits all around.
- Synergy: Taunt, War Roar.
- Good vs: swarm, brute | Weak vs: flying, evasive

### Last Bastion (`skill.last_bastion`)
Lv 30 (star 3) - Ultimate - CD 90s - area - shield - Classes: Warrior - Status: spec
- What: 8 s: allies r180 take 60% less damage; you taunt all.
- In real time: Squad-saving stand during a boss slam.
- Synergy: Bulwark, Bastion Aura.
- Good vs: boss, ranged | Weak vs: -

### Warlord's Banner (`skill.warlord_banner`)
Lv 50 (star 5) - Ultimate - CD 120s - area - buff - Classes: Warrior - Status: spec
- What: 30 s banner r200: allies +20% ATK, +15% SPD; enemies -15% ATK.
- In real time: Plant the banner at a chokepoint; fighting inside it wins.
- Synergy: Rally Cry.
- Good vs: swarm, boss | Weak vs: ranged

### World Splitter (`skill.world_splitter`)
Lv 70 (star 7) - Ultimate - CD 120s - line - dmg - Classes: Warrior - Status: spec
- What: Line 400 px: 400% damage, 30% DEF ignored.
- In real time: Telegraph line forward; targets in the line take the full hit.
- Synergy: Armor Break then Splitter.
- Good vs: armored, boss | Weak vs: evasive

## Thief skills

### Quick Slash (`skill.quick_slash`)
Lv 1 (star 1) - Active - CD 9s - melee - dmg - Classes: Thief - Status: implemented
- What: 220% damage to one nearby enemy.
- In real time: Fast one-shot burst.
- Synergy: Mark Target.
- Good vs: caster | Weak vs: armored

### Backstab (`skill.backstab`)
Lv 6 (star 1) - Active - CD 10s - melee - dmg - Classes: Thief - Status: spec
- What: 200% damage, 300% if the target is fighting another hero.
- In real time: Flank skill: reward positioning behind enemies already engaged.
- Synergy: Taunt from a front-liner.
- Good vs: brute, boss | Weak vs: swarm

### Shadow Step (`skill.shadow_step`)
Lv 9 (star 1) - Active - CD 14s - mid - mobility - Classes: Thief - Status: spec
- What: Teleport behind the target, 120 px.
- In real time: Instant reposition; next attack is a free Backstab.
- Synergy: Backstab.
- Good vs: ranged, caster | Weak vs: -

### Vanish (`skill.vanish`)
Lv 13 (star 2) - Active - CD 30s - self - stealth - Classes: Thief - Status: spec
- What: Invisible 4 s; next attack +100% damage.
- In real time: Escape aggro or set up an opener.
- Synergy: Backstab, Garrote.
- Good vs: ranged | Weak vs: beast

### Light Fingers (`skill.light_fingers`)
Lv 16 (star 2) - Active - CD 40s - self - utility - Classes: Thief - Status: spec
- What: For 12 s hits have 20% chance to drop a small gem pickup.
- In real time: Economy skill, pure reward.
- Synergy: Dagger Flurry.
- Good vs: swarm | Weak vs: -

### Fan of Knives (`skill.fan_of_knives`)
Lv 19 (star 2) - Active - CD 10s - cone - aoe - Classes: Thief - Status: spec
- What: 5 daggers in a cone, 70% each.
- In real time: Wide cone clear.
- Synergy: Poison Coat.
- Good vs: swarm | Weak vs: armored

### Crippling Strike (`skill.crippling_strike`)
Lv 22 (star 3) - Active - CD 16s - melee - cc - Classes: Thief - Status: spec
- What: 110% damage, slow 40% and bleed for 5 s.
- In real time: Lock a runner and keep damaging.
- Synergy: Caltrops.
- Good vs: fast | Weak vs: undead

### Evasion (`skill.evasion`)
Lv 25 (star 3) - Active - CD 32s - self - buff - Classes: Thief - Status: spec
- What: Dodge the next 3 attacks within 5 s.
- In real time: Dodge a telegraphed chain.
- Synergy: Parry-style timing.
- Good vs: brute, boss | Weak vs: ranged, swarm

### Garrote (`skill.garrote`)
Lv 28 (star 3) - Active - CD 24s - melee - cc - Classes: Thief - Status: spec
- What: Silence 2 s and bleed for 4 s; 250% from stealth.
- In real time: Shut down a caster from behind.
- Synergy: Vanish.
- Good vs: caster | Weak vs: undead

### Dagger Flurry (`skill.dagger_flurry`)
Lv 31 (star 4) - Active - CD 18s - melee - dmg - Classes: Thief - Status: spec
- What: 6 rapid hits at 50% over 2 s.
- In real time: Channel; cancelled if stunned.
- Synergy: Adrenaline.
- Good vs: armored, shielded | Weak vs: swarm

### Shadow Clone (`skill.shadow_clone`)
Lv 34 (star 4) - Active - CD 40s - self - summon - Classes: Thief - Status: spec
- What: Decoy absorbs aggro for 5 s.
- In real time: Pulls enemies off allies.
- Synergy: Vanish, Camouflage.
- Good vs: ranged | Weak vs: swarm

### Exploit Weakness (`skill.exploit_weakness`)
Lv 38 (star 4) - Active - CD 24s - mid - debuff - Classes: Thief - Status: spec
- What: Target takes +50% damage from your attacks for 6 s.
- In real time: Pre-burst setup.
- Synergy: Mark Target.
- Good vs: boss | Weak vs: swarm

### Venom Cloud (`skill.venom_cloud`)
Lv 42 (star 5) - Active - CD 28s - area - aoe - Classes: Thief - Status: spec
- What: r80 poison cloud: 4% max HP per sec for 6 s.
- In real time: Zone denial in corridors.
- Synergy: Caltrops.
- Good vs: swarm, beast | Weak vs: undead

### Assassinate (`skill.assassinate`)
Lv 46 (star 5) - Active - CD 20s - melee - dmg - Classes: Thief - Status: spec
- What: 300% vs under 40% HP, else 140%; resets on kill.
- In real time: Hunt through a wounded pack.
- Synergy: Shadow Step.
- Good vs: caster, boss | Weak vs: armored

### Blink Strike (`skill.blink_strike`)
Lv 50 (star 5) - Active - CD 26s - mid - dmg - Classes: Thief - Status: spec
- What: Dash through up to 3 enemies for 120% each.
- In real time: Line pierce while repositioning.
- Synergy: Backstab.
- Good vs: swarm, ranged | Weak vs: boss

### Shadow Dance (`skill.shadow_dance`)
Lv 54 (star 6) - Active - CD 60s - self - buff - Classes: Thief - Status: spec
- What: 5 s: -60% damage taken, +30% SPD, attacks teleport to nearest enemy.
- In real time: Kill window.
- Synergy: Adrenaline.
- Good vs: boss | Weak vs: -

### Deathmark (`skill.deathmark`)
Lv 10 (star 1) - Ultimate - CD 60s - mid - debuff - Classes: Thief - Status: spec
- What: After 5 s the target takes 150% of damage you dealt to it.
- In real time: Stack damage then let the mark burst.
- Synergy: Exploit Weakness.
- Good vs: boss | Weak vs: swarm

### Night of Knives (`skill.night_of_knives`)
Lv 30 (star 3) - Ultimate - CD 90s - area - aoe - Classes: Thief - Status: spec
- What: 6 s: rapid hits on all enemies within r150.
- In real time: Move through a pack.
- Synergy: Fan of Knives.
- Good vs: swarm | Weak vs: armored

### Phantom Army (`skill.phantom_army`)
Lv 50 (star 5) - Ultimate - CD 120s - self - summon - Classes: Thief - Status: spec
- What: 3 clones for 10 s deal 50% damage and distract.
- In real time: Overwhelm with aggro and damage.
- Synergy: Vanish.
- Good vs: boss | Weak vs: -

### Silent End (`skill.silent_end`)
Lv 70 (star 7) - Ultimate - CD 120s - melee - dmg - Classes: Thief - Status: spec
- What: Vanish; next attack kills non-boss under 50% HP or deals 500%.
- In real time: One perfect strike.
- Synergy: Garrote.
- Good vs: caster, boss | Weak vs: swarm

## Spearman skills

### Lunge (`skill.lunge`)
Lv 1 (star 1) - Active - CD 10s - short - dmg - Classes: Spearman - Status: implemented
- What: 190% damage on a long thrust, 100 px.
- In real time: Gap closer with reach.
- Synergy: Brace for Impact.
- Good vs: caster, ranged | Weak vs: swarm

### Pierce Line (`skill.pierce_line`)
Lv 7 (star 1) - Active - CD 12s - line - dmg - Classes: Spearman - Status: spec
- What: Thrust hits everything in a 160 px line for 120%.
- In real time: Line them up first.
- Synergy: Taunt.
- Good vs: swarm | Weak vs: evasive

### Sweep (`skill.sweep`)
Lv 11 (star 2) - Active - CD 14s - cone - aoe - Classes: Spearman - Status: spec
- What: Front arc r100: 90% damage and knockback.
- In real time: Push away melee attackers.
- Synergy: Pike Wall.
- Good vs: swarm | Weak vs: boss

### Brace for Impact (`skill.brace_for_impact`)
Lv 14 (star 2) - Active - CD 20s - self - buff - Classes: Spearman - Status: spec
- What: Set spear 4 s: the first melee attacker takes 200% counter.
- In real time: Against charge telegraphs.
- Synergy: Guard Stance.
- Good vs: brute, fast | Weak vs: ranged

### Spear Throw (`skill.spear_throw`)
Lv 17 (star 2) - Active - CD 15s - mid - dmg - Classes: Spearman - Status: spec
- What: 170% damage at 220 px.
- In real time: Ranged poke, spear returns.
- Synergy: Mark Target.
- Good vs: caster, ranged | Weak vs: armored

### Vault Strike (`skill.vault_strike`)
Lv 20 (star 2) - Active - CD 18s - mid - mobility - Classes: Spearman - Status: spec
- What: Leap 120 px, 140% damage.
- In real time: Gap closer.
- Synergy: Shoulder Charge.
- Good vs: caster | Weak vs: -

### Skewer (`skill.skewer`)
Lv 23 (star 3) - Active - CD 22s - melee - cc - Classes: Spearman - Status: spec
- What: 150% damage, pin target 1.5 s.
- In real time: Locks a runner.
- Synergy: Net Throw.
- Good vs: fast | Weak vs: boss

### Phalanx Stance (`skill.phalanx_stance`)
Lv 26 (star 3) - Active - CD 30s - self - buff - Classes: Spearman - Status: spec
- What: -30% frontal damage, +20% reach for 6 s.
- In real time: Hold a corridor.
- Synergy: Bulwark.
- Good vs: brute | Weak vs: ranged

### Dragoon Leap (`skill.dragoon_leap`)
Lv 30 (star 3) - Active - CD 24s - mid - aoe - Classes: Spearman - Status: spec
- What: Jump 200 px, land r60 for 160%.
- In real time: Aerial opener over the front line.
- Synergy: Dragon Lance.
- Good vs: caster, ranged | Weak vs: flying

### Hooking Pull (`skill.hooking_pull`)
Lv 33 (star 4) - Active - CD 24s - mid - cc - Classes: Spearman - Status: spec
- What: Pull an enemy 120 px to you.
- In real time: Drag a caster out.
- Synergy: Skewer.
- Good vs: caster, ranged | Weak vs: boss

### Whirling Polearm (`skill.whirling_polearm`)
Lv 36 (star 4) - Active - CD 20s - short - aoe - Classes: Spearman - Status: spec
- What: 360 r90 80% damage.
- In real time: Quick clear.
- Synergy: Taunt.
- Good vs: swarm | Weak vs: boss

### Impale (`skill.impale`)
Lv 40 (star 4) - Active - CD 22s - melee - dmg - Classes: Spearman - Status: spec
- What: 220% damage and bleed; double vs charging enemies.
- In real time: Counter to a charge telegraph.
- Synergy: Brace for Impact.
- Good vs: brute, fast | Weak vs: evasive

### Tempo Strike (`skill.tempo_strike`)
Lv 44 (star 5) - Active - CD 16s - melee - dmg - Classes: Spearman - Status: spec
- What: 3-hit combo; each hit adds +20% damage.
- In real time: Needs uninterrupted contact.
- Synergy: Skewer.
- Good vs: boss, armored | Weak vs: evasive

### Pike Wall (`skill.pike_wall`)
Lv 48 (star 5) - Active - CD 40s - line - cc - Classes: Spearman - Status: spec
- What: Spear barrier 5 s: enemies crossing slow 50% and take 60%.
- In real time: Place across a corridor.
- Synergy: Phalanx Stance.
- Good vs: swarm, brute | Weak vs: ranged, flying

### Storm Thrusts (`skill.storm_thrusts`)
Lv 52 (star 6) - Active - CD 24s - short - dmg - Classes: Spearman - Status: spec
- What: 8 thrusts at 40% over 2 s.
- In real time: Channel on a boss.
- Synergy: Armor Break (Warrior).
- Good vs: boss, armored | Weak vs: swarm

### Hunter's Reach (`skill.hunters_reach`)
Lv 56 (star 6) - Active - CD 40s - self - buff - Classes: Spearman - Status: spec
- What: +40% range, +15% damage for 8 s.
- In real time: Pressure ranged enemies.
- Synergy: Long Reach.
- Good vs: ranged, caster | Weak vs: fast

### Dragon Lance (`skill.dragon_lance`)
Lv 10 (star 1) - Ultimate - CD 60s - line - dmg - Classes: Spearman - Status: spec
- What: Beam 300 px for 220% damage.
- In real time: Telegraphed lane.
- Synergy: Pierce Line.
- Good vs: swarm, boss | Weak vs: evasive

### Skyfall Javelin (`skill.skyfall_javelin`)
Lv 30 (star 3) - Ultimate - CD 90s - area - aoe - Classes: Spearman - Status: spec
- What: Leap and throw: r100 for 300%.
- In real time: Big opener.
- Synergy: Dragoon Leap.
- Good vs: swarm, brute | Weak vs: flying

### Phalanx Command (`skill.phalanx_command`)
Lv 50 (star 5) - Ultimate - CD 120s - area - buff - Classes: Spearman - Status: spec
- What: 8 s: allies r200 +15% DEF, +25% reach.
- In real time: Group line fight.
- Synergy: Bulwark.
- Good vs: ranged, swarm | Weak vs: -

### Heaven's Spear (`skill.heavens_spear`)
Lv 70 (star 7) - Ultimate - CD 120s - line - dmg - Classes: Spearman - Status: spec
- What: Throw a huge spear 600 px: 500% damage, leaves a 6 s zone.
- In real time: Telegraphed lane.
- Synergy: Net Throw.
- Good vs: boss, armored | Weak vs: evasive

## Archer skills

### Piercing Shot (`skill.piercing_shot`)
Lv 1 (star 1) - Active - CD 10s - long - dmg - Classes: Archer - Status: implemented
- What: 200% damage, range 230 px.
- In real time: Reliable sniper hit.
- Synergy: Mark Target.
- Good vs: caster | Weak vs: evasive

### Quick Shot (`skill.quick_shot`)
Lv 6 (star 1) - Active - CD 8s - mid - dmg - Classes: Archer - Status: spec
- What: 3 arrows at 50% each.
- In real time: Fast, hits small targets.
- Synergy: Poison Coat.
- Good vs: swarm | Weak vs: armored

### Aimed Shot (`skill.aimed_shot`)
Lv 9 (star 1) - Active - CD 18s - long - dmg - Classes: Archer - Status: spec
- What: 2 s charge, 300% damage.
- In real time: Charge in cover.
- Synergy: Steady Aim.
- Good vs: boss | Weak vs: fast

### Pinning Arrow (`skill.pinning_arrow`)
Lv 12 (star 2) - Active - CD 18s - mid - cc - Classes: Archer - Status: spec
- What: Root target 1.5 s.
- In real time: Keep enemies off allies.
- Synergy: Aimed Shot.
- Good vs: fast, brute | Weak vs: boss

### Volley (`skill.volley`)
Lv 16 (star 2) - Active - CD 20s - area - aoe - Classes: Archer - Status: spec
- What: 5 arrows over 2 s, 50% each, r90.
- In real time: Zone damage.
- Synergy: Caltrops.
- Good vs: swarm | Weak vs: flying

### Poison Arrow (`skill.poison_arrow`)
Lv 19 (star 2) - Active - CD 14s - mid - dmg - Classes: Archer - Status: spec
- What: Poison: 4% max HP per sec for 6 s.
- In real time: Long-fight damage.
- Synergy: Snare Shot.
- Good vs: boss, brute | Weak vs: undead

### Snare Trap (`skill.snare_trap`)
Lv 22 (star 3) - Active - CD 26s - area - cc - Classes: Archer - Status: spec
- What: Place a trap for 20 s: root 2 s.
- In real time: Prepared defense.
- Synergy: Pinning Arrow.
- Good vs: fast, brute | Weak vs: flying

### Explosive Arrow (`skill.explosive_arrow`)
Lv 25 (star 3) - Active - CD 20s - mid - aoe - Classes: Archer - Status: spec
- What: r60 blast at 150%.
- In real time: Clump damage.
- Synergy: Volley.
- Good vs: swarm | Weak vs: evasive

### Ricochet (`skill.ricochet`)
Lv 29 (star 3) - Active - CD 16s - mid - dmg - Classes: Archer - Status: spec
- What: Bounces up to 3 enemies at 100%.
- In real time: Cleanup.
- Synergy: Explosive Arrow.
- Good vs: swarm | Weak vs: boss

### Eagle Eye (`skill.eagle_eye`)
Lv 33 (star 4) - Active - CD 40s - self - buff - Classes: Archer - Status: spec
- What: +25% range, +20% crit for 8 s.
- In real time: Pressure burst.
- Synergy: Aimed Shot.
- Good vs: boss | Weak vs: -

### Disabling Shot (`skill.disabling_shot`)
Lv 37 (star 4) - Active - CD 22s - mid - debuff - Classes: Archer - Status: spec
- What: Target ATK -40% for 5 s.
- In real time: Defensive.
- Synergy: Guard Stance.
- Good vs: brute, boss | Weak vs: ranged

### Rain of Arrows (`skill.rain_of_arrows`)
Lv 41 (star 5) - Active - CD 28s - area - aoe - Classes: Archer - Status: spec
- What: 4 s zone r110: 40% per 0.5 s.
- In real time: Area denial.
- Synergy: Caltrops.
- Good vs: swarm | Weak vs: flying

### Line Shot (`skill.line_shot`)
Lv 45 (star 5) - Active - CD 18s - line - dmg - Classes: Archer - Status: spec
- What: Pierces all in a line for 200%.
- In real time: Line them up.
- Synergy: Taunt.
- Good vs: swarm, armored | Weak vs: evasive

### Headshot (`skill.headshot`)
Lv 49 (star 5) - Active - CD 22s - long - dmg - Classes: Archer - Status: spec
- What: 260% crit vs targets not facing you.
- In real time: Positional.
- Synergy: Taunt.
- Good vs: caster, boss | Weak vs: fast

### Rapid Reposition (`skill.rapid_reposition`)
Lv 53 (star 6) - Active - CD 20s - short - mobility - Classes: Archer - Status: spec
- What: Dash 150 px and refresh attack.
- In real time: Kite.
- Synergy: Backstep.
- Good vs: fast | Weak vs: ranged

### Fire Arrows (`skill.fire_arrows`)
Lv 57 (star 6) - Active - CD 30s - self - buff - Classes: Archer - Status: spec
- What: 6 s: attacks burn 3% per sec.
- In real time: Sustained.
- Synergy: Poison Coat.
- Good vs: beast, undead | Weak vs: -

### Arrow Storm (`skill.arrow_storm`)
Lv 10 (star 1) - Ultimate - CD 60s - area - aoe - Classes: Archer - Status: spec
- What: 5 s hail r140.
- In real time: Group clear.
- Synergy: Volley.
- Good vs: swarm | Weak vs: flying

### Sniper's Verdict (`skill.snipers_verdict`)
Lv 30 (star 3) - Ultimate - CD 90s - long - dmg - Classes: Archer - Status: spec
- What: 3 s channel: 500% damage.
- In real time: Hold position.
- Synergy: Net Throw.
- Good vs: boss | Weak vs: fast

### Phantom Volley (`skill.phantom_volley`)
Lv 50 (star 5) - Ultimate - CD 120s - area - dmg - Classes: Archer - Status: spec
- What: 12 homing arrows at 100%.
- In real time: No aim needed.
- Synergy: Mark Target.
- Good vs: evasive, swarm | Weak vs: -

### Sunfall Barrage (`skill.sunfall_barrage`)
Lv 70 (star 7) - Ultimate - CD 120s - area - aoe - Classes: Archer - Status: spec
- What: 8 s r200 field: 100% per 0.5 s.
- In real time: Room-wide.
- Synergy: Caltrops.
- Good vs: swarm, boss | Weak vs: flying

## Mage skills

### Fire Burst (`skill.fire_burst`)
Lv 1 (star 1) - Active - CD 14s - mid - aoe - Classes: Mage - Status: implemented
- What: 180% damage in r80 around the target.
- In real time: Reliable burst.
- Synergy: Frost Shard.
- Good vs: swarm, undead | Weak vs: shielded

### Frost Shard (`skill.frost_shard`)
Lv 6 (star 1) - Active - CD 10s - mid - dmg - Classes: Mage - Status: spec
- What: 140% damage, slow 30% for 3 s.
- In real time: Kite control.
- Synergy: Fire Burst.
- Good vs: fast | Weak vs: undead

### Spark Chain (`skill.spark_chain`)
Lv 10 (star 1) - Active - CD 12s - mid - dmg - Classes: Mage - Status: spec
- What: Chains 3 targets at 110%.
- In real time: Good vs packs.
- Synergy: Mana Shield.
- Good vs: swarm | Weak vs: boss

### Mana Shield (`skill.mana_shield`)
Lv 13 (star 2) - Active - CD 26s - self - shield - Classes: Mage - Status: spec
- What: Absorb damage up to 120% MAG for 6 s.
- In real time: Defence.
- Synergy: Blink.
- Good vs: ranged | Weak vs: brute

### Flame Wall (`skill.flame_wall`)
Lv 16 (star 2) - Active - CD 24s - line - aoe - Classes: Mage - Status: spec
- What: 5 s wall burns for 4% per sec.
- In real time: Block a corridor.
- Synergy: Gravity Well.
- Good vs: swarm, beast | Weak vs: flying

### Blink (`skill.blink`)
Lv 19 (star 2) - Active - CD 18s - mid - mobility - Classes: Mage - Status: spec
- What: Teleport 150 px.
- In real time: Escape.
- Synergy: Mana Shield.
- Good vs: brute | Weak vs: ranged

### Frost Nova (`skill.frost_nova`)
Lv 22 (star 3) - Active - CD 24s - area - cc - Classes: Mage - Status: spec
- What: r100 freeze 1.2 s.
- In real time: Panic button.
- Synergy: Blink.
- Good vs: swarm, brute | Weak vs: boss

### Arcane Missiles (`skill.arcane_missiles`)
Lv 25 (star 3) - Active - CD 16s - mid - dmg - Classes: Mage - Status: spec
- What: 2 s channel: 5 homing missiles at 60%.
- In real time: Evasive targets.
- Synergy: Steady Aim.
- Good vs: evasive | Weak vs: shielded

### Lightning Bolt (`skill.lightning_bolt`)
Lv 28 (star 3) - Active - CD 14s - long - dmg - Classes: Mage - Status: spec
- What: 240% damage, stun 0.5 s.
- In real time: Heavy single target.
- Synergy: Frost Nova.
- Good vs: armored | Weak vs: ranged

### Barrier (`skill.barrier`)
Lv 31 (star 4) - Active - CD 28s - ally - shield - Classes: Mage - Status: spec
- What: Shield an ally for 20% max HP for 6 s.
- In real time: Protect a front-liner.
- Synergy: Taunt.
- Good vs: boss | Weak vs: -

### Gravity Well (`skill.gravity_well`)
Lv 34 (star 4) - Active - CD 26s - area - cc - Classes: Mage - Status: spec
- What: r90 pull and slow 4 s.
- In real time: Clump enemies for AoE.
- Synergy: Fire Burst.
- Good vs: swarm | Weak vs: boss

### Curse of Weakness (`skill.curse_weakness`)
Lv 37 (star 4) - Active - CD 24s - mid - debuff - Classes: Mage - Status: spec
- What: -25% ATK and DEF for 8 s.
- In real time: Debuff boss.
- Synergy: Armor Break.
- Good vs: boss, brute | Weak vs: swarm

### Meteor Call (`skill.meteor_call`)
Lv 40 (star 4) - Active - CD 30s - area - aoe - Classes: Mage - Status: spec
- What: 1.5 s delay, r90 for 300%.
- In real time: Delayed telegraph.
- Synergy: Gravity Well.
- Good vs: swarm, brute | Weak vs: fast

### Haste Aura (`skill.haste_aura`)
Lv 43 (star 5) - Active - CD 38s - area - buff - Classes: Mage - Status: spec
- What: Allies +20% SPD for 6 s.
- In real time: Squad rush.
- Synergy: Rally Cry.
- Good vs: boss | Weak vs: -

### Mind Blast (`skill.mind_blast`)
Lv 46 (star 5) - Active - CD 20s - area - cc - Classes: Mage - Status: spec
- What: Silence r70 for 3 s, 120% damage.
- In real time: Counter casters.
- Synergy: Curse.
- Good vs: caster | Weak vs: brute

### Soul Siphon (`skill.soul_siphon`)
Lv 55 (star 6) - Active - CD 28s - mid - dmg - Classes: Mage - Status: spec
- What: 5 s drain 60% per sec, heal self.
- In real time: Sustain.
- Synergy: Barrier.
- Good vs: boss | Weak vs: undead

### Cataclysm (`skill.cataclysm`)
Lv 10 (star 1) - Ultimate - CD 60s - area - aoe - Classes: Mage - Status: spec
- What: r120 for 300%.
- In real time: Large blast.
- Synergy: Gravity Well.
- Good vs: swarm | Weak vs: flying

### Absolute Zero (`skill.absolute_zero`)
Lv 30 (star 3) - Ultimate - CD 90s - area - cc - Classes: Mage - Status: spec
- What: r180 freeze 2.5 s and +30% damage.
- In real time: Control.
- Synergy: Fire Burst.
- Good vs: swarm | Weak vs: boss

### Starfall (`skill.starfall`)
Lv 50 (star 5) - Ultimate - CD 120s - area - aoe - Classes: Mage - Status: spec
- What: 6 meteors over 5 s at 200%.
- In real time: Area denial.
- Synergy: Frost Nova.
- Good vs: swarm, boss | Weak vs: fast

### Chrono Lock (`skill.chrono_lock`)
Lv 70 (star 7) - Ultimate - CD 150s - area - cc - Classes: Mage - Status: spec
- What: r220: enemies frozen 4 s (non-boss).
- In real time: Combo window.
- Synergy: Haste Aura.
- Good vs: swarm | Weak vs: boss

## Novice skills

### Scrap (`skill.scrap`)
Lv 2 (star 1) - Active - CD 8s - melee - dmg - Classes: Novice - Status: spec
- What: Wild flurry: 1.4x damage to one enemy.
- In real time: Novice staple. Short range, no setup.
- Synergy: None, it is the Novice opener.
- Good vs: caster | Weak vs: armored

### Desperate Swing (`skill.desperate_swing`)
Lv 9 (star 1) - Active - CD 18s - melee - dmg - Classes: Novice - Status: spec
- What: 2.0x damage, but take 5% max HP recoil.
- In real time: All-in hit for a Novice about to be promoted.
- Synergy: Second Breath afterwards.
- Good vs: caster | Weak vs: armored, shielded
