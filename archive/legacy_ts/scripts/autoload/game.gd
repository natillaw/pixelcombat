extends Node
## Autoload "Game": player progress, summoning, training, party, save/load.
## UI scripts never touch the save file directly; they call these methods and listen to `changed`.

signal changed

const DEFAULT_SAVE_PATH := "user://save.json"
const SAVE_VERSION := 21
const PARTY_SIZE := 5            # slots 0-2 = front row, slots 3-4 = back row; D-080: slot 0 is the Master
const MASTER_BED := "town_hall"   # D-080: the Master sleeps in the Hall (no dorm bed)
const XP_PER_BOOK := 100

var gems: int = SummonConfig.START_GEMS
var stones: int = 5              # promotion stones
var books: int = 5               # training books
var pity4: int = 0
var pity5: int = 0
var heroes: Dictionary = {}      # hero id -> HeroData (insertion order = order summoned)
var party: Array = ["", "", "", "", ""]
var rng := RandomNumberGenerator.new()
var autosave: bool = true
var save_path: String = DEFAULT_SAVE_PATH
var pull_count: int = 0          # total summons ever done (global pull number)
var summon_log: Array = []       # newest last, capped: lets any pull be reproduced from its seed
var memorial: Array = []         # fallen heroes, oldest first, NEVER capped or edited (D-011)
var _signatures: Dictionary = {} # appearance signatures already owned -> no duplicate looks
var hq_outputs: Dictionary = START_STOCK.duplicate()   # THE town storage (warehouse): resource id -> amount
var town_buildings: Dictionary = TownTables.start_levels()   # building id -> level (0 = not built), D-030
var tower_maps: Dictionary = {}
var onboarded: bool = false          # the welcome and the first ten summons happened (new accounts)
var hardcore: bool = false           # D-081: chosen once at the creator; the Master's death ends the game
var game_over: bool = false          # D-081: a hardcore game whose Master died (kept, only for the summary)
var game_over_info: Dictionary = {}  # {"floors", "heroes", "seconds", "cause"} for the end screen
var play_seconds: float = 0.0        # D-081: time played (end screen)
var cheated: bool = false            # D-146: the dev console was unlocked or a cheat used in this game (saved, never cleared)
var synergy_codex: Dictionary = {}   # D-090: synergy id -> true once discovered (SynergyDefs)
var skill_books: Dictionary = {}     # skill id -> copies owned (D-046)
var tower_cleared: Dictionary = {}   # floor (str) -> times completed (D-031: every floor is unlocked) # floor_num (str) -> {"seed": int, "width": int, "height": int, "grid_rows": Array}
# Town simulation state (HQ Phase 1, save v9). Rules live in TownSim / EconomyDefs.
const START_STOCK := {"materials": 60, "food": 120, "grain": 20, "herb": 6, "wood": 20, "stone": 20, "ore": 20, "ingot": 0,   # beta: enough ore for a first T1 set
    "medicine": 4, "potion": 2, "antidote": 1}
var town_clock: int = 8              # town hours since the first day (starts at 08:00)
var town_seed: int = 1
var town_jobs: Dictionary = {}       # building id -> recipe id it runs
var town_batches: Dictionary = {}    # building id -> {"recipe", "progress"}: inputs already taken
var construction: Array = []         # [{"bid", "to", "work_left"}] (D-048), materials already paid
var patients: Array = []             # hero ids in hospital beds
var town_layout: Dictionary = {}     # building id -> Vector2i plot position when moved (D-050)
var town_log: Array = []             # newest last, capped: notable town events
var town_problems: Dictionary = {}   # building id -> why it is not producing (recomputed every hour)
var stash: Array = []                # equipment items not worn (one inventory model: item dicts)
var item_seq: int = 0                # next item uid
var last_reason: String = ""         # why the last town action was refused (shown by the UI)
var _clock_acc: float = 0.0
const TOWN_LOG_CAP := 60


func _process(delta: float) -> void:
    if onboarded and not game_over:
        play_seconds += delta


func _ready() -> void:
    rng.randomize()
    load_game()


# --- summoning ----------------------------------------------------------------

## Spends gems and returns the new heroes (empty array if the banner is invalid or gems are short).
## Nothing changes (no gems, no pity, no log) unless the whole summon can be paid for.
func pull(count: int, banner_id: String = SummonConfig.DEFAULT_BANNER) -> Array:
    var banner := SummonConfig.get_banner(banner_id)
    if banner.is_empty() or count <= 0:
        return []
    var problems := SummonConfig.validate(banner)
    if not problems.is_empty():
        push_error("Summon banner '%s' is invalid: %s" % [banner_id, ", ".join(problems)])
        return []
    var cost := SummonConfig.cost_for(banner, count)
    if gems < cost or not can_summon(count):
        return []
    gems -= cost
    var out: Array = []
    for i in count:
        var before4 := pity4
        var before5 := pity5
        var r := Gacha.roll_stars(rng, pity4, pity5, banner)
        pity4 = int(r["pity4"])
        pity5 = int(r["pity5"])
        var h := _generate_unique(int(r["stars"]))
        _accept_summon(h, banner_id, banner, before4, before5)
        out.append(h)
    assign_beds()
    _commit()
    return out


func _accept_summon(h: HeroData, banner_id: String, banner: Dictionary, before4: int, before5: int) -> void:
    pull_count += 1
    h.summon_index = pull_count
    h.origin_banner = banner_id
    h.add_event("summoned", {"banner": banner_id, "banner_version": int(banner["version"]), "pull": pull_count})
    h.add_memory("summoned", "Summoned from the %s banner into the order." % banner_id, "", 2)
    heroes[h.id] = h
    give_kit(h)                                   # D-082b: white starter clothes + class weapon
    _signatures[h.signature()] = true
    _log_pull(h, banner_id, int(banner["version"]), before4, before5)


static func is_fighter(h: HeroData) -> bool:
    return h.hero_class != "class.commoner" and h.hero_class != "class.none"


## The ten free summons of a new account (vertical slice): real generated heroes with early odds
## (SummonConfig "starter"). Two safety nets, nothing else forced: (1) when the remaining summons could
## no longer reach STARTER_MIN_FIGHTERS combat classes, a non-fighter roll is redrawn (same stars);
## (2) if nobody knows the builder profession, the hero with the fewest professions learns it (a common
## person can be the builder). Only for an account with no heroes that has not been onboarded.
func starter_summons() -> Array:
    if onboarded or heroes.values().any(func(x): return not (x as HeroData).is_master):
        return []
    var banner := SummonConfig.get_banner(SummonConfig.STARTER_BANNER)
    var out: Array = []
    var fighters := 0
    var n := SummonConfig.STARTER_COUNT
    for i in n:
        var before4 := pity4
        var before5 := pity5
        var stars := Gacha.roll_stars(rng, pity4, pity5, banner)
        var st := int(stars["stars"])
        var h := _generate_unique(st)
        var tries := 0
        while not is_fighter(h) and fighters + (n - i - 1) < SummonConfig.STARTER_MIN_FIGHTERS and tries < 40:
            h = _generate_unique(st)
            tries += 1
        if is_fighter(h):
            fighters += 1
        _accept_summon(h, SummonConfig.STARTER_BANNER, banner, before4, before5)
        out.append(h)
    if not out.any(func(x): return (x as HeroData).knows_prof("builder")):
        var pick: HeroData = out[0]
        for x in out:
            if (x as HeroData).professions.size() < pick.professions.size() or (pick.professions.size() == (x as HeroData).professions.size() and (x as HeroData).stars < pick.stars):
                pick = x
        if pick.professions.size() >= ProfessionDefs.MAX_KNOWN:
            pick.forget_prof(String(pick.professions.keys()[pick.professions.size() - 1]))
        pick.learn_prof("builder")
        pick.professions["builder"]["lvl"] = 1
        pick.add_memory("builder", "Built houses before the summoning; the order's first builder.", "", 2)
    for x in out:
        if (x as HeroData).knows_prof("builder"):
            (x as HeroData).hq_assignment = "construction"           # builders start on the building site
            break
    # owner 2026-11-01: the forge takes only smiths, so the first ten always bring one (the hero with the
    # most free profession room learns it if no past life gave it)
    if not out.any(func(x): return (x as HeroData).knows_prof("blacksmith")):
        var pick: Array = out.duplicate()
        pick.sort_custom(func(a, b): return (a as HeroData).professions.size() < (b as HeroData).professions.size())
        for x in pick:
            if not is_fighter(x) and (x as HeroData).learn_prof("blacksmith") == "":
                break
        if not out.any(func(x): return (x as HeroData).knows_prof("blacksmith")):
            (pick[0] as HeroData).learn_prof("blacksmith")
    # a first squad of five is ready to go (fighters first): the player can change it in Menu -> Party.
    # D-080: slot 1 is the Master's; the summons fill the others.
    var first := 1 if master() != null else 0
    var squad: Array = out.filter(func(x): return is_fighter(x))
    for x in out:
        if squad.size() < PARTY_SIZE - first and not squad.has(x):
            squad.append(x)
    for i in mini(PARTY_SIZE - first, squad.size()):
        party[first + i] = (squad[i] as HeroData).id
    onboarded = true
    assign_beds()
    _commit()
    return out


func _log_pull(h: HeroData, banner_id: String, banner_version: int, before4: int, before5: int) -> void:
    summon_log.append({
        "n": pull_count,
        "banner": banner_id,
        "banner_version": banner_version,
        "seed": "%x" % h.hero_seed,
        "stars": h.stars,
        "gen": h.generator_version,
        "pity4_before": before4,
        "pity5_before": before5,
        "hero_id": h.id,
    })
    while summon_log.size() > SummonConfig.LOG_CAP:
        summon_log.pop_front()


## TownSim's safety net: a free 1-star hero joins when the roster is short (permadeath stays).
func recruit_wanderer() -> String:
    var h := _generate_unique(1)
    heroes[h.id] = h
    give_kit(h)
    _signatures[h.signature()] = true
    h.add_memory("joined", "Arrived at the town as a wanderer looking for work.", "", 2)
    _commit()
    return h.display_name()


func _generate_unique(stars: int) -> HeroData:
    var h: HeroData = null
    for attempt in 100:
        h = HeroGenerator.generate(_new_seed(), stars)
        if not _signatures.has(h.signature()) and not heroes.has(h.id):
            break
    _disambiguate_name(h)
    return h


## Two heroes never show the same name: the newer one gets a deterministic callsign.
func _disambiguate_name(h: HeroData) -> void:
    var taken := {}
    for id in heroes:
        taken[(heroes[id] as HeroData).display_name()] = true
    if not taken.has(h.display_name()):
        return
    h.callsign = SummonConfig.callsign_for(h.hero_seed, h.base_display_name(), taken)


func _new_seed() -> int:
    return ((int(rng.randi()) << 31) ^ int(rng.randi())) & 0x7FFFFFFFFFFFFFFF


# --- hero growth ----------------------------------------------------------------

func train(h: HeroData, use_books: int = 1) -> bool:
    if h == null or h.is_max_level() or books < use_books or use_books <= 0:
        return false
    books -= use_books
    h.add_xp(XP_PER_BOOK * use_books)
    _commit()
    return true


