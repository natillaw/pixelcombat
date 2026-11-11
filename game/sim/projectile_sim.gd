## ProjectileSim — proyectil determinista (flecha, hechizo, daga...).
##
## Lo lanza PlayerSim con el dano ya calculado y lo avanza CombatWorld en cada
## tick. Vuela en linea recta, golpea a los blancos (enemigos y muñecos) que toca,
## atraviesa `pierce` de ellos, y puede explotar al impactar. Muere al agotar su
## alcance, al salir de la arena o al chocar con un obstaculo. Es simulacion pura:
## la presentacion (ProjectileActor) solo lo lee.
class_name ProjectileSim
extends RefCounted

var owner: Object = null
var skill: Dictionary = {}
var position: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.RIGHT
var speed: float = 400.0
var radius: float = 5.0
var range_left: float = 300.0
var pierce_left: int = 0
var damage_mult: float = 1.0
## Tope de recurso / carga de ultimate del lanzamiento (compartido entre todos
## los proyectiles de una misma salva).
var tracker: Dictionary = {}
var explode: Dictionary = {}
var visual: String = "arrow"
var alive: bool = true
var travelled: float = 0.0

var _already_hit: Dictionary = {}


func _init(p_owner: Object, p_skill: Dictionary, p_direction: Vector2, p_position: Vector2, p_damage_mult: float, p_range_mult: float, p_tracker: Dictionary) -> void:
	owner = p_owner
	skill = p_skill
	direction = p_direction.normalized()
	position = p_position
	damage_mult = p_damage_mult
	tracker = p_tracker
	var spec: Dictionary = p_skill["projectile"]
	speed = float(spec["speed"])
	radius = float(spec["radius"])
	range_left = float(spec["range"]) * p_range_mult
	pierce_left = int(spec["pierce"])
	explode = spec.get("explode", {})
	visual = String(spec["visual"])


func step(world: Object, delta: float) -> void:
	if not alive:
		return
	var distance := minf(speed * delta, range_left)
	position += direction * distance
	range_left -= distance
	travelled += distance

	for target: Object in world.get_living_targets():
		var id := target.get_instance_id()
		if _already_hit.has(id):
			continue
		if position.distance_to(target.position) > radius + float(target.radius):
			continue
		_already_hit[id] = true
		owner.projectile_hit(self, target)
		if not explode.is_empty():
			_explode(world, target)
			alive = false
			return
		if pierce_left <= 0:
			alive = false
			return
		pierce_left -= 1

	if range_left <= 0.0 or not world.bounds.has_point(position) or world.blocked_by_obstacle(position, radius):
		alive = false


## La explosion alcanza a todo lo que este a su radio del impacto, salvo al blanco
## que ya recibio el golpe directo.
func _explode(world: Object, direct_target: Object) -> void:
	var blast_radius := float(explode["radius"])
	for target: Object in world.get_living_targets():
		if target == direct_target:
			continue
		if position.distance_to(target.position) <= blast_radius + float(target.radius):
			owner.projectile_hit(self, target, float(explode["mult"]))


func snapshot() -> Dictionary:
	return {"position": [position.x, position.y], "visual": visual, "range_left": range_left}
