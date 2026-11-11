class_name HeroData
extends RefCounted
## One summoned hero. Everything needed to rebuild it lives in to_dict(), so saves
## never depend on the generator staying identical between versions.

var id: String = ""
var hero_seed: int = 0
var hero_name: String = ""
var is_master: bool = false       # D-080: the player's own character (MasterDefs); never dies, sold or consumed
var first_name: String = ""       # D-080: the Master's chosen name and surname (hero_name = both)
var surname: String = ""
var leadership_points: int = 0    # D-081: Leadership from the Master's memories (MasterRules.leadership)
var master_memories: Array = []   # D-081: memory ids unlocked (MasterMemories), Master only
var bond_master: int = MasterDefs.BOND_START   # D-081: bond with the Master, 0-100 (MasterRules.bond_tier)
var epithet: String = ""
var stars: int = 1
var level: int = 1
var xp: int = 0
var hero_class: String = "class.none"
var look: Dictionary = {}         # overhaul LPC (D-A): race, body, skin, eyes, head, ears, hair, beard (LpcWardrobe)
var appearance: Dictionary = {}   # layer key -> "Folder/style_color" ("" = layer not used)
var traits: Array = []            # trait ids
var passives: Array = []          # passive ids
var innate: Array = []            # D-079 summon gifts (PowerDefs.GIFTS), rolled once at the summon; old heroes keep []
var background_id: String = ""
var background_text: String = ""
var profession: String = ""        # past life profession/job for base building lobby bonuses
var variance: Dictionary = {}     # stat key -> small seeded multiplier
var callsign: String = ""         # only set when another hero would share the same display name
var generator_version: int = 1    # 1 = Drop A heroes, 2 = summon system v2
var origin_banner: String = ""
var summon_index: int = 0         # global pull number when summoned (0 = unknown/legacy)
# Social state (spec sec 7). Three SEPARATE values; none of them ever blocks a direct order.
var trust: int = 50               # long-term, 0-100: belief that the commander protects/keeps promises
var obedience: int = 50           # long-term, 0-100: command discipline
var composure: int = 100          # short-term mission steadiness, 0-100 (resets between missions)
# Simulation fields (Phase 2 & 3): memories, relationships, hq assignments, activity states, secrets
var memories: Array = []          # [{"id": String, "type": String, "text": String, "time": int, "actor_id": String, "importance": int}]
var relationships: Dictionary = {} # other_id -> {"level": int, "status": String, "interactions": int}
var hq_assignment: String = ""    # workplace: "" | a building id | "construction" (D-048)
## Town activity (single state, TownSim): idle | working | sleeping | eating | socializing |
## in_treatment | deployed. Exclusive: a hero is never working and deployed at once.
var activity_state: String = "idle"
# Town life (HQ Phase 1, save v9): professions (D-049), needs, health, bed, gear.
var apprenticeship: Dictionary = {}  # prof -> {"hours", "progress" 0..1} beside a master (AptitudeDefs)
var aptitude_known: Dictionary = {}  # prof -> aptitude tier the player has learned (the master's opinion)
var professions: Dictionary = {}  # prof id -> {"lvl": int, "xp": float}; at most ProfessionDefs.MAX_KNOWN
var passion: String = ""          # profession from the past life (learns faster)
var hunger: int = 0               # 0 fed .. 100 starving
var fatigue: int = 0              # 0 rested .. 100 exhausted
var stress: int = 0               # 0 calm .. 100 breaking
var diseases: Array = []          # [{"id": String, "hours": float, "cause": String}]
var bed: String = ""              # dorm id ("" = sleeps rough), kept while deployed or in hospital
var exhausted_hours: int = 0
var equipment: Dictionary = {}    # slot -> item dict (ItemDefs.SLOTS)
var bag: Dictionary = {}          # consumable id -> count, carried into the tower
var hoard: Array = []             # D-125: items a greedy hero kept back from the loot ("caught" = the Master knows)
var bonus_skill_choice: int = 0   # D-129: extra skill choices from skill tomes (pista A reads it)
var discovered_secrets: Array = [] # secret IDs discovered
var secret_clues: Array = []      # discovered clue strings

