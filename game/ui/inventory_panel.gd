## InventoryPanel — mochila y equipo (tecla I). Pausa la simulación mientras está abierto.
##
## A la izquierda las ranuras de equipo de la clase activa; a la derecha la mochila
## compartida. Clic izquierdo en un item de la mochila lo equipa; clic derecho lo tira;
## clic en una ranura equipada lo guarda en la mochila. Clic derecho vende (solo en zona segura). Abajo se ve el detalle del
## item bajo el ratón. Es presentación: solo llama a PlayerSim.equip_from_bag(),
## unequip_gear() y sell_from_bag(), que son las que validan.
class_name InventoryPanel
extends Control

const FONT := preload("res://assets/fonts/m5x7.ttf")

const PANEL := Color(0.055, 0.065, 0.095, 0.96)
const EDGE := Color(0.33, 0.37, 0.47, 1.0)
const TEXT := Color(0.93, 0.90, 0.83, 1.0)
const MUTED := Color(0.84, 0.77, 0.60, 1.0)
const DIM := Color(0.72, 0.66, 0.55, 1.0)
const GOLD := Color(0.94, 0.74, 0.36, 1.0)
const RED := Color(0.88, 0.34, 0.28, 1.0)
const GREEN := Color(0.55, 0.82, 0.45, 1.0)

const PANEL_RECT := Rect2(36, 14, 568, 340)
const EQUIP_X := 48.0
const EQUIP_Y := 60.0
const EQUIP_W := 190.0
const ROW_H := 26.0
const BAG_X := 256.0
const BAG_Y := 60.0
## La mochila es una rejilla de 8 columnas: cada item es su propio icono (su pieza LPC).
const BAG_COLS := 8
const BAG_CELL := 37.0

var world: CombatWorld
var is_open: bool = false

var _message: String = ""
var _message_color: Color = MUTED
var _hover: Dictionary = {}


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
	if event.is_action_pressed("toggle_inventory"):
		_toggle()
		get_viewport().set_input_as_handled()
	elif is_open and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	if not is_open and TickManager.is_paused():
		return
	is_open = not is_open
	visible = is_open
	set_process(is_open)
	TickManager.set_paused(is_open)
	if is_open:
		_hover = {}
		_say("Clic: equipar. Clic derecho: vender. Solo en zona segura.", MUTED)
	queue_redraw()


func _process(_delta: float) -> void:
	_hover = _item_at(get_local_mouse_position())
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventMouseButton) or not event.pressed:
		return
	var position := (event as InputEventMouseButton).position
	var button := (event as InputEventMouseButton).button_index
	var slots := ItemCatalog.slots()
	for i: int in range(slots.size()):
		if _slot_rect(i).has_point(position):
			if button == MOUSE_BUTTON_LEFT and world.player.equipment.has(slots[i]):
				_report(world.player.unequip_gear(String(slots[i])), "Guardado en la mochila.")
			accept_event()
			return
	if button == MOUSE_BUTTON_LEFT:
		for entry: Dictionary in _consumable_rects():
			if (entry["rect"] as Rect2).has_point(position):
				_use_consumable(String(entry["id"]))
				accept_event()
				return
	var index := _bag_index_at(position)
	if index >= 0 and index < world.player.bag.size():
		if button == MOUSE_BUTTON_LEFT:
			_report(world.player.equip_from_bag(index), "Equipado.")
		elif button == MOUSE_BUTTON_RIGHT:
			var gained := world.player.sell_from_bag(index)
			if gained < 0:
				_say("Solo puedes vender en la ciudad o el patio.", RED)
			else:
				_say("Vendido por %d de oro." % gained, GOLD)
		accept_event()


## Zonas clicables de los consumibles (fila bajo los materiales): [{rect, id}].
func _consumable_rects() -> Array:
	var out: Array = []
	var x := EQUIP_X
	for id: String in ConsumableCatalog.ids():
		if world.player.consumable_count(id) <= 0:
			continue
		var width := 90.0
		out.append({"rect": Rect2(x, 337.0, width - 4.0, 11.0), "id": id})
		x += width
	return out


func _use_consumable(id: String) -> void:
	var reasons := {"none": "No te queda.", "dead": "No puedes ahora.", "cooldown": "Las pociones estan en enfriamiento.", "full": "No lo necesitas ahora."}
	var reason := world.player.use_consumable(id)
	if reason.is_empty():
		_say("Usado: %s." % String(ConsumableCatalog.item(id)["name"]), GOLD)
	else:
		_say(String(reasons.get(reason, "No se puede.")), RED)


func _report(reason: String, success: String) -> void:
	match reason:
		"":
			_say(success, GOLD)
		"busy":
			_say("Solo puedes cambiar de equipo en la ciudad o el patio.", RED)
		"class":
			_say("Tu clase no puede equipar eso.", RED)
		"full":
			_say("La mochila esta llena.", RED)
		_:
			_say("No se puede.", RED)


