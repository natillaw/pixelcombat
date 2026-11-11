## StatBlock — Bloque de stat con cálculo aditivo -> multiplicativo -> cap (ISSUE P1.2).
class_name StatBlock
extends RefCounted

const StatModifierScript = preload("res://combat/modifier.gd")

var base_value: float = 0.0
var min_value: float = -INF
var max_value: float = INF
var modifiers: Array = [] ## Array of StatModifier


func add_modifier(modifier: Object) -> void:
	modifiers.append(modifier)


func remove_modifier(modifier: Object) -> void:
	modifiers.erase(modifier)


func get_value() -> float:
	var flat_sum: float = 0.0
	var percent_multiplier: float = 1.0

	for mod in modifiers:
		if mod.type == StatModifierScript.Type.FLAT:
			flat_sum += mod.value
		elif mod.type == StatModifierScript.Type.PERCENT:
			percent_multiplier *= (1.0 + mod.value)

	var final_val = (base_value + flat_sum) * percent_multiplier
	return clampf(final_val, min_value, max_value)
