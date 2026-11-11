## InputMessage — Estructura de datos para los inputs del cliente por tick (ISSUE P0.4).
class_name InputMessage
extends RefCounted

var tick: int = 0
var peer_id: int = 0
var move_dir: Vector2 = Vector2.ZERO
## World-space direction the player is aiming at (normalised by the receiver).
var aim_dir: Vector2 = Vector2.RIGHT
var actions: Dictionary = {} # e.g. { "m1": true, "m2": false }
## Punto del mundo bajo el cursor (para recoger/recolectar lo que se clica).
var target_pos: Vector2 = Vector2.ZERO


func to_dict() -> Dictionary:
	return {
		"tick": tick,
		"peer_id": peer_id,
		"move_dir": [move_dir.x, move_dir.y],
		"aim_dir": [aim_dir.x, aim_dir.y],
		"actions": actions,
		"target_pos": [target_pos.x, target_pos.y]
	}


static func from_dict(data: Dictionary):
	var msg = new()
	msg.tick = data.get("tick", 0)
	msg.peer_id = data.get("peer_id", 0)
	var arr = data.get("move_dir", [0, 0])
	msg.move_dir = Vector2(arr[0], arr[1])
	var aim = data.get("aim_dir", [1, 0])
	msg.aim_dir = Vector2(aim[0], aim[1])
	msg.actions = data.get("actions", {})
	var target = data.get("target_pos", [0, 0])
	msg.target_pos = Vector2(target[0], target[1])
	return msg
