class_name AiDefs
extends RefCounted
## D-082: numbers for the autonomous heroes (layered AI), the ping wheel, revive, the bandits' roles and
## the way each weapon hits. Every value is a tuning placeholder. All randomness that reads these goes
## through the unit's seeded combat_rng (never the global randf) so the coming deterministic core can
## replay a fight.

# --- hero AI: layers (highest priority first) ------------------------------------------------------
## 1 survival (panic, potions, falling back) > 2 orders (pings, Commands) > 3 role > 4 personality.
const LAYERS := ["survival", "orders", "role", "personality"]

## Imperfection: an autonomous hero re-decides every DECIDE_MIN..DECIDE_MAX seconds, not every frame.
## Calm heroes (Composure 100) decide fastest; at Composure 0 they take DECIDE_MAX. DECIDE_JITTER adds a
## seeded spread so five heroes never think on the same tick.
const DECIDE_MIN := 0.2
const DECIDE_MAX := 0.8
const DECIDE_JITTER := 0.1
## Aim error of a shot, in degrees either side: AIM_BASE_DEG - AIM_PER_AGI x AGI (never below AIM_MIN_DEG),
## + AIM_COMPOSURE_DEG x (1 - Composure / 100); panicking multiplies it by AIM_PANIC_MULT.
const AIM_BASE_DEG := 9.0
const AIM_PER_AGI := 0.45
const AIM_MIN_DEG := 1.5
const AIM_COMPOSURE_DEG := 10.0
const AIM_PANIC_MULT := 2.0
## Sometimes an autonomous hero picks a target that is not the ideal one (any foe it can see in reach).
const WRONG_TARGET_CHANCE := 0.07

## Role of each class (layer 3).
const ROLE_BY_CLASS := {
    "class.warrior": "tank", "class.rogue": "dps", "class.mage": "dps", "class.archer": "scout",
    "class.cleric": "healer", "class.commoner": "support", "class.none": "support",
}
## tank: goes to the front and peels the foe hitting the weakest ally within PROTECT_RADIUS.
## dps: sticks to the squad's focus target (pinged / spotted / the one the most heroes hit).
## healer: stays HEALER_BACK px behind the front and keeps healing.
## scout: walks SCOUT_AHEAD px ahead of the Master when calm and keeps SCOUT_KEEP px from foes.
## support: helps the others' target and keeps SUPPORT_BACK px behind the front.
const PROTECT_RADIUS := 180.0
const HEALER_BACK := 110.0
const SCOUT_AHEAD := 90.0
const SCOUT_KEEP := 120.0
const SUPPORT_BACK := 60.0
const HEALER_SAFE := 150.0          # a healer steps back when a foe gets closer than this

## Personality (layer 4): small nudges by trait. ahead = px it walks in front of (or, negative, behind) its
## role spot; delay = extra seconds before it answers a ping or a Command; ignore_retreat_hp = above this
## health fraction it ignores a retreat ping (reckless); attack_delay = extra seconds before an attack ping.
const PERSONALITY := {
    "trait.reckless": {"ahead": 50.0, "delay": 0.0, "ignore_retreat_hp": 0.5, "attack_delay": 0.0},
    "trait.hot_headed": {"ahead": 30.0, "delay": 0.0, "ignore_retreat_hp": 0.7, "attack_delay": 0.0},
    "trait.cautious": {"ahead": -40.0, "delay": 0.2, "attack_delay": 0.8},
    "trait.gloomy": {"ahead": -20.0, "delay": 0.2, "attack_delay": 0.4},
    "trait.loyal": {"ahead": 0.0, "delay": -0.3, "follows_master": true},
}

