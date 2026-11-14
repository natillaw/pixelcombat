## Mission — una mision de un piso en ejecucion (el plan lo genera `MissionGen`).
##
## Cuenta el progreso escuchando al mundo (muertes, recolecciones, interacciones) y,
## para balizas y resistencia, mirando al jugador cada tick. No toca la simulacion salvo
## lo que la propia mision promete: crear oleadas, quitar el escudo de un jefe o hacer
## aparecer al jefe diferido. La sesion crea una por cada entrada del plan al entrar al
## piso y la desconecta al salir.
class_name Mission
extends RefCounted

var spec: Dictionary
var optional: bool = false
var target: int = 1
var progress: int = 0
var done: bool = false
var rewarded: bool = false

var _world: CombatWorld
var _layout: FloorLayout
var _kind: String
var _group: String
var _groups: Array = []
## Resistencia: segundos acumulados dentro de la zona y siguiente oleada.
var _elapsed: float = 0.0
var _started: bool = false
var _next_wave: float = 0.0
var _beacon: Vector2 = Vector2.ZERO
var _wave_rng: RandomNumberGenerator
var _outside_warned: bool = false
## Interrogatorio: ids de los PNJ testigos con los que ya se ha hablado.
var _talked: Dictionary = {}


func _init(p_spec: Dictionary) -> void:
	spec = p_spec
	optional = bool(spec["optional"])
	target = maxi(int(spec["target"]), 1) if String(spec["kind"]) != "survive" else int(spec["seconds"])
	_kind = String(spec["kind"])
	_group = String(spec.get("group", ""))
	_groups = spec.get("groups", [_group])
	if _kind == "survive":
		var at: Array = spec["beacon"]
		_beacon = Vector2(float(at[0]), float(at[1]))
		_wave_rng = RandomNumberGenerator.new()
		_wave_rng.seed = int(spec["wave_seed"])


func bind(world: CombatWorld, layout: FloorLayout) -> void:
	_world = world
	_layout = layout
	world.enemy_killed.connect(_on_enemy_killed)
	world.resource_gathered.connect(_on_gathered)
	world.interacted.connect(_on_interacted)
	world.npc_talked.connect(_on_npc_talked)


func unbind() -> void:
	if _world == null:
		return
	if _world.enemy_killed.is_connected(_on_enemy_killed):
		_world.enemy_killed.disconnect(_on_enemy_killed)
	if _world.resource_gathered.is_connected(_on_gathered):
		_world.resource_gathered.disconnect(_on_gathered)
	if _world.interacted.is_connected(_on_interacted):
		_world.interacted.disconnect(_on_interacted)
	if _world.npc_talked.is_connected(_on_npc_talked):
		_world.npc_talked.disconnect(_on_npc_talked)


## Para pruebas y trucos de depuracion: da la mision por cumplida.
func force_complete() -> void:
	_finish()


func title() -> String:
	return String(spec["title"])


func description() -> String:
	return String(spec["desc"])


func xp_mult() -> float:
	return float(spec["xp_mult"])


## Una linea para el HUD: {text, done, optional, ratio}.
func line() -> Dictionary:
	var text := title()
	var ratio := clampf(float(progress) / float(maxi(target, 1)), 0.0, 1.0)
	match _kind:
		"survive":
			if not _started:
				text += "  (activa la baliza)"
			else:
				text += "  %d / %d s" % [int(_elapsed), target]
		"clear":
			text += "  %d / %d" % [progress, target]
		_:
			text += "  %d / %d" % [progress, target]
	return {"text": text, "done": done, "optional": optional, "ratio": ratio, "desc": String(spec.get("desc", ""))}


