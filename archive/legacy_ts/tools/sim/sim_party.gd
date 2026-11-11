extends RefCounted
## D-083: builds the simulated account for one run: a fresh game (Game.new_game), the Master and the
## heroes of the config's "party" (class, level, stars or rarity, traits, attributes, skills) and their
## gear (a preset of tools/sim/configs/gear_presets.json and/or a list of real ItemDefs items). The same
## party_seed / gear_seed give the same heroes and the same random item properties in every run.

const PRESETS_PATH := "res://tools/sim/configs/gear_presets.json"
const PROGRESS_PATH := "res://tools/sim/configs/progress_profiles.json"
const SimConfig := preload("res://tools/sim/sim_config.gd")

## What an automatic preset puts in each slot, by class (only bases that exist in ItemDefs.BASES).
const AUTO_BASES := {
    "class.warrior": {"main_hand": "sword", "off_hand": "shield", "head": "helm", "chest": "mail"},
    # pista D (D-126): armour by class (plate warrior, leather rogue/archer, cloth mage/cleric)
    "class.cleric": {"main_hand": "mace", "off_hand": "shield", "head": "hood", "chest": "robe", "legs": "cloth_pants", "feet": "sandals"},
    "class.commoner": {"main_hand": "sword", "off_hand": "shield", "head": "leather_cap", "chest": "leather_vest", "legs": "leather_pants"},
    "class.rogue": {"main_hand": "dagger", "head": "leather_cap", "chest": "leather_vest", "legs": "leather_pants"},
    "class.archer": {"main_hand": "bow", "head": "leather_cap", "chest": "leather_vest", "legs": "leather_pants"},
    "class.mage": {"main_hand": "staff", "head": "hood", "chest": "robe", "legs": "cloth_pants", "feet": "sandals"},
}
const AUTO_COMMON := {"hands": "gloves", "legs": "greaves", "feet": "boots", "amulet": "amulet", "ring1": "ring", "ring2": "ring", "special": "charm"}
const MASTER_LOOK := {"race": "human", "body": "male", "skin": "light", "eyes": "blue", "hair": "hair_plain", "hair_color": "black", "beard": ""}


static func class_id(s: String) -> String:
    s = s.strip_edges().to_lower()
    var alias := {"guerrero": "warrior", "picaro": "rogue", "pícaro": "rogue", "arquero": "archer", "explorador": "archer",
        "ranger": "archer", "mago": "mage", "clerigo": "cleric", "clérigo": "cleric", "healer": "cleric", "plebeyo": "commoner"}
    s = String(alias.get(s, s))
    return HeroTables.canonical_class(s if s.begins_with("class.") else "class." + s)   # 03b: class.ranger -> class.archer


static func trait_id(s: String) -> String:
    return s if s.begins_with("trait.") else "trait." + s


static func load_presets() -> Dictionary:
    var r := SimConfig.load_file(PRESETS_PATH)
    return r.get("data", {})


