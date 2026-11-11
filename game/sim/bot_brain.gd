## BotBrain — IA sencilla que juega a una clase, para el laboratorio de balance y
## los tests. Elige el blanco mas cercano, apunta, mantiene la distancia que le
## conviene a su clase, usa las skills en cuanto estan listas y alcanzan, carga el
## M2 hasta el maximo y, si se le pide, esquiva los golpes avisados.
##
## No hace trampas: solo lee el estado publico de la simulacion y devuelve el mismo
## InputMessage que el teclado y el raton (con pulsaciones de un tick para que el
## input por flancos de la simulacion las vea).
class_name BotBrain
extends RefCounted

const PRESS_ORDER := ["ULTIMATE", "SPECIAL", "S1", "S2", "S3", "S4", "S5", "M2"]
const SLOT_ACTION := {"M2": "m2", "S1": "s1", "S2": "s2", "S3": "s3", "S4": "s4", "S5": "s5", "SPECIAL": "special", "ULTIMATE": "ultimate"}

## Si esquiva los ataques de los enemigos (Espacio) cuando ya van a caer.
var dodge_enemies: bool = false
## Si usa las posturas defensivas del Special (Iron Counter, Perfect Evasion):
## solo las abre cuando un enemigo esta a punto de golpearle.
var use_stances: bool = false
## Distancia a la que se queda un bot a distancia (px).
var ranged_distance: float = 170.0

var _pressed_last: Dictionary = {}
var _world: CombatWorld = null


func decide(world: CombatWorld) -> InputMessage:
	var message := InputMessage.new()
	message.peer_id = 1
	message.actions = {}
	_world = world
	var player: PlayerSim = world.player
	var target := _nearest_target(world)
	if target == null or not player.alive:
		_pressed_last = {}
		return message

	var to_target: Vector2 = target.position - player.position
	var distance := to_target.length()
	message.aim_dir = to_target.normalized() if distance > 0.001 else player.aim_dir
	var ranged := String((player.loadout.get("M1", {}) as Dictionary).get("shape", "cone")) == "projectile"
	var preferred := ranged_distance if ranged else maxf(24.0, _reach(player.loadout["M1"], target) * 0.6)

	# Movimiento: acercarse hasta la distancia deseada y, si es a distancia, no
	# dejarse alcanzar.
	if distance > preferred + 12.0:
		message.move_dir = message.aim_dir
	elif ranged and distance < preferred - 45.0:
		message.move_dir = -message.aim_dir

	if dodge_enemies and _should_dodge(world, player):
		message.actions["dodge"] = not bool(_pressed_last.get("dodge", false))

	var committed := player.state != PlayerSim.AttackState.IDLE
	message.actions["m1"] = distance <= _reach(player.loadout["M1"], target)

	# M2: se mantiene pulsado mientras se carga.
	if committed and String(player.current_skill.get("slot", "")) == "M2" and player.state == PlayerSim.AttackState.WINDUP:
		message.actions["m2"] = true
	if not committed:
		for slot: String in PRESS_ORDER:
			if not _can_use(player, slot, distance, target):
				continue
			var action: String = SLOT_ACTION[slot]
			if bool(_pressed_last.get(action, false)):
				continue
			message.actions[action] = true
			break
	_pressed_last = message.actions.duplicate()
	return message


func _nearest_target(world: CombatWorld) -> Object:
	var best: Object = null
	var best_distance := INF
	for target: Object in world.get_living_targets():
		var distance: float = target.position.distance_to(world.player.position)
		if distance < best_distance:
			best_distance = distance
			best = target
	return best


## Alcance util de una skill contra un blanco (px desde el centro del jugador).
func _reach(skill: Dictionary, target: Object) -> float:
	var radius := float(target.radius)
	match String(skill.get("shape", "cone")):
		"projectile":
			return float(skill["projectile"]["range"]) * 0.85
		"self":
			return 1000.0
		_:
			var base := float(skill.get("range", 0.0)) + radius
			if String(skill.get("anchor", "self")) == "aim_leap":
				base += float(skill["leap_distance"])
			elif String(skill.get("anchor", "self")) == "aim_point":
				base = float(skill["point_distance"]) + float(skill.get("range", 0.0)) * 0.5
			return base


func _can_use(player: PlayerSim, slot: String, distance: float, target: Object) -> bool:
	if not player.loadout.has(slot):
		return false
	var skill: Dictionary = player.loadout[slot]
	if player.attack_cooldown_left(slot) > 0.0:
		return false
	if player.resource_amount() < float(skill.get("cost", 0.0)) or player.ultimate_charge < float(skill.get("charge", 0.0)):
		return false
	if skill.has("charges") and player.charges_left(slot) < 1.0:
		return false
	if skill.has("stance"):
		return use_stances and _enemy_about_to_hit(player, float(skill["windup"]))
	if skill.has("buff"):
		return player.empower_mult <= 1.0 and distance <= 260.0
	if String(skill.get("shape", "cone")) == "circle" and String(skill.get("anchor", "self")) == "self":
		return distance <= float(skill["range"]) + float(target.radius) - 6.0
	if String(skill.get("anchor", "self")) == "aim_point":
		# La zona cae a point_distance hacia el cursor: solo vale si el blanco queda dentro.
		var half := float(skill["range"]) * 0.6
		return absf(distance - float(skill["point_distance"])) <= half
	return distance <= _reach(skill, target)


## Un enemigo cercano esta avisando un ataque que caera mientras la postura (que
## tarda `windup` en abrirse) ya este abierta.
func _enemy_about_to_hit(player: PlayerSim, windup: float) -> bool:
	for enemy: EnemySim in _world.enemies:
		if not enemy.alive or not enemy.is_telegraphing():
			continue
		var left := float(enemy.current_attack["windup"]) * (1.0 - enemy.telegraph_progress())
		if left > windup + 0.05 and left < windup + 0.35 and enemy.position.distance_to(player.position) <= float(enemy.current_attack["range"]) + 24.0:
			return true
	return false


## Hay un ataque de enemigo a punto de caer sobre el jugador (progreso del aviso
## alto y el jugador dentro de su alcance).
func _should_dodge(world: CombatWorld, player: PlayerSim) -> bool:
	if player.dodge_cooldown_left() > 0.0 or player.dodging:
		return false
	for enemy: EnemySim in world.enemies:
		if not enemy.alive or not enemy.is_telegraphing():
			continue
		if enemy.telegraph_progress() < 0.62:
			continue
		if enemy.position.distance_to(player.position) <= float(enemy.current_attack["range"]) + 22.0:
			return true
	return false