# Active skills (combat Phase 3, D-043..D-046): known skills, the W/E/R loadout (D-059) and the
# level-up choices still waiting for the player.
var skills: Array = []            # known skill ids (SkillDefs.SKILLS)
var loadout: Array = []           # equipped ids, up to SkillDefs.MAX_SLOTS, in W E R order
var skill_choices: Array = []     # [{"level": int, "options": [ids]}], oldest first
var ascension_fails: int = 0      # failed ascension attempts in a row (pity, ProgressionDefs)
var trained_skills: int = 0       # skills learned at the Training Grounds
var synth_bonus: Dictionary = {}  # D-061: permanent attribute points absorbed by synthesis {attr: n}
var synthesis_history: Array = [] # [{"from": hero id, "name": String, "xp": int, "attr": String}]

# Structured event ledger: [{seq, type, trust, obedience, info}], newest last, capped.
var events: Array = []
var event_seq: int = 0

const EVENT_CAP := 100
const MEMORY_CAP := 50


func add_memory(type: String, text: String, actor_id: String = "", importance: int = 1) -> void:
    memories.append({
        "id": "mem_%d_%d" % [Time.get_ticks_msec(), memories.size()],
        "type": type,
        "text": text,
        "time": event_seq,
        "actor_id": actor_id,
        "importance": importance
    })
    while memories.size() > MEMORY_CAP:
        memories.pop_front()


func update_relationship(other_id: String, delta: int, _context: String = "") -> void:
    if other_id == "" or other_id == id:
        return
    var rel: Dictionary
    if relationships.has(other_id):
        rel = (relationships[other_id] as Dictionary).duplicate()
    else:
        rel = {"level": 0, "status": "unfamiliar", "interactions": 0}
    rel["level"] = clampi(int(rel["level"]) + delta, -100, 100)
    rel["interactions"] = int(rel["interactions"]) + 1
    var lvl: int = rel["level"]
    if lvl < -25:
        rel["status"] = "hostile"
    elif lvl < 0:
        rel["status"] = "acquaintance"
    elif lvl <= 20:
        rel["status"] = "acquaintance"
    elif lvl <= 50:
        rel["status"] = "friend"
    else:
        rel["status"] = "trusted_ally"
    relationships[other_id] = rel


func get_relationship(other_id: String) -> Dictionary:
    if relationships.has(other_id):
        return relationships[other_id]
    return {"level": 0, "status": "unfamiliar", "interactions": 0}


func discover_secret(secret_id: String, clue_text: String) -> bool:
    if discovered_secrets.has(secret_id):
        return false # idempotent protection against duplicate discovery rewards
    discovered_secrets.append(secret_id)
    if clue_text != "" and not secret_clues.has(clue_text):
        secret_clues.append(clue_text)
    add_memory("secret_discovery", "Discovered secret technique: %s" % secret_id, "", 3)
    add_event("discovered_secret", {"secret_id": secret_id}, 5, 2)
    return true


func rescue_hero(other_hero: HeroData) -> void:
    if other_hero == null or other_hero.id == id:
        return
    add_memory("rescue", "Rescued %s from mortal danger." % other_hero.display_name(), other_hero.id, 3)
    update_relationship(other_hero.id, 15, "rescue")
    add_event("rescued_ally", {"ally_id": other_hero.id}, 5, 0)


func cooperate_with(other_hero: HeroData) -> void:
    if other_hero == null or other_hero.id == id:
        return
    add_memory("cooperate", "Worked closely with %s." % other_hero.display_name(), other_hero.id, 2)
    update_relationship(other_hero.id, 3, "cooperation")


func base_display_name() -> String:
    if epithet == "":
        return hero_name
    return "%s %s" % [hero_name, epithet]


func display_name() -> String:
    if callsign == "":
        return base_display_name()
    return "%s \"%s\"" % [base_display_name(), callsign]


## Records a structured event and applies its deterministic Trust/Obedience deltas.
func add_event(type: String, info: Dictionary = {}, trust_delta: int = 0, obedience_delta: int = 0) -> void:
    trust = clampi(trust + trust_delta, 0, 100)
    obedience = clampi(obedience + obedience_delta, 0, 100)
    event_seq += 1
    events.append({"seq": event_seq, "type": type, "trust": trust_delta, "obedience": obedience_delta, "info": info.duplicate()})
    while events.size() > EVENT_CAP:
        events.pop_front()


