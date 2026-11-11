## DamageEffect — Efecto de daño estandarizado (ISSUE P1.1).
class_name DamageEffect
extends "res://combat/effect.gd"

@export var base_damage: float = 10.0


func apply(context: Object) -> void:
	context.effect_type = "damage"
	context.amount = base_damage
