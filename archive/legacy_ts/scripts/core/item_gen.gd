class_name ItemGen
extends RefCounted
## Procedural equipment (Diablo-like principles, own data): base + rarity + affixes within ranges,
## uniques and set pieces. Deterministic for a given RNG state. `uid` must be unique per save.

## Rarity roll: deeper floors and better sources shift weight to the rare end. floor_bonus: boss = 3.
static func roll_rarity(rng: RandomNumberGenerator, ilvl: int, source_bonus: float = 0.0, min_rarity: String = "common") -> String:
    var total := 0.0
    var weights := {}
    var start := ItemDefs.RARITY_ORDER.find(min_rarity)
    for i in ItemDefs.RARITY_ORDER.size():
        if i < start:
            continue
        var r: String = ItemDefs.RARITY_ORDER[i]
        var w := float(ItemDefs.RARITIES[r]["weight"])
        if i >= 2:
            w *= 1.0 + 0.12 * float(ilvl) + source_bonus
        weights[r] = w
        total += w
    var roll := rng.randf() * total
    for r in weights:
        roll -= float(weights[r])
        if roll <= 0.0:
            return r
    return ItemDefs.RARITY_ORDER[start]


## Makes one item. base_id "" = random base (of kind when given). Set pieces: SET_CHANCE on rare/epic.
const SET_CHANCE := 0.15
static func generate(rng: RandomNumberGenerator, uid: int, ilvl: int, rarity: String, base_id: String = "", kind: String = "") -> Dictionary:
    ilvl = maxi(1, ilvl)
    var rd: Dictionary = ItemDefs.RARITIES[rarity]
    var unique_id := ""
    if rd.get("unique", false) and base_id == "":
        var uk: Array = ItemDefs.UNIQUES.keys()
        uk.sort()
        unique_id = String(uk[rng.randi() % uk.size()])
        base_id = String(ItemDefs.UNIQUES[unique_id]["base"])
    if base_id == "":
        var pool: Array = []
        for b in ItemDefs.BASES:
            if (kind == "" or String(ItemDefs.BASES[b]["kind"]) == kind) and ItemDefs.base_droppable(String(b)):   # bags: only crafted
                pool.append(b)
        pool.sort()
        base_id = String(pool[rng.randi() % pool.size()])
    var base: Dictionary = ItemDefs.BASES[base_id]
    var scale := (1.0 + ItemDefs.PER_ILVL * float(ilvl - 1)) * float(rd["mult"])
    var stats := {}
    for k in base["stats"]:
        var v := float(base["stats"][k])
        stats[k] = roundi(v * scale) if ItemDefs.SCALING_STATS.has(k) else snappedf(v * float(rd["mult"]), 0.01)
    var item := {"uid": uid, "base": base_id, "name": String(base["name"]), "rarity": rarity, "ilvl": ilvl,
        "stats": stats, "affixes": [], "power": {}, "unique": "", "set": ""}
    if unique_id != "":
        var u: Dictionary = ItemDefs.UNIQUES[unique_id]
        item["unique"] = unique_id
        item["name"] = String(u["name"])
        var pw: Dictionary = (u["power"] as Dictionary).duplicate()
        if rarity == "mythic":
            for k in pw:
                if typeof(pw[k]) == TYPE_FLOAT and k != "chance" and k != "dur":
                    pw[k] = snappedf(float(pw[k]) * ItemDefs.MYTHIC_POWER, 0.01)
            item["name"] = "Mythic " + String(u["name"])
        item["power"] = pw
    elif (rarity == "rare" or rarity == "epic") and rng.randf() < SET_CHANCE:
        for st in ItemDefs.SETS:
            if (ItemDefs.SETS[st]["pieces"] as Dictionary).has(base_id):
                item["set"] = st
                item["name"] = String(ItemDefs.SETS[st]["pieces"][base_id])
    _roll_affixes(rng, item, int(rd["affixes"]), String(base["kind"]), ilvl)
    if item["unique"] == "" and item["set"] == "" and not (item["affixes"] as Array).is_empty():
        var an := String(ItemDefs.AFFIXES[String(item["affixes"][0]["id"])]["name"])
        item["name"] = ("%s %s" % [item["name"], an]) if an.begins_with("of ") else ("%s %s" % [an, item["name"]])
    return item


## D-082b: one white starter item (no affixes, item level 1, the base's own minimum stats).
static func starter(base_id: String, uid: int) -> Dictionary:
    var base: Dictionary = ItemDefs.BASES[base_id]
    var it := {"uid": uid, "base": base_id, "name": String(base["name"]), "rarity": "common", "ilvl": 1,
        "stats": (base["stats"] as Dictionary).duplicate(), "affixes": [], "power": {}, "unique": "", "set": "", "source": "starter"}
    if base.has("visual_base"):
        it["visual_base"] = String(base["visual_base"])
    return it


