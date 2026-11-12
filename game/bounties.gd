## Bounties — el tablon de encargos del Gremio.
##
## Cada visita ofrece 3 encargos sorteados con la semilla del mundo y `bounty_serial` del jugador
## (determinista: la misma partida ve los mismos encargos hasta que se cobra uno). Hay hasta
## `max_active` encargos aceptados; su progreso lo actualizan los eventos del juego (enemigo
## derrotado, material ganado, piso completado) y se cobran en el Gremio.
class_name Bounties
extends RefCounted

const PATH := "res://data/bounties.json"
const BEAST_IDS := ["slime", "bat", "spider", "beetle", "wisp", "hornet"]

static var _data: Dictionary = {}


static func _load() -> void:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))


static func templates() -> Array:
	_load()
	return (_data["templates"] as Array).duplicate(true)


static func max_active() -> int:
	_load()
	return int(_data.get("max_active", 3))


## Los 3 encargos del tablon: [{template, kind, name, text, count, progress, gold, xp, consumable, ...}].
static func offers(world_seed: int, serial: int, highest_tier: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed * 131 + serial * 7919 + 17
	var pool := templates()
	var out: Array = []
	while out.size() < 3 and not pool.is_empty():
		var template: Dictionary = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		var range_count: Array = template["count"]
		var count := rng.randi_range(int(range_count[0]), int(range_count[1]))
		var span := maxf(float(int(range_count[1]) - int(range_count[0])), 1.0)
		var tier_mult := 1.0 + 0.25 * float(maxi(highest_tier - 1, 0))
		out.append({
			"template": String(template["id"]), "kind": String(template["kind"]), "name": String(template["name"]),
			"text": String(template["text"]).replace("{count}", str(count)), "count": count, "progress": 0,
			"gold": int(round(float(template["gold"]) * tier_mult * (0.8 + 0.4 * float(count - int(range_count[0])) / span))),
			"xp": int(round(float(template["xp"]) * tier_mult)),
			"consumable": String(template.get("consumable", "")),
			"group": String(template.get("group", "")), "enemy": String(template.get("enemy", "")), "material": String(template.get("material", "")),
		})
	return out


## Un enemigo muerto ("kill", id), un material ganado ("material", id concreto) o un piso completado
## ("floor") avanzan los encargos activos del jugador. Devuelve los que se completan con este evento.
static func progress(player: PlayerSim, event: String, subject: String, amount: int = 1) -> Array:
	var finished: Array = []
	for bounty: Dictionary in player.bounties:
		if int(bounty["progress"]) >= int(bounty["count"]):
			continue
		var matches := false
		match String(bounty["kind"]):
			"kill_group":
				var group := String(bounty["group"])
				matches = event == "kill" and ((group == "beast" and BEAST_IDS.has(subject)) or (group != "beast" and subject.begins_with(group)))
			"kill_type":
				matches = event == "kill" and subject == String(bounty["enemy"])
			"collect":
				var parsed := MaterialCatalog.parse(subject)
				matches = event == "material" and not parsed.is_empty() and String(parsed["kind"]) == String(bounty["material"])
			"clear_floors":
				matches = event == "floor"
		if matches:
			bounty["progress"] = mini(int(bounty["progress"]) + amount, int(bounty["count"]))
			if int(bounty["progress"]) >= int(bounty["count"]):
				finished.append(bounty)
	return finished


## Acepta una oferta: false si ya hay el maximo de encargos o ese ya esta aceptado.
static func accept(player: PlayerSim, offer: Dictionary) -> bool:
	if player.bounties.size() >= max_active():
		return false
	for bounty: Dictionary in player.bounties:
		if String(bounty["template"]) == String(offer["template"]):
			return false
	player.bounties.append(offer.duplicate(true))
	return true


## Cobra el encargo `index` si esta completo: oro, XP y consumible. Cambia el tablon (serial + 1).
static func turn_in(player: PlayerSim, index: int) -> bool:
	if index < 0 or index >= player.bounties.size():
		return false
	var bounty: Dictionary = player.bounties[index]
	if int(bounty["progress"]) < int(bounty["count"]):
		return false
	player.bounties.remove_at(index)
	player.add_gold(int(bounty["gold"]))
	player.grant_xp(int(bounty["xp"]), player.position)
	if String(bounty["consumable"]) != "":
		player.add_consumable(String(bounty["consumable"]), 1)
	player.bounty_serial += 1
	player.bounties_done += 1
	return true
