## TowerCatalog — configuracion de la torre, desde `data/tower.json`.
##
## Esquema:
##   floors, tier_size: pisos totales y pisos por tier (floors = tier_size x tiers)
##   scaling: {hp_per_floor, xp_per_floor} incremento por piso de la vida (y, a
##            mitad de ritmo, del dano) y de la XP de los enemigos
##   spike_positions: {mid_boss, boss} posicion dentro de cada tier (5 y 10) de los
##            pisos dificiles: mini-jefe y jefe
##   completion_xp: {level_fraction, boss_multiplier} XP al completar un piso (fraccion del coste del nivel N)
##   tiers: lista de {tier, name, placeholder, theme, pool: [{id, weight}], adds,
##            mid_boss, boss}; `theme` son colores [r, g, b] (ver FloorLayout)
class_name TowerCatalog
extends RefCounted

const PATH := "res://data/tower.json"
const THEME_KEYS := ["floor", "floor_dark", "floor_light", "wall", "wall_dark", "wall_light", "accent"]

static var _data: Dictionary = {}
static var _errors: Array[String] = []
static var _loaded: bool = false


static func floors() -> int:
	_ensure_loaded()
	return int(_data.get("floors", 0))


static func tier_size() -> int:
	_ensure_loaded()
	return int(_data.get("tier_size", 10))


static func tier_count() -> int:
	_ensure_loaded()
	return (_data.get("tiers", []) as Array).size()


static func tier_of_floor(floor_number: int) -> int:
	return (floor_number - 1) / tier_size() + 1


## Posicion del piso dentro de su tier (1..tier_size).
static func position_in_tier(floor_number: int) -> int:
	return (floor_number - 1) % tier_size() + 1


## Mini-jefe elite errante: {id, first_floor, last_floor, chance, boost}. En cada partida (semilla del
## mundo) hay `chance` de que aparezca una sola vez en un piso entre first_floor y last_floor.
static func elite_boss() -> Dictionary:
	_ensure_loaded()
	return (_data.get("elite_boss", {}) as Dictionary).duplicate(true)


## Piso (0 = ninguno) en el que esta partida tendra su mini-jefe elite; sale de la semilla del mundo.
static func elite_floor(world_seed: int) -> int:
	var config := elite_boss()
	if config.is_empty():
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed * 977 + 5
	if rng.randf() >= float(config["chance"]):
		return 0
	return rng.randi_range(int(config["first_floor"]), int(config["last_floor"]))


## "mid_boss", "boss" o "" segun la posicion del piso en su tier.
static func spike_kind(floor_number: int) -> String:
	_ensure_loaded()
	var spikes: Dictionary = _data["spike_positions"]
	var position := position_in_tier(floor_number)
	if position == int(spikes["boss"]):
		return "boss"
	if position == int(spikes["mid_boss"]):
		return "mid_boss"
	return ""


static func tier(number: int) -> Dictionary:
	_ensure_loaded()
	for entry: Variant in _data.get("tiers", []):
		if int((entry as Dictionary)["tier"]) == number:
			return (entry as Dictionary).duplicate(true)
	return {}


## Estilos de mapa de un tier con su peso: [{style, weight}].
static func styles(tier_number: int) -> Array:
	return (tier(tier_number).get("styles", []) as Array).duplicate(true)


## Bioma (clave del tileset) de un tier.
static func biome(tier_number: int) -> String:
	return String(tier(tier_number).get("biome", "forest"))


## Holgura de colision contra los muros de arboles de un bioma (data/biomes.json), 0 si no tiene.
static func biome_wall_margin(biome_id: String) -> float:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/biomes.json"))
	if parsed is Dictionary and (parsed as Dictionary).get(biome_id) is Dictionary:
		return float(((parsed as Dictionary)[biome_id] as Dictionary).get("wall_margin", 0.0))
	return 0.0


static func scaling() -> Dictionary:
	_ensure_loaded()
	return (_data.get("scaling", {}) as Dictionary).duplicate()


## Escala de vida de los enemigos en un piso (1 en el piso 1).
static func enemy_scale(floor_number: int) -> float:
	return 1.0 + float(scaling()["hp_per_floor"]) * float(maxi(floor_number - 1, 0))


## XP por completar un piso.
static func completion_xp(floor_number: int) -> int:
	_ensure_loaded()
	var spec: Dictionary = _data["completion_xp"]
	# XP de piso = una fraccion de lo que cuesta el nivel que se tiene al llegar a el (piso N = nivel N): asi
	# completar la mision principal de cada piso da casi un nivel y el ritmo no depende de los numeros del piso.
	var level_cost := Progression.xp_to_next(clampi(floor_number, 1, Progression.max_level() - 1))
	var base := int(round(float(spec["level_fraction"]) * float(level_cost)))
	return int(round(float(base) * float(spec["boss_multiplier"]))) if spike_kind(floor_number) != "" else base


static func errors() -> Array[String]:
	_ensure_loaded()
	return _errors.duplicate()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_data = {}
	_errors = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (parsed is Dictionary):
		_errors.append("%s: JSON invalido" % PATH)
		return
	var problems := validate(parsed)
	for problem: String in problems:
		_errors.append(problem)
	if problems.is_empty():
		_data = parsed