## Ascension (vertical slice): at the top level of its star rank, with tower materials, at the
## Sanctuary of Ascension. Kept as the one promotion entry point (the old stone price is gone).
func promote(h: HeroData) -> bool:
    return bool(attempt_promotion(h).get("ok", false))


func ascension_cost(h: HeroData) -> Dictionary:
    return (ProgressionDefs.ASCENSION_COST.get(h.stars + 1, {}) as Dictionary).duplicate()


## "" when the hero may try to ascend now, else why not.
func promotion_block(h: HeroData) -> String:
    if h == null:
        return "no hero"
    if h.stars >= HeroTables.MAX_STARS:
        return "already at the highest rank"
    if not h.is_max_level():
        return "needs level %d (now %d)" % [h.level_cap(), h.level]
    if building_level("ascension") <= 0:
        return "build the Sanctuary of Ascension"
    var cost := ascension_cost(h)
    for k in cost:
        if int(hq_outputs.get(k, 0)) < int(cost[k]):
            return "needs %d %s (have %d)" % [int(cost[k]), String(EconomyDefs.RESOURCES.get(k, {}).get("name", k)), int(hq_outputs.get(k, 0))]
    return ""


## Chance of the next attempt: base + luck + sanctuary level + pity (sure after PITY_HARD failures).
func promotion_chance(h: HeroData) -> float:
    if h.ascension_fails >= ProgressionDefs.ASCENSION_PITY_HARD:
        return 1.0
    var c := ProgressionDefs.ASCENSION_BASE + ProgressionDefs.ASCENSION_PER_LUCK * float(h.luck())
    c += ProgressionDefs.ASCENSION_PER_SANCTUARY * float(maxi(0, building_level("ascension") - 1))
    c += ProgressionDefs.ASCENSION_PITY_STEP * float(h.ascension_fails)
    return clampf(c, 0.0, 1.0)


## One attempt. The materials are spent; a failure gives part of the tower materials back and makes the
## next try likelier (never costs the hero its level). Returns {ok, chance, reason}.
func attempt_promotion(h: HeroData) -> Dictionary:
    last_reason = promotion_block(h)
    if last_reason != "":
        return {"ok": false, "chance": 0.0, "reason": last_reason}
    var chance := promotion_chance(h)
    var cost := ascension_cost(h)
    for k in cost:
        hq_outputs[k] = int(hq_outputs.get(k, 0)) - int(cost[k])
    var ok := rng.randf() < chance
    if ok:
        h.ascension_fails = 0
        h.promote()
        log_town("%s ascended to %d stars." % [h.display_name(), h.stars])
    else:
        h.ascension_fails += 1
        for k in cost:
            if k != "materials":
                hq_outputs[k] = int(hq_outputs.get(k, 0)) + floori(float(cost[k]) * ProgressionDefs.ASCENSION_FAIL_KEEP)
        h.add_event("ascension_failed", {"stars": h.stars + 1})
        log_town("%s's ascension failed (next chance %d%%)." % [h.display_name(), roundi(promotion_chance(h) * 100.0)])
    _commit()
    return {"ok": ok, "chance": chance, "reason": "" if ok else "the ascension failed"}


# --- synthesis and sacrifice (D-061, spec HEROES_AND_SUMMONING §14) -----------------------------------

## "" when `h` can be consumed now, else why not (dead, in the party = on an expedition, unknown).
func consumable_block(h: HeroData) -> String:
    if h == null or not heroes.has(h.id):
        return "not in the roster"
    if h.is_master:
        return "the Master cannot be sacrificed, absorbed or sold"
    if party.has(h.id):
        return "%s is in the party: take them out first" % h.display_name()
    return ""


## What a synthesis would do, without doing it (the confirmation screen shows exactly this).
func synthesis_preview(target: HeroData, sources: Array) -> Dictionary:
    var p := {"ok": true, "reason": "", "xp": 0, "levels": 0, "attrs": {}, "lost": [], "warning": ""}
    if target == null or not heroes.has(target.id):
        return {"ok": false, "reason": "no target"}
    if sources.is_empty() or sources.size() > ProgressionDefs.SYNTH_MAX_SOURCES:
        return {"ok": false, "reason": "choose 1 to %d heroes to absorb" % ProgressionDefs.SYNTH_MAX_SOURCES}
    var gain := 0
    for s in sources:
        var src := s as HeroData
        if src == target:
            return {"ok": false, "reason": "a hero cannot absorb itself"}
        var why := consumable_block(src)
        if why != "":
            return {"ok": false, "reason": why}
        var same := src.hero_class == target.hero_class
        gain += roundi(float(src.total_xp()) * (ProgressionDefs.SYNTH_SAME_CLASS if same else ProgressionDefs.SYNTH_EFFICIENCY))
        if same:
            var a := src.best_attribute()
            p["attrs"][a] = int(p["attrs"].get(a, 0)) + ProgressionDefs.SYNTH_ATTR_BONUS
        p["lost"].append(src.display_name())
    var copy := HeroData.from_dict(target.to_dict())
    p["levels"] = copy.add_xp(gain)
    p["xp"] = gain
    p["capped"] = copy.is_max_level()
    if heroes.size() - sources.size() < PARTY_SIZE:
        p["warning"] = "fewer than %d heroes would be left" % PARTY_SIZE
    return p


## Synthesis: the target absorbs the sources (lossy, irreversible). Saves first; sources go to the
## memorial with cause "sacrificed" and keep their identity. Returns the preview that was applied.
func synthesize(target: HeroData, sources: Array) -> Dictionary:
    var p := synthesis_preview(target, sources)
    if not bool(p.get("ok", false)):
        last_reason = String(p.get("reason", ""))
        return p
    save_game()                                     # checkpoint before an irreversible operation
    for k in p["attrs"]:
        target.synth_bonus[k] = int(target.synth_bonus.get(k, 0)) + int(p["attrs"][k])
    target.add_xp(int(p["xp"]))
    for s in sources:
        var src := s as HeroData
        target.synthesis_history.append({"from": src.id, "name": src.display_name(), "xp": int(p["xp"]), "attr": src.best_attribute()})
        src.add_event("synthesized", {"into": target.id})
        record_death(src, "sacrificed", "synthesis into %s" % target.display_name())
    target.add_event("received_synthesis", {"sources": sources.size(), "xp": int(p["xp"])})
    target.add_memory("synthesis", "Took in the strength of %s." % ", ".join(p["lost"]), "", 3)
    _commit()
    return p


func sacrifice_preview(h: HeroData) -> Dictionary:
    var why := consumable_block(h)
    if why != "":
        return {"ok": false, "reason": why}
    var gain: Dictionary = (ProgressionDefs.SACRIFICE.get(h.stars, ProgressionDefs.SACRIFICE[1]) as Dictionary).duplicate()
    for k in ProgressionDefs.SACRIFICE_CLASS.get(h.hero_class, {}):
        gain[k] = int(gain.get(k, 0)) + int(ProgressionDefs.SACRIFICE_CLASS[h.hero_class][k])
    return {"ok": true, "gain": gain, "warning": "fewer than %d heroes would be left" % PARTY_SIZE if heroes.size() - 1 < PARTY_SIZE else ""}


## Sacrifice: the hero becomes tower materials (irreversible; memorial cause "sacrificed").
func sacrifice(h: HeroData) -> Dictionary:
    var p := sacrifice_preview(h)
    if not bool(p.get("ok", false)):
        last_reason = String(p.get("reason", ""))
        return p
    save_game()
    for k in p["gain"]:
        hq_outputs[k] = mini(storage_cap(), int(hq_outputs.get(k, 0)) + int(p["gain"][k]))
    h.add_event("sacrificed", {"gain": p["gain"]})
    record_death(h, "sacrificed", "sacrifice")
    _commit()
    return p


## Class skills a hero could learn at the Training Grounds now (deterministic choice of up to 3).
func training_options(h: HeroData) -> Array:
    var pool: Array = []
    for sid in SkillDefs.SKILLS:
        if String(SkillDefs.SKILLS[sid].get("class", "")) == h.hero_class and not h.skills.has(sid):
            pool.append(String(sid))
    pool.sort()
    var r := RandomNumberGenerator.new()
    r.seed = h.hero_seed ^ (h.trained_skills * 7907 + 1)
    var out: Array = []
    while not pool.is_empty() and out.size() < ProgressionDefs.TRAIN_OPTIONS:
        out.append(pool.pop_at(r.randi() % pool.size()))
    return out


func training_block(h: HeroData) -> String:
    if building_level("training_grounds") <= 0:
        return "build the Training Grounds"
    if h.stars < ProgressionDefs.TRAIN_MIN_STARS:
        return "1-star heroes grow by experience; ascend to 2 stars to train"
    if h.trained_skills >= h.stars - 1:
        return "trained as much as its rank allows (%d)" % (h.stars - 1)
    if training_options(h).is_empty():
        return "knows every skill of its class"
    if not has_resources(ProgressionDefs.TRAIN_COST):
        return "needs %s" % str(ProgressionDefs.TRAIN_COST)
    return ""


## Learns one of the offered class skills (the player's choice).
func train_skill(h: HeroData, skill_id: String) -> String:
    last_reason = training_block(h)
    if last_reason == "" and not training_options(h).has(skill_id):
        last_reason = "not one of the offered skills"
    if last_reason != "":
        return last_reason
    for k in ProgressionDefs.TRAIN_COST:
        hq_outputs[k] = int(hq_outputs.get(k, 0)) - int(ProgressionDefs.TRAIN_COST[k])
    h.learn_skill(skill_id)
    h.trained_skills += 1
    log_town("%s trained %s." % [h.display_name(), String(SkillDefs.info(skill_id)["name"])])
    _commit()
    return ""


# --- party ----------------------------------------------------------------------

func assign_party(slot: int, hero_id: String) -> void:
    if slot < 0 or slot >= PARTY_SIZE or not heroes.has(hero_id):
        return
    if master() != null and (slot == 0 or hero_id == master().id):
        last_reason = "slot 1 is always the Master"
        return
    for i in PARTY_SIZE:
        if party[i] == hero_id:
            party[i] = ""
    party[slot] = hero_id
    _commit()


func clear_slot(slot: int) -> void:
    if slot < 0 or slot >= PARTY_SIZE:
        return
    if slot == 0 and master() != null:
        last_reason = "slot 1 is always the Master"
        return
    party[slot] = ""
    _commit()


func clear_party() -> void:
    party = ["", "", "", "", ""]
    if master() != null:
        party[0] = master().id
    _commit()


# --- the Master (D-080) ---------------------------------------------------------------------------

## The player's own character, or null (a new account before the creator, or a save from before D-080).
func master() -> HeroData:
    for id in heroes:
        if (heroes[id] as HeroData).is_master:
            return heroes[id]
    return null


## True when the character creator must open: an account that exists (or is being started) with no Master.
func needs_master() -> bool:
    return master() == null


