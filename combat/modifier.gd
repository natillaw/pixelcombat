## StatModifier — Modificador de stat aditivo o multiplicativo (ISSUE P1.2).
class_name StatModifier
extends RefCounted

enum Type { FLAT, PERCENT }

var type: Type = Type.FLAT
var value: float = 0.0
var source: Object = null


func _init(p_type: Type, p_value: float, p_source: Object = null) -> void:
	type = p_type
	value = p_value
	source = p_source
