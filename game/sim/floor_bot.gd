## FloorBot — un BotBrain que recorre un piso entero: pelea a los enemigos cercanos (con la
## logica de combate de BotBrain) y, si no hay ninguno a la vista, navega hasta el siguiente por el
## campo de flujo del mapa. Lo usa el laboratorio de campana (CampaignLab) para medir el ritmo y la
## dificultad reales de los pisos; juega con el mismo InputMessage que una persona.
class_name FloorBot
extends BotBrain

## A que distancia empieza a pelear con un enemigo (px).
var engage_distance: float = 300.0
## Descansa (parado) si baja de este porcentaje de vida y no hay enemigos cerca.
var rest_below: float = 0.0
var _goal_cell: Vector2i = Vector2i(-1, -1)
## false = juega como una persona: solo conoce lo que ha visto (casillas, enemigos, objetos); explora por el borde de lo
## desconocido y va a por lo que ve. true = el comportamiento antiguo (conoce el mapa y donde esta cada enemigo).
var knows_map: bool = false
## Hasta donde ve el bot (px), con linea de vision.
var vision_radius: float = 460.0
var _known: PackedByteArray = PackedByteArray()
var _known_grid: TileGrid = null
var _seen_enemies: Array = []
var _seen_loot: Array = []
var _path: Array[Vector2] = []
var _replan_ticks: int = 0
var _tick_count: int = 0
## Se acabo lo que explorar sin completar el piso: recurre al metodo antiguo para rematar (enemigos escondidos).
var _exhausted: bool = false
var _field: PackedInt32Array = PackedInt32Array()
var _last_position: Vector2 = Vector2.ZERO
var _stuck: int = 0
var _target: EnemySim = null
var _unstick_direction: Vector2 = Vector2.ZERO
var _unstick_ticks: int = 0
## Enemigos a los que no hay camino desde donde esta el bot (se descartan y se prueba con otro).
var _ignored: Array = []
var _field_grid: TileGrid = null
var _fight_stuck: int = 0
var _fight_last: Vector2 = Vector2.ZERO
var _path_ticks: int = 0
## Casillas con holgura suficiente para el cuerpo del jugador (por piso) y el campo de flujo por ellas.
var _open: PackedByteArray = PackedByteArray()
var _safe_field: PackedInt32Array = PackedInt32Array()


func decide(world: CombatWorld) -> InputMessage:
	var player: PlayerSim = world.player
	if not player.alive:
		return super.decide(world)
	var near := _nearest_target(world)
	if near != null:
		return _fight(world, near)
	var message := InputMessage.new()
	message.peer_id = 1
	message.actions = {}
	var health_ratio := player.health / maxf(player.max_health, 1.0)
	if rest_below > 0.0 and health_ratio < rest_below:
		return message
	if world.grid == null:
		return message
	_tick_count += 1
	_ensure_known(world.grid)
	var direction := Vector2.ZERO
	if knows_map or _exhausted:
		var known_direction := _known_map_direction(world, player)
		if known_direction == Vector2.INF:
			return message
		direction = known_direction
	else:
		_reveal(world)
		_pickup_near(world, message)
		direction = _explore_direction(world, player)
		if direction == Vector2.ZERO:
			return message
	# Atascado contra un obstaculo (arbol pegado a un muro, esquina): prueba varias salidas y sigue la que mas avanza.
	_stuck = _stuck + 1 if player.position.distance_to(_last_position) < 0.8 else 0
	_last_position = player.position
	if _unstick_ticks > 0:
		_unstick_ticks -= 1
		direction = _unstick_direction
	elif _stuck > 10:
		_unstick_direction = _best_escape(world, player, direction)
		_unstick_ticks = 40
		_stuck = 0
	message.move_dir = direction
	message.aim_dir = direction
	return message


func _known_map_direction(world: CombatWorld, player: PlayerSim) -> Vector2:
	## Comportamiento antiguo: Vector2.INF = no hay nada que hacer (quedarse quieto).
	var goal: Variant = _goal(world)
	if goal == null:
		return Vector2.INF
	var cell := world.grid.world_to_cell((goal as EnemySim).position)
	if cell != _goal_cell or _field_grid != world.grid:
		_goal_cell = cell
		_field_grid = world.grid
		_field = world.grid.distance_field(cell, 100000)
		_safe_field = _build_safe_field(world.grid, cell)
	var here := world.grid.world_to_cell(player.position)
	if world.grid.in_bounds(here.x, here.y) and _field[here.y * world.grid.cols + here.x] < 0 and _target != null:
		_ignored.append(_target)
		_target = null
		# Si ya no queda ninguno al que haya camino, se vuelve a intentar con todos (el mapa cambia al moverse).
		if _ignored.size() > world.enemies.size():
			_ignored.clear()
		return Vector2.INF
	var direction := _safe_direction(world.grid, player.position)
	if direction == Vector2.ZERO:
		direction = world.grid.flow_direction(_field, player.position)
	if direction == Vector2.ZERO:
		direction = ((goal as EnemySim).position - player.position).normalized()
	return direction