## Makes the Master from the creator's choices (HeroGenerator.create_master) and puts them in slot 1.
## Whoever had slot 1 moves to the first empty slot, or out of the party if it is full. Nobody is removed
## from the roster (an old save keeps every hero).
func create_master(choices: Dictionary) -> HeroData:
    if master() != null:
        return master()
    var h: HeroData = null
    for i in 50:                                  # the creator's seed first (its preview showed that starter skill)
        h = HeroGenerator.create_master(int(choices["seed"]) if i == 0 and choices.has("seed") else rng.randi(), choices)
        if not heroes.has(h.id) and not _signatures.has(h.signature()):
            break
    heroes[h.id] = h
    give_kit(h)
    _signatures[h.signature()] = true
    var old := String(party[0])
    party[0] = h.id
    if old != "" and old != h.id:
        for i in range(1, PARTY_SIZE):
            if party[i] == "":
                party[i] = old
                break
    h.add_memory("master", "Stood in the circle again and called out: this time, someone answered.", "", 3)
    if not onboarded:
        hardcore = bool(choices.get("hardcore", false))   # D-081: only when the game is created, never later
    assign_beds()
    _commit()
    return h


## D-081 barber / mirror: only the look changes (never race, class, trait, name or background).
## "" on success, else why not.
func restyle_master(look: Dictionary) -> String:
    var m := master()
    if m == null:
        return "no Master"
    if not has_resources(MasterDefs.BARBER_COST):
        return "needs %s" % str(MasterDefs.BARBER_COST)
    var nl: Dictionary = m.look.duplicate()
    for k in ["body", "skin", "eyes", "hair", "hair_color", "beard"]:
        if look.has(k):
            nl[k] = look[k]
    nl["race"] = m.look.get("race", "human")
    m.look = HeroGenerator.master_look(nl)
    for k in MasterDefs.BARBER_COST:
        hq_outputs[k] = int(hq_outputs.get(k, 0)) - int(MasterDefs.BARBER_COST[k])
    _commit()
    return ""


## D-081: a hardcore Master died. The game is kept but marked over, with a summary for the end screen.
func _end_hardcore(m: HeroData, cause: String) -> void:
    game_over = true
    game_over_info = {"name": m.display_name(), "cause": cause, "floors": highest_cleared(), "heroes": heroes.size() - 1,
        "memorial": memorial.size() + 1, "seconds": roundi(play_seconds)}


func party_slot_of(hero_id: String) -> int:
    return party.find(hero_id)


func party_heroes() -> Array:
    var out: Array = []
    for id in party:
        if heroes.has(id) and (heroes[id] as HeroData).hq_assignment != "expedition":   # away: master prompt C
            out.append(heroes[id])
    return out


## D-077: a secret objective may give a unique (red), never one this account already found.
func roll_unique(chance: float = ItemLibrary.UNIQUE_CHANCE) -> String:
    var left: Array = ItemDefs.UNIQUES.keys().filter(func(u): return not uniques_found.has(u))
    if left.is_empty() or rng.randf() >= chance or stash.size() >= stash_cap():
        return ""
    left.sort()
    var uid := String(left[rng.randi() % left.size()])
    var it := ItemGen.generate(rng, _next_uid(), 10, "unique", String(ItemDefs.UNIQUES[uid]["base"]))
    it["unique"] = uid
    it["name"] = String(ItemDefs.UNIQUES[uid]["name"])
    it["power"] = (ItemDefs.UNIQUES[uid]["power"] as Dictionary).duplicate()
    stash.append(it)
    uniques_found.append(uid)
    return String(it["name"])


# --- master prompt B: the merchant (MerchantDefs) ---------------------------------------------

var merchant_used: Dictionary = {}   # "day:offer" -> trades done (not saved: resets with the day)


func merchant_offers() -> Array:
    var r := RandomNumberGenerator.new()
    r.seed = hash("merchant:%d" % town_day())
    var idx: Array = range(MerchantDefs.OFFERS.size())
    var out: Array = []
    while out.size() < mini(MerchantDefs.OFFERS_PER_DAY, idx.size()):
        out.append(idx.pop_at(r.randi() % idx.size()))
    return out


func merchant_trade(offer: int) -> String:
    if not merchant_offers().has(offer):
        return "not on sale today"
    var key := "%d:%d" % [town_day(), offer]
    if int(merchant_used.get(key, 0)) >= MerchantDefs.TRADES_PER_OFFER:
        return "sold out for today"
    var o: Dictionary = MerchantDefs.OFFERS[offer]
    for k in o["give"]:
        if int(hq_outputs.get(k, 0)) < int(o["give"][k]):
            return "needs %d %s" % [int(o["give"][k]), String(EconomyDefs.RESOURCES.get(k, {}).get("name", k)).to_lower()]
    for k in o["give"]:
        hq_outputs[k] = int(hq_outputs[k]) - int(o["give"][k])
    for k in o["get"]:
        hq_outputs[k] = int(hq_outputs.get(k, 0)) + int(o["get"][k])
    merchant_used[key] = int(merchant_used.get(key, 0)) + 1
    _commit()
    return ""


# --- permanent death / memorial (D-011, T-013) -----------------------------------

## Permanent death: the hero leaves the roster and party for good and a full snapshot goes to the
## memorial. Returns false if the hero is not on the roster (e.g. a sandbox test hero).
## Survivors in the party lose a little Trust (deterministic, never a refused order: D-016).
func record_death(h: HeroData, cause: String = "", mission: String = "") -> bool:
    if h != null and h.is_master:
        if not hardcore:
            return false              # D-080: the Master never dies (comes home wounded instead)
        _end_hardcore(h, cause)       # D-081: hardcore, the game ends (the Master still goes to the memorial)
    elif h != null and heroes.has(h.id) and cause != "sacrificed" and master() != null and party.has(h.id):
        # D-081: a hero lost on an expedition with the Master shakes everybody's bond with them
        for other in party_heroes():
            if other != h:
                MasterRules.bond_event(other, "ally_died")
                if cause.contains("left behind"):
                    MasterRules.bond_event(other, "left_behind")
    if h == null or not heroes.has(h.id):
        return false
    h.add_event("died", {"cause": cause, "mission": mission})
    memorial.append({
        "n": memorial.size() + 1,
        "hero_id": h.id,
        "name": h.display_name(),
        "stars": h.stars,
        "level": h.level,
        "class": h.hero_class,
        "traits": h.traits.duplicate(),
        "background": h.background_text,
        "summon_index": h.summon_index,
        "cause": cause,
        "mission": mission,
        "snapshot": h.to_dict(),
    })
    heroes.erase(h.id)            # the appearance signature stays taken: no look is ever reused
    patients.erase(h.id)          # its equipment is lost with it (kept in the memorial snapshot)
    assign_beds()
    for i in PARTY_SIZE:
        if party[i] == h.id:
            party[i] = ""
    for other in (party_heroes() if cause != "sacrificed" else []):     # D-061: witnessing a sacrifice changes nothing (default)
        var oh := other as HeroData
        oh.add_event("ally_fell", {"name": h.display_name()}, -2, 0)
        oh.add_memory("witnessed_death", "Witnessed the fall of %s in combat." % h.display_name(), h.id, 3)
        oh.update_relationship(h.id, -5, "death")
    _commit()
    return true


# --- headquarters & simulation (Phase 2 & Mega Prompt Town & Persistent Maps) --------

func assign_hq(hero_id: String, facility: String) -> void:
    if heroes.has(hero_id):
        assign_work(heroes[hero_id], facility)


func unassign_hq(hero_id: String) -> void:
    assign_hq(hero_id, "")


## Total beds of the built dormitories: the town can house this many heroes (no beds, no summons).
func max_hero_capacity() -> int:
    var cap := 1 if master() != null else 0         # D-080: the Master's own room in the Hall
    for bid in TownTables.ids():
        if TownTables.is_dorm(bid):
            cap += TownTables.beds_at(bid, building_level(bid))
    return cap


func beds_used(bid: String) -> int:
    var n := 0
    for id in heroes:
        if (heroes[id] as HeroData).bed == bid:
            n += 1
    return n


## Keeps each hero's bed if it still exists; gives free beds to the rest (summon order). Heroes over
## capacity (old saves) sleep rough; nobody is ever removed for lack of beds.
func assign_beds() -> void:
    var free := {}
    for bid in TownTables.ids():
        if TownTables.is_dorm(bid):
            free[bid] = TownTables.beds_at(bid, building_level(bid))
    var homeless: Array = []
    for id in heroes:
        var h: HeroData = heroes[id]
        if h.is_master:
            h.bed = MASTER_BED                      # D-080: the Master sleeps in the Hall, not in a dorm bed
            continue
        if h.bed != "" and int(free.get(h.bed, 0)) > 0:
            free[h.bed] = int(free[h.bed]) - 1
        else:
            h.bed = ""
            homeless.append(h)
    for h in homeless:
        for bid in free:
            if int(free[bid]) > 0:
                h.bed = String(bid)
                free[bid] = int(free[bid]) - 1
                break


func building_level(bid: String) -> int:
    return int(town_buildings.get(bid, 0))


## Materials for the next level, or -1 when the building is unknown or already at max level.
func next_building_cost(bid: String) -> int:
    var b := TownTables.info(bid)
    if b.is_empty() or building_level(bid) >= int(b["max"]):
        return -1
    return TownTables.upgrade_cost(bid, building_level(bid))


## Starts building (0 -> 1) or upgrading a town building (D-048): pays the materials now and queues
## the work for builders. Refused (nothing changes, last_reason says why) when maxed, capped by the
## Summoner's Hall, not unlocked, already under construction or short of materials.
func build_or_upgrade(bid: String) -> bool:
    last_reason = construction_block(bid)
    if last_reason == "" and not is_placed(bid):
        var spot: Vector2i = (TownTables.info(bid)["plot"] as Rect2i).position
        if placement_block(bid, spot, false) != "":
            last_reason = "choose where to build it (Build menu)"
        else:
            town_layout[bid] = spot
    if last_reason != "":
        return false
    var cost := next_building_cost(bid)
    hq_outputs["materials"] = int(hq_outputs.get("materials", 0)) - cost
    var to := building_level(bid) + 1
    construction.append({"bid": bid, "to": to, "work_left": EconomyDefs.BUILD_HOURS_PER_LEVEL * float(to)})
    log_town("Construction started: %s level %d." % [TownTables.info(bid)["name"], to])
    _commit()
    return true


## "" if bid can start construction now, otherwise the reason.
func construction_block(bid: String) -> String:
    var b := TownTables.info(bid)
    if b.is_empty():
        return "unknown building"
    var cost := next_building_cost(bid)
    if cost < 0:
        return "already at max level"
    var hall := building_level("town_hall")
    if bid != "town_hall" and building_level(bid) == 0 and hall < int(b.get("hall", 0)):
        return "needs Summoner's Hall level %d" % int(b.get("hall", 0))
    if bid != "town_hall" and building_level(bid) + 1 > hall:
        return "upgrade the Summoner's Hall first (level cap %d)" % hall
    if construction.any(func(p): return String(p["bid"]) == bid):
        return "already under construction"
    if construction.size() >= builder_count():
        return "every builder is busy (one building per builder)"
    if int(hq_outputs.get("materials", 0)) < cost:
        return "needs %d materials" % cost
    return ""


func under_construction(bid: String) -> Dictionary:
    for p in construction:
        if String(p["bid"]) == bid:
            return p
    return {}


