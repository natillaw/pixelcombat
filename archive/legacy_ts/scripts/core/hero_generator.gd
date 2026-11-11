class_name HeroGenerator
extends RefCounted
## Turns (seed, stars) into a complete hero. Same seed + stars = same hero, always.
## Rarity shows up as MORE sprite layers (hat, held item, facial hair), fancier styles,
## more traits/passives and a higher level cap - all of it procedural.


const VERSION := 6   # 6 = no starting active (D-142: only Q). 1 = Drop A. 2 adds Trust/Obedience/Composure. 3 adds the starting active skill (D-044) and the first profession from the past life (D-049, no new rolls); look/class/traits are unchanged. 5 adds the summon gifts (D-079, own RNG)


static func generate(hero_seed: int, stars: int) -> HeroData:
	var rng := RandomNumberGenerator.new()
	rng.seed = hero_seed
	var h := HeroData.new()
	h.hero_seed = hero_seed
	h.id = "hero_%x" % hero_seed
	h.stars = clampi(stars, 1, HeroTables.MAX_STARS)
	var sd: Dictionary = HeroTables.STAR_DATA[h.stars]

	h.appearance = _make_appearance(rng, sd)       # v3 TPF look: kept as the legacy appearance
	h.look = lpc_look(hero_seed)
	h.hero_class = _roll_birth_class(rng, h.stars)
	h.hero_name = _make_name(rng)
	if h.stars == 4:
		h.epithet = String(_pick(rng, HeroTables.EPITHETS_4))
	elif h.stars == 5:
		h.epithet = String(_pick(rng, HeroTables.EPITHETS_5))
	h.traits = _roll_traits(rng, int(sd["traits"]), [])
	h.passives = _roll_passives(rng, h.traits, int(sd["passives"]), [])

	var bg: Dictionary = _pick(rng, HeroTables.BACKGROUNDS)
	h.background_id = String(bg["id"])
	h.background_text = String(bg["text"]).replace("{name}", h.hero_name.split(" ")[0])
	var prof_keys: Array = HeroTables.PROFESSIONS.keys()
	h.profession = String(prof_keys[rng.randi() % prof_keys.size()])

	for k in HeroTables.STAT_KEYS:
		h.variance[k] = rng.randf_range(0.92, 1.08)

	# Social state. The first roll is the same call the old loyalty used, so existing seeds keep
	# their looks, class, traits and Trust. Obedience is a NEW roll appended after everything else.
	var trust := 50 + rng.randi_range(-10, 10)
	var obedience := 50 + rng.randi_range(-8, 8)
	for t in h.traits:
		trust += int(HeroTables.TRAITS[t]["loyalty"])
		obedience += int(HeroTables.OBEDIENCE_MODS.get(t, 0))
	h.trust = clampi(trust, 0, 100)
	h.obedience = clampi(obedience, 0, 100)
	h.composure = 100
	h.innate = roll_gifts(hero_seed, h.stars)
	h.generator_version = VERSION
	h.ensure_skills()
	h.init_professions()
	return h


## Called by HeroData.promote(): newly reached stars unlock a class (3+), traits, passives.
static func apply_promotion(h: HeroData) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = h.hero_seed ^ (h.stars * 7919)
	var sd: Dictionary = HeroTables.STAR_DATA[h.stars]
	var pool: Array = HeroTables.PROMOTION_CLASS_POOL
	# F-007: the pool is empty until advanced classes are decided (P-07); never divide by zero.
	if h.hero_class == "class.none" and h.stars >= 3 and not pool.is_empty():
		h.hero_class = String(pool[rng.randi() % pool.size()])
	if h.traits.size() < int(sd["traits"]):
		h.traits = _roll_traits(rng, int(sd["traits"]), h.traits)
	if h.passives.size() < int(sd["passives"]):
		h.passives = _roll_passives(rng, h.traits, int(sd["passives"]), h.passives)


# --- appearance -------------------------------------------------------------