# --- revive (D-036 amended by D-082) -------------------------------------------------------------
## A downed hero has AGONY_TIME seconds (CombatRules) before dying. Lifting them = staying next to them
## REVIVE_HOLD seconds (the Master holds F; the AI channels the same time); a hit interrupts it.
## Autonomous heroes go lift a fallen ally on their own when their score (role + bond + personality)
## reaches REVIVE_MIN_SCORE and no foe stands within REVIVE_SAFE of the fallen.
const REVIVE_PROMPT_RANGE := 48.0
const REVIVE_MIN_SCORE := 1.0
const REVIVE_SAFE := 70.0
const REVIVE_ROLE_SCORE := {"healer": 2.0, "support": 1.2, "tank": 0.8, "dps": 0.6, "scout": 0.6}
const REVIVE_BOND_LEVEL := 50       # relationship level with the fallen from which the bond counts
const REVIVE_BOND_SCORE := 1.0
const REVIVE_TRAIT_SCORE := {"trait.kind": 0.8, "trait.loyal": 0.5, "trait.cautious": -0.3, "trait.arrogant": -0.4}
const REVIVE_RADIUS := 420.0        # how far an autonomous hero will go on its own to lift an ally

# --- pings ----------------------------------------------------------------------------------------
## Quick ping: Shift + click (contextual). Wheel: hold Shift + click PING_WHEEL_HOLD seconds, release on an
## option. PING_MODIFIER is the key held for both (configurable; the input action "ping" uses it).
const PING_MODIFIER := KEY_SHIFT
const PING_WHEEL_HOLD := 0.25
const PING_WHEEL_INNER := 44.0      # px (D-082b: ~60 % of the first size; the canvas stretch scales it with the UI)
const PING_WHEEL_OUTER := 74.0
const PING_WHEEL_DEAD := 10.0       # px around the centre: releasing there cancels
## The eight pings, in wheel order (clockwise from the top). life = seconds the marker stays on the map.
const PINGS := {
    "regroup": {"name": "Regroup!", "icon": "order_follow", "color": Color(0.55, 0.95, 0.6), "life": 4.0},
    "attack": {"name": "Attack here", "icon": "order_attack", "color": Color(1.0, 0.4, 0.3), "life": 4.0},
    "defend": {"name": "Defend this area", "icon": "order_hold", "color": Color(0.55, 0.75, 1.0), "life": 6.0},
    "explore": {"name": "Explore here", "icon": "order_explore", "color": Color(0.9, 0.85, 0.5), "life": 4.0},
    "gather": {"name": "Gather here", "icon": "order_interact", "color": Color(0.75, 0.6, 0.35), "life": 4.0},
    "danger": {"name": "Danger! Fall back", "icon": "order_retreat", "color": Color(1.0, 0.75, 0.2), "life": 4.0},
    "spotted": {"name": "Enemy spotted", "icon": "order_attack_move", "color": Color(1.0, 0.25, 0.55), "life": 8.0},
    "help": {"name": "Help / lift", "icon": "order_move", "color": Color(0.5, 1.0, 0.9), "life": 5.0},
    "camp": {"name": "Camp here", "icon": "order_hold", "color": Color(1.0, 0.65, 0.3), "life": 5.0},   # D-090 (CampDefs)
    # quick ping on bare ground (not on the wheel)
    "move": {"name": "Go here", "icon": "order_move", "color": Color(0.95, 0.95, 0.95), "life": 3.0},
}
const PING_ORDER := ["regroup", "attack", "defend", "explore", "gather", "danger", "spotted", "help", "camp"]
## A ping order lasts this long; then the hero goes back to its own judgement (Auto).
const PING_ORDER_TIME := 14.0
const DEFEND_RADIUS := 120.0        # a "defend" ping fights what comes this close to the spot
const DANGER_DIST := 220.0          # a "danger" ping sends heroes this far from the spot, toward the Master
const SPOTTED_TIME := 8.0           # an "enemy spotted" foe stays visible to everyone this long
## Who answers and how fast. Every hero answers after REACT_BASE + its personality delay; outside the
## Master's leadership_radius() it takes OUT_OF_RADIUS_DELAY more. Obedience (effective, with the
## Leadership and bond bonuses, minus the spam penalty) below CombatRules.OBEY_MIN = it does not obey
## (it says so). Deterministic: never a roll (D-016).
const REACT_BASE := 0.3
const OUT_OF_RADIUS_DELAY := 0.6
## Anti-spam: more than SPAM_COUNT pings within SPAM_WINDOW seconds costs SPAM_PENALTY Obedience per extra
## ping, up to SPAM_MAX; the penalty fades at SPAM_DECAY points per second.
const SPAM_WINDOW := 5.0
const SPAM_COUNT := 4
const SPAM_PENALTY := 6.0
const SPAM_MAX := 40.0
const SPAM_DECAY := 2.0