func _say(text: String, color: Color) -> void:
	_message = text
	_message_color = color


func _slot_rect(i: int) -> Rect2:
	return Rect2(EQUIP_X, EQUIP_Y + float(i) * ROW_H, EQUIP_W, ROW_H - 3.0)


func _bag_rect(index: int) -> Rect2:
	var col := index % BAG_COLS
	var row := index / BAG_COLS
	return Rect2(BAG_X + float(col) * BAG_CELL, BAG_Y + float(row) * BAG_CELL, BAG_CELL - 2.0, BAG_CELL - 2.0)


func _bag_index_at(position: Vector2) -> int:
	for i: int in range(ItemCatalog.bag_size()):
		if _bag_rect(i).has_point(position):
			return i
	return -1


## Item bajo el cursor (de una ranura o de la mochila) o {}.
func _item_at(position: Vector2) -> Dictionary:
	var slots := ItemCatalog.slots()
	for i: int in range(slots.size()):
		if _slot_rect(i).has_point(position) and world.player.equipment.has(slots[i]):
			return world.player.equipment[slots[i]]
	var index := _bag_index_at(position)
	if index >= 0 and index < world.player.bag.size():
		return world.player.bag[index]
	return {}


func _draw() -> void:
	if not is_open or world == null:
		return
	draw_rect(Rect2(0, 0, 640, 360), Color(0.0, 0.0, 0.0, 0.5))
	UiStyle.draw_panel(self, PANEL_RECT)
	var player := world.player
	_text("INVENTARIO  -  %s" % String(player.class_def["name"]).to_upper(), Vector2(48, 36), 14, GOLD)
	_text("I / ESC  CERRAR", Vector2(0, 36), 7, MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 592)
	_text("EQUIPO", Vector2(EQUIP_X, 54), 7, MUTED)
	_text("ORO  %d" % player.gold, Vector2(0, 54), 7, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 592)
	_text("MOCHILA  %d / %d" % [player.bag.size(), ItemCatalog.bag_size()], Vector2(BAG_X, 54), 7, MUTED)
	_draw_materials(player)

	var slots := ItemCatalog.slots()
	for i: int in range(slots.size()):
		var rect := _slot_rect(i)
		var slot := String(slots[i])
		draw_rect(rect, Color(0.07, 0.08, 0.14, 1.0))
		draw_rect(rect, UiStyle.GOLD if rect.has_point(get_local_mouse_position()) else UiStyle.GOLD_DIM, false, 1.0)
		UiStyle.draw_slot_bg(self, Rect2(rect.position + Vector2(2, 1), Vector2(24, rect.size.y - 2.0)))
		_text(ItemCatalog.slot_name(slot).to_upper(), rect.position + Vector2(30, 9), 7, DIM)
		if player.equipment.has(slot):
			var piece: Dictionary = player.equipment[slot]
			ItemIcons.draw(self, piece, Rect2(rect.position + Vector2(3, 2), Vector2(22, rect.size.y - 4.0)))
			UiStyle.draw_rarity_frame(self, Rect2(rect.position + Vector2(2, 1), Vector2(24, rect.size.y - 2.0)), String(piece["rarity"]))
			_text(ItemCatalog.display_name(piece), rect.position + Vector2(30, 20), 7, ItemCatalog.rarity_color(String(piece["rarity"])), HORIZONTAL_ALIGNMENT_LEFT, EQUIP_W - 34.0)
		else:
			_text("vacio", rect.position + Vector2(30, 20), 7, DIM)

	for i: int in range(ItemCatalog.bag_size()):
		if i >= player.bag.size():
			UiStyle.draw_slot_bg(self, _bag_rect(i))
	for i: int in range(player.bag.size()):
		var rect := _bag_rect(i)
		var piece: Dictionary = player.bag[i]
		var color := ItemCatalog.rarity_color(String(piece["rarity"]))
		UiStyle.draw_slot_bg(self, rect)
		ItemIcons.draw(self, piece, rect)
		UiStyle.draw_rarity_frame(self, rect, String(piece["rarity"]))
		_text("T%d" % int(piece["tier"]), rect.position + Vector2(3, 9), 7, color.lightened(0.25))
		if rect.has_point(get_local_mouse_position()):
			draw_rect(rect, Color(1, 1, 1, 0.16))

	_draw_detail(player)
	_text(_message, Vector2(48, 318), 7, _message_color)


