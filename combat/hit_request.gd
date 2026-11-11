## HitRequest — Solicitud de impacto enviada del cliente al servidor (ISSUE P0.5).
class_name HitRequest
extends RefCounted

var attacker_id: int = 0
var target_id: int = 0
var skill_id: StringName = &""
var tick: int = 0


func to_dict() -> Dictionary:
	return {
		"attacker_id": attacker_id,
		"target_id": target_id,
		"skill_id": String(skill_id),
		"tick": tick
	}


static func from_dict(data: Dictionary):
	var req = new()
	req.attacker_id = data.get("attacker_id", 0)
	req.target_id = data.get("target_id", 0)
	req.skill_id = StringName(data.get("skill_id", ""))
	req.tick = data.get("tick", 0)
	return req