# --- bandit AI by role (D-082) ----------------------------------------------------------------------
## Bandit role per creature type (EnemyDefs types keep their combat role; this is how they think).
const BANDIT_AI := {
    "bandido_bruto": "brute", "bandido_maton": "brute", "bandido_degollador": "assassin",
    "bandido_arquero": "archer", "bandido_mago": "caster", "bandido_chaman": "support",
    "capitan_bandido": "leader", "jefe_baron_carmesi": "brute",
}
## Brute: goes for the highest threat it has taken (damage dealt to it); threat decays THREAT_DECAY per s.
const THREAT_DECAY := 0.15
## D-090 aggro: every creature keeps a threat table. Damage dealt to it adds THREAT_PER_DAMAGE per point,
## healing an ally adds THREAT_PER_HEAL per point healed to every awake creature within THREAT_HEAL_RADIUS
## of the healed ally that is already fighting; both x THREAT_CLASS_MULT of the hero's class (warrior x2).
## A taunt (War Cry) forces the target for its duration and puts the taunter TAUNT_TOP x above the top.
## Creatures with no special role (and the brutes) follow the table; it switches only when another hero
## passes the current one by THREAT_SWITCH (no flip-flopping between two close values).
const THREAT_PER_DAMAGE := 1.0
const THREAT_PER_HEAL := 0.5
const THREAT_HEAL_RADIUS := 320.0
const THREAT_CLASS_MULT := {"warrior": 2.0}   # keyed without "class." (simulator overrides: AiDefs.THREAT_CLASS_MULT.warrior)
const TAUNT_TOP := 1.1
const THREAT_SWITCH := 1.1
## Archer creatures (bandido_arquero): the hero in range with a clear shot, nearest first.
const ARCHER_PICK_RANGE := 1.0      # x its strike range
## Assassin: hunts these classes first (unless taunted).
const ASSASSIN_PREY := ["class.cleric", "class.mage"]
const ASSASSIN_REACH := 2.0         # x perception for its prey
## Archer: keeps ARCHER_KEEP px and, with no line of sight, looks for a spot that has one.
const ARCHER_KEEP := 120.0
const ARCHER_LOS_TRIES := 8
## Caster: backs off when a hero is closer than CASTER_PRESSED (shorter cooldown than other ranged).
const CASTER_PRESSED := 95.0
const CASTER_BACK_CD := 1.2
## Leader: every LEADER_EVERY s buffs the bandits within LEADER_RADIUS ("inspired" for LEADER_BUFF_TIME).
const LEADER_EVERY := 4.0
const LEADER_RADIUS := 200.0
const LEADER_BUFF_TIME := 5.0
## Fleeing: once under FLEE_HP a bandit rolls FLEE_CHANCE (once) to run for FLEE_TIME s.
const FLEE_HP := 0.25
const FLEE_CHANCE := 0.35
const FLEE_TIME := 6.0
## Horn: the "horn" bandit of a group sounds it HORN_DELAY s after being alerted (or at once under
## HORN_HP): every sleeping creature within HORN_RADIUS wakes and comes.
## D-084 noise: a creature that joins a fight wakes the awake-but-idle creatures of OTHER groups within
## NOISE_RADIUS (once; they do not spread it further). Charging into the middle of the camps pulls them all.
const NOISE_RADIUS := 260.0
## D-084 surrounded: SURROUND_MIN+ awake foes within SURROUND_RADIUS of a hero -> it takes SURROUND_MULT damage.
const SURROUND_RADIUS := 72.0
const SURROUND_MIN := 3
const SURROUND_MULT := 1.25
const HORN_DELAY := 5.0
const HORN_HP := 0.6
const HORN_RADIUS := 520.0
## Morale: when a leader dies, every bandit within MORALE_RADIUS rolls MORALE_FLEE to run (FLEE_TIME).
const MORALE_RADIUS := 320.0
const MORALE_FLEE := 0.5

