## CharacterStateMachine — Máquina de estados del personaje (ISSUE P1.4).
class_name CharacterStateMachine
extends RefCounted

var states: Dictionary = {} ## StringName -> CharacterState
var current_state_name: StringName = &"idle"
var current_state: Object = null
var actor: Object = null
var is_invulnerable: bool = false


func _init(p_actor: Object) -> void:
	actor = p_actor


func add_state(name: StringName, state: Object) -> void:
	states[name] = state


func change_state(name: StringName) -> void:
	if not states.has(name):
		return
	if current_state:
		current_state.exit(actor)
	current_state_name = name
	current_state = states[name]
	current_state.enter(actor)


func update(delta: float) -> void:
	if current_state:
		var next_state = current_state.update(actor, delta)
		if next_state != &"" and next_state != current_state_name:
			change_state(next_state)


func set_invulnerable(value: bool) -> void:
	is_invulnerable = value