func complete_construction(bid: String, to: int) -> void:
    town_buildings[bid] = maxi(building_level(bid), to)
    log_town("%s reached level %d." % [TownTables.info(bid)["name"], to])
    if TownTables.is_dorm(bid):
        assign_beds()


## Owner 2026-11-02: one building site per builder (heroes who know the trade or work the site);
## at least one, so a new town can always queue its first building.
func builder_count() -> int:
    return maxi(1, heroes.values().filter(func(h): return (h as HeroData).knows_prof("builder") or (h as HeroData).hq_assignment == "construction").size())


func builders() -> Array:
    return heroes.values().filter(func(h): return (h as HeroData).hq_assignment == "construction")


func can_summon(count: int) -> bool:
    return heroes.size() + count <= max_hero_capacity()


## Why a summon of `count` is blocked by housing ("" = it is not).
func housing_block(count: int) -> String:
    var free := max_hero_capacity() - heroes.size()
    return "" if free >= count else "not enough beds (%d free): build or upgrade a dormitory" % maxi(0, free)


## D-004 / D-026: a floor is generated once per account and then always loaded as it was. v2 floors
## are stored as a full snapshot; floors saved before v2 (seed only, F-014) keep being rebuilt by the
## generator version 1 they were made with, so they never change under the player's feet.
func get_or_create_tower_floor_map(floor_num: int) -> ProceduralMap:
    var f_key := str(floor_num)
    if tower_maps.has(f_key):
        var m_data: Dictionary = tower_maps[f_key]
        if int(m_data.get("gen", 1)) >= 2 and m_data.has("snapshot"):
            return ProceduralMap.from_snapshot(m_data["snapshot"], floor_num)
        return ProceduralMap.new(int(m_data["width"]), int(m_data["height"]), int(m_data["seed"]), floor_num, 1)
    var cfg := TowerExpedition.get_floor_config(floor_num)
    var f_seed := rng.randi()
    var pmap := ProceduralMap.new(int(cfg["width"]), int(cfg["height"]), f_seed, floor_num)
    tower_maps[f_key] = {"seed": f_seed, "width": pmap.width, "height": pmap.height, "gen": pmap.gen_version,
        "snapshot": pmap.to_snapshot(), "explored": ""}
    _commit()
    return pmap


## D-146 dev console /seed N: the floor is generated again from that seed (its explored memory goes too).
func dev_regen_floor(floor_num: int, f_seed: int) -> void:
    var cfg := TowerExpedition.get_floor_config(floor_num)
    var pmap := ProceduralMap.new(int(cfg["width"]), int(cfg["height"]), f_seed, floor_num)
    tower_maps[str(floor_num)] = {"seed": f_seed, "width": pmap.width, "height": pmap.height, "gen": pmap.gen_version,
        "snapshot": pmap.to_snapshot(), "explored": ""}
    _commit()


## Fog of war memory (D-056): explored cells of a floor, bit-packed + base64 (a 92x80 floor = ~1.3 KB).
func floor_explored(floor_num: int) -> String:
    return String((tower_maps.get(str(floor_num), {}) as Dictionary).get("explored", ""))


func set_floor_explored(floor_num: int, packed: String) -> void:
    var f_key := str(floor_num)
    if tower_maps.has(f_key):
        tower_maps[f_key]["explored"] = packed


## Floor completion reward (owner: "sí" to quick progression, 2026-10-30). Placeholder numbers:
## deeper floors pay more materials (for town buildings), stones (promotion) and gems; even floors give a
## training book. Skill books (D-046): boss floors (every 10th) always drop one, rescue and exploration
## missions reward one, other floors have a SKILL_BOOK_CHANCE drop.
const SKILL_BOOK_CHANCE := 0.25
const BOOK_MISSIONS := ["rescue", "exploration"]


func complete_floor(floor_num: int, mission: String = "") -> Dictionary:
    # D-066: the tower pays in gear and rarities, not in town materials (those come from the Wilds). The
    # first clear of a floor pays in full; later clears pay much less (the tower is not a farm).
    var key := str(floor_num)
    var first := int(tower_cleared.get(key, 0)) == 0
    var r := {"gems": (ProgressionDefs.FIRST_GEMS_BASE + ProgressionDefs.FIRST_GEMS_PER_FLOOR * floor_num) if first
            else ProgressionDefs.REPLAY_GEMS_BASE + ProgressionDefs.REPLAY_GEMS_PER_FLOOR * floor_num, "stones": (1 + floor_num / 4) if first else 0,
        "books": (1 if floor_num % 2 == 0 else 0) if first else 0, "skill_books": [], "materials": 0, "food": 0,
        "starsteel": ProgressionDefs.TOWER_STARSTEEL_BASE + floor_num / 2 if first else 0, "essence": 1 + floor_num / 3 if first else 0, "first": first}
    # master prompt A: the mission chest (always something; full on the first clear) and first-clear keys
    r["chest"] = LootService.chest(floor_num, first, rng)
    for res in r["chest"]:
        hq_outputs[res] = mini(storage_cap(), int(hq_outputs.get(res, 0)) + int(r["chest"][res]))
    tower_cleared[key] = int(tower_cleared.get(key, 0)) + 1
    r["memory"] = MasterRules.unlock_memory(master(), floor_num)     # D-081: tenth floors, once
    gems += int(r["gems"])
    stones += int(r["stones"])
    books += int(r["books"])
    for rare in ["starsteel", "essence"]:
        hq_outputs[rare] = int(hq_outputs.get(rare, 0)) + int(r[rare])
    var drops := 0
    if not first:
        drops = -99                                       # no free skill books from replays
    if floor_num % 10 == 0:
        drops += 1
    if BOOK_MISSIONS.has(mission):
        drops += 1
    if drops == 0 and rng.randf() < SKILL_BOOK_CHANCE:
        drops = 1
    for i in drops:
        var b := random_skill_book()
        if b != "":
            grant_skill_book(b)
            (r["skill_books"] as Array).append(b)
    r["items"] = []
    r["left_behind"] = 0
    var boss := floor_num % 10 == 0
    var n_items := (2 + floor_num / 3 + (2 if boss else 0)) if first else 1
    for i in n_items:
        # tower loot is better than anything a town forge makes early: at least uncommon, a boss floor rare
        var rarity := ItemGen.roll_rarity(rng, floor_num + 2, 3.0 if boss else 1.0, "rare" if (boss or floor_num % 5 == 0) and i == 0 else "uncommon")
        if stash.size() >= stash_cap():
            r["left_behind"] = int(r["left_behind"]) + 1     # no room: left in the tower (shown in the result)
            continue
        var it := ItemGen.generate_drop(rng, _next_uid(), floor_num, rarity, ItemLibrary.theme_of(String(TowerExpedition.get_floor_config(floor_num)["foes"][0])))
        stash.append(it)
        (r["items"] as Array).append(ItemDefs.item_label(it))
    _commit()
    return r


# --- skill books (D-046) ----------------------------------------------------------------

## Classes of the living roster, in summon order (all classes if the roster is empty).
func roster_classes() -> Array:
    var classes: Array = []
    for id in heroes:
        var c: String = (heroes[id] as HeroData).hero_class
        if not classes.has(c):
            classes.append(c)
    return classes if not classes.is_empty() else SkillDefs.KITS.keys()


## A random book; for one class when class_id is given, otherwise for any class in the roster.
func random_skill_book(class_id: String = "") -> String:
    var classes: Array = [class_id] if class_id != "" else roster_classes()
    var pool := SkillDefs.book_pool(classes)
    return "" if pool.is_empty() else String(pool[rng.randi() % pool.size()])


## Sources: tower loot, mission rewards, the Library and (hook) secrets.
func grant_skill_book(skill_id: String, count: int = 1) -> void:
    if not SkillDefs.SKILLS.has(skill_id) or count <= 0:
        return
    skill_books[skill_id] = int(skill_books.get(skill_id, 0)) + count


## Reads a book: "" when learned, otherwise the reason it cannot be read (the book is kept).
func use_skill_book(h: HeroData, skill_id: String) -> String:
    if h == null or int(skill_books.get(skill_id, 0)) <= 0:
        return "no such book"
    if h.skills.has(skill_id):
        return "already known"
    if not SkillDefs.usable_by(skill_id, h.hero_class):
        return "not for a %s" % h.class_title()
    h.learn_skill(skill_id)
    skill_books[skill_id] = int(skill_books[skill_id]) - 1
    if int(skill_books[skill_id]) <= 0:
        skill_books.erase(skill_id)
    _commit()
    return ""


## Library (D-046): transcribe a book of the chosen class for materials; cheaper at higher levels.
func library_cost() -> int:
    var lv := building_level("library")
    if lv <= 0:
        return 0
    var cost := maxi(20, TownTables.LIBRARY_BASE_COST - TownTables.LIBRARY_DISCOUNT * (lv - 1))
    if workers_at("library").any(func(h): return (h as HeroData).knows_prof("scholar")):
        cost = roundi(float(cost) * 0.75)                      # a scholar at work: 25% cheaper
    return cost


func library_transcribe(class_id: String) -> String:
    var cost := library_cost()
    if cost <= 0 or int(hq_outputs.get("materials", 0)) < cost or not SkillDefs.KITS.has(class_id):
        return ""
    var b := random_skill_book(class_id)
    if b == "":
        return ""
    hq_outputs["materials"] = int(hq_outputs["materials"]) - cost
    grant_skill_book(b)
    _commit()
    return b


## One town day (the HQ screen button). Kept for older callers: summary keys "<res>_produced".
func process_headquarters_turn() -> Dictionary:
    var rep := pass_time(24)
    var summary := {"events": (rep["events"] as Array).size()}
    for res in rep["produced"]:
        summary[String(res) + "_produced"] = int(rep["produced"][res])
    return summary


# --- town simulation (HQ Phase 1, D-047..D-050) ---------------------------------------------

## Advances the town and saves. deployed = hero ids in the tower during that time.
func pass_time(hours: int, deployed: Array = []) -> Dictionary:
    var rep := TownSim.advance(self, hours, deployed)
    for ev in rep["events"]:
        log_town(String(ev))
    _commit()
    return rep


## D-047: while the player is in the town the clock runs slowly (REAL_SECONDS_PER_HOUR).
func town_tick(delta: float) -> void:
    _clock_acc += delta
    if _clock_acc >= EconomyDefs.REAL_SECONDS_PER_HOUR:
        _clock_acc -= EconomyDefs.REAL_SECONDS_PER_HOUR
        pass_time(1)


func town_day() -> int:
    return town_clock / 24 + 1


func town_time_text() -> String:
    return "Day %d, %02d:00" % [town_day(), town_clock % 24]


func log_town(text: String) -> void:
    town_log.append("[%s] %s" % [town_time_text(), text])
    while town_log.size() > TOWN_LOG_CAP:
        town_log.pop_front()


func storage_cap() -> int:
    return EconomyDefs.STORAGE_BASE + EconomyDefs.STORAGE_PER_LEVEL * building_level("warehouse")


func stash_cap() -> int:
    return EconomyDefs.STASH_BASE + EconomyDefs.STASH_PER_LEVEL * building_level("warehouse")


func has_resources(cost: Dictionary) -> bool:
    for k in cost:
        if int(hq_outputs.get(k, 0)) < int(cost[k]):
            return false
    return true


