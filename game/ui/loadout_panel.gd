## LoadoutPanel — el libro de skills (Tab). Pausa la simulacion mientras esta abierto.
##
## Un libro de hechizos (paquete CraftPix Animated Magic Book) que se abre al pulsar Tab. Arriba, las
## pestañas de clase (cada clase conserva su nivel, XP y loadout). La pagina izquierda es el kit: los
## basicos (M1, M2), la movilidad de la clase y los huecos equipables (S1-S3, Especial y Ultimate). La
## derecha lista las habilidades: las del kit base y las de mundo, que se aprenden con la instructora
## del Gremio (o con los libros que se encuentren). Clic en una habilidad disponible la equipa (en el
## hueco elegido o en el primero libre); clic en una equipada, o clic derecho en un hueco, la quita.
## Es presentacion: solo llama a PlayerSim.equip()/unequip(), que son las que validan.
class_name LoadoutPanel
extends Control

const FONT := preload("res://assets/fonts/m6x11.ttf")
const BOOK_TEX := preload("res://assets/pixel/book/Open_book.png")

const INK := Color(0.20, 0.13, 0.07, 1.0)
const INK_SOFT := Color(0.42, 0.30, 0.18, 1.0)
const GOLD := Color(0.62, 0.38, 0.08, 1.0)
const GREEN := Color(0.12, 0.45, 0.18, 1.0)
const RED := Color(0.62, 0.15, 0.12, 1.0)
const LINE := Color(0.45, 0.32, 0.18, 0.5)
const TAB_BG := Color(0.09, 0.10, 0.14, 0.96)
const TAB_TEXT := Color(0.94, 0.74, 0.36, 1.0)
const TAB_MUTED := Color(0.78, 0.72, 0.56, 1.0)

const SLOT_ROWS_ALL := ["S1", "S2", "S3", "SPECIAL", "ULTIMATE"]
const SLOT_KEYS := {"S1": "Q", "S2": "E", "S3": "R", "SPECIAL": "X", "ULTIMATE": "F"}
const SLOT_NAMES := {"S1": "Skill Q", "S2": "Skill E", "S3": "Skill R", "SPECIAL": "Especial", "ULTIMATE": "Ultimate (F)"}
## El libro: hoja de 4 x 3 fotogramas de 272 px (el ultimo es el libro abierto).
const FRAME := 272.0
const FRAME_COUNT := 12
const FRAME_FPS := 22.0
const BOOK_SCALE := 1.7
const CELL_CENTER := Vector2(136.0, 175.5)
## Paginas dentro del fotograma abierto (px del fotograma).
const LEFT_PAGE := Rect2(30.0, 100.0, 98.0, 148.0)
const RIGHT_PAGE := Rect2(146.0, 100.0, 96.0, 148.0)
const SLOT_ROW_H := 28.0
const ENTRY_ROW_H := 15.0
const TAB_Y := 5.0
const TAB_W := 92.0
const TAB_H := 15.0

var world: CombatWorld
var is_open: bool = false

var _selected_slot: String = ""
var _message: String = ""
var _message_color: Color = INK_SOFT
var _entries: Array = []
var _open_time: float = 0.0


func bind(p_world: CombatWorld) -> void:
	world = p_world
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_process(false)


func _input(event: InputEvent) -> void:
	if world == null or get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if event.is_action_pressed("toggle_loadout"):
		_toggle()
		get_viewport().set_input_as_handled()
	elif is_open and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	if not is_open and (not world.player.can_edit_loadout() or TickManager.is_paused()):
		return
	is_open = not is_open
	visible = is_open
	set_process(is_open)
	TickManager.set_paused(is_open)
	if is_open:
		_selected_slot = ""
		_open_time = 0.0
		_message = "Elige un hueco y una habilidad. Clic derecho en un hueco para vaciarlo."
		_message_color = INK_SOFT
		_entries = _build_entries()
	queue_redraw()


func _process(delta: float) -> void:
	_open_time += delta
	queue_redraw()


## Huecos que se muestran: Q E R y F, y el Especial solo en las clases que aun lo usan.
func _slot_rows() -> Array:
	var rows: Array = []
	for slot: String in SLOT_ROWS_ALL:
		if slot == "SPECIAL" and not (world.player.class_def.get("default_loadout", {}) as Dictionary).has("SPECIAL"):
			continue
		rows.append(slot)
	return rows


