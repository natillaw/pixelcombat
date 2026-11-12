## CharacterSheet — la ficha del personaje (tecla C): el personaje con sus huecos de equipo y sus
## estadisticas, con el panel Equipment del paquete CraftPix. Clic en un hueco equipado lo guarda
## en la mochila (solo en zona segura, como el inventario). Pausa la simulacion mientras esta abierto.
## Es presentacion: solo lee PlayerSim y llama a unequip_gear(), que valida.
##
## Todo se dibuja a escalas enteras (panel x3, iconos x3, texto a 14 px = 2 x 7 px de la fuente) para
## que el pixel art no se deforme ni el texto quede borroso.
class_name CharacterSheet
extends Control

const FONT := preload("res://assets/fonts/m5x7.ttf")
const SHEET := preload("res://assets/pixel/ui/craftpix/Equipment.png")

const INK := Color(0.20, 0.13, 0.07, 1.0)
const INK_SOFT := Color(0.42, 0.30, 0.18, 1.0)
const GOLD := Color(0.55, 0.33, 0.06, 1.0)
const GREEN := Color(0.10, 0.42, 0.16, 1.0)
const RED := Color(0.62, 0.15, 0.12, 1.0)
const TITLE := Color(0.96, 1.0, 0.92, 1.0)
const CREAM := Color(0.96, 0.90, 0.78, 1.0)

## Panel sin figura de la hoja (px de la hoja), escala en pantalla y textos.
const PANEL_SRC := Rect2(7, 192, 148, 85)
const SCALE := 3.0
const SLOT_SRC := Rect2(80, 321, 15, 15)
const SLOT_SIZE := 45.0
const TEXT := 14
const TEXT_BIG := 14
## Zona de texto de la parte clara (px dentro del panel ya escalado).
const TEXT_X := 218.0
const TEXT_W := 206.0
const ROW_H := 17.0

## Iconos exactos de la hoja (px de la hoja, sin los restos de los vecinos).
const ICONS := {
	"head": Rect2(130, 338, 12, 12), "weapon": Rect2(114, 354, 12, 12), "chest": Rect2(146, 338, 12, 12),
	"ring": Rect2(99, 354, 11, 12), "legs": Rect2(146, 338, 12, 12), "feet": Rect2(147, 354, 10, 12),
}
## Hueco -> posicion (px dentro del panel ya escalado) y nombre.
const SLOTS := {
	"head": {"pos": Vector2(78, 40), "name": "Cabeza"},
	"weapon": {"pos": Vector2(14, 96), "name": "Arma"},
	"chest": {"pos": Vector2(142, 96), "name": "Pecho"},
	"ring": {"pos": Vector2(14, 156), "name": "Anillo"},
	"legs": {"pos": Vector2(142, 156), "name": "Piernas"},
	"feet": {"pos": Vector2(78, 200), "name": "Pies"},
}

var world: CombatWorld
var is_open: bool = false

var _message: String = ""
var _message_color: Color = Color(0.86, 0.80, 0.62)
var _was_paused: bool = false


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
	if event.is_action_pressed("toggle_character"):
		_toggle()
		get_viewport().set_input_as_handled()
	elif is_open and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	if not is_open and TickManager.is_paused():
		return
	is_open = not is_open
	visible = is_open
	set_process(is_open)
	if is_open:
		_was_paused = TickManager.is_paused()
		TickManager.set_paused(true)
		_message = "Clic en un hueco equipado para guardarlo en la mochila."
		_message_color = Color(0.86, 0.80, 0.62)
	else:
		TickManager.set_paused(_was_paused)
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _origin() -> Vector2:
	return (Vector2(640.0, 360.0) - PANEL_SRC.size * SCALE) * 0.5 + Vector2(0.0, 4.0)


func _slot_rect(slot: String) -> Rect2:
	return Rect2(_origin() + (SLOTS[slot]["pos"] as Vector2), Vector2(SLOT_SIZE, SLOT_SIZE))


func _slot_at(position: Vector2) -> String:
	for slot: String in SLOTS:
		if _slot_rect(slot).has_point(position):
			return slot
	return ""