## Recipe the building runs (its chosen job, else its first one; "" if it has none).
func job_of(bid: String) -> String:
    var jobs: Array = TownTables.info(bid).get("jobs", [])
    if jobs.is_empty():
        return ""
    var j := String(town_jobs.get(bid, ""))
    if jobs.has(j) and (EconomyDefs.is_auto(j) or int(craft_left.get(bid, 0)) > 0):
        return j
    for x in jobs:                                    # owner 2026-11-02: without an order only basic work runs
        if EconomyDefs.is_auto(String(x)):
            return String(x)
    return ""


func set_job(bid: String, recipe: String) -> bool:
    if not (TownTables.info(bid).get("jobs", []) as Array).has(recipe):
        return false
    town_jobs[bid] = recipe
    if not EconomyDefs.is_auto(recipe) and int(craft_left.get(bid, 0)) <= 0:
        craft_left[bid] = 1                           # a craft never runs forever: picking it is an order of one
    _commit()
    return true


## Profession a workplace needs ("" if none).
## Work places taken for this hero: at a specialist-only building apprentices have their own places
## (TownTables.APPRENTICE_SLOTS) and do not use the workers' ones.
func _slots_taken(bid: String, h: HeroData) -> int:
    if not TownTables.SPECIALIST_ONLY.has(bid):
        return workers_at(bid).size()
    var prof := workplace_prof(bid)
    var pupils: Array = workers_at(bid).filter(func(w): return not (w as HeroData).knows_prof(prof))
    if h.knows_prof(prof):
        return workers_at(bid).size() - pupils.size()
    return 999 if pupils.size() >= TownTables.APPRENTICE_SLOTS else 0


func workplace_prof(bid: String) -> String:
    if bid == "construction":
        return "builder"
    if bid == "library":
        return "scholar"
    var rid := job_of(bid)
    if rid == "":                                     # an order-only bench with no order still has its trade
        var jobs: Array = TownTables.info(bid).get("jobs", [])
        rid = String(jobs[0]) if not jobs.is_empty() else ""
    return "" if rid == "" else String(EconomyDefs.recipe(rid)["prof"])


func workers_at(bid: String) -> Array:
    return heroes.values().filter(func(h): return (h as HeroData).hq_assignment == bid)


## Puts a hero to work (D-049): the workplace's profession is learned as an apprentice if the hero
## has a free profession slot. "" on success, else the reason (nothing changes).
func assign_work(h: HeroData, bid: String) -> String:
    last_reason = ""
    if h == null or not heroes.has(h.id):
        last_reason = "unknown hero"
    elif h.is_master and bid != "":
        last_reason = "the Master leads the village: no job for them"
    elif bid == "":
        h.hq_assignment = ""
    elif bid != "construction" and building_level(bid) <= 0:
        last_reason = "not built yet"
    elif bid != "construction" and _slots_taken(bid, h) >= TownTables.worker_slots(bid, building_level(bid)) and h.hq_assignment != bid:
        last_reason = "no free work place (%d)" % TownTables.worker_slots(bid, building_level(bid))
    else:
        var prof := workplace_prof(bid)
        if prof == "":
            last_reason = "nobody works here"
        elif TownTables.SPECIALIST_ONLY.has(bid) and not h.knows_prof(prof):
            # apprentice: needs a master at work there and room for one more profession
            var master: bool = workers_at(bid).any(func(w): return (w as HeroData).prof_level(prof) >= TownTables.MASTER_MIN_LVL)
            if not master:
                last_reason = "only a %s can work here (an apprentice needs a master working there)" % String(ProfessionDefs.info(prof)["name"]).to_lower()
            elif h.professions.size() >= ProfessionDefs.MAX_KNOWN:
                last_reason = "already knows %d professions: forget one first" % ProfessionDefs.MAX_KNOWN
            else:
                if String(h.aptitude_known.get(prof, "")) == "incompatible":
                    last_reason = "%s has no talent for this trade" % h.display_name()
                    return last_reason
                if not (h.apprenticeship.get(prof) is Dictionary):
                    h.apprenticeship[prof] = {"hours": 0.0, "progress": 0.0}
                h.hq_assignment = bid
                h.add_memory("hq_assign", "Became an apprentice at the %s." % TownTables.info(bid).get("name", bid), "", 2)
        else:
            last_reason = h.learn_prof(prof)
            if last_reason == "":
                h.hq_assignment = bid
                h.add_memory("hq_assign", "Started working at the %s." % (TownTables.info(bid).get("name", "construction site")), "", 1)
    if last_reason == "":
        _commit()
    return last_reason


## True if the hero can do its job this hour (building built, job possible, project to build).
func can_work_now(h: HeroData) -> bool:
    if h.hq_assignment == "":
        return false
    if h.hq_assignment == "construction":
        return not construction.is_empty() and h.knows_prof("builder")
    var prof := workplace_prof(h.hq_assignment)
    if building_level(h.hq_assignment) > 0 and h.apprenticeship.has(prof):
        return true                                  # an apprentice goes to work to learn (TownSim._apprentices)
    return building_level(h.hq_assignment) > 0 and h.knows_prof(prof)


## Takes a recipe's inputs and opens a batch. "" on success, else why it cannot start.
func start_batch(bid: String, rid: String) -> String:
    var r: Dictionary = EconomyDefs.recipe(rid)
    if r.get("service", false):
        return ""
    if building_level(bid) < int(r.get("blvl", 0)):           # owner 2026-11-02: better dishes need a better kitchen
        return "needs %s level %d" % [TownTables.info(bid).get("name", bid), int(r["blvl"])]
    if not has_resources(r["in"]):
        var missing: Array = []
        for k in r["in"]:
            if int(hq_outputs.get(k, 0)) < int(r["in"][k]):
                missing.append(EconomyDefs.RESOURCES[k]["name"].to_lower())
        return "missing " + ", ".join(missing)
    for k in r["out"]:
        if int(hq_outputs.get(k, 0)) + int(r["out"][k]) > storage_cap():
            return "storage full (%s): upgrade the warehouse" % EconomyDefs.RESOURCES[k]["name"].to_lower()
    if r.has("item") and stash.size() >= stash_cap():
        return "equipment stash full"
    for k in r["in"]:
        hq_outputs[k] = int(hq_outputs[k]) - int(r["in"][k])
    town_batches[bid] = {"recipe": rid, "progress": 0.0}
    return ""


func finish_batch(bid: String, best_level: int, rr: RandomNumberGenerator, report: Dictionary) -> void:
    var b: Dictionary = town_batches.get(bid, {})
    town_batches.erase(bid)
    if b.is_empty():
        return
    var r: Dictionary = EconomyDefs.recipe(String(b["recipe"]))
    for k in r["out"]:
        hq_outputs[k] = int(hq_outputs.get(k, 0)) + int(r["out"][k])
        report["produced"][k] = int(report["produced"].get(k, 0)) + int(r["out"][k])
    if r.has("craft"):                                      # D-077 library recipe: one clean crafted piece
        var it2 := ItemGen.generate_crafted(rr, _next_uid(), String(b["recipe"]), ItemGen.craft_rarity(rr, best_level, building_level(bid)),
            String(craft_affix.get(bid, "")))
        stash.append(it2)
        (report["events"] as Array).append("The %s made %s." % [TownTables.info(bid)["name"], ItemDefs.item_label(it2)])
    if r.has("item"):
        var rarity := ItemGen.craft_rarity(rr, best_level, building_level(bid))
        var floor_rarity := String(r.get("min_rarity", "common"))
        if ItemDefs.RARITY_ORDER.find(rarity) < ItemDefs.RARITY_ORDER.find(floor_rarity):
            rarity = floor_rarity                             # D-066: starsteel gear is at least rare
        var kinds: Array = ItemDefs.CRAFTABLE[String(r["item"])]
        var it := ItemGen.generate(rr, _next_uid(), 1 + best_level + building_level(bid) + int(r.get("ilvl_bonus", 0)), rarity, String(kinds[rr.randi() % kinds.size()]))
        stash.append(it)
        (report["events"] as Array).append("The %s forged %s." % [TownTables.info(bid)["name"], ItemDefs.item_label(it)])
    if not EconomyDefs.is_auto(String(b["recipe"])) and int(craft_left.get(bid, 0)) > 0:
        craft_left[bid] = int(craft_left[bid]) - 1          # owner 2026-11-02: crafts only by the Master's order
        if int(craft_left[bid]) <= 0:
            craft_left.erase(bid)
            town_jobs.erase(bid)                          # the order is done: the bench rests
            (report["events"] as Array).append("The %s finished its order." % TownTables.info(bid)["name"])


# --- building placement (D-050) ----------------------------------------------------------------

func plot_of(bid: String) -> Rect2i:
    return TownTables.plot_at(bid, town_layout)


## "" if `bid` can stand with its top-left corner at `cell`, else the reason: inside the town, off the
## plaza, not over another building, its door free, and every built building still reachable.
func placement_block(bid: String, cell: Vector2i, need_near: bool = true) -> String:
    if not TownTables.BUILDINGS.has(bid):
        return "unknown building"
    var p := plot_of(bid)
    p.position = cell
    if p.position.x < 1 or p.position.y < 1 or p.end.x > TownTables.MAP_W - 1 or p.end.y > TownTables.MAP_H - 2:
        return "outside the town"
    if p.intersects(TownTables.PLAZA):
        return "the plaza must stay free"
    var door := Vector2i(p.position.x + p.size.x / 2, p.end.y)
    var near := false
    for other in TownTables.ids():
        if other == bid or not is_placed(other):
            continue
        var q := plot_of(other)
        if p.grow(TownTables.NEAR_CELLS).intersects(q):
            near = true
        if q.intersects(p):
            return "overlaps the %s" % TownTables.info(other)["name"]
        if q.has_point(door):
            return "its door would face a wall"
    if need_near and not near:
        return "too far from the town: build within %d cells of another building" % TownTables.NEAR_CELLS
    var trial := town_layout.duplicate()
    trial[bid] = cell
    var m := TownMap.new(town_buildings, trial)
    var start := m.center_of(m.goal_cell)
    for other in TownTables.ids():
        if building_level(other) > 0 and m.find_path(start, m.center_of(m.door_of(other))).is_empty():
            return "it would cut off the %s" % TownTables.info(other)["name"]
    return ""


## Debug / tests: every basic building at level 1 or more on its default plot (the pre-slice town).
func debug_full_town() -> void:
    for bid in TownTables.PRE_SLICE_TOWN:
        town_buildings[bid] = maxi(1, building_level(bid))
    assign_beds()
    _commit()


## Built, under construction, or with its site placed (free placement: unplaced buildings take no ground).
func is_placed(bid: String) -> bool:
    return building_level(bid) > 0 or town_layout.has(bid) or not under_construction(bid).is_empty()


## Clash-of-Clans style: choose where a new building goes, pay, and the builders start there.
func place_and_build(bid: String, cell: Vector2i) -> String:
    last_reason = construction_block(bid)
    if last_reason == "":
        last_reason = placement_block(bid, cell)
    if last_reason != "":
        return last_reason
    town_layout[bid] = cell
    build_or_upgrade(bid)
    return last_reason