func _book_ready() -> bool:
	return _open_time >= float(FRAME_COUNT) / FRAME_FPS


# --- Geometria del libro --------------------------------------------------------------


func _cell_origin() -> Vector2:
	return Vector2(320.0, 180.0) - CELL_CENTER * BOOK_SCALE


func _page_rect(page: Rect2) -> Rect2:
	return Rect2(_cell_origin() + page.position * BOOK_SCALE, page.size * BOOK_SCALE)


func _slot_rect(index: int) -> Rect2:
	var page := _page_rect(LEFT_PAGE)
	return Rect2(page.position.x, page.position.y + 84.0 + float(index) * (SLOT_ROW_H + 2.0), page.size.x, SLOT_ROW_H)


func _entry_rect(index: int) -> Rect2:
	var page := _page_rect(RIGHT_PAGE)
	return Rect2(page.position.x, page.position.y + 20.0 + float(index) * ENTRY_ROW_H, page.size.x, ENTRY_ROW_H - 1.0)


func _tab_rect(index: int) -> Rect2:
	var left := 320.0 - float(ClassCatalog.all_ids().size()) * (TAB_W + 4.0) * 0.5
	return Rect2(left + float(index) * (TAB_W + 4.0), TAB_Y, TAB_W, TAB_H)


func _tab_at(position: Vector2) -> String:
	var ids := ClassCatalog.all_ids()
	for i: int in range(ids.size()):
		if _tab_rect(i).has_point(position):
			return ids[i]
	return ""


func _slot_at(position: Vector2) -> String:
	for i: int in range(_slot_rows().size()):
		if _slot_rect(i).has_point(position):
			return _slot_rows()[i]
	return ""


func _entry_at(position: Vector2) -> Dictionary:
	for i: int in range(_entries.size()):
		if _entry_rect(i).has_point(position):
			return _entries[i]
	return {}


# --- Entrada --------------------------------------------------------------------------


func _gui_input(event: InputEvent) -> void:
	if not is_open or not _book_ready() or not (event is InputEventMouseButton) or not event.pressed:
		return
	var position := (event as InputEventMouseButton).position
	var button := (event as InputEventMouseButton).button_index
	var tab := _tab_at(position)
	if not tab.is_empty():
		if button == MOUSE_BUTTON_LEFT:
			_switch_class(tab)
		accept_event()
		return
	var slot := _slot_at(position)
	if not slot.is_empty():
		if button == MOUSE_BUTTON_RIGHT:
			if world.player.unequip(slot):
				_say("Hueco %s vaciado." % SLOT_NAMES[slot], INK_SOFT)
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
	var player := world.player
	if bool(skill.get("world", false)) and not player.learned_skills.has(String(id)):
		_say(("%s esta en un libro: buscalo en el mundo (jefes, elite, misiones secretas)." if String(skill.get("source", "trainer")) == "book" else "%s se aprende con Dara, en el Gremio de Albor.") % SkillCatalog.display_name(skill), RED)
		return
	if int(skill["unlock_level"]) > player.level:
		_say("%s se desbloquea en el nivel %d." % [SkillCatalog.display_name(skill), int(skill["unlock_level"])], RED)
		return
	var equipped_slot := _slot_of(id)
	if not equipped_slot.is_empty():
		if player.unequip(equipped_slot):
			_say("%s retirada de %s." % [SkillCatalog.display_name(skill), SLOT_NAMES[equipped_slot]], INK_SOFT)
		_entries = _build_entries()
		return
	var target := _target_slot_for(skill)
	if target.is_empty():
		_say("No hay hueco donde quepa %s." % SkillCatalog.display_name(skill), RED)
		return
	var result := player.equip(target, id)
	if result.is_empty():
		_say("%s equipada en %s." % [SkillCatalog.display_name(skill), SLOT_NAMES[target]], GREEN)
		_selected_slot = ""
	else:
		_say("No se pudo equipar: %s." % result, RED)
	_entries = _build_entries()


## Slot elegido si la skill cabe; si no, el primero libre donde quepa; si no hay
## libres, el primero donde quepa (la sustituye).
func _target_slot_for(skill: Dictionary) -> String:
	var player := world.player
	if not _selected_slot.is_empty() and player.slot_accepts(_selected_slot, skill):
		return _selected_slot
	var first_fit := ""
	for slot: String in _slot_rows():
		if not player.slot_accepts(slot, skill):
			continue
		if first_fit.is_empty():
			first_fit = slot
		if not player.loadout.has(slot):
			return slot
	return first_fit