# --- Exploracion como una persona (sin conocer el mapa) -------------------------------------


func _ensure_known(grid: TileGrid) -> void:
	if _known_grid != grid:
		_known_grid = grid
		_known.resize(grid.cols * grid.rows)
		_known.fill(0)
		_seen_enemies.clear()
		_seen_loot.clear()
		_path.clear()
		_exhausted = false
		_replan_ticks = 0
		_ensure_open(grid)


## Casillas con holgura para el cuerpo (una sola vez por piso).
func _ensure_open(grid: TileGrid) -> void:
	var cells := grid.cols * grid.rows
	if _open.size() == cells and _open_grid == grid:
		return
	_open_grid = grid
	var clearance := TowerGenerator._clearance_px(grid)
	var radius := PlayerSim.RADIUS + grid.wall_margin * TileGrid.NORTH_MARGIN_FACTOR
	_open.resize(cells)
	for i: int in range(cells):
		_open[i] = 1 if clearance[i] >= radius and not grid.blocks_move(i % grid.cols, i / grid.cols) else 0


## Descubre lo que ve el bot: las casillas a la vista (y sus vecinas, muros incluidos), los enemigos y el botin.
func _reveal(world: CombatWorld) -> void:
	var grid := world.grid
	_ensure_known(grid)
	if _tick_count % 6 != 1:
		return
	var origin := world.player.position
	var here := grid.world_to_cell(origin)
	var span := int(ceil(vision_radius / TileGrid.TILE))
	for r: int in range(here.y - span, here.y + span + 1):
		for c: int in range(here.x - span, here.x + span + 1):
			if not grid.in_bounds(c, r) or _known[r * grid.cols + c] == 1:
				continue
			var center := grid.cell_center(c, r)
			if center.distance_to(origin) > vision_radius:
				continue
			if absi(c - here.x) <= 1 and absi(r - here.y) <= 1 or grid.line_clear(origin, center):
				for dr: int in range(-1, 2):
					for dc: int in range(-1, 2):
						if grid.in_bounds(c + dc, r + dr):
							_known[(r + dr) * grid.cols + c + dc] = 1
	for enemy: EnemySim in world.enemies:
		if enemy.alive and not _seen_enemies.has(enemy) and enemy.position.distance_to(origin) <= vision_radius and world.line_of_sight(origin, enemy.position):
			_seen_enemies.append(enemy)
	_seen_enemies = _seen_enemies.filter(func(e: EnemySim) -> bool: return e.alive and world.enemies.has(e))
	for drop: LootDrop in world.loot_drops:
		if not _seen_loot.has(drop) and drop.position.distance_to(origin) <= vision_radius and grid.line_clear(origin, drop.position):
			_seen_loot.append(drop)
	_seen_loot = _seen_loot.filter(func(d: LootDrop) -> bool: return world.loot_drops.has(d))


## Como un clic de recoger: junto a un objeto que ya ha visto, pulsa recoger sobre el.
func _pickup_near(world: CombatWorld, message: InputMessage) -> void:
	for drop: LootDrop in _seen_loot:
		if drop.position.distance_to(world.player.position) <= 48.0:
			message.target_pos = drop.position
			message.actions["pickup"] = _tick_count % 2 == 0
			return


## Hacia donde andar: sigue el camino planificado (hacia lo que ha visto o hacia el borde de lo desconocido).
func _explore_direction(world: CombatWorld, player: PlayerSim) -> Vector2:
	_replan_ticks -= 1
	if _path.is_empty() or _replan_ticks <= 0:
		_plan(world, player)
		_replan_ticks = 20
	while not _path.is_empty() and player.position.distance_to(_path[0]) < 20.0:
		_path.remove_at(0)
	if _path.is_empty():
		return Vector2.ZERO
	return (_path[0] - player.position).normalized()


