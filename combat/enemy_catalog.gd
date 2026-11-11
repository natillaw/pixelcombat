## EnemyCatalog — catálogo de enemigos, cargado desde `data/enemies/*.json`.
##
## Añadir un enemigo es añadir un objeto al JSON de su tier; no hace falta código
## nuevo mientras sus ataques usen una forma existente (cone, line, circle).
## `validate()` comprueba el esquema y lo ejecuta `tests/test_enemies.gd` sobre
## todos los archivos.
##
## Esquema (tiempos en segundos, distancias en px):
##   id, name, tier, role, description, respawn_seconds (0 = no reaparece)
##   stats:  health, speed, radius, damage, xp (experiencia al morir), armor
##           (opcional, reduccion
##           armor / (armor + 100) como la del jugador)
##   ai:     aggro_range, leash (multiplo de aggro_range a partir del cual deja
##           de perseguir), keep_distance (opcional: si el jugador se acerca
##           mas que el 70 % de esa distancia, retrocede; para tiradores)
##   sprite: sheet (tira horizontal de frames cuadrados), frame, frames, fps, scale,
##           tint (opcional, [r, g, b, a])
##   resist (opcional): {estado: 0..1} resistencia a estados; 1 = inmune (jefes), 0,5
##           = duracion a la mitad
##   boss (opcional): true marca un jefe (barra de vida propia)
##   phases (opcional, jefes): lista ordenada de {name, hp_below (fraccion de vida
##           a partir de la cual entra, la primera es 1.0), speed_mult, attacks
##           (ids permitidos en la fase), summons: [{id, count}]}. Al entrar en
##           una fase hay una pausa (rugido) en la que es invulnerable
##   attacks: lista de ataques con
##     id, shape ("cone": range+arc | "line": range+width | "circle": range)
##     windup (TELEGRAPH visible, el golpe cae al terminar), active, recovery,
##     cooldown, damage_mult (sobre stats.damage), trigger_range (distancia a la
##     que decide lanzarlo), weight (probabilidad relativa entre ataques listos)
##     shape "projectile": en vez de range/arc/width lleva `projectile` {speed,
##       range, radius, count, spread, pierce, visual}; dispara al acabar el aviso
##       y el aviso marca el carril
##     on_hit (opcional): [{id, duration, strength?}] estados que aplica al jugador
##       cuando el golpe le alcanza de verdad (no si lo esquiva o lo bloquea)
##     dash_distance (opcional): se desplaza esa distancia durante `active`
class_name EnemyCatalog
extends RefCounted

const ENEMIES_DIR := "res://data/enemies/"
const SHAPES := ["cone", "line", "circle", "projectile"]

static var _enemies: Dictionary = {}
static var _errors: Array[String] = []
static var _loaded: bool = false


## Copia profunda de la definicion de un enemigo, o {} si no existe.
static func enemy(id: StringName) -> Dictionary:
	_ensure_loaded()
	if not _enemies.has(id):
		return {}
	return (_enemies[id] as Dictionary).duplicate(true)


static func has_enemy(id: StringName) -> bool:
	_ensure_loaded()
	return _enemies.has(id)


static func all_ids() -> Array[StringName]:
	_ensure_loaded()
	var ids: Array[StringName] = []
	for id: StringName in _enemies:
		ids.append(id)
	return ids


static func errors() -> Array[String]:
	_ensure_loaded()
	return _errors.duplicate()


static func reload() -> void:
	_loaded = false
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_enemies = {}
	_errors = []
	var dir := DirAccess.open(ENEMIES_DIR)
	if dir == null:
		_errors.append("no se puede abrir %s" % ENEMIES_DIR)
		return
	var files: Array[String] = []
	for file_name: String in dir.get_files():
		if file_name.ends_with(".json"):
			files.append(file_name)
	files.sort()
	for file_name: String in files:
		_load_file(ENEMIES_DIR + file_name)