func _slot_of(id: StringName) -> String:
	for slot: String in _slot_rows():
		if world.player.loadout.has(slot) and StringName(String((world.player.loadout[slot] as Dictionary)["id"])) == id:
			return slot
	return ""


func _switch_class(new_class_id: String) -> void:
	var result := world.player.switch_class(new_class_id)
	if result.is_empty():
		_selected_slot = ""
		_entries = _build_entries()
		_say("Clase: %s." % String(world.player.class_def["name"]), GREEN)
	else:
		_say("No se puede cambiar de clase ahora (%s)." % result, RED)


func _say(text: String, color: Color) -> void:
	_message = text
	_message_color = color


## Habilidades de la clase actual (sin M1 y M2): las del kit base primero, luego las de mundo, por nivel.
func _build_entries() -> Array:
	var entries: Array = []
	for id: StringName in SkillCatalog.ids_for_class(world.player.class_id):
		var data := SkillCatalog.skill(id)
		if String(data["slot"]) == "M1" or String(data["slot"]) == "M2" or not bool(data.get("implemented", false)) or bool(data.get("retired", false)):
			continue
		entries.append({"skill": data})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var world_a := bool(a["skill"].get("world", false))
		var world_b := bool(b["skill"].get("world", false))
		if world_a != world_b:
			return not world_a
		return int(a["skill"]["unlock_level"]) < int(b["skill"]["unlock_level"]))
	return entries


# --- Dibujo ---------------------------------------------------------------------------


func _draw() -> void:
	if not is_open or world == null:
		return
	var player := world.player
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.62))
	var frame := mini(int(_open_time * FRAME_FPS), FRAME_COUNT - 1)
	var source := Rect2(float(frame % 4) * FRAME, float(frame / 4) * FRAME, FRAME, FRAME)
	draw_texture_rect_region(BOOK_TEX, Rect2(_cell_origin(), Vector2(FRAME, FRAME) * BOOK_SCALE), source)
	if not _book_ready():
		return
	_draw_tabs(player)
	_draw_left_page(player)
	_draw_right_page(player)
	_text(_message, Vector2(0, 349), 8, _message_color if _message_color != INK_SOFT else TAB_MUTED, HORIZONTAL_ALIGNMENT_CENTER, 640.0)


