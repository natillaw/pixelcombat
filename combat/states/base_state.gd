## CharacterState — Estado base para la máquina de estados del personaje (ISSUE P1.4).
class_name CharacterState
extends RefCounted


func enter(_actor: Object) -> void:
	pass


func exit(_actor: Object) -> void:
	pass


func update(_actor: Object, _delta: float) -> StringName:
	return &""