## BFS desde el jugador por casillas conocidas hasta lo mas cercano de: botin visto, enemigo visto o borde de lo desconocido.
func _plan(world: CombatWorld, player: PlayerSim) -> void:
	var grid := world.grid
	var cols := grid.cols
	var start := grid.world_to_cell(player.position)
	var goals: Dictionary = {}
	for drop: LootDrop in _seen_loot:
		var cell := grid.world_to_cell(drop.position)
		goals[cell.y * cols + cell.x] = true
	for enemy: EnemySim in _seen_enemies:
		if enemy.invulnerable or enemy.summoned:
			continue
		var cell := grid.world_to_cell(enemy.position)
		goals[cell.y * cols + cell.x] = true
	# Primero va a por lo que ya ha visto (enemigos, botin); solo si no hay nada, explora el borde de lo desconocido.
	var parents := PackedInt32Array()
	var found := -1
	for use_frontier: bool in [false, true]:
		if not use_frontier and goals.is_empty():
			continue
		parents = PackedInt32Array()
		parents.resize(cols * grid.rows)
		parents.fill(-2)
		found = _search(grid, start, goals, parents, use_frontier)
		if found >= 0:
			break
	_path.clear()
	if found < 0:
		_exhausted = true                       # nada mas que explorar: remata con el metodo antiguo
		return
	var index := found
	var reverse: Array[Vector2] = []
	while parents[index] >= 0:
		reverse.append(grid.cell_center(index % cols, index / cols))
		index = parents[index]
	reverse.reverse()
	_path = reverse


## BFS desde `start` por casillas conocidas y abiertas; devuelve la casilla de `goals` (o del borde de lo desconocido) mas cercana, o -1.
func _search(grid: TileGrid, start: Vector2i, goals: Dictionary, parents: PackedInt32Array, use_frontier: bool) -> int:
	var cols := grid.cols
	var queue: Array[int] = [start.y * cols + start.x]
	parents[queue[0]] = -1
	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		var cell := Vector2i(index % cols, index / cols)
		if goals.has(index) or (use_frontier and index != queue[0] and _is_frontier(grid, cell)):
			return index
		for dr: int in range(-1, 2):
			for dc: int in range(-1, 2):
				if dr == 0 and dc == 0:
					continue
				var next := Vector2i(cell.x + dc, cell.y + dr)
				if not grid.in_bounds(next.x, next.y):
					continue
				var next_index := next.y * cols + next.x
				if parents[next_index] != -2 or _known[next_index] == 0 or not (_open[next_index] == 1 or goals.has(next_index)):
					continue
				if dr != 0 and dc != 0 and (not _is_open(grid, Vector2i(cell.x + dc, cell.y)) or not _is_open(grid, Vector2i(cell.x, cell.y + dr))):
					continue
				parents[next_index] = index
				queue.append(next_index)
	return -1


## Casilla conocida y abierta con alguna vecina todavia desconocida.
func _is_frontier(grid: TileGrid, cell: Vector2i) -> bool:
	if not _is_open(grid, cell):
		return false
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var next := cell + offset
		if grid.in_bounds(next.x, next.y) and _known[next.y * grid.cols + next.x] == 0:
			return true
	return false


## Pelea con la logica de BotBrain; si el avance en linea recta se atasca contra un muro (el enemigo se ve pero hay
## una esquina de por medio), sigue el camino hasta el durante un rato.
func _fight(world: CombatWorld, target: Object) -> InputMessage:
	var message := super.decide(world)
	var player: PlayerSim = world.player
	_fight_stuck = _fight_stuck + 1 if message.move_dir != Vector2.ZERO and player.position.distance_to(_fight_last) < 0.5 else 0
	_fight_last = player.position
	if _path_ticks > 0:
		_path_ticks -= 1
		var field := world.grid.distance_field(world.grid.world_to_cell(target.position), 400) if world.grid != null else PackedInt32Array()
		var direction := world.grid.flow_direction(field, player.position) if field.size() > 0 else Vector2.ZERO
		if direction != Vector2.ZERO:
			message.move_dir = direction
	elif _fight_stuck > 20 and target.position.distance_to(player.position) > 50.0:
		_path_ticks = 90
		_fight_stuck = 0
	return message


## Solo se pelea con lo que esta cerca, a la vista y que se puede danar.
func _nearest_target(world: CombatWorld) -> Object:
	var best: Object = null
	var best_distance := engage_distance
	for target: Object in world.get_living_targets():
		if target is EnemySim and (target as EnemySim).invulnerable:
			continue
		var distance: float = target.position.distance_to(world.player.position)
		if distance < best_distance and (distance < 70.0 or world.line_of_sight(world.player.position, target.position)):
			best_distance = distance
			best = target
	return best