## JSON turns every number into a float. Whole floats go back to ints so a reloaded
## ledger/log is identical to what was saved.
static func intify(v: Variant) -> Variant:
    match typeof(v):
        TYPE_FLOAT:
            return int(v) if is_equal_approx(v, roundf(v)) else v
        TYPE_DICTIONARY:
            var out := {}
            for k in v:
                out[k] = intify(v[k])
            return out
        TYPE_ARRAY:
            return v.map(func(x): return intify(x))
    return v


func set_composure(v: int) -> void:
    composure = clampi(v, 0, 100)


## Old (v1) saves only had one "loyalty" number. It becomes Trust; Obedience is derived from traits.
static func legacy_obedience(trait_ids: Array) -> int:
    var v := 50
    for t in trait_ids:
        v += int(HeroTables.OBEDIENCE_MODS.get(t, 0))
    return clampi(v, 0, 100)


## D-081: command ids granted by memories (MasterMemories rewards), in addition to the level unlocks.
func memory_commands() -> Array:
    var out: Array = []
    for mid in master_memories:
        var c := String((MasterMemories.info(String(mid)).get("reward", {}) as Dictionary).get("command", ""))
        if MasterDefs.COMMANDS.has(c):
            out.append(c)
    return out


func class_title() -> String:
    return String(HeroTables.CLASSES[hero_class]["name"])


func star_color() -> Color:
    return HeroTables.STAR_COLORS[stars]


func signature() -> String:
    var parts: Array = []
    for key in SpriteComposer.LAYER_ORDER:
        parts.append(String(appearance.get(key, "")))
    return "|".join(parts)


func level_cap() -> int:
    return int(HeroTables.STAR_DATA[stars]["level_cap"])


func is_max_level() -> bool:
    return level >= level_cap()


func xp_to_next() -> int:
    return 40 + level * level * 6


## Adds experience and returns how many levels were gained.
func add_xp(amount: int) -> int:
    var gained := 0
    if is_max_level():
        return 0
    var before := level
    xp += amount
    while level < level_cap() and xp >= xp_to_next():
        xp -= xp_to_next()
        level += 1
        gained += 1
    if level >= level_cap():
        xp = 0
    _queue_skill_choices(before, level)
    return gained


# --- active skills (D-043..D-046) -----------------------------------------------------------

## D-142 (replaces D-044): heroes start with only Q (the basic attack); W, E and R come from the level
## choices at 2, 5 and 10. Kept as the hook new heroes, promotions and loads call: it only trims a loadout
## that somehow holds more than MAX_SLOTS. Known skills of saved heroes are never taken away (D-004).
func ensure_skills() -> void:
    while loadout.size() > SkillDefs.MAX_SLOTS:
        loadout.pop_back()


## Learns a skill (level choice, book, trainer). Fills a free W/E/R slot. False if already known
## or not for this class.
func learn_skill(id: String, log_event: bool = true) -> bool:
    if skills.has(id) or not SkillDefs.usable_by(id, hero_class):
        return false
    skills.append(id)
    if loadout.size() < SkillDefs.MAX_SLOTS:
        loadout.append(id)
    if log_event:
        add_event("learned_skill", {"skill": id})
    return true


## Puts a known skill in a slot (0-2 = W E R); swaps if it was in another slot.
func equip_skill(slot_index: int, id: String) -> bool:
    if not skills.has(id) or slot_index < 0 or slot_index >= SkillDefs.MAX_SLOTS:
        return false
    var old := loadout.find(id)
    if slot_index >= loadout.size():
        if old >= 0:
            return true
        loadout.append(id)
        return true
    if old >= 0:
        loadout[old] = loadout[slot_index]
    loadout[slot_index] = id
    return true


## D-045: resolves the oldest pending level choice. False if `id` is not one of its options.
func choose_skill(choice_index: int, id: String) -> bool:
    if choice_index < 0 or choice_index >= skill_choices.size():
        return false
    var c: Dictionary = skill_choices[choice_index]
    if not (c["options"] as Array).has(id) or not learn_skill(id):
        return false
    skill_choices.remove_at(choice_index)
    if bool(c.get("bonus", false)) and get("bonus_skill_choice") != null:
        set("bonus_skill_choice", maxi(0, int(get("bonus_skill_choice")) - 1))   # D-090: the tome's extra option is used
    # options learned meanwhile disappear from the other pending choices
    for other in skill_choices:
        (other["options"] as Array).erase(id)
    skill_choices = skill_choices.filter(func(x): return not (x["options"] as Array).is_empty())
    return true


