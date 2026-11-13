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


func decide(world: CombatWorld) -> InputMessage:
	var player: PlayerSim = world.player
	if not player.alive:
		return super.decide(world)
	var near := _nearest_target(world)
	if near != null:
		return super.decide(world)
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
	var here := world.grid.world_to_cell(player.position)
	if world.grid.in_bounds(here.x, here.y) and _field[here.y * world.grid.cols + here.x] < 0 and _target != null:
		_ignored.append(_target)
		_target = null
		# Si ya no queda ninguno al que haya camino, se vuelve a intentar con todos (el mapa cambia al moverse).
		if _ignored.size() > world.enemies.size():
			_ignored.clear()
		return message
	var direction := world.grid.flow_direction(_field, player.position)
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
