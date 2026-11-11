class_name LootService
extends RefCounted
## Master prompt A: rolls tower loot from LootDefs. Pure functions over a given RNG; seed_for() gives
## a reproducible seed per floor and run so a bug can be replayed.


static func seed_for(floor_num: int, run: int) -> int:
    return hash("loot:%d:%d" % [floor_num, run])


static func floor_def(floor_num: int) -> Dictionary:
    return LootDefs.FLOORS.get(clampi(floor_num, 1, 10), {})


## What one defeated creature leaves ({id: amount}); a boss also rolls its own table.
static func enemy_drops(floor_num: int, is_boss: bool, first_clear: bool, rng: RandomNumberGenerator) -> Dictionary:
    var out := {}
    var d := floor_def(floor_num)
    _roll(d.get("drops", {}), out, rng, {})
    if is_boss:
        _roll(d.get("boss", {}), out, rng, d.get("first_chance", {}) if first_clear else {})
    return out


## The mission chest (always something) plus first-clear keys.
static func chest(floor_num: int, first_clear: bool, rng: RandomNumberGenerator) -> Dictionary:
    var out := {}
    var d := floor_def(floor_num)
    var c: Dictionary = d.get("chest", {})
    for id in c:
        var n := rng.randi_range(int(c[id][0]), int(c[id][1]))
        out[id] = n if first_clear else maxi(1, roundi(float(n) * LootDefs.REPLAY_CHEST))
    if first_clear:
        var f: Dictionary = d.get("first", {})
        for id in f:
            out[id] = int(out.get(id, 0)) + int(f[id])
    return out


static func _roll(table: Dictionary, out: Dictionary, rng: RandomNumberGenerator, chance_override: Dictionary) -> void:
    for id in table:
        var e: Array = table[id]
        if rng.randf() < float(chance_override.get(id, e[0])):
            out[id] = int(out.get(id, 0)) + rng.randi_range(int(e[1]), int(e[2]))


# --- pista D (D-120..D-129) -----------------------------------------------------------------------

## "boss" | "elite" (a leader, a shaman or a caller) | "normal".
static func creature_rank(is_boss: bool, ai_role: String, job: String) -> String:
    if is_boss:
        return "boss"
    if ai_role == "leader" or job == "shaman" or job == "caller":
        return "elite"
    return "normal"


## D-120: what one body carries: {"res": {id: n}, "items": [item dicts]}. Materials and keys from the
## floor table (LootDefs.FLOORS), equipment by rank (grey junk on normal creatures), rarely a book.
## greed = the squad's greedy bonus (greed_bonus); uid_of = Callable giving a fresh item uid.
static func body_loot(floor_num: int, rank: String, theme: String, first_clear: bool, greed: float,
        rng: RandomNumberGenerator, uid_of: Callable) -> Dictionary:
    var res := enemy_drops(floor_num, rank == "boss", first_clear, rng)
    var items: Array = []
    var chance := float(LootDefs.CREATURE_ITEM_CHANCE.get(rank, 0.0)) * (1.0 + greed)
    for i in int(LootDefs.CREATURE_ITEMS.get(rank, 1)):
        if rng.randf() >= chance:
            continue
        if rank == "normal" and rng.randf() < LootDefs.JUNK_CHANCE:
            items.append(ItemGen.generate_junk(rng, int(uid_of.call()), floor_num, theme))
            continue
        var rarity := ItemGen.roll_rarity(rng, floor_num + 1, float(LootDefs.ITEM_RARITY_BONUS.get(rank, 0.0)),
            "uncommon" if rank != "normal" else "common")
        items.append(ItemGen.generate_drop(rng, int(uid_of.call()), floor_num, rarity, theme))
    if rank == "boss":
        for g in LootDefs.BOSS_GUARANTEED.get(floor_num, []):     # D-142: e.g. the epic axe of floor 10
            var it := ItemGen.generate(rng, int(uid_of.call()), floor_num, String(g["rarity"]), String(g["base"]))
            it["source"] = "drop"
            it["theme"] = theme
            items.append(it)
    if rng.randf() < float(LootDefs.BOOK_CHANCE.get(rank, 0.0)):
        var b := roll_book(rng)
        res[b] = int(res.get(b, 0)) + 1
    return {"res": res, "items": items}


static func roll_book(rng: RandomNumberGenerator) -> String:
    var total := 0.0
    for b in LootDefs.BOOKS:
        total += float(LootDefs.BOOK_WEIGHTS[b])
    var roll := rng.randf() * total
    for b in LootDefs.BOOKS:
        roll -= float(LootDefs.BOOK_WEIGHTS[b])
        if roll <= 0.0:
            return String(b)
    return String(LootDefs.BOOKS[0])


## D-124: item places in a hero's backpack (base + the equipped bag's "pack").
static func pack_slots(h: HeroData) -> int:
    var bag: Dictionary = h.equipment.get("bag", {}) if h != null else {}
    return LootDefs.PACK_SLOTS + int(ItemDefs.BASES.get(String(bag.get("base", "")), {}).get("stats", {}).get("pack", 0))


static func is_greedy(h: HeroData) -> bool:
    return h != null and h.traits.has(String(LootDefs.GREEDY["trait"]))


## D-125: the squad's extra loot chance from its greedy heroes.
static func greed_bonus(heroes: Array) -> float:
    var n := 0
    for h in heroes:
        if is_greedy(h):
            n += 1
    return minf(float(LootDefs.GREEDY["max_bonus"]), float(n) * float(LootDefs.GREEDY["loot_bonus"]))


## D-125 on the way home: a greedy hero may keep items back. {"given": [...], "kept": [...]}.
static func greedy_split(h: HeroData, items: Array, rng: RandomNumberGenerator) -> Dictionary:
    var out := {"given": [], "kept": []}
    for it in items:
        if is_greedy(h) and not h.is_master and rng.randf() < float(LootDefs.GREEDY["keep_chance"]):
            (out["kept"] as Array).append(it)
        else:
            (out["given"] as Array).append(it)
    return out


## D-123: materials a salvaged piece gives (junk has its own table).
static func salvage_yield(item: Dictionary) -> Dictionary:
    var kind := String(ItemDefs.BASES.get(String(item.get("base", "")), {}).get("kind", "armor"))
    if ItemDefs.is_junk(item):
        return (LootDefs.SALVAGE_JUNK.get(kind, {"materials": 1}) as Dictionary).duplicate()
    var n := 1 + maxi(0, ItemDefs.RARITY_ORDER.find(String(item.get("rarity", "common"))))
    var out := {}
    var table: Dictionary = LootDefs.SALVAGE.get(kind, {"materials": 1})
    for k in table:
        out[k] = int(table[k]) * n
    return out


## The best rarity in a list of items ("" if empty): a body glows in that colour.
static func best_rarity(items: Array) -> String:
    var best := ""
    var rank := -2
    for it in items:
        var r := String(it.get("rarity", "common"))
        var i := -1 if r == "junk" else ItemDefs.RARITY_ORDER.find(r)
        if i > rank:
            rank = i
            best = r
    return best
