## LoadoutPanel — panel para equipar skills (Tab). Pausa la simulación mientras
## está abierto.
##
## A la izquierda los slots (S1-S5, Special y Ultimate); a la derecha el Skill
## Book completo con el estado de cada skill: equipada, disponible, bloqueada por
## nivel o aún sin implementar. Clic en una skill disponible la equipa (en el slot
## seleccionado o en el primero libre donde quepa); clic en una equipada, o clic
## derecho en un slot, la quita. Es presentación: solo llama a
## WarriorSim.equip()/unequip(), que son las que validan.
class_name LoadoutPanel
extends Control

const FONT := preload("res://assets/fonts/m5x7.ttf")

const PANEL := Color(0.055, 0.065, 0.095, 0.96)
const EDGE := Color(0.33, 0.37, 0.47, 1.0)
const TEXT := Color(0.93, 0.90, 0.83, 1.0)
const MUTED := Color(0.56, 0.60, 0.70, 1.0)
const DIM := Color(0.36, 0.39, 0.46, 1.0)
const GOLD := Color(0.94, 0.74, 0.36, 1.0)
const GREEN := Color(0.55, 0.82, 0.45, 1.0)
const RED := Color(0.88, 0.34, 0.28, 1.0)

const PANEL_RECT := Rect2(36, 14, 568, 332)
const SLOT_ROWS := ["S1", "S2", "S3", "S4", "S5", "SPECIAL", "ULTIMATE"]
const SLOT_KEYS := {"S1": "1", "S2": "2", "S3": "3", "S4": "4", "S5": "5", "SPECIAL": "Q", "ULTIMATE": "F"}
const SLOT_ROW_Y := 70.0
const SLOT_ROW_H := 24.0
const BOOK_ROW_Y := 62.0
const BOOK_ROW_H := 15.0

var world: CombatWorld
var is_open: bool = false

var _selected_slot: String = ""
var _message: String = ""
var _message_color: Color = MUTED
var _entries: Array = []


func bind(p_world: CombatWorld) -> void:
	world = p_world
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_process(false)


func _input(event: InputEvent) -> void:
	if world == null:
		return
	if event.is_action_pressed("toggle_loadout"):
		_toggle()
		get_viewport().set_input_as_handled()
	elif is_open and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	if not is_open and not world.warrior.can_edit_loadout():
		return
	is_open = not is_open
	visible = is_open
	set_process(is_open)
	TickManager.set_paused(is_open)
	if is_open:
		_selected_slot = ""
		_message = "Elige un hueco y una skill. Clic derecho en un hueco para vaciarlo."
		_message_color = MUTED
		_entries = _build_entries()
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventMouseButton) or not event.pressed:
		return
	var position := (event as InputEventMouseButton).position
	var button := (event as InputEventMouseButton).button_index
	var slot := _slot_at(position)
	if not slot.is_empty():
		if button == MOUSE_BUTTON_RIGHT:
			if world.warrior.unequip(slot):
				_say("Hueco %s vaciado." % slot, MUTED)
			_entries = _build_entries()
		else:
			_selected_slot = slot
		accept_event()
		return
	var entry := _entry_at(position)
	if not entry.is_empty() and button == MOUSE_BUTTON_LEFT:
		_click_skill(entry)
		accept_event()


func _click_skill(entry: Dictionary) -> void:
	var skill: Dictionary = entry["skill"]
	var id := StringName(String(skill["id"]))
	var warrior := world.warrior
	if not bool(skill.get("implemented", false)):
		_say("%s aún no está implementada." % skill["name"], DIM)
		return
	if int(skill["unlock_level"]) > warrior.level:
		_say("%s se desbloquea en el nivel %d." % [skill["name"], int(skill["unlock_level"])], RED)
		return
	var equipped_slot := _slot_of(id)
	if not equipped_slot.is_empty():
		if warrior.unequip(equipped_slot):
			_say("%s retirada de %s." % [skill["name"], equipped_slot], MUTED)
		_entries = _build_entries()
		return
	var target := _target_slot_for(skill)
	if target.is_empty():
		_say("No hay hueco donde quepa %s." % skill["name"], RED)
		return
	var result := warrior.equip(target, id)
	if result.is_empty():
		_say("%s equipada en %s." % [skill["name"], target], GREEN)
		_selected_slot = ""
	else:
		_say("No se pudo equipar: %s." % result, RED)
	_entries = _build_entries()


## Slot elegido si la skill cabe; si no, el primero libre donde quepa; si no hay
## libres, el primero donde quepa (la sustituye).
func _target_slot_for(skill: Dictionary) -> String:
	var warrior := world.warrior
	if not _selected_slot.is_empty() and warrior.slot_accepts(_selected_slot, skill):
		return _selected_slot
	var first_fit := ""
	for slot: String in SLOT_ROWS:
		if not warrior.slot_accepts(slot, skill):
			continue
		if first_fit.is_empty():
			first_fit = slot
		if not warrior.loadout.has(slot):
			return slot
	return first_fit


func _slot_of(id: StringName) -> String:
	for slot: String in SLOT_ROWS:
		if world.warrior.loadout.has(slot) and StringName(String((world.warrior.loadout[slot] as Dictionary)["id"])) == id:
			return slot
	return ""


func _say(text: String, color: Color) -> void:
	_message = text
	_message_color = color