func _gui_input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventMouseButton) or not event.pressed or (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	var slot := _slot_at((event as InputEventMouseButton).position)
	if not slot.is_empty() and world.player.equipment.has(slot):
		match world.player.unequip_gear(slot):
			"":
				_say("Guardado en la mochila.", Color(0.6, 0.9, 0.5))
			"busy":
				_say("Solo puedes cambiar de equipo en la ciudad o el patio.", Color(1.0, 0.55, 0.45))
			"full":
				_say("La mochila esta llena.", Color(1.0, 0.55, 0.45))
			_:
				_say("No se puede.", Color(1.0, 0.55, 0.45))
	accept_event()


func _say(text: String, color: Color) -> void:
	_message = text
	_message_color = color


# --- Dibujo ---------------------------------------------------------------------------


func _draw() -> void:
	if not is_open or world == null:
		return
	var player := world.player
	var origin := _origin()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.62))
	draw_texture_rect_region(SHEET, Rect2(origin, PANEL_SRC.size * SCALE), PANEL_SRC)
	# Titulo en la pestaña verde (a la izquierda del boton de cerrar).
	_text("PERSONAJE", origin + Vector2(201.0, 22.0), TEXT_BIG, TITLE, HORIZONTAL_ALIGNMENT_CENTER, 200.0)
	_draw_figure(player, origin)
	var hovered := ""
	for slot: String in SLOTS:
		_draw_slot(slot, player)
		if _slot_rect(slot).has_point(get_local_mouse_position()):
			hovered = slot
	_draw_text_area(player, origin, hovered)
	_text(_message, Vector2(0, 352), TEXT, _message_color, HORIZONTAL_ALIGNMENT_CENTER, 640.0)


## El personaje con lo que lleva puesto, en el centro de la parte oscura del panel.
func _draw_figure(player: PlayerSim, origin: Vector2) -> void:
	var texture := LpcComposer.pose_texture_for(ClassLook.look(player.class_id, player.appearance), "class." + player.class_id, "idle", ClassLook.equipment(player.class_id, player.equipment))
	if texture == null:
		return
	var center := origin + Vector2(100.0, 140.0)
	draw_circle(center + Vector2(0, 54), 30.0, Color(0, 0, 0, 0.22))
	draw_texture_rect(texture, Rect2(center - Vector2(64, 64), Vector2(128, 128)), false)


func _draw_slot(slot: String, player: PlayerSim) -> void:
	var rect := _slot_rect(slot)
	draw_texture_rect_region(SHEET, rect, SLOT_SRC)
	var hovered := rect.has_point(get_local_mouse_position())
	if hovered:
		draw_rect(rect, Color(1, 1, 1, 0.18))
	var equipped: bool = player.equipment.has(slot)
	var icon: Rect2 = ICONS[slot]
	var target := Rect2(rect.position + (rect.size - icon.size * SCALE) * 0.5, icon.size * SCALE)
	var tint := Color(1, 1, 1, 1.0) if equipped else Color(1, 1, 1, 0.3)
	if slot == "legs":
		tint = Color(0.82, 0.62, 0.42, tint.a)
	draw_texture_rect_region(SHEET, target, icon, tint)
	if equipped:
		var color := ItemCatalog.rarity_color(String((player.equipment[slot] as Dictionary)["rarity"]))
		draw_rect(rect, color, false, 3.0)
		_text("T%d" % int((player.equipment[slot] as Dictionary)["tier"]), rect.position + Vector2(4, 13), TEXT, color.lightened(0.25), HORIZONTAL_ALIGNMENT_LEFT, 30.0)


