## CampaignLab — simula una campana: una clase con su nivel y su equipo recorre los pisos 1..N de
## la torre uno tras otro con el FloorBot (limpia cada piso, sube de nivel, equipa lo mejor que
## suelta). Mide por piso: tiempo, nivel, vida perdida, muertes e items; es el termometro de la
## curva de dificultad (escala por piso, jefes, regeneracion...).
##
##   godot --headless --path . --script tools/balance/run_campaign.gd -- warrior 10
class_name CampaignLab
extends RefCounted

const DT := 1.0 / 60.0
const SEED := 20261110
const MAX_FLOOR_SECONDS := 1500.0


## Equipa de la mochila lo que mejora el equipo actual (suma de stats); solo en zona segura.
static func auto_equip(player: PlayerSim) -> void:
	player.safe_zone = true
	var improved := true
	var guard := 0
	while improved and guard < 60:
		improved = false
		guard += 1
		for index: int in range(player.bag.size()):
			if player.equip_reason(index) != "":
				continue
			var piece: Dictionary = player.bag[index]
			var slot := String(ItemCatalog.item(String(piece["id"]))["slot"])
			if not player.equipment.has(slot) or _score(piece) > _score(player.equipment[slot]):
				player.equip_from_bag(index)
				improved = true
				break
	player.safe_zone = false


static func _score(piece: Dictionary) -> float:
	var total := 0.0
	for stat: String in piece["stats"]:
		var weight := 1.0
		if stat == "crit_chance":
			weight = 200.0
		elif stat == "armor" or stat == "stamina":
			weight = 0.7
		total += float(piece["stats"][stat]) * weight
	return total


## Recorre los pisos 1..max_floor. `regen` = fraccion de vida maxima por segundo fuera de combate.
## Devuelve una fila por piso: {floor, level_start, level_end, seconds, deaths, hp_lost, completed, items}.
static func run(class_id: String, max_floor: int, regen: float = 0.0, rest_below: float = 0.0) -> Array:
	var world := CombatWorld.new(SEED)
	var session := GameSession.new(world, "")
	world.player.safe_zone = true
	world.player.switch_class(class_id)
	world.player.set_character("Bot", {})
	PlayerSim.regen_per_second = regen
	var bot := FloorBot.new()
	bot.dodge_enemies = true
	bot.use_stances = true
	bot.rest_below = rest_below
	var rows: Array = []
	for floor_number: int in range(1, max_floor + 1):
		var row := {"floor": floor_number, "level_start": world.player.level, "deaths": 0, "hp_lost": 0.0, "seconds": 0.0, "completed": false, "items": 0}
		var attempts := 0
		while attempts < 4 and not bool(row["completed"]):
			attempts += 1
			auto_equip(world.player)
			for n: int in range(1, floor_number):
				session.tower.complete(n)
			var forced: Array = []
			var spike := TowerCatalog.spike_kind(floor_number)
			if spike == "":
				forced = ["clear"]
			elif spike == "mid_boss":
				forced = ["hunt"]
			else:
				forced = ["elites"]
			session._enter(TowerGenerator.generate(floor_number, SEED, attempts, forced), false)
			session._floor_done = false
			session.tower.visit(floor_number)
			var damage := [0.0]
			var callable := func(amount: float, _src: Vector2, _dot: bool) -> void: damage[0] += amount
			world.player.damage_taken.connect(callable)
			var bag_before := world.player.bag.size()
			var elapsed := 0.0
			while elapsed < MAX_FLOOR_SECONDS and world.player.alive and not session.is_floor_done():
				world.submit_input(bot.decide(world))
				world.step(DT)
				elapsed += DT
				# Recoger todo lo que cae (el bot no hace clic).
				if world.loot_drops.size() > 0 and int(elapsed * 60.0) % 30 == 0:
					for drop: LootDrop in world.loot_drops.duplicate():
						if world.player.bag_has_room():
							world.player.add_item(drop.item)
							world.loot_drops.erase(drop)
							world.loot_removed.emit(drop)
			world.player.damage_taken.disconnect(callable)
			if not session.is_floor_done() and world.player.alive:
				_report_stuck(world, session, bot)
			row["seconds"] = float(row["seconds"]) + elapsed
			row["hp_lost"] = float(row["hp_lost"]) + damage[0]
			row["items"] = int(row["items"]) + world.player.bag.size() - bag_before
			if session.is_floor_done():
				row["completed"] = true
			else:
				row["deaths"] = int(row["deaths"]) + (0 if world.player.alive else 1)
				world.player.reset(world.player.position)
		row["level_end"] = world.player.level
		row["hp_max"] = world.player.max_health
		rows.append(row)
		if not bool(row["completed"]):
			break
	PlayerSim.regen_per_second = 0.015
	return rows


## Diagnostico de un piso que no se termina: que queda vivo y donde esta el bot.
static func _report_stuck(world: CombatWorld, session: GameSession, bot: FloorBot) -> void:
	print("   [atascado] jugador %s hp %d, mision %s" % [str(world.player.position), int(world.player.health), str(session.mission_lines().map(func(l: Dictionary) -> String: return String(l["text"])))])
	for enemy: EnemySim in world.enemies:
		if enemy.alive:
			print("   [vivo] %s %s inv=%s req=%s group=%s" % [enemy.def_id, str(enemy.position), str(enemy.invulnerable), str(enemy.required), str(enemy.group)])
	print("   [objetivo] %s stuck=%d" % [str(bot._target.position) if bot._target != null else "-", bot._stuck])
