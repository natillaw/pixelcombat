## RogueResource — Gestión de recursos duales de la clase Rogue (Energy y Combo Points) (Phase 2).
class_name RogueResource
extends RefCounted

var resource_name: String = "Energy"
var current_amount: float = 100.0
var max_amount: float = 100.0
var min_amount: float = 0.0

var combo_points: int = 0
var max_combo_points: int = 5


func generate(amount: float) -> void:
	current_amount = minf(current_amount + amount, max_amount)


func consume(amount: float) -> bool:
	if current_amount >= amount:
		current_amount -= amount
		return true
	return false


func get_current() -> float:
	return current_amount


func add_combo_point(points: int = 1) -> void:
	combo_points = mini(combo_points + points, max_combo_points)


func consume_combo_points() -> int:
	var pts = combo_points
	combo_points = 0
	return pts


func get_combo_points() -> int:
	return combo_points