func _queue_skill_choices(from_level: int, to_level: int) -> void:
    for lv in SkillDefs.choice_levels():
        if lv > from_level and lv <= to_level:
            # D-090: a skill tome (pista D, optional field bonus_skill_choice) adds one more option
            var extra := 1 if get("bonus_skill_choice") != null and int(get("bonus_skill_choice")) > 0 else 0
            var opts := SkillDefs.level_choices(hero_class, skills, lv, hero_seed, extra)
            if not opts.is_empty():
                skill_choices.append({"level": lv, "options": opts, "bonus": opts.size() > SkillDefs.CHOICE_OPTIONS})


## Luck 1-10: a fixed trait of the hero, derived from its seed (nothing new is stored, the same hero
## always has the same luck). Used by ascension; other systems can read it later.
func luck() -> int:
    return 1 + int(absi(hero_seed) % 10)


func promotion_cost() -> int:
    return stars * 3


func can_promote() -> bool:
    return stars < HeroTables.MAX_STARS and is_max_level()


func promote() -> void:
    if not can_promote():
        return
    stars += 1
    HeroGenerator.apply_promotion(self)
    ensure_skills()
    add_event("promoted", {"stars": stars})


# --- professions (D-049) --------------------------------------------------------------------

func prof_level(prof: String) -> int:
    return int((professions.get(prof, {}) as Dictionary).get("lvl", -1))


func knows_prof(prof: String) -> bool:
    return professions.has(prof)


## Learns a profession as an apprentice (level 0). "" if learned, else the reason it cannot.
func learn_prof(prof: String) -> String:
    if knows_prof(prof):
        return ""
    if not ProfessionDefs.PROFESSIONS.has(prof):
        return "unknown profession"
    if professions.size() >= ProfessionDefs.MAX_KNOWN:
        return "already knows %d professions: forget one first" % ProfessionDefs.MAX_KNOWN
    professions[prof] = {"lvl": 0, "xp": 0.0}
    add_event("learned_profession", {"prof": prof})
    return ""


func forget_prof(prof: String) -> bool:
    if not professions.has(prof):
        return false
    professions.erase(prof)
    add_event("forgot_profession", {"prof": prof})
    return true


## Experience from work; returns true on level-up.
func add_prof_xp(prof: String, amount: float) -> bool:
    if not professions.has(prof):
        return false
    var p: Dictionary = professions[prof]
    if int(p["lvl"]) >= ProfessionDefs.MAX_LEVEL:
        return false
    p["xp"] = float(p["xp"]) + amount * (ProfessionDefs.PASSION_XP if prof == passion else 1.0)
    var up := false
    while int(p["lvl"]) < ProfessionDefs.MAX_LEVEL and float(p["xp"]) >= ProfessionDefs.xp_to_next(int(p["lvl"])):
        p["xp"] = float(p["xp"]) - ProfessionDefs.xp_to_next(int(p["lvl"]))
        p["lvl"] = int(p["lvl"]) + 1
        up = true
    if up:
        add_memory("prof_level", "Became a level %d %s." % [int(p["lvl"]), ProfessionDefs.info(prof)["name"]], "", 2)
    return up


## Work done per hour in a profession: level, helping attribute, fatigue, hunger, diseases.
func work_efficiency(prof: String) -> float:
    var lvl := prof_level(prof)
    if lvl < 0:
        return 0.0
    var eff := ProfessionDefs.efficiency(lvl)
    var attr := String(ProfessionDefs.info(prof).get("attr", ""))
    if attr != "":
        eff *= 1.0 + 0.02 * float(int(attributes().get(attr, 5)) - 5)
    eff *= 1.0 - float(fatigue) / 200.0
    if hunger >= 100:
        eff *= 0.5
    for d in diseases:
        eff *= float(EconomyDefs.DISEASES.get(String(d["id"]), {}).get("work", 1.0))
    return maxf(0.05, eff)