func _draw_tabs(player: PlayerSim) -> void:
	var ids := ClassCatalog.all_ids()
	for i: int in range(ids.size()):
		var rect := _tab_rect(i)
		var active := ids[i] == player.class_id
		var saved: Dictionary = player.progress.get(ids[i], {})
		var level := player.level if active else int(saved.get("level", 1))
		draw_rect(rect, Color(0.16, 0.14, 0.09, 1.0) if active else TAB_BG)
		draw_rect(rect, TAB_TEXT if active else Color(0.33, 0.37, 0.47, 1.0), false, 1.0)
		if rect.has_point(get_local_mouse_position()) and not active:
			draw_rect(rect, Color(1, 1, 1, 0.08))
		var name := String(ClassCatalog.class_def(ids[i])["name"]).to_upper()
		_text("%s  %d" % [name, level], rect.position + Vector2(0, 10), 7, TAB_TEXT if active else TAB_MUTED, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


func _draw_left_page(player: PlayerSim) -> void:
	var page := _page_rect(LEFT_PAGE)
	_text(String(player.class_def["name"]).to_upper(), page.position + Vector2(0, 8), 10, INK, HORIZONTAL_ALIGNMENT_CENTER, page.size.x)
	_text("Nivel %d   XP %d / %d" % [player.level, player.xp, player.xp_to_next()], page.position + Vector2(0, 21), 7, INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER, page.size.x)
	draw_line(page.position + Vector2(4, 26), page.position + Vector2(page.size.x - 4.0, 26), LINE, 1.0)
	var info_y := page.position.y + 38.0
	for slot: String in ["M1", "M2"]:
		if player.loadout.has(slot):
			_text("%s  %s" % [slot, SkillCatalog.display_name(player.loadout[slot] as Dictionary)], Vector2(page.position.x + 2.0, info_y), 7, INK)
		info_y += 12.0
	var mobility := player.mobility()
	_text("MOV  %s (%.0f s)" % [String(mobility.get("name", "Esquiva")), float(mobility["cooldown"])], Vector2(page.position.x + 2.0, info_y), 7, GREEN)
	info_y += 12.0
	_text("ULTI  %s" % String(player.class_def.get("ult_charge", {}).get("_doc", "")), Vector2(page.position.x + 2.0, info_y), 7, INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, page.size.x - 2.0)
	for i: int in range(_slot_rows().size()):
		_draw_slot_row(i, _slot_rows()[i], player)


func _draw_slot_row(index: int, slot: String, player: PlayerSim) -> void:
	var rect := _slot_rect(index)
	var selected := slot == _selected_slot
	draw_rect(rect, Color(0.45, 0.32, 0.18, 0.14))
	draw_rect(rect, GOLD if selected else LINE, false, 1.0 if not selected else 2.0)
	_text(String(SLOT_KEYS[slot]), rect.position + Vector2(5, 18), 7, INK_SOFT)
	if player.loadout.has(slot):
		var skill: Dictionary = player.loadout[slot]
		var icon := SkillIcons.texture(String(skill["id"]))
		if icon != null:
			draw_texture_rect(icon, Rect2(rect.position + Vector2(20, 3), Vector2(22, 22)), false)
		_text(String(SkillCatalog.display_name(skill)), rect.position + Vector2(46, 12), 7, INK, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 48.0)
		var cost := "%d" % int(skill.get("cost", 0.0)) if float(skill.get("cost", 0.0)) > 0.0 else "libre"
		_text(cost, rect.position + Vector2(46, 24), 7, GOLD)
	else:
		_text("- vacio -", rect.position + Vector2(22, 18), 7, INK_SOFT)


func _draw_right_page(player: PlayerSim) -> void:
	var page := _page_rect(RIGHT_PAGE)
	_text("HABILIDADES", page.position + Vector2(0, 10), 10, INK, HORIZONTAL_ALIGNMENT_CENTER, page.size.x)
	draw_line(page.position + Vector2(4, 16), page.position + Vector2(page.size.x - 4.0, 16), LINE, 1.0)
	var unknown := 0
	for i: int in range(_entries.size()):
		_draw_entry_row(i, _entries[i]["skill"], player)
		if bool((_entries[i]["skill"] as Dictionary).get("world", false)) and not player.learned_skills.has(String(_entries[i]["skill"]["id"])):
			unknown += 1
	var hovered := _entry_at(get_local_mouse_position())
	var foot := page.end.y - 10.0
	if not hovered.is_empty():
		_text(String((hovered["skill"] as Dictionary).get("description", "")), Vector2(page.position.x, foot - 14.0), 7, INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, page.size.x)
	elif unknown > 0:
		_text("%d por aprender (Gremio)" % unknown, Vector2(page.position.x, foot), 7, INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, page.size.x)


func _draw_entry_row(index: int, skill: Dictionary, player: PlayerSim) -> void:
	var rect := _entry_rect(index)
	var id := StringName(String(skill["id"]))
	var unlock_at := int(skill["unlock_level"])
	var is_world := bool(skill.get("world", false))
	var learned := not is_world or player.learned_skills.has(String(id))
	var equipped := _slot_of(id)
	var color := INK
	var tag := ""
	if not learned:
		color = INK_SOFT
		tag = "Libro" if String(skill.get("source", "trainer")) == "book" else "Gremio"
	elif unlock_at > player.level:
		color = INK_SOFT
		tag = "nv %d" % unlock_at
	elif not equipped.is_empty():
		color = GOLD
		tag = "en %s" % SLOT_KEYS[equipped]
	var dim := color == INK_SOFT
	if rect.has_point(get_local_mouse_position()):
		draw_rect(rect, Color(0.45, 0.32, 0.18, 0.18))
	var icon := SkillIcons.texture(String(skill["id"]))
	if icon != null:
		draw_texture_rect(icon, Rect2(rect.position + Vector2(1, 0), Vector2(13, 13)), false, Color(1, 1, 1, 0.45 if dim else 1.0))
	_text(String(SkillCatalog.display_name(skill)), rect.position + Vector2(17, 10), 7, color, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 17.0 - (30.0 if tag != "" else 0.0))
	_text(tag, rect.position + Vector2(0, 10), 7, color, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 1.0)


func _text(text: String, at: Vector2, font_size: int, color: Color, alignment: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(FONT, at, text, alignment, width, maxi(font_size, UiStyle.MIN_FONT), color)