static func validate(data: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for field: String in ["floors", "tier_size"]:
		if not _is_number(data.get(field)) or float(data[field]) < 1.0:
			problems.append("'%s' debe ser >= 1" % field)
	var scaling_data: Variant = data.get("scaling")
	if not (scaling_data is Dictionary) or not _is_number((scaling_data as Dictionary).get("hp_per_floor")) or float(scaling_data["hp_per_floor"]) < 0.0 or not _is_number((scaling_data as Dictionary).get("xp_per_floor")) or float(scaling_data["xp_per_floor"]) < 0.0:
		problems.append("scaling necesita hp_per_floor y xp_per_floor >= 0")
	var spikes: Variant = data.get("spike_positions")
	if not (spikes is Dictionary) or not _is_number((spikes as Dictionary).get("mid_boss")) or not _is_number((spikes as Dictionary).get("boss")):
		problems.append("spike_positions necesita mid_boss y boss")
	elif _is_number(data.get("tier_size")) and (int(spikes["boss"]) > int(data["tier_size"]) or int(spikes["mid_boss"]) >= int(spikes["boss"]) or int(spikes["mid_boss"]) < 1):
		problems.append("spike_positions debe cumplir 1 <= mid_boss < boss <= tier_size")
	var completion: Variant = data.get("completion_xp")
	if not (completion is Dictionary) or not _is_number((completion as Dictionary).get("level_fraction")) or float(completion["level_fraction"]) < 0.0 or not _is_number((completion as Dictionary).get("boss_multiplier")) or float(completion["boss_multiplier"]) < 1.0:
		problems.append("completion_xp necesita level_fraction >= 0 y boss_multiplier >= 1")

	var tiers: Variant = data.get("tiers")
	if not (tiers is Array) or (tiers as Array).is_empty():
		problems.append("falta la lista 'tiers'")
		return problems
	if _is_number(data.get("floors")) and _is_number(data.get("tier_size")) and int(data["floors"]) != int(data["tier_size"]) * (tiers as Array).size():
		problems.append("floors (%d) debe ser tier_size x numero de tiers (%d)" % [int(data["floors"]), int(data["tier_size"]) * (tiers as Array).size()])
	for i: int in range((tiers as Array).size()):
		problems.append_array(_validate_tier(tiers[i], i + 1))
	return problems


static func _validate_tier(tier_data: Variant, expected: int) -> Array[String]:
	var problems: Array[String] = []
	if not (tier_data is Dictionary):
		return ["el tier %d no es un objeto" % expected]
	var spec: Dictionary = tier_data
	var label := "tier %d" % expected
	if not _is_number(spec.get("tier")) or int(spec["tier"]) != expected:
		problems.append("%s: el campo 'tier' debe ser %d (en orden)" % [label, expected])
	if not (spec.get("name") is String) or String(spec["name"]).is_empty():
		problems.append("%s: falta 'name'" % label)
	if not (spec.get("placeholder") is bool):
		problems.append("%s: 'placeholder' debe ser true/false" % label)
	var theme: Variant = spec.get("theme")
	if not (theme is Dictionary):
		problems.append("%s: falta 'theme'" % label)
	else:
		for key: String in THEME_KEYS:
			var color: Variant = (theme as Dictionary).get(key)
			if not (color is Array) or (color as Array).size() < 3:
				problems.append("%s: theme.%s debe ser [r, g, b]" % [label, key])
	var pool: Variant = spec.get("pool")
	if not (pool is Array) or (pool as Array).is_empty():
		problems.append("%s: falta 'pool'" % label)
	else:
		for entry: Variant in pool:
			if not (entry is Dictionary) or not EnemyCatalog.has_enemy(StringName(String((entry as Dictionary).get("id", "")))) or not _is_number((entry as Dictionary).get("weight")) or float(entry["weight"]) <= 0.0:
				problems.append("%s: cada entrada de pool necesita un enemigo conocido y weight > 0" % label)
			elif bool(EnemyCatalog.enemy(StringName(String(entry["id"]))).get("boss", false)):
				problems.append("%s: un jefe no puede estar en el pool normal" % label)
	for field: String in ["mid_boss", "mid_boss_2", "boss"]:
		var boss_id := StringName(String(spec.get(field, "")))
		if not EnemyCatalog.has_enemy(boss_id) or not bool(EnemyCatalog.enemy(boss_id).get("boss", false)):
			problems.append("%s: %s debe ser un jefe conocido" % [label, field])
	if String(spec.get("biome", "")).is_empty():
		problems.append("%s: falta biome" % label)
	if not (spec.get("styles") is Array) or (spec["styles"] as Array).is_empty():
		problems.append("%s: faltan styles" % label)
	else:
		for entry: Variant in spec["styles"]:
			if not (entry is Dictionary) or not MapGen.STYLES.has(String((entry as Dictionary).get("style", ""))) or not _is_number((entry as Dictionary).get("weight")) or float(entry["weight"]) <= 0.0:
				problems.append("%s: estilo invalido %s" % [label, str(entry)])
	var nest_id := StringName(String(spec.get("nest", "")))
	if not EnemyCatalog.has_enemy(nest_id) or not EnemyCatalog.enemy(nest_id).has("spawner"):
		problems.append("%s: nest debe ser un enemigo con spawner" % label)
	if not (spec.get("adds") is Array) or (spec["adds"] as Array).is_empty():
		problems.append("%s: falta 'adds' (crias de los pisos de jefe)" % label)
	else:
		for add_id: Variant in spec["adds"]:
			if not EnemyCatalog.has_enemy(StringName(String(add_id))):
				problems.append("%s: la cria '%s' no existe" % [label, str(add_id)])
	return problems


static func _is_number(value: Variant) -> bool:
	return value is float or value is int