## D-077 drop: a base from the enemy family's theme, named after it ("Cutthroat's Dagger").
static func generate_drop(rng: RandomNumberGenerator, uid: int, ilvl: int, rarity: String, theme: String) -> Dictionary:
    var th: Dictionary = ItemLibrary.THEMES.get(theme, ItemLibrary.THEMES["beast"])
    var bases: Array = (th["bases"] as Array).filter(func(b): return ItemDefs.base_droppable(String(b)))
    var item := generate(rng, uid, ilvl, rarity, String(bases[rng.randi() % bases.size()]) if not bases.is_empty() else "")
    if String(item["unique"]) == "" and String(item["set"]) == "":
        var word := String(th["names"][rng.randi() % (th["names"] as Array).size()])
        item["name"] = "%s %s" % [word, ItemDefs.BASES[String(item["base"])]["name"]]
        if not (item["affixes"] as Array).is_empty():
            var an := String(ItemDefs.AFFIXES.get(String(item["affixes"][0]["id"]), {}).get("name", ""))
            if an.begins_with("of "):
                item["name"] = "%s %s" % [item["name"], an]
    item["source"] = "drop"
    item["theme"] = theme
    return item


## D-123 grey junk: a worn-out piece of the theme ("Rusty Sword"); never worn, salvaged into materials.
const JUNK_WORDS := {"weapon": ["Rusty", "Chipped", "Bent"], "armor": ["Torn", "Rotten", "Cracked"], "jewel": ["Tarnished", "Dull"]}
static func generate_junk(rng: RandomNumberGenerator, uid: int, ilvl: int, theme: String) -> Dictionary:
    var th: Dictionary = ItemLibrary.THEMES.get(theme, ItemLibrary.THEMES["beast"])
    var bases: Array = (th["bases"] as Array).filter(func(b): return ItemDefs.base_droppable(String(b)))
    var item := generate(rng, uid, ilvl, "junk", String(bases[rng.randi() % bases.size()]) if not bases.is_empty() else "")
    var words: Array = JUNK_WORDS.get(String(ItemDefs.BASES[String(item["base"])]["kind"]), ["Worn"])
    item["name"] = "%s %s" % [String(words[rng.randi() % words.size()]), ItemDefs.BASES[String(item["base"])]["name"]]
    item["source"] = "drop"
    item["theme"] = theme
    return item


## D-077 crafted: the line's clean piece of a tier, at most rare, one chosen affix (affix_id, or the
## first rolled), a smith set for armour pieces.
static func generate_crafted(rng: RandomNumberGenerator, uid: int, rid: String, rarity: String, affix_id: String = "") -> Dictionary:
    var r: Dictionary = ItemLibrary.recipes()[rid]
    var tier := int(r["tier"])
    if ItemDefs.RARITY_ORDER.find(rarity) > ItemDefs.RARITY_ORDER.find(ItemLibrary.CRAFT_MAX_RARITY):
        rarity = ItemLibrary.CRAFT_MAX_RARITY
    var item := generate(rng, uid, int(ItemLibrary.TIERS[tier]["ilvl"]), rarity, String(r["craft"]))
    item["affixes"] = []
    var kind := String(ItemDefs.BASES[String(r["craft"])]["kind"])
    var pool := ItemDefs.AFFIXES.keys().filter(func(a): return (ItemDefs.AFFIXES[a]["kinds"] as Array).has(kind))
    if (affix_id == "" or not ItemDefs.AFFIXES.has(affix_id)) and not pool.is_empty():
        pool.sort()
        affix_id = String(pool[rng.randi() % pool.size()])
    if ItemDefs.AFFIXES.has(affix_id):                          # D-124: bags take no property
        var a: Dictionary = ItemDefs.AFFIXES[affix_id]
        var v := lerpf(float(a["min"]), float(a["max"]), 0.5 + 0.15 * float(ItemDefs.RARITY_ORDER.find(rarity)))
        if ItemDefs.SCALING_STATS.has(String(a["stat"])):
            v = float(roundi(v * (1.0 + ItemDefs.PER_ILVL * float(int(item["ilvl"]) - 1))))
        item["affixes"] = [{"id": affix_id, "stat": String(a["stat"]), "value": snappedf(v, 0.01)}]
    item["name"] = String(r["name"])
    item["metal"] = String(ItemLibrary.TIERS[tier]["metal"])
    item["source"] = "craft"
    item["set"] = ""
    if String(r["line"]) == "blacksmith" and ItemLibrary.SET_PIECES.has(String(r["craft"])):
        item["set"] = "smith_t%d" % tier
    return item


