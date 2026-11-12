## GroundZone — zona persistente en el suelo que dejan algunos ataques de jefe (grietas, charcos,
## campos malditos). Mientras dura, el jugador que esta dentro recibe dano y estados cada `tick`
## segundos. Lo avanza CombatWorld; la presentacion (ZoneActor) solo lo lee.
class_name GroundZone
extends RefCounted

var position: Vector2 = Vector2.ZERO
var radius: float = 60.0
var duration: float = 4.0
var age: float = 0.0
var tick: float = 0.5
var damage: float = 0.0
var effects: Array = []
var visual: String = "dark"
var alive: bool = true
var _tick_left: float = 0.0


func _init(spec: Dictionary, at: Vector2, base_damage: float) -> void:
	position = at
	radius = float(spec["radius"])
	duration = float(spec["duration"])
	tick = float(spec.get("tick", 0.5))
	damage = base_damage * float(spec.get("damage_mult", 0.3))
	effects = spec.get("status", [])
	visual = String(spec.get("visual", "dark"))
	_tick_left = float(spec.get("delay", 0.6))


func step(delta: float, player: PlayerSim) -> void:
	age += delta
	if age >= duration:
		alive = false
		return
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left += tick
	if player == null or not player.alive or player.position.distance_to(position) > radius + PlayerSim.RADIUS:
		return
	if damage > 0.0:
		player.take_damage(damage, position, false)
	for effect: Dictionary in effects:
		player.apply_status(String(effect["id"]), float(effect["duration"]), float(effect.get("strength", 0.0)), position)