func move_building(bid: String, cell: Vector2i) -> String:
    last_reason = placement_block(bid, cell)
    if last_reason == "":
        town_layout[bid] = cell
        log_town("%s moved." % TownTables.info(bid)["name"])
        _commit()
    return last_reason


func _layout_to_json() -> Dictionary:
    var out := {}
    for bid in town_layout:
        out[bid] = [town_layout[bid].x, town_layout[bid].y]
    return out


# --- equipment and consumables (D-039) -------------------------------------------------------

## D-082b: every hero wears and carries real white items: the same plain clothes for all (and the Master)
## and the class's simple weapon (ItemDefs.starter_kit). Only fills empty slots (never replaces gear), and
## never the off hand while a two-handed weapon is held. Returns how many items it gave.
func give_kit(h: HeroData) -> int:
    var n := 0
    var kit := ItemDefs.starter_kit(h.hero_class)
    for slot in kit:
        if h.equipment.has(slot):
            continue
        if slot == "off_hand" and h.equipment.has("main_hand") and bool(ItemDefs.BASES.get(String(h.equipment["main_hand"].get("base", "")), {}).get("two_handed", false)):
            continue
        if slot == "main_hand" and h.equipment.has("off_hand") and bool(ItemDefs.BASES[String(kit[slot])].get("two_handed", false)):
            continue
        h.equipment[slot] = ItemGen.starter(String(kit[slot]), _next_uid())
        n += 1
    return n


func _next_uid() -> int:
    item_seq += 1
    return item_seq


func stash_index(uid: int) -> int:
    for i in stash.size():
        if int(stash[i]["uid"]) == uid:
            return i
    return -1


## Equips a stash item. Two-handed weapons free the off hand; rings take a free ring slot. Replaced
## items go back to the stash. "" on success, else the reason.
func equip(h: HeroData, uid: int, slot: String = "") -> String:
    var i := stash_index(uid)
    if h == null or i < 0:
        return "item not in the stash"
    var it: Dictionary = stash[i]
    var req := ItemLibrary.equip_block(h, it)
    if req != "":
        return req
    var allowed := ItemDefs.slots_for(String(it["base"]))
    if allowed.is_empty():
        return "that slot opens later (D-060)"
    if slot == "":
        slot = String(allowed[0])
        for s in allowed:
            if not h.equipment.has(s):
                slot = String(s)
                break
    if not allowed.has(slot):
        return "does not fit there"
    var two := bool(ItemDefs.BASES[String(it["base"])].get("two_handed", false))
    var back: Array = []
    if h.equipment.has(slot):
        back.append(h.equipment[slot])
    if two and h.equipment.has("off_hand"):
        back.append(h.equipment["off_hand"])
    if slot == "off_hand" and h.equipment.has("main_hand") and bool(ItemDefs.BASES[String(h.equipment["main_hand"]["base"])].get("two_handed", false)):
        back.append(h.equipment["main_hand"])
    if stash.size() - 1 + back.size() > stash_cap():
        return "no room in the stash for the replaced items"
    stash.remove_at(i)
    for b in back:
        for s in h.equipment.keys():
            if h.equipment[s] == b:
                h.equipment.erase(s)
        stash.append(b)
    h.equipment[slot] = it
    _commit()
    return ""


func unequip(h: HeroData, slot: String) -> String:
    if h == null or not h.equipment.has(slot):
        return "nothing there"
    if stash.size() >= stash_cap():
        return "equipment stash full"
    stash.append(h.equipment[slot])
    h.equipment.erase(slot)
    _commit()
    return ""


## Breaks an unwanted stash item into resources (ingots for metal gear, materials otherwise).
func salvage(uid: int) -> Dictionary:
    var i := stash_index(uid)
    if i < 0:
        return {}
    var it: Dictionary = stash[i]
    stash.remove_at(i)
    var got := LootService.salvage_yield(it)                 # D-123: grey junk has its own table
    for res in got:
        hq_outputs[res] = mini(storage_cap(), int(hq_outputs.get(res, 0)) + int(got[res]))
    _commit()
    return got


const BAG_SLOTS := 3                 # different consumables a hero can carry
const BAG_STACK := 3                 # of each


## Moves one consumable from town storage into the hero's bag (carried into the tower).
func pack_consumable(h: HeroData, res: String) -> String:
    if not LootDefs.CONSUMABLES.has(res):                     # D-128: the carry list lives in LootDefs
        return "cannot be carried"
    if int(hq_outputs.get(res, 0)) <= 0:
        return "none in storage"
    if not h.bag.has(res) and h.bag.size() >= BAG_SLOTS:
        return "bag full"
    if int(h.bag.get(res, 0)) >= BAG_STACK:
        return "can carry only %d" % BAG_STACK
    hq_outputs[res] = int(hq_outputs[res]) - 1
    h.bag[res] = int(h.bag.get(res, 0)) + 1
    _commit()
    return ""


func unpack_consumable(h: HeroData, res: String) -> String:
    if int(h.bag.get(res, 0)) <= 0:
        return "not carried"
    h.bag[res] = int(h.bag[res]) - 1
    if int(h.bag[res]) <= 0:
        h.bag.erase(res)
    hq_outputs[res] = int(hq_outputs.get(res, 0)) + 1
    _commit()
    return ""


# --- expeditions ----------------------------------------------------------------------------

## End of an expedition (vertical slice). outcome "success" | "escaped" | "failed".
## loot = resources gathered and dropped during the run (resource -> amount): kept on success and on
## escape, lost if the squad was wiped. Success also pays the floor's completion reward (complete_floor)
## and completion XP + MVP bonus (ExpeditionResults). Returns everything the results screen shows.
# --- the Wilds (D-066) ------------------------------------------------------------------------

var wilds_runs: int = 0
# master prompt C/B: offline expeditions (OfflineExpeditions), portal upgrades, summon pity, merchant
var expeditions: Array = []          # [{floor, heroes: [id], start, end}] (unix seconds)
var exp_charges: int = ExpeditionDefs.CHARGES_MAX
var exp_charge_t: float = 0.0
var portal_upgrades: Dictionary = {}
var craft_left: Dictionary = {}      # building -> pieces still to make for the current order (WoW-style "Create x N")
var craft_affix: Dictionary = {}     # building -> affix chosen for its crafted gear
var uniques_found: Array = []        # D-077: unique ids already dropped on this account (never again)


## WoW-style crafting order: make `count` of a recipe at a building (0 = keep going).
func order_craft(bid: String, rid: String, count: int, affix: String = "") -> String:
    if workers_at(bid).is_empty():
        return "nobody works here"
    if not (TownTables.info(bid).get("jobs", []) as Array).has(rid):
        return "this building cannot make that"
    var r: Dictionary = EconomyDefs.recipe(rid)
    if building_level(bid) < int(r.get("blvl", 0)):
        return "needs %s level %d" % [TownTables.info(bid).get("name", bid), int(r["blvl"])]
    if count <= 0 and not EconomyDefs.is_auto(rid):     # "Create all" = as many as the stores pay for
        count = 999
        for k in r["in"]:
            count = mini(count, int(hq_outputs.get(k, 0)) / maxi(1, int(r["in"][k])))
        if count <= 0:
            return "missing materials (farm them in the tower or the Wilds)"
    if not EconomyDefs.is_auto(rid) and not has_resources(r["in"]):
        return "missing materials (farm them in the tower or the Wilds)"
    town_jobs[bid] = rid
    if count > 0:
        craft_left[bid] = count
    else:
        craft_left.erase(bid)
    if affix != "":
        craft_affix[bid] = affix
    else:
        craft_affix.erase(bid)
    town_batches.erase(bid)
    _commit()
    return "" # "charges" | "formation" | "retry" -> count              # runs in the Wilds (stat only; not saved)


func highest_cleared() -> int:
    var best := 0
    for k in tower_cleared:
        if int(tower_cleared[k]) > 0:
            best = maxi(best, int(k))
    return best


func wilds_tier() -> int:
    return DungeonDefs.tier_for(highest_cleared())


## A brand new Wilds map (never saved: every run is a different place).
func new_wilds_map(tier: int) -> ProceduralMap:
    var cfg := DungeonDefs.config(tier)
    return ProceduralMap.new(int(cfg["width"]), int(cfg["height"]), rng.randi(), -tier)


## "" if the squad may enter tower floor `floor_num` now, else why not (no town gate since 2026-10-31).
func floor_block(floor_num: int) -> String:
    return TowerExpedition.floor_block(floor_num, building_level("town_hall"))


## Advice (not a lock) when the town is weaker than a floor expects.
func floor_advice(floor_num: int) -> String:
    return TowerExpedition.floor_advice(floor_num, building_level("town_hall"))


## End of a Wilds run: what was gathered and dropped is kept when the squad gets out (escaped) and lost
## if it was wiped. Creature XP is shared as in an escape; there is no completion reward or MVP bonus.
func finish_wilds(tier: int, outcome: String, loot: Dictionary, entries: Array, kill_xp: int) -> Dictionary:
    wilds_runs += 1
    var rep := finish_expedition(-tier, "failed" if outcome == "failed" else "escaped", loot, entries, kill_xp)
    rep["outcome"] = outcome
    rep["tier"] = tier
    return rep


func finish_expedition(floor_num: int, outcome: String, loot: Dictionary, entries: Array, kill_xp: int, mission: String = "", secret_done: bool = false) -> Dictionary:
    var rep := {"outcome": outcome, "loot": {}, "lost_loot": {}, "reward": {}, "xp": [], "mvp": "", "mvp_reason": "", "mvp_bonus": 0}
    if outcome == "failed":
        rep["lost_loot"] = loot.duplicate()
    else:
        for res in loot:
            var before := int(hq_outputs.get(res, 0))
            hq_outputs[res] = mini(storage_cap(), before + int(loot[res]))
            rep["loot"][res] = int(hq_outputs[res]) - before
    var with_master := entries.any(func(e): return (e["hero"] as HeroData).is_master)
    if outcome == "success" and floor_num > 0:
        if with_master:                                   # D-081: a floor cleared together
            for e in entries:
                if bool(e["alive"]):
                    MasterRules.bond_event(e["hero"], "floor_cleared")
        rep["reward"] = complete_floor(floor_num, mission)
        if secret_done:
            rep["unique"] = roll_unique()
    var res := ExpeditionResults.compute(entries, outcome, floor_num, kill_xp, secret_done)
    if res["mvp"] != null:
        rep["mvp"] = (res["mvp"] as HeroData).display_name()
        if with_master:
            MasterRules.bond_event(res["mvp"], "mvp")
        rep["mvp_reason"] = res["mvp_reason"]
        rep["mvp_bonus"] = int(res.get("mvp_bonus", 0))
    for e in entries:
        var h: HeroData = e["hero"]
        var xp := int((res["xp"] as Dictionary).get(h.id, 0))
        var lv := h.level
        var gained := h.add_xp(xp) if xp > 0 and bool(e["alive"]) else 0
        rep["xp"].append({"name": h.display_name(), "xp": xp, "from": lv, "to": h.level, "levels": gained, "alive": bool(e["alive"]),
            "mvp": res["mvp"] == h, "capped": h.is_max_level()})
    _commit()
    return rep