## Three affix choices a crafter offers for a recipe (deterministic per recipe and day).
static func craft_affix_choices(rid: String, day: int) -> Array:
    var r: Dictionary = ItemLibrary.recipes()[rid]
    var kind := String(ItemDefs.BASES[String(r["craft"])]["kind"])
    var pool := ItemDefs.AFFIXES.keys().filter(func(a): return (ItemDefs.AFFIXES[a]["kinds"] as Array).has(kind))
    pool.sort()
    var rng := RandomNumberGenerator.new()
    rng.seed = hash("%s:%d" % [rid, day])
    var out: Array = []
    while out.size() < mini(ItemLibrary.CRAFT_AFFIX_CHOICES, pool.size()):
        out.append(pool.pop_at(rng.randi() % pool.size()))
    return out


static func _roll_affixes(rng: RandomNumberGenerator, item: Dictionary, count: int, kind: String, ilvl: int) -> void:
    var pool: Array = []
    for a in ItemDefs.AFFIXES:
        if (ItemDefs.AFFIXES[a]["kinds"] as Array).has(kind):
            pool.append(a)
    pool.sort()
    var groups := {}
    var scale := 1.0 + ItemDefs.PER_ILVL * float(ilvl - 1)
    while count > 0 and not pool.is_empty():
        var id := String(pool.pop_at(rng.randi() % pool.size()))
        var a: Dictionary = ItemDefs.AFFIXES[id]
        if groups.has(a["group"]):
            continue
        groups[a["group"]] = true
        var v := rng.randf_range(float(a["min"]), float(a["max"])) * float(ItemDefs.RARITIES.get(String(item.get("rarity", "common")), {}).get("quality", 1.0))   # D-122
        if ItemDefs.SCALING_STATS.has(String(a["stat"])):
            v = float(roundi(v * scale))
        else:
            v = snappedf(v, 0.01)
        (item["affixes"] as Array).append({"id": id, "stat": String(a["stat"]), "value": v})
        count -= 1
    # D-077: a cursed affix on some non-common pieces, always paired with a boosted good one
    if not (item["affixes"] as Array).is_empty() and String(item.get("rarity", "common")) != "common" and rng.randf() < ItemLibrary.CURSE_CHANCE:
        var good: Dictionary = item["affixes"][0]
        good["value"] = snappedf(float(good["value"]) * ItemLibrary.CURSE_BOOST, 0.01)
        var ck: Array = ItemLibrary.CURSES.keys()
        ck.sort()
        var cid := String(ck[rng.randi() % ck.size()])
        var c: Dictionary = ItemLibrary.CURSES[cid]
        (item["affixes"] as Array).append({"id": cid, "stat": String(c["stat"]), "value": snappedf(rng.randf_range(float(c["min"]), float(c["max"])), 0.01), "cursed": true})


## Crafted item (blacksmith): rarity comes from the smith's level and the forge level, with a small
## controlled luck. A high forge with an apprentice cannot make masterpieces (and the reverse).
static func craft_rarity(rng: RandomNumberGenerator, prof_level: int, building_level: int) -> String:
    var score := minf(float(prof_level) * 1.5, float(building_level) * 3.0) + float(rng.randi_range(-1, 1))
    if score >= 12.0:
        return "epic"
    if score >= 7.0:
        return "rare"
    if score >= 3.0:
        return "uncommon"
    return "common"


## One-line description of the item's numbers for the UI.
static func describe(item: Dictionary) -> String:
    var parts: Array = []
    for k in item.get("stats", {}):
        parts.append("%s %s" % [_fmt(String(k), float(item["stats"][k])), k])
    for a in item.get("affixes", []):
        parts.append("%s %s" % [_fmt(String(a["stat"]), float(a["value"])), a["stat"]])
    if String(item.get("unique", "")) != "":
        parts.append(String(ItemDefs.UNIQUES[String(item["unique"])]["desc"]))
    var proc := ItemDefs.proc_text(String(item.get("base", "")))
    if proc != "":
        parts.append(proc)
    if String(item.get("set", "")) != "":
        parts.append("Set: " + String(ItemDefs.SETS[String(item["set"])]["name"]))
    return ", ".join(parts)


static func _fmt(stat: String, v: float) -> String:
    if stat in ["crit", "status_resist", "interval_pct", "lifesteal", "thorns"]:
        return "+%d%%" % roundi(v * 100.0)
    return "+%d" % roundi(v)
