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
	var goal: Variant = _goal(world)
	if goal == null or world.grid == null:
		return message
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
		return message
	var direction := _safe_direction(world.grid, player.position)
	if direction == Vector2.ZERO:
		direction = world.grid.flow_direction(_field, player.position)
	if direction == Vector2.ZERO:
		direction = ((goal as EnemySim).position - player.position).normalized()
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