static func _make_appearance(rng: RandomNumberGenerator, sd: Dictionary) -> Dictionary:
	var rolls: int = int(sd["style_rolls"])
	var hair_color := rng.randi_range(1, 5)
	var a := {}
	a["body"] = "Body/%d" % rng.randi_range(1, 5)
	a["eyes"] = "Eyes/%d" % rng.randi_range(1, 4)
	a["rear_hair"] = _styled(rng, "rear_hair", hair_color, rolls) if rng.randf() < 0.85 else ""
	a["front_hair"] = _styled(rng, "front_hair", hair_color, rolls) if rng.randf() < 0.92 else ""
	a["facial_hair"] = _styled(rng, "facial_hair", hair_color, 1) if rng.randf() < float(sd["facial"]) else ""
	a["top"] = _styled(rng, "top", rng.randi_range(1, 5), rolls)
	a["bottom"] = _styled(rng, "bottom", rng.randi_range(1, 5), rolls)
	a["shoes"] = "Bottom/Shoes_Layer"
	a["hat"] = _styled(rng, "hat", rng.randi_range(1, 5), rolls) if rng.randf() < float(sd["hat"]) else ""
	var held_styles: Array = HeroTables.HELD_STYLES
	var held_roll := rng.randf()
	var held_style: int = int(held_styles[rng.randi() % held_styles.size()])
	a["held"] = ("Held_Item/%d" % held_style) if held_roll < float(sd["held"]) else ""
	return a


static func _styled(rng: RandomNumberGenerator, key: String, color: int, rolls: int) -> String:
	var d: Dictionary = HeroTables.LAYER_DEFS[key]
	var styles: Array = d["styles"]
	var best: int = int(styles[rng.randi() % styles.size()])
	for i in range(rolls - 1):
		best = maxi(best, int(styles[rng.randi() % styles.size()]))
	return "%s/%d_%d" % [d["folder"], best, color]


# --- class / name / traits ---------------------------------------------------

static func _roll_birth_class(rng: RandomNumberGenerator, _stars: int) -> String:
	return _weighted(rng, HeroTables.BIRTH_CLASS_WEIGHTS)


static func _make_name(rng: RandomNumberGenerator) -> String:
	var first: String = String(_pick(rng, HeroTables.NAME_START)) + String(_pick(rng, HeroTables.NAME_END))
	return "%s %s" % [first, _pick(rng, HeroTables.FAMILY_NAMES)]


static func _roll_traits(rng: RandomNumberGenerator, count: int, existing: Array) -> Array:
	var pool: Array = HeroTables.TRAITS.keys()
	var chosen: Array = existing.duplicate()
	var guard := 0
	while chosen.size() < count and guard < 200:
		guard += 1
		var t: String = String(pool[rng.randi() % pool.size()])
		if chosen.has(t) or _conflicts(t, chosen):
			continue
		chosen.append(t)
	return chosen


static func _conflicts(t: String, chosen: Array) -> bool:
	for pair in HeroTables.TRAIT_CONFLICTS:
		if pair[0] == t and chosen.has(pair[1]):
			return true
		if pair[1] == t and chosen.has(pair[0]):
			return true
	return false


static func _roll_passives(rng: RandomNumberGenerator, traits: Array, count: int, existing: Array) -> Array:
	var out: Array = existing.duplicate()
	var candidates: Array = []
	for t in traits:
		var p: String = String(HeroTables.TRAITS[t]["passive"])
		if not candidates.has(p):
			candidates.append(p)
	_shuffle(rng, candidates)
	for p in candidates:
		if out.size() >= count:
			break
		if not out.has(p):
			out.append(p)
	var pool: Array = HeroTables.PASSIVES.keys()
	var guard := 0
	while out.size() < count and guard < 200:
		guard += 1
		var p2: String = String(pool[rng.randi() % pool.size()])
		if not out.has(p2):
			out.append(p2)
	return out


# --- small helpers -------------------------------------------------------------

static func _pick(rng: RandomNumberGenerator, arr: Array) -> Variant:
	return arr[rng.randi() % arr.size()]