## Checks every id in the party against the game's tables. Returns the list of problems.
static func validate(cfg: Dictionary, presets: Dictionary) -> Array:
    var errors: Array = []
    var masters := 0
    for i in (cfg["party"] as Array).size():
        var spec: Dictionary = cfg["party"][i]
        var where := "party[%d]" % i
        var cls := class_id(String(spec.get("class", "warrior")))
        var is_master := bool(spec.get("master", false))
        masters += 1 if is_master else 0
        if not HeroTables.CLASSES.has(cls):
            errors.append("%s: class \"%s\" does not exist (%s)" % [where, spec.get("class"), ", ".join(HeroTables.CLASSES.keys())])
        elif is_master and not MasterDefs.CLASSES.has(cls):
            errors.append("%s: the Master cannot be %s (%s)" % [where, cls, str(MasterDefs.CLASSES)])
        if spec.has("rarity") and not SimConfig.RARITY_STARS.has(String(spec["rarity"]).to_lower()):
            errors.append("%s: rarity \"%s\" does not exist (%s)" % [where, spec["rarity"], ", ".join(SimConfig.RARITY_STARS.keys())])
        if spec.has("stars") and (int(spec["stars"]) < 1 or int(spec["stars"]) > HeroTables.MAX_STARS):
            errors.append("%s: stars must be 1-%d" % [where, HeroTables.MAX_STARS])
        for t in spec.get("traits", []):
            if not HeroTables.TRAITS.has(trait_id(String(t))):
                errors.append("%s: trait \"%s\" does not exist" % [where, t])
        for p in spec.get("passives", []):
            if not HeroTables.PASSIVES.has(String(p)):
                errors.append("%s: passive \"%s\" does not exist" % [where, p])
        for a in (spec.get("attrs", {}) as Dictionary):
            if not HeroTables.ATTR_KEYS.has(String(a)):
                errors.append("%s: attribute \"%s\" does not exist (%s)" % [where, a, ", ".join(HeroTables.ATTR_KEYS)])
        for sk in spec.get("skills", []):
            if not SkillDefs.SKILLS.has(String(sk)):
                errors.append("%s: skill \"%s\" does not exist" % [where, sk])
            elif HeroTables.CLASSES.has(cls) and not SkillDefs.usable_by(String(sk), cls):
                errors.append("%s: skill \"%s\" is not for %s" % [where, sk, cls])
        errors.append_array(_validate_gear(spec.get("gear", "kit_blanco"), presets, where))
    if masters > 1:
        errors.append("party: only one hero can be the Master")
    if (cfg["party"] as Array).is_empty():
        errors.append("party: empty")
    return errors


static func _validate_gear(gear: Variant, presets: Dictionary, where: String) -> Array:
    var errors: Array = []
    var items: Array = []
    if gear is String:
        if not presets.has(gear):
            errors.append("%s: gear preset \"%s\" does not exist (%s)" % [where, gear, ", ".join(presets.keys())])
        else:
            items = presets[gear].get("items", [])
    elif gear is Dictionary:
        if gear.has("preset") and not presets.has(String(gear["preset"])):
            errors.append("%s: gear preset \"%s\" does not exist" % [where, gear["preset"]])
        items = gear.get("items", [])
    elif gear is Array:
        items = gear
    for it in items:
        if not (it is Dictionary) or not ItemDefs.BASES.has(String(it.get("base", ""))):
            errors.append("%s: item \"%s\" does not exist in ItemDefs.BASES" % [where, str(it.get("base", it) if it is Dictionary else it)])
        elif it.has("rarity") and not ItemDefs.RARITIES.has(String(it["rarity"])):
            errors.append("%s: item rarity \"%s\" does not exist (%s)" % [where, it["rarity"], ", ".join(ItemDefs.RARITY_ORDER)])
    return errors


## Fresh account + party for one run. "" on success, else the problem.
static func build(cfg: Dictionary, run_seed: int, presets: Dictionary) -> String:
    Game.autosave = false
    Game.save_path = "user://sim_%d.json" % OS.get_process_id()
    Game.new_game()
    Game.onboarded = true
    Game.rng.seed = run_seed
    var party: Array = cfg["party"]
    var master_i := -1
    for i in party.size():
        if bool(party[i].get("master", false)):
            master_i = i
    var gear_rng := RandomNumberGenerator.new()
    var slot := 1
    var order: Array = []
    if master_i >= 0:
        order.append(master_i)
    for i in party.size():
        if i != master_i:
            order.append(i)
    for i in order:
        var spec: Dictionary = party[i]
        var h_seed := int(spec.get("seed", hash([int(cfg["party_seed"]), i])))
        var h := _make_hero(spec, h_seed, i == master_i)
        if h == null:
            return "party[%d]: could not build the hero" % i
        Game.heroes[h.id] = h
        if i != master_i:
            if slot >= Game.PARTY_SIZE:
                return "party: at most %d heroes" % Game.PARTY_SIZE
            Game.party[slot] = h.id
            slot += 1
        gear_rng.seed = hash([int(cfg["gear_seed"]), i])
        var err := _equip(h, spec.get("gear", "kit_blanco"), presets, gear_rng)
        if err != "":
            return "party[%d] gear: %s" % [i, err]
    if master_i < 0:                              # no Master: the heroes fill the slots from 1
        var ids: Array = []
        for id in Game.party:
            if id != "":
                ids.append(id)
        Game.party = ["", "", "", "", ""]
        for k in ids.size():
            Game.party[k] = ids[k]
    Game.rng.seed = run_seed                       # the run's own rolls start from the same point
    return ""


