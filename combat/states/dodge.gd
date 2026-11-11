## DodgeState — Estado de esquiva con iframes (ISSUE P1.4).
class_name DodgeState
extends "res://combat/states/base_state.gd"

var duration: float = 0.25
var iframe_duration: float = 0.15
var elapsed: float = 0.0


func enter(actor: Object) -> void:
	elapsed = 0.0
	if actor.has_method("set_invulnerable"):
		actor.set_invulnerable(true)


func exit(actor: Object) -> void:
	if actor.has_method("set_invulnerable"):
		actor.set_invulnerable(false)


func update(_actor: Object, delta: float) -> StringName:
	elapsed += delta
	if elapsed >= iframe_duration and _actor.has_method("set_invulnerable"):
		_actor.set_invulnerable(false)

	if elapsed >= duration:
		return &"idle"
	return &""