## Past-life occupation becomes the first profession (new heroes and save migration).
func init_professions() -> void:
    var prof := String(ProfessionDefs.FROM_PAST_LIFE.get(profession, ""))
    if prof != "" and professions.is_empty():
        professions[prof] = {"lvl": ProfessionDefs.PAST_LIFE_LEVEL, "xp": 0.0}
        passion = prof


# --- health ----------------------------------------------------------------------------------

func has_disease(id: String) -> bool:
    return diseases.any(func(d): return String(d["id"]) == id)


## Adds a disease (once per kind). Returns true if it is new.
func catch_disease(id: String, cause: String) -> bool:
    if has_disease(id) or not EconomyDefs.DISEASES.has(id):
        return false
    diseases.append({"id": id, "hours": float(EconomyDefs.DISEASES[id]["hours"]), "cause": cause})
    add_memory("disease", "Fell ill: %s (%s)." % [EconomyDefs.DISEASES[id]["name"], cause], "", 2)
    return true


## Mood 0..100 from needs (derived, never saved).
func mood() -> int:
    return clampi(100 - stress / 2 - hunger / 4 - fatigue / 4 - 10 * diseases.size(), 0, 100)


## D-035: the five attributes, computed from saved data (class, stars, level, personal variance,
## traits). No new random roll, so existing heroes keep their identity.
func attributes() -> Dictionary:
    var prof: Dictionary = HeroTables.CLASS_COMBAT.get(hero_class, HeroTables.CLASS_COMBAT["class.none"])
    var star_factor := 0.8 + 0.2 * float(stars)
    var out := {}
    for i in HeroTables.ATTR_KEYS.size():
        var k: String = HeroTables.ATTR_KEYS[i]
        var legacy: String = HeroTables.ATTR_LEGACY[k]
        var v: float = (float(prof["attrs"][i]) + float(prof["growth"][i]) * float(level - 1)) * star_factor
        v *= float(variance.get(legacy, 1.0))
        for t in traits:
            var mods: Dictionary = HeroTables.TRAITS[t].get("mods", {})
            v *= float(mods.get(legacy, 1.0))
        for d in diseases:
            v *= float((EconomyDefs.DISEASES.get(String(d["id"]), {}).get("mods", {}) as Dictionary).get(k, 1.0))
        out[k] = maxi(1, roundi(v) + int(synth_bonus.get(k, 0)))
    return out


## All the experience this hero has gathered since level 1 (for synthesis).
func total_xp() -> int:
    var t := xp
    for lv in range(1, level):
        t += 40 + lv * lv * 6                    # same curve as xp_to_next()
    return t


## The attribute this hero is strongest in (what a synthesis passes on).
func best_attribute() -> String:
    var a := attributes()
    var best := ""
    for k in a:
        if best == "" or int(a[k]) > int(a[best]):
            best = String(k)
    return best


## Combat stats derived from the attributes (CombatRules.derive). Keeps the legacy keys
## hp/atk/mag/def/spd used by the UI: atk = physical power, mag = magic power, def = armor, spd = AGI.
func get_stats() -> Dictionary:
    return ItemDefs.apply_equipment(CombatRules.derive(attributes(), hero_class), equipment, hero_class)


func power() -> int:
    var s := get_stats()
    return roundi(float(s["hp"]) * 0.1 + float(s["atk"]) * 1.5 + float(s["mag"]) * 1.5 + float(s["def"]) + float(s["spd"]))