static func _make_hero(spec: Dictionary, h_seed: int, is_master: bool) -> HeroData:
    var cls := class_id(String(spec.get("class", "warrior")))
    var stars := int(spec.get("stars", SimConfig.RARITY_STARS.get(String(spec.get("rarity", "")).to_lower(), 2)))
    var h: HeroData
    if is_master:
        var traits: Array = spec.get("traits", [])
        h = HeroGenerator.create_master(h_seed, {"first": String(spec.get("name", "Sim")), "last": "Master", "class": cls,
            "trait": trait_id(String(traits[0])) if not traits.is_empty() else "", "look": MASTER_LOOK})
        Game.party[0] = h.id
    else:
        h = HeroGenerator.generate(h_seed, stars)
        if String(spec.get("name", "")) != "":
            h.hero_name = String(spec["name"])
        if h.hero_class != cls:
            h.hero_class = cls
            h.skills = []
            h.loadout = []
            h.skill_choices = []
            h.ensure_skills()
    if spec.has("traits"):
        h.traits = (spec["traits"] as Array).map(func(t): return trait_id(String(t)))
        if not spec.has("passives"):
            h.passives = HeroGenerator._roll_passives(HeroGenerator._rng_for(h_seed), h.traits, int(HeroTables.STAR_DATA[h.stars]["passives"]), [])
    if spec.has("passives"):
        h.passives = (spec["passives"] as Array).duplicate()
    var lvl := clampi(int(spec.get("level", 1)), 1, h.level_cap())
    if lvl > h.level:
        var from := h.level
        h.level = lvl
        h._queue_skill_choices(from, lvl)
    if spec.has("skills"):
        h.skills = []
        h.loadout = []
        h.skill_choices = []
        for sk in spec["skills"]:
            h.learn_skill(String(sk), false)
        h.ensure_skills()
    else:
        while not h.skill_choices.is_empty():   # level choices: the first option, always (deterministic)
            if not h.choose_skill(0, String(h.skill_choices[0]["options"][0])):
                h.skill_choices.remove_at(0)
    var want: Dictionary = spec.get("attrs", {})
    if not want.is_empty():
        h.synth_bonus = {}
        var base := h.attributes()
        for k in want:
            h.synth_bonus[String(k)] = int(want[k]) - int(base[String(k)])
    return h