## Cada tick: balizas, resistencia y comprobacion de la limpieza.
func update(delta: float) -> void:
	if done or _world == null:
		return
	match _kind:
		"clear":
			var alive := 0
			for enemy: EnemySim in _world.enemies:
				if enemy.alive and enemy.required and not enemy.summoned:
					alive += 1
			var total := int(spec.get("total", target))
			progress = clampi(total - alive, 0, target)
			if progress >= target or alive == 0:
				_finish()
		"explore":
			if not _world.player.alive:
				return
			for object: Interactable in _world.interactables:
				if object.kind == "waypoint" and not object.done and object.group == _group:
					if _world.player.position.distance_to(object.position) <= Interactable.WAYPOINT_RADIUS:
						object.done = true
						progress += 1
						_world.interacted.emit(object)
			if progress >= target:
				_finish()
		"survive":
			_update_survive(delta)


func _update_survive(delta: float) -> void:
	if not _started or not _world.player.alive:
		return
	var inside := _world.player.position.distance_to(_beacon) <= float(spec["radius"])
	if not inside:
		return
	_elapsed += delta
	progress = int(_elapsed)
	_next_wave -= delta
	if _next_wave <= 0.0:
		_next_wave = float(spec["wave_interval"])
		_spawn_wave()
	if _elapsed >= float(target):
		progress = target
		_finish()


## Una oleada alrededor de la baliza, a 300-420 px, solo en suelo libre.
func _spawn_wave() -> void:
	var pool: Array = spec["wave_pool"]
	for i: int in range(int(spec["wave_size"])):
		var point := _beacon
		for attempt: int in range(14):
			var candidate := _beacon + Vector2.from_angle(_wave_rng.randf() * TAU) * _wave_rng.randf_range(300.0, 420.0)
			if _world.grid == null or _world.grid.is_walkable_point(candidate):
				point = candidate
				break
		var enemy_spec := {"id": StringName(String(pool[_wave_rng.randi_range(0, pool.size() - 1)])), "position": point, "required": false, "group": "wave"}
		var enemy := _world.spawn_from_spec(enemy_spec, _layout.enemy_scale)
		enemy.respawns = false
		enemy.state = EnemySim.State.CHASE


func _on_enemy_killed(enemy: EnemySim) -> void:
	if done or enemy.summoned:
		return
	match _kind:
		"kill_group":
			if enemy.group == _group:
				progress += 1
				if progress >= target:
					_finish()
		"slay":
			if String(enemy.def_id) == String(spec["enemy_id"]):
				progress += 1
				if progress >= target:
					_finish()


func _on_npc_talked(npc_id: String) -> void:
	if done or _kind != "interrogate" or _talked.has(npc_id):
		return
	for npc: Dictionary in _layout.npcs:
		if String(npc["id"]) == npc_id and String(npc.get("group", "")) == _group:
			_talked[npc_id] = true
			progress = _talked.size()
			if progress >= target:
				_finish()
			return


func _on_gathered(node: ResourceNode, _material_id: String, amount: int) -> void:
	if done or _kind != "collect" or node.kind != String(spec["material_kind"]):
		return
	progress += amount
	if progress >= target:
		progress = target
		_finish()


func _on_interacted(object: Interactable) -> void:
	if done:
		return
	if _kind == "survive" and object.kind == "beacon" and object.group == _group:
		_started = true
		_next_wave = 3.0
		return
	if not ["interact", "relic", "explore"].has(_kind) or not _groups.has(object.group):
		return
	if _kind == "explore":
		return
	progress += 1
	if progress >= target:
		_finish()


func _finish() -> void:
	if done:
		return
	done = true
	progress = target
	var on_complete: Dictionary = spec.get("on_complete", {})
	if on_complete.has("unshield"):
		for enemy: EnemySim in _world.enemies:
			if enemy.group == String(on_complete["unshield"]):
				enemy.invulnerable = false
	if on_complete.has("spawn_deferred"):
		for enemy_spec: Dictionary in _layout.deferred_enemies:
			if String(enemy_spec["group"]) == String(on_complete["spawn_deferred"]):
				var enemy := _world.spawn_from_spec(enemy_spec, _layout.enemy_scale)
				enemy.respawns = false
