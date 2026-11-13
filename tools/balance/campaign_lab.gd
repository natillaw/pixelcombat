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
static func run(class_id: String, max_floor: int, regen: float = 0.0, rest_below: float = 0.0, forced_clear: bool = false, on_row: Callable = Callable()) -> Array:
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
			_prepare(world.player)
			for n: int in range(1, floor_number):
				session.tower.complete(n)
			# Por defecto se juegan las misiones reales de cada piso (historia incluida); `forced_clear` reproduce la
			# campana antigua (limpiar, cazar elites) para comparar.
			var forced: Array = []
			var spike := TowerCatalog.spike_kind(floor_number)
			if forced_clear:
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
			var probe := Vector2(-9999, -9999)
			while elapsed < MAX_FLOOR_SECONDS and world.player.alive and not session.is_floor_done():
				var message := bot.decide(world)
				# Como una persona: pocion de vida con poca vida y elixir con poco recurso.
				var player := world.player
				if player.health < player.max_health * 0.4 and player.potion_cooldown_left <= 0.0:
					message.actions["quick_health"] = true
				if player.resource.get_current() < player.resource.max_amount * 0.15:
					message.actions["quick_resource"] = true
				world.submit_input(message)
				world.step(DT)
				elapsed += DT
				if int(elapsed * 60.0) % 7200 == 0 and elapsed > 1.0:
					if player.position.distance_to(probe) < 80.0:
						_diagnose(world, bot, message, session)
						elapsed = MAX_FLOOR_SECONDS
					probe = player.position
				# Como una persona: el bot solo recoge lo que ve y lo coge con un clic cerca (FloorBot). Con la mochila llena tira lo peor.
				if not world.player.bag_has_room() and int(elapsed * 60.0) % 30 == 0:
					_discard_worst(world.player)
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
		if on_row.is_valid():
			on_row.call(row)
		if not bool(row["completed"]):
			break
	PlayerSim.regen_per_second = 0.015
	return rows


static func _diagnose(world: CombatWorld, bot: FloorBot, message: InputMessage, session: GameSession) -> void:
	var player := world.player
	var grid := world.grid
	var here := grid.world_to_cell(player.position)
	print("   [sin-avance] piso %d grid %dx%d bounds %s celda_tipo %d pos %s cell %s move_dir %s actions %s target %s" % [int(session.layout.floor_number), grid.cols, grid.rows, str(world.bounds), grid.get_cell(here.x, here.y), str(player.position), str(here), str(message.move_dir), str(message.actions.keys()), str(bot._target.position) if bot._target != null else "-"])
	if bot._field_grid == grid and bot._field.size() > 0:
		print("   [campo] aqui=%d" % (bot._field[here.y * grid.cols + here.x] if bot._field.size() > here.y * grid.cols + here.x else -9))
	var near := []
	for target: Object in world.get_living_targets():
		if target.position.distance_to(player.position) < 400.0:
			near.append("%s@%s inv=%s los=%s" % [target.get("def_id"), str(target.position), str(target.get("invulnerable")), str(world.line_of_sight(player.position, target.position))])
	print("   [cerca] %s" % str(near))
	var obs := []
	for o: Dictionary in world.obstacles:
		if (o["position"] as Vector2).distance_to(player.position) < 120.0:
			obs.append("%s r=%s" % [str(o["position"]), str(o["radius"])])
	print("   [obstaculos] %s margin=%s tile=%s" % [str(obs), str(grid.wall_margin), str(TileGrid.TILE)])
	for dr: int in range(-4, 5):
		var line := "   "
		for dc: int in range(-4, 5):
			var c := here.x + dc
			var r := here.y + dr
			var f: int = bot._safe_field[r * grid.cols + c] if bot._field_grid == grid and bot._safe_field.size() > r * grid.cols + c else -9
			line += ("#### " if grid.blocks_move(c, r) else "%4d " % f)
		print(line)
	var moves := []
	for step: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		moves.append("%s->%s" % [str(step), str(world.resolve_position(player.position + step * 12.0, PlayerSim.RADIUS).distance_to(player.position))])
	print("   [mov] %s" % str(moves))

## Diagnostico de un piso que no se termina: que queda vivo y donde esta el bot.
static func _report_stuck(world: CombatWorld, session: GameSession, bot: FloorBot) -> void:
	print("   [atascado] jugador %s hp %d, mision %s" % [str(world.player.position), int(world.player.health), str(session.mission_lines().map(func(l: Dictionary) -> String: return String(l["text"])))])
	for enemy: EnemySim in world.enemies:
		if enemy.alive:
			print("   [vivo] %s %s inv=%s req=%s group=%s" % [enemy.def_id, str(enemy.position), str(enemy.invulnerable), str(enemy.required), str(enemy.group)])
	print("   [objetivo] %s stuck=%d" % [str(bot._target.position) if bot._target != null else "-", bot._stuck])


## En la ciudad antes de cada piso: vende lo que sobra, compra pociones con el oro y se come lo que lleve.
static func _prepare(player: PlayerSim) -> void:
	player.safe_zone = true
	for index: int in range(player.bag.size() - 1, -1, -1):
		player.sell_from_bag(index)
	while player.consumable_count("health_potion") < 4 and bool(Services.buy_consumable(player, "health_potion")["ok"]):
		pass
	while player.consumable_count("resource_potion") < 2 and bool(Services.buy_consumable(player, "resource_potion")["ok"]):
		pass
	for food: String in ["herb_bread", "hunters_stew", "silk_tea"]:
		if player.consumable_count(food) == 0:
			Services.buy_consumable(player, food)
		player.use_consumable(food)
	player.safe_zone = false


static func _discard_worst(player: PlayerSim) -> void:
	var worst := 0
	var worst_value := 1 << 30
	for index: int in range(player.bag.size()):
		var value := ItemCatalog.sell_value(player.bag[index])
		if value < worst_value:
			worst_value = value
			worst = index
	player.discard_from_bag(worst)