func _draw_text_area(player: PlayerSim, origin: Vector2, hovered: String) -> void:
	var at := origin + Vector2(TEXT_X, 58.0)
	if not hovered.is_empty():
		if player.equipment.has(hovered):
			_draw_item_detail(player.equipment[hovered], at)
		else:
			_text(String(SLOTS[hovered]["name"]), at, TEXT_BIG, INK, HORIZONTAL_ALIGNMENT_LEFT, TEXT_W)
			_text("Hueco vacio", at + Vector2(0, ROW_H), TEXT, INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, TEXT_W)
		return
	_text("%s, %s" % [player.character_name, String(player.class_def["name"])], at, TEXT_BIG, INK, HORIZONTAL_ALIGNMENT_LEFT, TEXT_W)
	draw_line(at + Vector2(0, 5), at + Vector2(TEXT_W, 5), Color(0.45, 0.32, 0.18, 0.55), 2.0)
	var rows: Array = [
		["Nivel", str(player.level), INK],
		["Vida", "%d/%d" % [int(player.health), int(player.max_health)], INK],
		[String(player.class_def["resource"]["name"]), "%d/%d" % [int(player.resource.get_current()), int(player.resource.max_amount)], INK],
		["Armadura", "%d (-%d%%)" % [int(player.stats.get_stat(&"armor")), int(round(player.armor_reduction() * 100.0))], INK],
		["Fuerza", str(int(round(player.stats.get_stat(&"strength")))), INK],
		["Agilidad", str(int(round(player.stats.get_stat(&"agility")))), INK],
		["Intelecto", str(int(round(player.stats.get_stat(&"intellect")))), INK],
		["Aguante", str(int(round(player.stats.get_stat(&"stamina")))), INK],
		["Critico", "%d%%" % int(round(player.stats.get_crit_chance() * 100.0)), INK],
		["Movilidad", "%s %ds" % [String(player.mobility().get("name", "Esquiva")), int(float(player.mobility()["cooldown"]))], GREEN],
	]
	var y := at.y + 24.0
	for row: Array in rows:
		_text(String(row[0]), Vector2(at.x, y), TEXT, INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, TEXT_W)
		_text(String(row[1]), Vector2(at.x, y), TEXT, row[2], HORIZONTAL_ALIGNMENT_RIGHT, TEXT_W)
		y += ROW_H


func _draw_item_detail(piece: Dictionary, at: Vector2) -> void:
	var base := ItemCatalog.item(String(piece["id"]))
	var color := ItemCatalog.rarity_color(String(piece["rarity"]))
	_text(ItemCatalog.display_name(piece), at, TEXT_BIG, color.darkened(0.45), HORIZONTAL_ALIGNMENT_LEFT, TEXT_W)
	_text("%s, tier %d" % [ItemCatalog.slot_name(String(base["slot"])), int(piece["tier"])], at + Vector2(0, ROW_H), TEXT, INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, TEXT_W)
	draw_line(at + Vector2(0, 22), at + Vector2(TEXT_W, 22), Color(0.45, 0.32, 0.18, 0.55), 2.0)
	var y := at.y + 40.0
	for stat: String in piece["stats"]:
		var value := float(piece["stats"][stat])
		_text(_stat_name(stat), Vector2(at.x, y), TEXT, INK_SOFT, HORIZONTAL_ALIGNMENT_LEFT, TEXT_W)
		_text("+%d%%" % int(round(value * 100.0)) if stat == "crit_chance" else "+%s" % str(snappedf(value, 0.1)), Vector2(at.x, y), TEXT, INK, HORIZONTAL_ALIGNMENT_RIGHT, TEXT_W)
		y += ROW_H
	var classes: Variant = base.get("classes")
	if classes != null:
		_text("Solo: %s" % ", ".join((classes as Array).map(func(c: Variant) -> String: return String(c).capitalize())), Vector2(at.x, y + 4.0), TEXT, RED, HORIZONTAL_ALIGNMENT_LEFT, TEXT_W)
		y += ROW_H
	_text("Vale %d de oro" % ItemCatalog.sell_value(piece), Vector2(at.x, y + 4.0), TEXT, GOLD, HORIZONTAL_ALIGNMENT_LEFT, TEXT_W)


func _stat_name(stat: String) -> String:
	var names := {"weapon_min": "Dano minimo", "weapon_max": "Dano maximo", "attack_power_bonus": "Poder de ataque", "spell_power_bonus": "Poder magico", "crit_chance": "Critico", "strength": "Fuerza", "agility": "Agilidad", "intellect": "Intelecto", "stamina": "Aguante", "armor": "Armadura"}
	return String(names.get(stat, stat.replace("_", " ").capitalize()))


func _text(text: String, at: Vector2, font_size: int, color: Color, alignment: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	# Sombra de un pixel para que se lea sobre el pergamino y sobre la madera.
	if color.get_luminance() > 0.6:
		draw_string(FONT, at + Vector2(1, 1), text, alignment, width, font_size, Color(0, 0, 0, 0.55))
	draw_string(FONT, at, text, alignment, width, font_size, color)
