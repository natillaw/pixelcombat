## ClassResource — Recurso único de clase (Fury/Energy/Concentration/Faith/Heat) (ISSUE P1.2).
class_name ClassResource
extends RefCounted

var resource_name: String = "Fury"
var current_amount: float = 0.0
var max_amount: float = 100.0
var min_amount: float = 0.0


func generate(amount: float) -> void:
	current_amount = minf(current_amount + amount, max_amount)


func consume(amount: float) -> bool:
	if current_amount >= amount:
		current_amount -= amount
		return true
	return false


func consume_all() -> float:
	var amount = current_amount
	current_amount = 0.0
	return amount


func get_current() -> float:
	return current_amount


func is_full() -> bool:
	return current_amount >= max_amount