static func _weighted(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := rng.randf() * total
	for k in weights:
		r -= float(weights[k])
		if r <= 0.0:
			return String(k)
	return String(weights.keys()[0])


static func _shuffle(rng: RandomNumberGenerator, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := int(rng.randi() % (i + 1))
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## Overhaul LPC (v4): the LPC look comes from its own RNG (hero_seed ^ 0x4C5043), so name, class,
## traits, passives and Trust of every old seed stay exactly as they were (tests/test_hero_fixture.gd).
static func lpc_look(hero_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hero_seed ^ 0x4C5043
	var total := 0
	for r in SummonConfig.RACE_WEIGHTS:
		total += int(SummonConfig.RACE_WEIGHTS[r])
	var roll := rng.randi() % maxi(1, total)
	var race := "human"
	for r in SummonConfig.RACE_WEIGHTS:
		roll -= int(SummonConfig.RACE_WEIGHTS[r])
		if roll < 0:
			race = String(r)
			break
	return LpcWardrobe.random_look(rng, race)


## D-079 summon gifts: from their own RNG (hero_seed ^ 0x47494654), so every other roll of an old seed stays
## the same. One combat gift with PowerDefs.GIFT_CHANCE by stars (a 5-star may get a second), and one
## trade gift with TRADE_GIFT_CHANCE. Rolled only at the summon: promotions never add gifts.
static func roll_gifts(hero_seed: int, stars: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hero_seed ^ 0x47494654
	var combat: Array = []
	var trade: Array = []
	for g in PowerDefs.GIFTS:
		if String(PowerDefs.GIFTS[g]["kind"]) == "combat":
			combat.append(g)
		else:
			trade.append(g)
	combat.sort()
	trade.sort()
	var out: Array = []
	var s := clampi(stars, 1, 5)
	if rng.randf() < float(PowerDefs.GIFT_CHANCE[s]):
		out.append(String(combat[rng.randi() % combat.size()]))
		if s == 5 and rng.randf() < PowerDefs.GIFT_SECOND_5:
			var rest: Array = combat.filter(func(x): return not out.has(x))
			out.append(String(rest[rng.randi() % rest.size()]))
	if rng.randf() < float(PowerDefs.TRADE_GIFT_CHANCE[s]):
		out.append(String(trade[rng.randi() % trade.size()]))
	return out


## D-080: the Master from the character creator. Same pipeline as a summon (generate) at MasterDefs.STARS,
## then the player's choices replace name, look, class and traits. choices = {"first", "last", "look",
## "class", "trait"}. Starts in the plain starter outfit like every summon (LpcWardrobe.STARTER_OUTFIT).
static func create_master(hero_seed: int, choices: Dictionary) -> HeroData:
	var h := generate(hero_seed, MasterDefs.STARS)
	h.is_master = true
	h.first_name = String(choices.get("first", "")).strip_edges().left(MasterDefs.NAME_MAX)
	h.surname = String(choices.get("last", "")).strip_edges().left(MasterDefs.NAME_MAX)
	h.hero_name = "%s %s" % [h.first_name, h.surname]
	h.epithet = ""
	var look: Dictionary = h.look.duplicate()
	for k in (choices.get("look", {}) as Dictionary):
		look[k] = choices["look"][k]
	h.look = master_look(look)
	var cls := String(choices.get("class", "class.warrior"))
	h.hero_class = cls if MasterDefs.CLASSES.has(cls) else "class.warrior"
	var t := String(choices.get("trait", ""))
	h.traits = [t] if HeroTables.TRAITS.has(t) else _roll_traits(_rng_for(hero_seed), 1, [])
	h.passives = _roll_passives(_rng_for(hero_seed), h.traits, int(HeroTables.STAR_DATA[h.stars]["passives"]), [])
	h.background_id = MasterDefs.BACKGROUND_ID
	h.background_text = MasterDefs.BACKGROUND_TEXT
	h.innate = []                                  # gifts come from the summoning circle; the Master was not summoned
	h.trust = MasterDefs.TRUST
	h.obedience = MasterDefs.OBEDIENCE
	h.skills = []
	h.loadout = []
	h.ensure_skills()                              # D-142: no starter, only Q
	return h


## The parts of a look that follow from the others (same rules as LpcWardrobe.random_look): the head
## of the body, elven ears for elves, beards only on male bodies. The creator's preview uses it too.
static func master_look(look: Dictionary) -> Dictionary:
	var out := look.duplicate()
	out["head"] = "head_human_" + String(out.get("body", "male"))
	out["ears"] = "ears_elven" if String(out.get("race", "human")) == "elf" else ""
	if String(out.get("body", "male")) != "male":
		out["beard"] = ""
	return out


static func _rng_for(hero_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hero_seed ^ 0x4D4153
	return rng