## El enemigo vivo mas cercano por camino (el que hay que matar para avanzar); los protegidos
## por un escudo se dejan para el final.
func _goal(world: CombatWorld) -> Variant:
	_ignored = _ignored.filter(func(e: EnemySim) -> bool: return world.enemies.has(e))
	if _target != null and _target.alive and world.enemies.has(_target):
		return _target
	var best: Variant = null
	var best_distance := INF
	for enemy: EnemySim in world.enemies:
		if not enemy.alive or enemy.summoned or enemy.invulnerable or _ignored.has(enemy):
			continue
		var distance := enemy.position.distance_to(world.player.position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	_target = best as EnemySim
	return best




## De varias direcciones alternativas, la que mas desplaza al jugador tras resolver las colisiones (la mejor salida
## de un hueco entre un arbol y un muro).
func _best_escape(world: CombatWorld, player: PlayerSim, blocked: Vector2) -> Vector2:
	var best := blocked.rotated(PI * 0.5)
	var best_gain := -1.0
	for angle: float in [PI * 0.5, -PI * 0.5, PI * 0.75, -PI * 0.75, PI, PI * 0.25, -PI * 0.25]:
		var candidate := blocked.rotated(angle)
		var moved := world.resolve_position(player.position + candidate * 24.0, PlayerSim.RADIUS)
		var gain := moved.distance_to(player.position)
		if gain > best_gain:
			best_gain = gain
			best = candidate
	return best


## Campo de flujo solo por casillas por las que cabe el cuerpo (radio del jugador + holgura de muros): un atajo
## de una casilla de ancho que el campo crudo da por bueno, la colision no deja cruzarlo.
func _build_safe_field(grid: TileGrid, goal: Vector2i) -> PackedInt32Array:
	var cells := grid.cols * grid.rows
	var field := PackedInt32Array()
	field.resize(cells)
	field.fill(-1)
	if _open.size() != cells or _open_grid != grid:
		_open_grid = grid
		var clearance := TowerGenerator._clearance_px(grid)
		var radius := PlayerSim.RADIUS + grid.wall_margin * TileGrid.NORTH_MARGIN_FACTOR
		_open.resize(cells)
		for i: int in range(cells):
			_open[i] = 1 if clearance[i] >= radius and not grid.blocks_move(i % grid.cols, i / grid.cols) else 0
	var start := goal
	if not _is_open(grid, goal):
		start = Vector2i(-1, -1)
		for ring: int in range(1, 4):
			for dr: int in range(-ring, ring + 1):
				for dc: int in range(-ring, ring + 1):
					if start.x < 0 and _is_open(grid, Vector2i(goal.x + dc, goal.y + dr)):
						start = Vector2i(goal.x + dc, goal.y + dr)
		if start.x < 0:
			return field
	var queue: Array[Vector2i] = [start]
	field[start.y * grid.cols + start.x] = 0
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		var here := field[cell.y * grid.cols + cell.x]
		for dr: int in range(-1, 2):
			for dc: int in range(-1, 2):
				if dr == 0 and dc == 0:
					continue
				var next := Vector2i(cell.x + dc, cell.y + dr)
				if not _is_open(grid, next) or field[next.y * grid.cols + next.x] != -1:
					continue
				if dr != 0 and dc != 0 and (not _is_open(grid, Vector2i(cell.x + dc, cell.y)) or not _is_open(grid, Vector2i(cell.x, cell.y + dr))):
					continue
				field[next.y * grid.cols + next.x] = here + 1
				queue.append(next)
	return field


var _open_grid: TileGrid = null


func _is_open(grid: TileGrid, cell: Vector2i) -> bool:
	return grid.in_bounds(cell.x, cell.y) and _open[cell.y * grid.cols + cell.x] == 1


## Direccion hacia la vecina abierta de menor distancia; ZERO si el bot no esta en una casilla del campo seguro.
func _safe_direction(grid: TileGrid, position: Vector2) -> Vector2:
	var cell := grid.world_to_cell(position)
	if _safe_field.size() == 0 or not grid.in_bounds(cell.x, cell.y):
		return Vector2.ZERO
	var here := _safe_field[cell.y * grid.cols + cell.x]
	if here <= 0:
		return Vector2.ZERO
	var best := here
	var best_cell := cell
	for dr: int in range(-1, 2):
		for dc: int in range(-1, 2):
			var next := Vector2i(cell.x + dc, cell.y + dr)
			if (dr == 0 and dc == 0) or not grid.in_bounds(next.x, next.y):
				continue
			var value := _safe_field[next.y * grid.cols + next.x]
			if value < 0 or value >= best:
				continue
			if dr != 0 and dc != 0 and (not _is_open(grid, Vector2i(cell.x + dc, cell.y)) or not _is_open(grid, Vector2i(cell.x, cell.y + dr))):
				continue
			best = value
			best_cell = next
	if best_cell == cell:
		return Vector2.ZERO
	return (grid.cell_center(best_cell.x, best_cell.y) - position).normalized()