func to_dict() -> Dictionary:
    return {
        "id": id,
        "seed": "%x" % hero_seed,   # stored as hex text: JSON numbers would lose 64-bit precision
        "name": hero_name,
        "is_master": is_master,
        "first_name": first_name,
        "surname": surname,
        "leadership_points": leadership_points,
        "master_memories": master_memories.duplicate(),
        "bond_master": bond_master,
        "epithet": epithet,
        "stars": stars,
        "level": level,
        "xp": xp,
        "class": hero_class,
        "appearance": appearance.duplicate(),
        "look": look.duplicate(),
        "traits": traits.duplicate(),
        "passives": passives.duplicate(),
        "innate": innate.duplicate(),
        "background_id": background_id,
        "background_text": background_text,
        "profession": profession,
        "variance": variance.duplicate(),
        "callsign": callsign,
        "generator_version": generator_version,
        "origin_banner": origin_banner,
        "summon_index": summon_index,
        "trust": trust,
        "obedience": obedience,
        "composure": composure,
        "event_seq": event_seq,
        "events": events.duplicate(true),
        "memories": memories.duplicate(true),
        "relationships": intify(relationships.duplicate(true)),
        "hq_assignment": hq_assignment,
        "activity_state": activity_state,
        "discovered_secrets": discovered_secrets.duplicate(),
        "secret_clues": secret_clues.duplicate(),
        "skills": skills.duplicate(),
        "loadout": loadout.duplicate(),
        "skill_choices": intify(skill_choices.duplicate(true)),
        "professions": intify(professions.duplicate(true)),
        "apprenticeship": apprenticeship.duplicate(true),
        "aptitude_known": aptitude_known.duplicate(),     # same numbers as after a JSON round trip
        "passion": passion,
        "needs": [hunger, fatigue, stress, exhausted_hours],
        "diseases": intify(diseases.duplicate(true)),
        "bed": bed,
        "equipment": intify(equipment.duplicate(true)),
        "bag": bag.duplicate(),
        "hoard": intify(hoard.duplicate(true)),
        "bonus_skill_choice": bonus_skill_choice,
        "ascension_fails": ascension_fails,
        "trained_skills": trained_skills,
        "synth_bonus": synth_bonus.duplicate(),
        "synthesis_history": synthesis_history.duplicate(true),
    }


