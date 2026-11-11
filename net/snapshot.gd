## Snapshot — Estado autoritativo del servidor por tick (ISSUE P0.4).
class_name Snapshot
extends RefCounted

var tick: int = 0
var entity_states: Dictionary = {} # peer_id -> { "position": [x, y], "velocity": [vx, vy], "health": 100 }


func to_dict() -> Dictionary:
	return {
		"tick": tick,
		"entity_states": entity_states
	}


static func from_dict(data: Dictionary):
	var snap = new()
	snap.tick = data.get("tick", 0)
	snap.entity_states = data.get("entity_states", {})
	return snap
