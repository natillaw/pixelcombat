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
## Enemigos a los que no hay camino desde donde esta el bot (se descartan y se prueba con otro).
var _ignored: Array = []


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
	if cell != _goal_cell:
		_goal_cell = cell
		_field = world.grid.distance_field(cell, 100000)
	var here := world.grid.world_to_cell(player.position)
	if _field[here.y * world.grid.cols + here.x] < 0 and _target != null:
		_ignored.append(_target)
		_target = null
		return message
	var direction := world.grid.flow_direction(_field, player.position)
	if direction == Vector2.ZERO:
		direction = ((goal as EnemySim).position - player.position).normalized()
	# Atascado contra un obstaculo (arbol, roca): rodearlo de lado y alternar el lado.
	_stuck = _stuck + 1 if player.position.distance_to(_last_position) < 0.8 else 0
	_last_position = player.position
	if _stuck > 12:
		var side := 1.0 if (_stuck / 50) % 2 == 0 else -1.0
		direction = direction.rotated(side * PI * 0.5)
		if _stuck > 400:
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
