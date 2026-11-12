## Registers the input map at runtime (before the main scene loads).
##
## Keeping the map in code means the game and the headless suites share the
## exact same actions, and the project does not depend on editor-generated
## [input] blocks. Actions are never rebuilt twice (hot reload safe).
extends Node

const ACTIONS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"attack_m1": [],
	"attack_m2": [],
	"dodge": [KEY_SPACE],
	"skill_1": [KEY_1],
	"skill_2": [KEY_2],
	"skill_3": [KEY_3],
	"skill_4": [KEY_4],
	"skill_5": [KEY_5],
	"special": [KEY_Q],
	"ultimate": [KEY_F],
	"toggle_debug_overlay": [KEY_F3],
	"toggle_loadout": [KEY_TAB],
	"toggle_inventory": [KEY_I],
	"debug_level_up": [KEY_F5],
	"debug_level_reset": [KEY_F6],
	"debug_class_next": [KEY_F7],
	"restart_training": [KEY_R],
	"interact": [KEY_E],
	"floor_prev": [KEY_COMMA],
	"floor_next": [KEY_PERIOD],
	"quick_health": [KEY_H],
	"quick_resource": [KEY_J],
	"quit_game": [KEY_ESCAPE],
}


func _enter_tree() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for key: int in ACTIONS[action]:
			_add_key(action, key)
	_add_mouse_button("attack_m1", MOUSE_BUTTON_LEFT)
	_add_mouse_button("attack_m2", MOUSE_BUTTON_RIGHT)
	Settings.load_and_apply()


func _add_key(action: String, keycode: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	if not _has_event(action, event):
		InputMap.action_add_event(action, event)


func _add_mouse_button(action: String, button: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	if not _has_event(action, event):
		InputMap.action_add_event(action, event)


func _has_event(action: String, event: InputEvent) -> bool:
	for existing: InputEvent in InputMap.action_get_events(action):
		if existing.is_match(event):
			return true
	return false