static func _load_file(path: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not (parsed as Dictionary).get("enemies") is Array:
		_errors.append("%s: JSON invalido o sin lista 'enemies'" % path)
		return
	for raw: Variant in (parsed as Dictionary)["enemies"]:
		if not (raw is Dictionary):
			_errors.append("%s: entrada que no es un objeto" % path)
			continue
		var entry: Dictionary = raw
		var problems := validate(entry)
		for problem: String in problems:
			_errors.append("%s [%s]: %s" % [path, str(entry.get("id", "?")), problem])
		if not problems.is_empty():
			continue
		var id := StringName(String(entry["id"]))
		if _enemies.has(id):
			_errors.append("%s: id duplicado '%s'" % [path, id])
			continue
		var stored := entry.duplicate(true)
		stored["id"] = id
		_enemies[id] = stored


## Lista de problemas del esquema para un enemigo (vacia si es valido).
static func validate(entry: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for field: String in ["id", "name", "role", "description"]:
		if not _is_text(entry.get(field)) or String(entry[field]).is_empty():
			problems.append("falta el texto '%s'" % field)
	if not _is_number(entry.get("tier")) or float(entry["tier"]) < 1.0:
		problems.append("'tier' debe ser >= 1")
	if not _is_number(entry.get("respawn_seconds")) or float(entry["respawn_seconds"]) < 0.0:
		problems.append("'respawn_seconds' debe ser >= 0")

	var stats: Variant = entry.get("stats")
	if not (stats is Dictionary):
		problems.append("falta 'stats'")
	else:
		for field: String in ["health", "radius", "damage"]:
			if not _is_number((stats as Dictionary).get(field)) or float(stats[field]) <= 0.0:
				problems.append("stats.%s debe ser > 0" % field)
		if not _is_number((stats as Dictionary).get("xp")) or float(stats["xp"]) < 0.0:
			problems.append("stats.xp debe ser >= 0")
		for field: String in ["speed", "armor"]:
			if (stats as Dictionary).has(field) and (not _is_number(stats[field]) or float(stats[field]) < 0.0):
				problems.append("stats.%s debe ser >= 0" % field)
		if not _is_number((stats as Dictionary).get("speed")):
			problems.append("stats.speed es obligatorio")

	var ai: Variant = entry.get("ai")
	if not (ai is Dictionary):
		problems.append("falta 'ai'")
	else:
		if not _is_number((ai as Dictionary).get("aggro_range")) or float(ai["aggro_range"]) <= 0.0:
			problems.append("ai.aggro_range debe ser > 0")
		if not _is_number((ai as Dictionary).get("leash")) or float(ai["leash"]) < 1.0:
			problems.append("ai.leash debe ser >= 1")
		if (ai as Dictionary).has("keep_distance") and (not _is_number(ai["keep_distance"]) or float(ai["keep_distance"]) <= 0.0):
			problems.append("ai.keep_distance debe ser > 0")

	var sprite: Variant = entry.get("sprite")
	if not (sprite is Dictionary):
		problems.append("falta 'sprite'")
	else:
		if not _is_text((sprite as Dictionary).get("sheet")) or String(sprite["sheet"]).is_empty():
			problems.append("sprite.sheet es obligatorio")
		for field: String in ["frame", "frames", "fps", "scale"]:
			if not _is_number((sprite as Dictionary).get(field)) or float(sprite[field]) <= 0.0:
				problems.append("sprite.%s debe ser > 0" % field)
		if (sprite as Dictionary).has("tint") and (not (sprite["tint"] is Array) or (sprite["tint"] as Array).size() != 4):
			problems.append("sprite.tint debe ser [r, g, b, a]")

	var attacks: Variant = entry.get("attacks")
	if not (attacks is Array) or (attacks as Array).is_empty():
		problems.append("necesita al menos un ataque en 'attacks'")
	else:
		var seen: Dictionary = {}
		for attack: Variant in attacks:
			if not (attack is Dictionary):
				problems.append("un ataque no es un objeto")
				continue
			for problem: String in validate_attack(attack):
				problems.append("ataque '%s': %s" % [str((attack as Dictionary).get("id", "?")), problem])
			var attack_id := str((attack as Dictionary).get("id", ""))
			if seen.has(attack_id):
				problems.append("ataque duplicado '%s'" % attack_id)
			seen[attack_id] = true
	if entry.has("resist"):
		if not (entry["resist"] is Dictionary):
			problems.append("'resist' debe ser un objeto")
		else:
			for status_id: String in entry["resist"]:
				if not StatusCatalog.has_status(status_id) or not _is_number(entry["resist"][status_id]) or float(entry["resist"][status_id]) < 0.0 or float(entry["resist"][status_id]) > 1.0:
					problems.append("resist.%s debe ser un estado conocido con valor entre 0 y 1" % status_id)
	if entry.has("boss") and not (entry["boss"] is bool):
		problems.append("'boss' debe ser true/false")
	if entry.has("phases"):
		problems.append_array(_validate_phases(entry))
	return problems


static func _validate_phases(entry: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var phases: Variant = entry["phases"]
	if not (phases is Array) or (phases as Array).is_empty():
		return ["'phases' debe ser una lista no vacia"]
	var attack_ids: Dictionary = {}
	if entry.get("attacks") is Array:
		for attack: Variant in entry["attacks"]:
			if attack is Dictionary:
				attack_ids[str((attack as Dictionary).get("id", ""))] = true
	var previous := 2.0
	for i: int in range((phases as Array).size()):
		var phase: Variant = phases[i]
		if not (phase is Dictionary):
			problems.append("la fase %d no es un objeto" % i)
			continue
		var spec: Dictionary = phase
		if not _is_text(spec.get("name")) or String(spec["name"]).is_empty():
			problems.append("fase %d: falta 'name'" % i)
		if not _is_number(spec.get("hp_below")) or float(spec["hp_below"]) <= 0.0 or float(spec["hp_below"]) > 1.0:
			problems.append("fase %d: hp_below debe estar entre 0 y 1" % i)
		elif float(spec["hp_below"]) >= previous:
			problems.append("fase %d: hp_below debe ser menor que el de la fase anterior" % i)
		else:
			previous = float(spec["hp_below"])
		if i == 0 and _is_number(spec.get("hp_below")) and not is_equal_approx(float(spec["hp_below"]), 1.0):
			problems.append("la primera fase debe empezar en hp_below = 1.0")
		if not _is_number(spec.get("speed_mult")) or float(spec["speed_mult"]) <= 0.0:
			problems.append("fase %d: speed_mult debe ser > 0" % i)
		if spec.has("attacks"):
			if not (spec["attacks"] is Array) or (spec["attacks"] as Array).is_empty():
				problems.append("fase %d: 'attacks' debe ser una lista no vacia" % i)
			else:
				for attack_id: Variant in spec["attacks"]:
					if not attack_ids.has(str(attack_id)):
						problems.append("fase %d: el ataque '%s' no existe" % [i, str(attack_id)])
		if spec.has("summons"):
			if not (spec["summons"] is Array):
				problems.append("fase %d: 'summons' debe ser una lista" % i)
			else:
				for summon: Variant in spec["summons"]:
					if not (summon is Dictionary) or not _is_text((summon as Dictionary).get("id")) or not _is_number((summon as Dictionary).get("count")) or float(summon["count"]) < 1.0:
						problems.append("fase %d: cada invocacion necesita id y count >= 1" % i)
	return problems


static func validate_attack(attack: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	if not _is_text(attack.get("id")) or String(attack["id"]).is_empty():
		problems.append("falta 'id'")
	if not _is_number(attack.get("windup")) or float(attack["windup"]) <= 0.0:
		problems.append("'windup' (el telegraph) debe ser > 0")
	for field: String in ["active", "recovery", "cooldown"]:
		if not _is_number(attack.get(field)) or float(attack[field]) < 0.0:
			problems.append("'%s' debe ser >= 0" % field)
	for field: String in ["damage_mult", "trigger_range", "weight"]:
		if not _is_number(attack.get(field)) or float(attack[field]) <= 0.0:
			problems.append("'%s' debe ser > 0" % field)
	var shape: Variant = attack.get("shape")
	if not (shape is String) or not SHAPES.has(shape):
		problems.append("forma desconocida '%s' (cone, line, circle o projectile)" % str(shape))
		return problems
	if shape == "projectile":
		problems.append_array(SkillCatalog.validate_projectile_spec(attack.get("projectile")))
		return problems
	if not _is_number(attack.get("range")) or float(attack["range"]) <= 0.0:
		problems.append("'range' debe ser > 0")
	if shape == "cone" and (not _is_number(attack.get("arc")) or float(attack["arc"]) <= 0.0 or float(attack["arc"]) > 360.0):
		problems.append("cone: 'arc' debe estar entre 0 y 360")
	if shape == "line" and (not _is_number(attack.get("width")) or float(attack["width"]) <= 0.0):
		problems.append("line: 'width' debe ser > 0")
	if attack.has("on_hit"):
		problems.append_array(StatusCatalog.validate_on_hit(attack["on_hit"]))
	if attack.has("dash_distance"):
		if not _is_number(attack["dash_distance"]) or float(attack["dash_distance"]) < 0.0:
			problems.append("'dash_distance' debe ser >= 0")
		elif float(attack["dash_distance"]) > 0.0 and float(attack.get("active", 0.0)) <= 0.0:
			problems.append("un dash necesita 'active' > 0")
	return problems


static func _is_number(value: Variant) -> bool:
	return value is float or value is int


static func _is_text(value: Variant) -> bool:
	return value is String or value is StringName