## Todas las skills con ficha (Skill Book + Special + Ultimate), por nivel.
func _build_entries() -> Array:
	var entries: Array = []
	var seen: Dictionary = {}
	for entry: Dictionary in WarriorKit.get_skill_book():
		var id := StringName(String(entry["id"]))
		var data := SkillCatalog.skill(id)
		var skill: Dictionary = data if not data.is_empty() else entry.duplicate(true)
		seen[id] = true
		entries.append({"skill": skill})
	for id: StringName in SkillCatalog.all_ids():
		var data := SkillCatalog.skill(id)
		if seen.has(id) or String(data["slot"]) == "M1" or String(data["slot"]) == "M2":
			continue
		entries.append({"skill": data})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["skill"]["unlock_level"]) < int(b["skill"]["unlock_level"]))
	return entries


func _slot_rect(index: int) -> Rect2:
	return Rect2(PANEL_RECT.position.x + 14.0, SLOT_ROW_Y + index * (SLOT_ROW_H + 3.0), 232.0, SLOT_ROW_H)


func _entry_rect(index: int) -> Rect2:
	return Rect2(PANEL_RECT.position.x + 272.0, BOOK_ROW_Y + index * BOOK_ROW_H, 282.0, BOOK_ROW_H - 1.0)


func _slot_at(position: Vector2) -> String:
	for i: int in range(SLOT_ROWS.size()):
		if _slot_rect(i).has_point(position):
			return SLOT_ROWS[i]
	return ""


func _entry_at(position: Vector2) -> Dictionary:
	for i: int in range(_entries.size()):
		if _entry_rect(i).has_point(position):
			return _entries[i]
	return {}


func _draw() -> void:
	if not is_open or world == null:
		return
	var warrior := world.warrior
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.55))
	draw_rect(PANEL_RECT, PANEL)
	draw_rect(PANEL_RECT, EDGE, false, 1.0)
	_text("LOADOUT", PANEL_RECT.position + Vector2(14, 20), 14, GOLD)
	_text("LV %d   XP %d / %d" % [warrior.level, warrior.xp, warrior.xp_to_next()], PANEL_RECT.position + Vector2(100, 19), 7, TEXT)
	_text("TAB / ESC  CERRAR", Vector2(PANEL_RECT.position.x, PANEL_RECT.position.y + 19), 7, MUTED, HORIZONTAL_ALIGNMENT_RIGHT, PANEL_RECT.size.x - 14.0)

	_text("HUECOS", Vector2(PANEL_RECT.position.x + 14.0, 60.0), 7, MUTED)
	for i: int in range(SLOT_ROWS.size()):
		_draw_slot_row(i, SLOT_ROWS[i], warrior)

	_text("SKILL BOOK", Vector2(PANEL_RECT.position.x + 272.0, 56.0), 7, MUTED)
	for i: int in range(_entries.size()):
		_draw_book_row(i, _entries[i]["skill"], warrior)

	_text(_message, Vector2(PANEL_RECT.position.x + 14.0, PANEL_RECT.end.y - 10.0), 7, _message_color)


func _draw_slot_row(index: int, slot: String, warrior: WarriorSim) -> void:
	var rect := _slot_rect(index)
	draw_rect(rect, Color(0.09, 0.10, 0.14, 1.0))
	var selected := slot == _selected_slot
	draw_rect(rect, GOLD if selected else EDGE, false, 1.0)
	_text("[%s]" % SLOT_KEYS[slot], rect.position + Vector2(6, 15), 7, MUTED)
	_text(slot, rect.position + Vector2(30, 15), 7, MUTED)
	if warrior.loadout.has(slot):
		var skill: Dictionary = warrior.loadout[slot]
		_text(String(skill["name"]), rect.position + Vector2(62, 15), 7, TEXT)
		var cost := "%d" % int(skill.get("cost", 0.0)) if float(skill.get("cost", 0.0)) > 0.0 else ""
		_text(cost, Vector2(rect.position.x, rect.position.y + 15), 7, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 6.0)
	else:
		_text("— vacío —", rect.position + Vector2(62, 15), 7, DIM)


func _draw_book_row(index: int, skill: Dictionary, warrior: WarriorSim) -> void:
	var rect := _entry_rect(index)
	var id := StringName(String(skill["id"]))
	var implemented := bool(skill.get("implemented", false))
	var unlock_at := int(skill["unlock_level"])
	var equipped := _slot_of(id)
	var color := TEXT
	var tag := ""
	if not implemented:
		color = DIM
		tag = "próximamente"
	elif unlock_at > warrior.level:
		color = DIM
		tag = "bloqueada"
	elif not equipped.is_empty():
		color = GOLD
		tag = "en %s" % equipped
	if rect.has_point(get_local_mouse_position()):
		draw_rect(rect, Color(1, 1, 1, 0.07))
	_text("LV %2d" % unlock_at, rect.position + Vector2(2, 10), 7, GREEN if unlock_at <= warrior.level else RED)
	_text(String(skill["name"]), rect.position + Vector2(34, 10), 7, color)
	var kind := String(skill.get("slot", ""))
	if kind == "SPECIAL" or kind == "ULTIMATE":
		_text(kind, rect.position + Vector2(150, 10), 7, MUTED)
	_text(tag, Vector2(rect.position.x, rect.position.y + 10), 7, color, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 4.0)


func _text(text: String, at: Vector2, font_size: int, color: Color, alignment: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(FONT, at, text, alignment, width, font_size, color)
