## BalanceLab — mide a las clases con bots, sin ventana y de forma determinista.
##
## Escenarios:
##   dps_run:  el bot pega a un muneco que no se mueve ni ataca durante N segundos
##             con todas sus skills; devuelve DPS sostenido, rafaga y casts.
##   wave_run: el bot (que esquiva) se enfrenta a los cuatro enemigos del tier 1;
##             devuelve si limpia la oleada, en cuanto tiempo y con cuanta vida.
##
## Los resultados salen en `matrix()` y se vuelcan a `tests/out/balance_matrix.csv`
## con `tools/balance/run_balance.gd`. `tests/test_balance.gd` exige que ninguna
## clase se salga de la banda de balance.
class_name BalanceLab
extends RefCounted

const DT := 1.0 / 60.0
const ARENA := Rect2(0, 0, 900, 600)


## DPS contra un muneco inmortal. El jugador empieza con la Ultimate cargada y
## los recursos llenos (el escenario mide el potencial, no la preparacion).
static func dps_run(class_id: String, level: int, seconds: float = 20.0, seed_value: int = 1) -> Dictionary:
	var world := _new_world(class_id, level, seed_value)
	var dummy := world.add_dummy(world.player.position + Vector2(60, 0), false)
	dummy.max_health = 1.0e9
	dummy.health = 1.0e9
	var bot := BotBrain.new()
	var buckets: Array = []
	for i: int in range(int(ceil(seconds))):
		buckets.append(0.0)
	var casts: Dictionary = {}
	var hits := [0]
	world.player.attack_hit.connect(func(_skill: Dictionary, _t: Object, damage: float, _c: bool, _p: Vector2) -> void:
		var second := mini(int(float(world.tick) * DT), buckets.size() - 1)
		buckets[second] = float(buckets[second]) + damage
		hits[0] += 1)
	world.player.attack_started.connect(func(skill: Dictionary, _d: Vector2) -> void:
		var id := String(skill["id"])
		casts[id] = int(casts.get(id, 0)) + 1)
	for i: int in range(int(seconds / DT)):
		world.submit_input(bot.decide(world))
		world.step(DT)
	var total := 0.0
	for value: float in buckets:
		total += value
	var burst_seconds := 6
	var burst := 0.0
	for i: int in range(mini(burst_seconds, buckets.size())):
		burst += float(buckets[i])
	var sustained := 0.0
	var tail := buckets.size() / 2
	for i: int in range(buckets.size() - tail, buckets.size()):
		sustained += float(buckets[i])
	return {
		"class": class_id,
		"level": level,
		"dps": total / seconds,
		"burst_dps": burst / float(burst_seconds),
		"sustained_dps": sustained / float(tail),
		"hits": hits[0],
		"casts": casts,
		"hp": world.player.max_health,
	}


## Oleada del tier 1 (Slime, Bat, Spider, Beetle) con un bot que esquiva.
static func wave_run(class_id: String, level: int, seed_value: int = 1, max_seconds: float = 90.0) -> Dictionary:
	var world := _new_world(class_id, level, seed_value)
	var center := world.player.position
	var spawns := [
		[&"slime", Vector2(170, 20)], [&"bat", Vector2(-160, -60)],
		[&"spider", Vector2(30, -190)], [&"beetle", Vector2(-40, 170)],
	]
	for entry: Array in spawns:
		var enemy := world.add_enemy(entry[0], center + entry[1])
		enemy.data["respawn_seconds"] = 0.0
	var bot := BotBrain.new()
	bot.dodge_enemies = true
	bot.use_stances = true
	var damage_taken := [0.0]
	world.player.damage_taken.connect(func(amount: float, _src: Vector2, _dot: bool) -> void: damage_taken[0] += amount)
	var elapsed := 0.0
	var cleared := false
	while elapsed < max_seconds and world.player.alive:
		world.submit_input(bot.decide(world))
		world.step(DT)
		elapsed += DT
		if world.get_living_targets().is_empty():
			cleared = true
			break
	return {
		"class": class_id,
		"level": level,
		"cleared": cleared,
		"alive": world.player.alive,
		"time": elapsed,
		"damage_taken": damage_taken[0],
		"hp_left": world.player.health / world.player.max_health,
	}


## Una fila por clase (en el orden del selector) con ambos escenarios.
static func matrix(level: int = 10, seconds: float = 20.0) -> Array:
	var rows: Array = []
	for class_id: String in ClassCatalog.all_ids():
		var dps := dps_run(class_id, level, seconds)
		var wave := wave_run(class_id, level)
		rows.append({
			"class": class_id,
			"level": level,
			"hp": dps["hp"],
			"dps": dps["dps"],
			"burst_dps": dps["burst_dps"],
			"sustained_dps": dps["sustained_dps"],
			"wave_cleared": wave["cleared"],
			"wave_time": wave["time"],
			"wave_hp_left": wave["hp_left"],
			"wave_damage_taken": wave["damage_taken"],
		})
	return rows


static func _new_world(class_id: String, level: int, seed_value: int) -> CombatWorld:
	var world := CombatWorld.new(seed_value)
	world.setup_arena(ARENA)
	world.player.switch_class(class_id)
	world.player.set_level(level)
	world.player.ultimate_charge = WarriorKit.ULTIMATE_CHARGE_MAX
	return world