## preset name | {"preset": name, "items": [...]} | [items]. Items: {"base", "rarity", "ilvl", "slot",
## "stats": {fixed values}, "affixes": [] to clear}. Presets: {"starter": bool, "rarity", "ilvl", "slots",
## "bases": {slot: base}, "items": [...]}.
static func _equip(h: HeroData, gear: Variant, presets: Dictionary, rng: RandomNumberGenerator) -> String:
    var preset: Dictionary = {}
    var items: Array = []
    if gear is String:
        preset = presets.get(gear, {})
    elif gear is Dictionary:
        preset = presets.get(String(gear.get("preset", "")), {})
        items = gear.get("items", [])
    elif gear is Array:
        items = gear
        preset = {"starter": false}
    if bool(preset.get("starter", true)):
        Game.give_kit(h)
    var auto: Array = []
    var bases: Dictionary = AUTO_BASES.get(h.hero_class, AUTO_BASES["class.warrior"]).duplicate()
    bases.merge(AUTO_COMMON)
    bases.merge(preset.get("bases", {}), true)
    for s in preset.get("slots", []):
        if bases.has(String(s)):
            auto.append({"base": bases[String(s)], "slot": String(s), "rarity": preset.get("rarity", "common"), "ilvl": preset.get("ilvl", 1)})
    auto.append_array(preset.get("items", []))
    auto.append_array(items)
    for spec in auto:
        var base := String(spec["base"])
        if not ItemDefs.base_open(base):
            continue                                 # a slot the game has not opened yet (D-060)
        var it := ItemGen.generate(rng, Game._next_uid(), int(spec.get("ilvl", preset.get("ilvl", 1))), String(spec.get("rarity", preset.get("rarity", "common"))), base)
        if spec.has("stats"):
            (it["stats"] as Dictionary).merge(spec["stats"], true)
        if spec.has("affixes") and (spec["affixes"] as Array).is_empty():
            it["affixes"] = []
        Game.stash.append(it)
        var why := Game.equip(h, int(it["uid"]), String(spec.get("slot", "")))
        var own := String(AUTO_BASES.get(h.hero_class, {}).get(String(spec.get("slot", "")), ""))
        if why != "" and ItemLibrary.armor_of(it) != "" and own != "" and own != base:   # D-126: the class's own armour instead
            Game.stash.remove_at(Game.stash_index(int(it["uid"])))
            it = ItemGen.generate(rng, Game._next_uid(), int(spec.get("ilvl", preset.get("ilvl", 1))), String(spec.get("rarity", preset.get("rarity", "common"))), own)
            Game.stash.append(it)
            why = Game.equip(h, int(it["uid"]), String(spec.get("slot", "")))
        if why != "":
            Game.stash.remove_at(Game.stash_index(int(it["uid"])))
            if spec in items or spec in (preset.get("items", []) as Array):
                return "%s cannot be equipped on %s: %s" % [base, h.hero_class, why]
    Game.stash.clear()                               # what was replaced does not count as loot
    return ""


static func load_progress() -> Dictionary:
    return SimConfig.load_file(PROGRESS_PATH).get("data", {})


## D-084: with "progress" set, every hero gets the level and the gear tier that profile gives for this
## floor (gear_style picks the tierN_def / tierN_atk flavour). Without it the party is used as written.
static func with_progress(cfg: Dictionary, floor_num: int) -> Dictionary:
    var prof := String(cfg.get("progress", ""))
    if prof == "":
        return cfg
    var p: Dictionary = load_progress().get(prof, {})
    var out: Dictionary = cfg.duplicate(true)
    var i := clampi(floor_num, 1, 10) - 1
    var lvl := int(p["levels"][i])
    var gear := String(p["gear"][i])
    var style := String(cfg.get("gear_style", "mix"))
    if gear != "kit_blanco" and style != "mix":
        gear = "%s_%s" % [gear, style]
    for h in out["party"]:
        h["level"] = lvl
        h["gear"] = gear
    return out


static func validate_progress(cfg: Dictionary, presets: Dictionary) -> Array:
    var prof := String(cfg.get("progress", ""))
    if prof == "":
        return []
    var all := load_progress()
    if not all.has(prof):
        return ["progress \"%s\" does not exist (%s)" % [prof, ", ".join(all.keys().filter(func(k): return not String(k).begins_with("_")))]]
    var errors: Array = []
    var style := String(cfg.get("gear_style", "mix"))
    if not style in ["mix", "def", "atk"]:
        errors.append("gear_style must be mix, def or atk")
    for g in all[prof]["gear"]:
        var name := String(g) if g == "kit_blanco" or style == "mix" else "%s_%s" % [g, style]
        if not presets.has(name):
            errors.append("progress %s: gear preset %s does not exist" % [prof, name])
    return errors