## Materiales que lleva el jugador, en una linea bajo el titulo y sin pasar del panel.
func _draw_materials(player: PlayerSim) -> void:
	var parts: Array = []
	var ids: Array = player.materials.keys()
	ids.sort()
	for id: String in ids:
		parts.append("%s x%d" % [MaterialCatalog.display_name(id), int(player.materials[id])])
	_text("MATERIALES  " + ("-" if parts.is_empty() else "   ".join(parts)), Vector2(EQUIP_X, 330), 7, MUTED, HORIZONTAL_ALIGNMENT_LEFT, 544)
	var rects := _consumable_rects()
	if rects.is_empty():
		_text("Sin consumibles (taberna, mercader y botin). Teclas rapidas: %s vida, %s energia" % [Settings.short_label("quick_health"), Settings.short_label("quick_resource")], Vector2(EQUIP_X, 340), 7, DIM, HORIZONTAL_ALIGNMENT_LEFT, 544)
	for entry: Dictionary in rects:
		var spec := ConsumableCatalog.item(String(entry["id"]))
		var icon := SkillIcons.consumable(String(spec.get("icon", "")))
		if icon != null:
			draw_texture_rect(icon, Rect2((entry["rect"] as Rect2).position + Vector2(0, -1), Vector2(12, 12)), false)
		_text("%s x%d" % [spec["name"], player.consumable_count(String(entry["id"]))], (entry["rect"] as Rect2).position + Vector2(14, 8), 7, GREEN, HORIZONTAL_ALIGNMENT_LEFT, 74.0)


func _draw_detail(player: PlayerSim) -> void:
	var gear := player.gear_stats()
	var total_lines: Array = []
	for stat: String in gear:
		total_lines.append("%s %s" % [_stat_label(stat), _stat_value(stat, float(gear[stat]))])
	_text("TOTAL EQUIPO", Vector2(EQUIP_X, 228), 7, MUTED)
	var y := 238.0
	for line: String in total_lines:
		_text(line, Vector2(EQUIP_X, y), 7, TEXT)
		y += 9.0
	if total_lines.is_empty():
		_text("sin equipo", Vector2(EQUIP_X, y), 7, DIM)
	if _hover.is_empty():
		return
	var box := Rect2(BAG_X, 262, 340, 62)
	draw_rect(box, Color(0.04, 0.05, 0.08, 1.0))
	draw_rect(box, EDGE, false, 1.0)
	var color := ItemCatalog.rarity_color(String(_hover["rarity"]))
	_text(ItemCatalog.display_name(_hover), box.position + Vector2(6, 12), 7, color)
	_text("TIER %d  %s" % [int(_hover["tier"]), ItemCatalog.slot_name(String(ItemCatalog.item(String(_hover["id"]))["slot"])).to_upper()], box.position + Vector2(0, 12), 7, MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 334)
	var classes: Variant = ItemCatalog.item(String(_hover["id"])).get("classes")
	if classes != null:
		_text("SOLO: %s" % ", ".join((classes as Array).map(func(c: Variant) -> String: return String(c).to_upper())), box.position + Vector2(6, 22), 7, DIM)
	_text("VALOR %d" % ItemCatalog.sell_value(_hover), box.position + Vector2(0, 22), 7, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 334)
	# Comparacion con lo que llevas puesto en esa ranura.
	var slot := String(ItemCatalog.item(String(_hover["id"]))["slot"])
	var worn: Variant = player.equipment.get(slot)
	var is_worn := worn != null and JSON.stringify(worn) == JSON.stringify(_hover)
	var compare: Dictionary = (worn as Dictionary)["stats"] if worn != null and not is_worn else {}
	var names: Array = (_hover["stats"] as Dictionary).keys()
	for stat: String in compare:
		if not names.has(stat):
			names.append(stat)
	var col := 0
	var row := 0
	for stat: String in names:
		var value: float = float((_hover["stats"] as Dictionary).get(stat, 0.0))
		var line := "+%s %s" % [_stat_value(stat, value), _stat_label(stat)]
		var line_color := TEXT
		if worn != null and not is_worn:
			var delta := value - float(compare.get(stat, 0.0))
			if absf(delta) > 0.0001:
				line += "  (%s%s)" % ["+" if delta > 0.0 else "-", _stat_value(stat, absf(delta))]
				line_color = GREEN if delta > 0.0 else RED
		_text(line, box.position + Vector2(6 + col * 112, 34 + row * 9), 7, line_color)
		row += 1
		if row >= 3:
			row = 0
			col += 1


static func _stat_label(stat: String) -> String:
	match stat:
		"strength": return "FUERZA"
		"agility": return "AGILIDAD"
		"stamina": return "VIGOR"
		"intellect": return "INTELECTO"
		"armor": return "ARMADURA"
		"crit_chance": return "CRITICO"
		"attack_power_bonus": return "PODER ATAQUE"
		"spell_power_bonus": return "PODER MAGICO"
		"weapon_min": return "DANO MIN"
		"weapon_max": return "DANO MAX"
	return stat.to_upper()


static func _stat_value(stat: String, value: float) -> String:
	if stat == "crit_chance":
		return "%.1f%%" % (value * 100.0)
	return "%.1f" % value


func _text(text: String, at: Vector2, font_size: int, color: Color, alignment: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(FONT, at, text, alignment, width, font_size, color)