static func from_dict(d: Dictionary) -> HeroData:
    var h := HeroData.new()
    h.id = str(d.get("id", ""))
    h.hero_seed = String(d.get("seed", "0")).hex_to_int()
    h.hero_name = str(d.get("name", "Unknown"))
    h.is_master = bool(d.get("is_master", false))     # save v16 or older: no Master (the creator opens once)
    h.first_name = str(d.get("first_name", ""))
    h.surname = str(d.get("surname", ""))
    h.leadership_points = int(d.get("leadership_points", 0))           # save v17 or older: 0, no memories, bond 30
    for mid in d.get("master_memories", []):
        if not MasterMemories.info(String(mid)).is_empty():
            h.master_memories.append(String(mid))
    h.bond_master = clampi(int(d.get("bond_master", MasterDefs.BOND_START)), 0, 100)
    h.epithet = str(d.get("epithet", ""))
    h.stars = clampi(int(d.get("stars", 1)), 1, HeroTables.MAX_STARS)
    h.level = maxi(1, int(d.get("level", 1)))
    h.xp = int(d.get("xp", 0))
    h.hero_class = HeroTables.canonical_class(str(d.get("class", "class.none")))   # 03b: class.ranger -> class.archer
    if not HeroTables.CLASSES.has(h.hero_class):
        h.hero_class = "class.none"
    h.appearance = (d.get("appearance", {}) as Dictionary).duplicate()
    h.look = (d.get("look", {}) as Dictionary).duplicate()
    if h.look.is_empty():
        h.look = HeroGenerator.lpc_look(h.hero_seed)  # TPF heroes become LPC deterministically
    if h.is_master and not MasterDefs.RACES.has(String(h.look.get("race", "human"))):
        h.look["race"] = "human"                     # D-081 (save v17): an elf Master becomes human, the rest stays
        h.look = HeroGenerator.master_look(h.look)
    h.traits = (d.get("traits", []) as Array).duplicate()
    h.passives = (d.get("passives", []) as Array).duplicate()
    for g in d.get("innate", []):            # save v15 or older: no gifts ([]), never rolled again (D-004)
        if PowerDefs.GIFTS.has(String(g)):
            h.innate.append(String(g))
    h.background_id = str(d.get("background_id", ""))
    h.background_text = str(d.get("background_text", ""))
    h.profession = str(d.get("profession", ""))
    h.variance = (d.get("variance", {}) as Dictionary).duplicate()
    h.callsign = str(d.get("callsign", ""))
    h.generator_version = int(d.get("generator_version", 1))
    h.origin_banner = str(d.get("origin_banner", ""))
    h.summon_index = int(d.get("summon_index", 0))
    if d.has("trust"):
        h.trust = clampi(int(d["trust"]), 0, 100)
        h.obedience = clampi(int(d.get("obedience", 50)), 0, 100)
        h.composure = clampi(int(d.get("composure", 100)), 0, 100)
    else:
        # v1 save: single loyalty value -> Trust, Obedience derived from traits
        h.trust = clampi(int(d.get("loyalty", 50)), 0, 100)
        h.obedience = legacy_obedience(h.traits)
        h.composure = 100
    h.events = intify(d.get("events", []) as Array)
    h.event_seq = int(d.get("event_seq", h.events.size()))
    h.memories = intify(d.get("memories", []) as Array)
    h.relationships = (d.get("relationships", {}) as Dictionary).duplicate()
    h.hq_assignment = str(d.get("hq_assignment", ""))
    h.activity_state = str(d.get("activity_state", "idle"))
    if not (h.activity_state in ["idle", "working", "sleeping", "eating", "socializing", "in_treatment"]):
        h.activity_state = "idle"          # old free-text states and a stale "deployed" become idle
    h.discovered_secrets = (d.get("discovered_secrets", []) as Array).duplicate()
    h.secret_clues = (d.get("secret_clues", []) as Array).duplicate()
    if d.has("skills"):
        for sid in d["skills"]:
            if SkillDefs.SKILLS.has(String(sid)) and not h.skills.has(String(sid)):
                h.skills.append(String(sid))
        for sid in d.get("loadout", []):
            if h.skills.has(String(sid)) and not h.loadout.has(String(sid)) and h.loadout.size() < SkillDefs.MAX_SLOTS:
                h.loadout.append(String(sid))
        h.skill_choices = intify(d.get("skill_choices", []) as Array)
        h.ascension_fails = int(d.get("ascension_fails", 0))
        h.trained_skills = int(d.get("trained_skills", 0))
        h.synth_bonus = intify(d.get("synth_bonus", {}) as Dictionary)
        h.synthesis_history = (d.get("synthesis_history", []) as Array).duplicate(true)
        h.ensure_skills()
    else:
        # save v7 or older (D-043..D-045): the class starter, plus the choices of every learn
        # level already reached, so veteran heroes are not left behind.
        h.ensure_skills()
        h._queue_skill_choices(0, h.level)
    h.apprenticeship = (d.get("apprenticeship", {}) as Dictionary).duplicate(true)
    h.aptitude_known = (d.get("aptitude_known", {}) as Dictionary).duplicate()
    if d.has("professions"):
        h.professions = (d["professions"] as Dictionary).duplicate(true)
        for k in h.professions.keys():
            if not ProfessionDefs.PROFESSIONS.has(k):
                h.professions.erase(k)
            else:
                h.professions[k] = {"lvl": int(h.professions[k].get("lvl", 0)), "xp": float(h.professions[k].get("xp", 0.0))}
        h.passion = str(d.get("passion", ""))
    else:
        h.init_professions()               # save v8 or older: past life -> first profession
    var needs: Array = d.get("needs", [0, 0, 0, 0])
    if needs.size() >= 4:
        h.hunger = clampi(int(needs[0]), 0, 100)
        h.fatigue = clampi(int(needs[1]), 0, 100)
        h.stress = clampi(int(needs[2]), 0, 100)
        h.exhausted_hours = int(needs[3])
    for dz in d.get("diseases", []):
        if EconomyDefs.DISEASES.has(String(dz.get("id", ""))):
            h.diseases.append({"id": String(dz["id"]), "hours": float(dz.get("hours", 1.0)), "cause": str(dz.get("cause", ""))})
    h.bed = str(d.get("bed", ""))
    var eq: Dictionary = d.get("equipment", {})
    for slot in eq:
        if ItemDefs.SLOTS.has(String(slot)) and typeof(eq[slot]) == TYPE_DICTIONARY:
            h.equipment[String(slot)] = intify(eq[slot])
    var bg: Dictionary = d.get("bag", {})
    for k in bg:
        if int(bg[k]) > 0:
            h.bag[String(k)] = int(bg[k])
    for it in d.get("hoard", []):                # D-125 / D-129: missing in older saves -> defaults
        if typeof(it) == TYPE_DICTIONARY:
            h.hoard.append(intify(it))
    h.bonus_skill_choice = int(d.get("bonus_skill_choice", 0))
    return h
