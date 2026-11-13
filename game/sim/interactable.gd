## Interactable — un objeto del mundo con el que se interactua (altar, baliza, jaula,
## reliquia, sello...), sobre todo para las misiones de los pisos.
##
## Se usa con clic izquierdo estando cerca y quieto, igual que recolectar: canaliza
## `channel_seconds` y queda hecho. Los `waypoint` no se clican: se activan al pasar
## cerca. `group` los une a una mision (para contar cuantos van) y `requires` pide
## llevar algo (la reliquia) para poder usarlos.
class_name Interactable
extends RefCounted

## A que distancia del cursor debe estar para contar como clicado.
const CLICK_RADIUS := 26.0
## A que distancia pasa un waypoint a estar hecho.
const WAYPOINT_RADIUS := 70.0

var kind: String
var position: Vector2
var label: String = ""
var channel_seconds: float = 2.0
var group: String = ""
var requires: String = ""
var done: bool = false
## Efectos al usarlo (ver CombatWorld.apply_effects), grupo exclusivo (al usar uno se cierran los demas del grupo) y texto.
var effects: Array = []
var exclusive: String = ""
var text: String = ""
## Cofres: "wood", "iron" o "gold" (camara sellada); solo cambia el aspecto y el botin.
var tier: String = ""


func _init(p_kind: String, p_position: Vector2, p_group: String = "", p_channel: float = 2.0, p_requires: String = "", p_label: String = "") -> void:
	kind = p_kind
	position = p_position
	group = p_group
	channel_seconds = p_channel
	requires = p_requires
	label = p_label


func clickable() -> bool:
	return not done and kind != "waypoint"


func gather_seconds() -> float:
	return channel_seconds


func display_name() -> String:
	return label if label != "" else kind
