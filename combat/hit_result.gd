## HitResult — Resultado autoritativo de impacto decidido por el servidor (ISSUE P0.5).
class_name HitResult
extends RefCounted

var attacker_id: int = 0
var target_id: int = 0
var damage: float = 0.0
var is_critical: bool = false
var tick: int = 0
var accepted: bool = false


func to_dict() -> Dictionary:
	return {
		"attacker_id": attacker_id,
		"target_id": target_id,
		"damage": damage,
		"is_critical": is_critical,
		"tick": tick,
		"accepted": accepted
	}


static func from_dict(data: Dictionary):
	var res = new()
	res.attacker_id = data.get("attacker_id", 0)
	res.target_id = data.get("target_id", 0)
	res.damage = data.get("damage", 0.0)
	res.is_critical = data.get("is_critical", false)
	res.tick = data.get("tick", 0)
	res.accepted = data.get("accepted", false)
	return res
