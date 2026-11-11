## HitResolver — Validador autoritativo de impactos en el servidor (ISSUE P0.5).
class_name HitResolver
extends RefCounted

const HitResultScript = preload("res://combat/hit_result.gd")
const MAX_MELEE_RANGE: float = 50.0


func resolve_hit(request: Object, attacker_pos: Vector2, target_pos: Vector2) -> Object:
	var result = HitResultScript.new()
	result.attacker_id = request.attacker_id
	result.target_id = request.target_id
	result.tick = request.tick

	# Validación autoritativa: distancia y reglas del servidor
	var distance = attacker_pos.distance_to(target_pos)
	if distance <= MAX_MELEE_RANGE:
		result.accepted = true
		result.damage = 25.0 # Daño base autoritativo de skill
		result.is_critical = false
	else:
		result.accepted = false
		result.damage = 0.0
		result.is_critical = false

	return result