## Called when a squad comes back from a floor (won or lost). results = [{"hero": HeroData,
## "downed": bool, "poisoned": bool}] for the survivors; died = how many fell. The expedition day
## passes in the town with the squad away (D-047), then the squad comes home with its scars.
func after_expedition(results: Array, floor_num: int, died: int, hours: int = EconomyDefs.HOURS_PER_EXPEDITION) -> Dictionary:
    var ids: Array = []
    for r in results:
        ids.append((r["hero"] as HeroData).id)
    var rep := TownSim.advance(self, hours, ids)
    for r in results:
        var h: HeroData = r["hero"]
        if not heroes.has(h.id):
            continue
        h.activity_state = "idle"
        h.hunger = clampi(h.hunger + int(EconomyDefs.AFTER_MISSION["hunger"]), 0, 100)
        h.fatigue = clampi(h.fatigue + int(EconomyDefs.AFTER_MISSION["fatigue"]), 0, 100)
        h.stress = clampi(h.stress + int(EconomyDefs.AFTER_MISSION["stress"]) + died * int(EconomyDefs.AFTER_MISSION["stress_death"]), 0, 100)
        var ch: Dictionary = EconomyDefs.DISEASE_CHANCE
        if bool(r.get("master_lost", false)) and h.is_master and h.catch_disease(MasterDefs.WOUND_DISEASE, "fell on floor %d" % floor_num):
            (rep["events"] as Array).append("%s was carried home wounded." % h.hero_name)
        if bool(r.get("downed", false)) and rng.randf() < float(ch["downed"]) and h.catch_disease("infected_wound", "downed on floor %d" % floor_num):
            (rep["events"] as Array).append("%s's wound got infected." % h.hero_name)
        if bool(r.get("poisoned", false)) and rng.randf() < float(ch["poisoned"]) and h.catch_disease("toxin", "poisoned on floor %d" % floor_num):
            (rep["events"] as Array).append("%s still has poison in the blood." % h.hero_name)
        if floor_num != 0 and floor_num < 10 and rng.randf() < float(ch["forest"]) and h.catch_disease("marsh_fever", "the wet forest of floor %d" % floor_num):
            (rep["events"] as Array).append("%s came back with marsh fever." % h.hero_name)
        if floor_num >= 5 and rng.randf() < float(ch["deep"]) and h.catch_disease("cave_cough", "the damp air of floor %d" % floor_num):
            (rep["events"] as Array).append("%s has a cough." % h.hero_name)
    for ev in rep["events"]:
        log_town(String(ev))
    _commit()
    return rep


# --- debug / reset ----------------------------------------------------------------

func grant(add_gems: int, add_stones: int, add_books: int) -> void:
    gems += add_gems
    stones += add_stones
    books += add_books
    _commit()


func new_game() -> void:
    onboarded = false
    hardcore = false
    game_over = false
    game_over_info = {}
    play_seconds = 0.0
    cheated = false
    synergy_codex = {}
    gems = SummonConfig.START_GEMS
    stones = 5
    books = 5
    pity4 = 0
    pity5 = 0
    pull_count = 0
    summon_log.clear()
    memorial.clear()
    heroes.clear()
    _signatures.clear()
    party = ["", "", "", "", ""]
    hq_outputs = START_STOCK.duplicate()
    town_buildings = TownTables.start_levels()
    tower_maps.clear()
    tower_cleared.clear()
    expeditions.clear()
    uniques_found.clear()
    craft_left.clear()
    craft_affix.clear()
    exp_charges = ExpeditionDefs.CHARGES_MAX
    exp_charge_t = 0.0
    portal_upgrades.clear()
    skill_books.clear()
    _reset_town()
    SpriteComposer.clear_cache()
    _commit()


func _reset_town() -> void:
    town_clock = 8
    town_seed = rng.randi()
    town_jobs = {}
    town_batches = {}
    construction = []
    patients = []
    town_layout = {}
    town_log = []
    town_problems = {}
    stash = []
    item_seq = 0


# --- save / load ------------------------------------------------------------------

func _commit() -> void:
    if autosave:
        save_game()
    changed.emit()


func save_game() -> bool:
    var hero_list: Array = []
    for id in heroes:
        hero_list.append((heroes[id] as HeroData).to_dict())
    var data := {
        "version": SAVE_VERSION,
        "gems": gems,
        "stones": stones,
        "books": books,
        "pity4": pity4,
        "pity5": pity5,
        "pull_count": pull_count,
        "summon_log": summon_log,
        "memorial": memorial,
        "party": party,
        "heroes": hero_list,
        "hq_outputs": hq_outputs,
        "town_buildings": town_buildings,
        "tower_maps": tower_maps,
        "tower_cleared": tower_cleared,
        "uniques_found": uniques_found, "craft_left": craft_left, "craft_affix": craft_affix,
        "expeditions": expeditions, "exp_charges": exp_charges, "exp_charge_t": exp_charge_t, "portal_upgrades": portal_upgrades,
        "skill_books": skill_books,
        "town": {"clock": town_clock, "seed": "%x" % town_seed, "jobs": town_jobs, "batches": town_batches,
            "construction": construction, "patients": patients, "log": town_log, "item_seq": item_seq,
            "layout": _layout_to_json()},
        "stash": stash,
        "onboarded": onboarded,
        "hardcore": hardcore, "game_over": game_over, "game_over_info": game_over_info, "play_seconds": play_seconds,
        "synergy_codex": synergy_codex,
        "cheated": cheated,
    }
    return _write_atomic(JSON.stringify(data))


## Write to a temp file, check it parses, keep the previous save as .bak, then swap it in.
func _write_atomic(text: String) -> bool:
    var tmp := save_path + ".tmp"
    var bak := save_path + ".bak"
    var f := FileAccess.open(tmp, FileAccess.WRITE)
    if f == null:
        push_warning("Could not write save file: %s" % tmp)
        return false
    f.store_string(text)
    f.close()
    if typeof(JSON.parse_string(FileAccess.get_file_as_string(tmp))) != TYPE_DICTIONARY:
        push_warning("Save verification failed; previous save kept.")
        return false
    var dir := DirAccess.open(save_path.get_base_dir())
    if dir == null:
        return false
    if FileAccess.file_exists(save_path):
        dir.copy(save_path, bak)
        dir.remove(save_path)
    if dir.rename(tmp, save_path) != OK:
        if FileAccess.file_exists(bak):
            dir.copy(bak, save_path)
        push_warning("Could not finalize save; restored backup.")
        return false
    return true


func load_game() -> void:
    var parsed: Variant = _read_save(save_path)
    if typeof(parsed) != TYPE_DICTIONARY:
        parsed = _read_save(save_path + ".bak")
        if typeof(parsed) == TYPE_DICTIONARY:
            push_warning("Main save unreadable, loaded the backup.")
    if typeof(parsed) != TYPE_DICTIONARY:
        if FileAccess.file_exists(save_path):
            push_warning("Save file unreadable, starting a new game.")
        new_game()
        return
    apply_save(parsed)
    changed.emit()


