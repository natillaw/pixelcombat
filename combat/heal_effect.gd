## HealEffect — Efecto de curación estandarizado (ISSUE P1.1).
class_name HealEffect
extends "res://combat/effect.gd"

@export var base_heal: float = 10.0


func apply(context: Object) -> void:
	context.effect_type = "heal"
	context.amount = base_heal
