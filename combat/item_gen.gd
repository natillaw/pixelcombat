## ItemGen — genera items concretos de forma determinista (el RNG lo pone quien llama).
##
## Un item es {id, rarity, tier, stats}: los stats base del item x multiplicador de
## rareza x multiplicador de tier, mas un afijo aleatorio por cada `affixes` de la
## rareza. Con el mismo RNG (misma semilla y estado) siempre sale el mismo item.
class_name ItemGen
extends RefCounted


## Elige una rareza; `bonus` multiplica el peso de cada una por (1 + bonus x posicion),
## asi los jefes y cofres favorecen las raras sin descartar las comunes.
static func roll_rarity(rng: RandomNumberGenerator, bonus: float = 0.0) -> String:
	var rarities := ItemCatalog.rarities()
	var total := 0.0
	var weights: Array = []
	for i: int in range(rarities.size()):
		var weight := float(rarities[i]["weight"]) * (1.0 + bonus * float(i))
		weights.append(weight)
		total += weight
	var roll := rng.randf() * total
	for i: int in range(rarities.size()):
		roll -= float(weights[i])
		if roll <= 0.0:
			return String(rarities[i]["id"])
	return String(rarities[rarities.size() - 1]["id"])


## `slot`, `rarity` e `item_id` vacios se eligen al azar; `class_id` filtra los items
## que esa clase puede equipar.
static func roll_item(rng: RandomNumberGenerator, tier: int, rarity: String = "", slot: String = "", class_id: String = "", item_id: String = "", bonus: float = 0.0) -> Dictionary:
	var base: Dictionary = ItemCatalog.item(item_id)
	if base.is_empty():
		var slots := ItemCatalog.slots()
		var chosen_slot := slot if slot != "" else String(slots[rng.randi_range(0, slots.size() - 1)])
		var candidates := ItemCatalog.items_for(chosen_slot, class_id)
		base = candidates[rng.randi_range(0, candidates.size() - 1)]
	var rarity_id := rarity if rarity != "" else roll_rarity(rng, bonus)
	var spec := ItemCatalog.rarity(rarity_id)
	var scale := float(spec["stat_mult"]) * ItemCatalog.tier_multiplier(tier)
	var stats: Dictionary = {}
	for stat: String in base["stats"]:
		stats[stat] = _round_stat(stat, float(base["stats"][stat]) * scale)
	var pool := ItemCatalog.affixes()
	for i: int in range(int(spec["affixes"])):
		var affix: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		var value := rng.randf_range(float(affix["min"]), float(affix["max"])) * scale
		var stat := String(affix["stat"])
		stats[stat] = _round_stat(stat, float(stats.get(stat, 0.0)) + value)
	return {"id": String(base["id"]), "rarity": rarity_id, "tier": tier, "stats": stats}


## Botin de un enemigo muerto: devuelve el item o {} si no suelta nada.
## `kind`: "normal", "mid_boss" o "boss" (tambien la clave del bonus de rareza).
## `table` es el bloque `loot` del enemigo (opcional): `chance` cambia la probabilidad y
## `slots` limita las ranuras que puede soltar.
static func roll_drop(rng: RandomNumberGenerator, tier: int, kind: String, table: Dictionary = {}) -> Dictionary:
	var loot := ItemCatalog.loot()
	var chance := float(loot["boss_chance"]) if kind != "normal" else float(loot["normal_chance"])
	chance = float(table.get("chance", chance))
	if rng.randf() >= chance:
		return {}
	var bonus := float((loot["rarity_bonus"] as Dictionary).get(kind, 0.0))
	var slot := ""
	var slots: Array = table.get("slots", [])
	if not slots.is_empty():
		slot = String(slots[rng.randi_range(0, slots.size() - 1)])
	return roll_item(rng, tier, "", slot, "", "", bonus)


## Cofre al completar un piso por primera vez: siempre da un item.
static func roll_chest(rng: RandomNumberGenerator, tier: int, spike: String) -> Dictionary:
	var key := "floor_chest" if spike == "" else "floor_chest_" + spike
	var bonus := float((ItemCatalog.loot()["rarity_bonus"] as Dictionary).get(key, 0.0))
	return roll_item(rng, tier, "", "", "", "", bonus)


static func _round_stat(stat: String, value: float) -> float:
	if stat == "crit_chance":
		return snappedf(value, 0.001)
	return snappedf(value, 0.1)