func _read_save(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        return null
    return JSON.parse_string(FileAccess.get_file_as_string(path))


func apply_save(data: Dictionary) -> void:
    data = _migrate(data)
    onboarded = bool(data.get("onboarded", true))
    hardcore = bool(data.get("hardcore", false))
    game_over = bool(data.get("game_over", false))
    game_over_info = (data.get("game_over_info", {}) as Dictionary).duplicate()
    play_seconds = float(data.get("play_seconds", 0.0))
    cheated = bool(data.get("cheated", false))       # D-146
    synergy_codex = (data.get("synergy_codex", {}) as Dictionary).duplicate() if data.get("synergy_codex", {}) is Dictionary else {}   # D-090
    gems = int(data.get("gems", 0))
    stones = int(data.get("stones", 0))
    books = int(data.get("books", 0))
    pity4 = int(data.get("pity4", 0))
    pity5 = int(data.get("pity5", 0))
    heroes.clear()
    _signatures.clear()
    for d in data.get("heroes", []):
        var h := HeroData.from_dict(d)
        if h.id == "":
            continue
        heroes[h.id] = h
        _signatures[h.signature()] = true
    pull_count = maxi(int(data.get("pull_count", heroes.size())), heroes.size())
    summon_log = HeroData.intify(data.get("summon_log", []) as Array)
    memorial = HeroData.intify(data.get("memorial", []) as Array)
    party = ["", "", "", "", ""]
    var saved_party: Array = data.get("party", [])
    for i in mini(saved_party.size(), PARTY_SIZE):
        var id := str(saved_party[i])
        if heroes.has(id):
            party[i] = id
    hq_outputs = HeroData.intify(data.get("hq_outputs", {"food": 50, "materials": 50, "medicine": 50}) as Dictionary)
    town_buildings = HeroData.intify(data.get("town_buildings", TownTables.start_levels()) as Dictionary)
    tower_maps = HeroData.intify(data.get("tower_maps", {}) as Dictionary)
    tower_cleared = HeroData.intify(data.get("tower_cleared", {}) as Dictionary)
    expeditions = (data.get("expeditions", []) as Array).duplicate(true)
    uniques_found = (data.get("uniques_found", []) as Array).duplicate()
    craft_left = HeroData.intify(data.get("craft_left", {}) as Dictionary)
    craft_affix = (data.get("craft_affix", {}) as Dictionary).duplicate()
    exp_charges = int(data.get("exp_charges", ExpeditionDefs.CHARGES_MAX))
    exp_charge_t = float(data.get("exp_charge_t", 0.0))
    portal_upgrades = HeroData.intify(data.get("portal_upgrades", {}) as Dictionary)
    skill_books = {}
    var sb: Dictionary = data.get("skill_books", {})
    for k in sb:
        grant_skill_book(String(k), int(sb[k]))
    _reset_town()
    var t: Dictionary = data.get("town", {})
    town_clock = int(t.get("clock", 8))
    town_seed = String(t.get("seed", "1")).hex_to_int()
    town_jobs = (t.get("jobs", {}) as Dictionary).duplicate()
    for bid in HeroData.intify(t.get("batches", {}) as Dictionary):
        var bt: Dictionary = t["batches"][bid]
        if EconomyDefs.has_recipe(String(bt.get("recipe", ""))):
            town_batches[String(bid)] = {"recipe": String(bt["recipe"]), "progress": float(bt.get("progress", 0.0))}
    for p in t.get("construction", []):
        if TownTables.BUILDINGS.has(String(p.get("bid", ""))):
            construction.append({"bid": String(p["bid"]), "to": int(p["to"]), "work_left": float(p["work_left"])})
    for id in t.get("patients", []):
        if heroes.has(String(id)) and not patients.has(String(id)):
            patients.append(String(id))
    town_log = (t.get("log", []) as Array).duplicate()
    item_seq = int(t.get("item_seq", 0))
    if int(data.get("kit_migration", 0)) == 1:   # v18 -> v19 (D-082b): the kit fills empty slots (after item_seq)
        for hk in heroes:
            give_kit(heroes[hk])
    var lay: Dictionary = t.get("layout", {})
    for bid in lay:
        var xy: Array = lay[bid]
        if TownTables.BUILDINGS.has(String(bid)) and xy.size() == 2:
            town_layout[String(bid)] = Vector2i(int(xy[0]), int(xy[1]))
    for it in data.get("stash", []):
        if typeof(it) == TYPE_DICTIONARY and ItemDefs.BASES.has(String(it.get("base", ""))):
            stash.append(HeroData.intify(it))
            item_seq = maxi(item_seq, int(it.get("uid", 0)))
    for id in heroes:
        for slot in (heroes[id] as HeroData).equipment:
            item_seq = maxi(item_seq, int((heroes[id] as HeroData).equipment[slot].get("uid", 0)))
    for res in START_STOCK:
        if not hq_outputs.has(res):
            hq_outputs[res] = 0
    assign_beds()


## v19 -> v20 for one hero dict (also memorial snapshots): 03b class id, D-125 hoard, D-129 bonus skill
## choice, D-090 "bonus" flag on pending skill choices.
func _migrate_hero_v20(hd: Dictionary) -> void:
    hd["class"] = HeroTables.canonical_class(String(hd.get("class", "class.none")))
    if not (hd.get("hoard") is Array):
        hd["hoard"] = []
    hd["bonus_skill_choice"] = int(hd.get("bonus_skill_choice", 0))
    for c in hd.get("skill_choices", []):
        if c is Dictionary and not c.has("bonus"):
            c["bonus"] = false


## Old save versions get upgraded here when the format changes.
func _migrate(data: Dictionary) -> Dictionary:
    var v := int(data.get("version", 1))
    if v < 2:
        # v1 -> v2: summon log + pull counter appear; hero Trust/Obedience/Composure are
        # filled per hero inside HeroData.from_dict (old "loyalty" becomes Trust).
        data["pull_count"] = (data.get("heroes", []) as Array).size()
        data["summon_log"] = []
    if v < 3:
        data["memorial"] = []         # v2 -> v3: memorial of fallen heroes appears
    if v < 4:
        data["hq_facilities"] = {"kitchen": 1, "workshop": 1, "infirmary": 1, "common": 1}
        data["hq_outputs"] = {"food": 50, "materials": 50, "medicine": 50}
    if v < 5:
        data["town_buildings"] = {"town_hall": 1, "dorm_1": 1, "dorm_2": 1, "blacksmith": 1, "kitchen": 1, "infirmary": 1}
        data["tower_maps"] = {}
    if v < 6:
        # v5 -> v6 (D-030): one building model. Old hq_facilities levels move into town_buildings;
        # buildings that did not exist yet start at their default level.
        var tb: Dictionary = (data.get("town_buildings", {}) as Dictionary).duplicate()
        var old_fac: Dictionary = data.get("hq_facilities", {})
        for bid in TownTables.ids():
            if not tb.has(bid):
                tb[bid] = int(old_fac.get(bid, TownTables.pre_slice_start(bid)))
        data["town_buildings"] = tb
        data.erase("hq_facilities")
    if v < 7:
        data["tower_cleared"] = {}      # v6 -> v7: tower floor completions
    if v < 8:
        # v7 -> v8: skill books appear; each hero gets its starter skill and pending level
        # choices inside HeroData.from_dict (no stored data is lost or rerolled).
        data["skill_books"] = {}
    if v < 9:
        # v8 -> v9 (HQ Phase 1): new production buildings start at their default level, old storage
        # keeps its numbers (missing resources start at the default stock). Heroes get professions,
        # needs and beds inside HeroData.from_dict / assign_beds. Nothing is rerolled or removed.
        var tb9: Dictionary = (data.get("town_buildings", {}) as Dictionary).duplicate()
        for bid in TownTables.ids():
            if not tb9.has(bid):
                tb9[bid] = TownTables.pre_slice_start(bid)
        data["town_buildings"] = tb9
        var st9: Dictionary = (data.get("hq_outputs", {}) as Dictionary).duplicate()
        for res in START_STOCK:
            if not st9.has(res):
                st9[res] = int(START_STOCK[res])
        data["hq_outputs"] = st9
    if v < 10:
        # v9 -> v10 (D-056): floors gain a generator version, a full snapshot and explored cells. Floors
        # already saved stay generator 1 (rebuilt from their seed exactly as before, D-026); nothing rerolls.
        var tm: Dictionary = (data.get("tower_maps", {}) as Dictionary).duplicate(true)
        for k in tm:
            var e: Dictionary = tm[k]
            if not e.has("gen"):
                e["gen"] = 1
            if not e.has("explored"):
                e["explored"] = ""
        data["tower_maps"] = tm
        data["onboarded"] = true          # existing accounts never see the new-account welcome
    if v < 11:
        # v10 -> v11 (master prompt C/B): offline expeditions start empty with full charges
        data["expeditions"] = []
        data["exp_charges"] = ExpeditionDefs.CHARGES_MAX
        data["exp_charge_t"] = 0.0
        data["portal_upgrades"] = {}
    if v < 20:
        # v19 -> v20 (integration of pistas A/C/D + Sim Lab, task 03b): every new field gets its default and
        # the ranger ("explorador") becomes the archer. Pista C and the Sim Lab store nothing in the save.
        if not (data.get("synergy_codex") is Dictionary):
            data["synergy_codex"] = {}                     # D-090: discovered synergies
        for hd in data.get("heroes", []):
            if hd is Dictionary:
                _migrate_hero_v20(hd)
        for m in data.get("memorial", []):
            if m is Dictionary:
                if m.has("class"):
                    m["class"] = HeroTables.canonical_class(String(m["class"]))
                if m.get("snapshot") is Dictionary:
                    _migrate_hero_v20(m["snapshot"])
    if v < 19:
        data["kit_migration"] = 1         # v18 -> v19 (D-082b): the starter kit goes into empty slots on load
    if v < 18:
        pass                              # v17 -> v18 (D-081): Leadership, memories and bond (0 / [] / 30 on load); an elf Master becomes human; hardcore off
    if v < 17:
        pass                              # v16 -> v17 (D-080): heroes gain is_master/first_name/surname (false/""); a save without a Master opens the creator once, the roster stays
    if v < 16:
        pass                              # v15 -> v16 (D-079): heroes gain "innate" summon gifts; old heroes get [] on load (never rolled)
    if v < 15:
        pass                              # v14 -> v15: apprenticeship becomes {hours, progress}; aptitude_known (defaults {})
    if v < 14:
        pass                              # v13 -> v14: heroes gain "apprenticeship" (defaults to {} on load)
    if v < 13:
        # v12 -> v13 (overhaul LPC, D-A): every hero and memorial snapshot gets its LPC look from its
        # seed; the TPF look stays in "appearance" as the legacy one.
        for hd in data.get("heroes", []):
            if hd is Dictionary and not (hd as Dictionary).has("look"):
                hd["look"] = HeroGenerator.lpc_look(int(hd.get("hero_seed", 0)))
        for m in data.get("memorial", []):
            if m is Dictionary and m.has("snapshot") and not (m["snapshot"] as Dictionary).has("look"):
                m["snapshot"]["look"] = HeroGenerator.lpc_look(int(m["snapshot"].get("hero_seed", 0)))
    if v < 12:
        # v11 -> v12 (master prompt D, owner 2026-10-31): the tower changed hands (bandits, new missions,
        # threat budgets). Floors saved before keep their old creatures in the snapshot, so they are
        # generated again; what was cleared (tower_cleared) and the rewards stay.
        data["tower_maps"] = {}
    if v < 21:
        data["cheated"] = false           # v20 -> v21 (D-146): games saved before the dev console are clean
    data["version"] = SAVE_VERSION
    return data


# --- pista D (D-121..D-129): loot brought home, greed, books ---------------------------------------

## D-124: the squad is out of the tower (success or escape). packs = [{"hero": HeroData, "items": [...]}].
## Every pack goes to the Master's stash; a greedy hero may keep pieces back (D-125, hero.hoard) and the
## Master notices with LootDefs.GREEDY.discover. Items with no stash room are left in the tower.
## Returns {"items": [labels], "left_behind": n, "kept": n, "caught": [text]}.
func deliver_packs(packs: Array) -> Dictionary:
    var rep := {"items": [], "left_behind": 0, "kept": 0, "caught": []}
    for p in packs:
        var h: HeroData = p.get("hero")
        var split := LootService.greedy_split(h, p.get("items", []), rng)
        for it in split["given"]:
            if stash.size() >= stash_cap():
                rep["left_behind"] = int(rep["left_behind"]) + 1
                continue
            stash.append(it)
            (rep["items"] as Array).append(ItemDefs.item_label(it))
        for it in split["kept"]:
            var seen: bool = rng.randf() < float(LootDefs.GREEDY["discover"])
            it["caught"] = seen
            h.hoard.append(it)
            rep["kept"] = int(rep["kept"]) + 1
            if seen:
                var line := "%s tried to keep %s for themself." % [h.display_name(), String(it.get("name", "?"))]
                (rep["caught"] as Array).append(line)
                log_town(line)
    _commit()
    return rep


## D-125: heroes the Master caught hoarding loot.
func hoard_suspects() -> Array:
    return heroes.values().filter(func(h): return (h as HeroData).hoard.any(func(it): return bool(it.get("caught", false))))


## D-125: the Master searches a greedy hero: everything hoarded goes to the stash (room permitting) and
## the hero takes it badly (deterministic Trust/Obedience deltas). Returns how many items came back.
func confiscate_hoard(h: HeroData) -> int:
    if h == null or h.hoard.is_empty():
        return 0
    var back := 0
    var keep: Array = []
    for it in h.hoard:
        if stash.size() < stash_cap():
            it.erase("caught")
            stash.append(it)
            back += 1
        else:
            keep.append(it)
    h.hoard = keep
    h.add_event("loot_confiscated", {"items": back}, int(LootDefs.GREEDY["confiscate_trust"]), int(LootDefs.GREEDY["confiscate_obedience"]))
    _commit()
    return back


## D-129: uses a book from town storage. book_xp: one level; book_skill: +1 bonus skill choice;
## book_trade: +1 level in `prof` (a profession the hero knows; pista B points it at villagers);
## book_plan: Game.apply_master_plan when the town has it (pista B), else it stays in storage.
## "" on success, else why not (the book is not spent).
func use_book(book: String, h: HeroData, prof: String = "") -> String:
    if int(hq_outputs.get(book, 0)) <= 0:
        return "none in storage"
    match book:
        "book_xp":
            if h == null or h.is_max_level():
                return "already at the level cap"
            h.add_xp(maxi(1, h.xp_to_next() - h.xp))
        "book_skill":
            if h == null:
                return "choose a hero"
            h.bonus_skill_choice += 1
        "book_trade":
            if h == null or not h.knows_prof(prof):
                return "the hero has no such profession"
            if h.prof_level(prof) >= ProfessionDefs.MAX_LEVEL:
                return "already a master"
            var p: Dictionary = h.professions[prof]
            p["lvl"] = int(p["lvl"]) + 1
            p["xp"] = 0.0
        "book_plan":
            if not has_method("apply_master_plan"):
                return "kept: master plans unlock buildings when the town is ready for them"
            var why := String(call("apply_master_plan"))
            if why != "":
                return why
        _:
            return "not a book"
    hq_outputs[book] = int(hq_outputs[book]) - 1
    _commit()
    return ""