# --- weapons: how each one hits (D-082) ---------------------------------------------------------------
## hits = blows per basic attack, gap = seconds between them, mult = share of the hero's power per blow
## (flat armour applies to every blow, so many light blows do less against armour).
## Rogue: two daggers, left then right: ~55 % of a warrior's blow each. With the rogue's own attributes
## (more AGI = a quicker rhythm, less FUE) its damage per second stays within ~15 % of a warrior's of the
## same level against an unarmoured foe (tests/smoke_ai.gd checks levels 1, 5 and 10).
const WEAPON_PATTERN := {
    "dagger": {"hits": 2, "gap": 0.15, "mult": 0.55},
}
## Bows: the basic shot is a real arrow (not homing): it flies toward where the target was when it was
## released, so the target can step out of it. BOW_DRAW = seconds of draw before the release.
const BOW_DRAW := 0.3
const BOW_RANGE := 230.0            # also never beyond what the hero sees in the fog (vision_cells)
const SHOT_SPEED := 520.0           # px/s of a hero's basic shot (arrow or bolt)
const SHOT_WIDTH := 4.0             # half-width of the arrow, added to the body it can touch
const ARROW_STICK := 0.6            # seconds a landed arrow stays stuck before it fades
const ARROW_TRAIL := 0.12           # seconds of trail behind a flying arrow
## D-090 finite arrows: an archer enters with ARROWS_START (+ the "arrows" it carries in its bag: making and
## buying them is pista D). Each shot spends one; an arrow that lands in a creature can be taken back from
## its body (ARROW_RECOVER of them, walking within ARROW_PICKUP px; the AI goes for bodies within ARROW_SEEK
## when calm). With none left the archer fights up close at NO_ARROW_MULT. ARROWS_LOW = shown over the hero.
const ARROWS_START := 60
const ARROW_BAG_ID := "arrows"
const ARROW_RECOVER := 0.75
const ARROW_PICKUP := 36.0
const ARROW_SEEK := 320.0
const NO_ARROW_MULT := 0.5
const ARROWS_LOW := 12


## Seconds between two decisions of an autonomous hero (Composure 0-100).
static func decide_interval(composure: int) -> float:
    var k := clampf(float(composure) / 100.0, 0.0, 1.0)
    return lerpf(DECIDE_MAX, DECIDE_MIN, k)


## Aim error (degrees either side) for a shot.
static func aim_error_deg(agi: int, composure: int, panicked: bool) -> float:
    var e := maxf(AIM_MIN_DEG, AIM_BASE_DEG - AIM_PER_AGI * float(agi))
    e += AIM_COMPOSURE_DEG * (1.0 - clampf(float(composure) / 100.0, 0.0, 1.0))
    return e * (AIM_PANIC_MULT if panicked else 1.0) * SimMode.aim_error_mult   # D-083: 1.0 in the game


static func role_of(class_id: String) -> String:
    return String(ROLE_BY_CLASS.get(class_id, "support"))


## The personality nudges of a hero (sum over its traits).
static func personality(traits: Array) -> Dictionary:
    var p := {"ahead": 0.0, "delay": 0.0, "ignore_retreat_hp": 2.0, "attack_delay": 0.0, "follows_master": false}
    for t in traits:
        var d: Dictionary = PERSONALITY.get(t, {})
        p["ahead"] = float(p["ahead"]) + float(d.get("ahead", 0.0))
        p["delay"] = float(p["delay"]) + float(d.get("delay", 0.0))
        p["attack_delay"] = float(p["attack_delay"]) + float(d.get("attack_delay", 0.0))
        if d.has("ignore_retreat_hp"):
            p["ignore_retreat_hp"] = minf(float(p["ignore_retreat_hp"]), float(d["ignore_retreat_hp"]))
        if bool(d.get("follows_master", false)):
            p["follows_master"] = true
    return p
