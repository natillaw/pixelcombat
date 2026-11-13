## CraftingPanel — taller de un edificio de la ciudad (se abre al usar su puerta).
##
## A la izquierda las recetas de la estacion; a la derecha el detalle: item, stats base
## del tier elegido, materiales (tienes/necesitas) y oro. Flechas izquierda/derecha o
## clic en el selector cambian el tier (hasta el que tengas abierto en la torre).
## Clic en FABRICAR (o Intro) lo fabrica. Es presentacion: la logica y las
## comprobaciones estan en `Crafting` y `GameSession.craft()`.
class_name CraftingPanel
extends Control

const FONT := preload("res://assets/fonts/m6x11.ttf")

const PANEL := Color(0.055, 0.065, 0.095, 0.96)
const EDGE := Color(0.33, 0.37, 0.47, 1.0)
const TEXT := Color(0.93, 0.90, 0.83, 1.0)
const MUTED := Color(0.84, 0.77, 0.60, 1.0)
const DIM := Color(0.58, 0.50, 0.40, 1.0)
const GOLD := Color(0.94, 0.74, 0.36, 1.0)
const GREEN := Color(0.55, 0.82, 0.45, 1.0)
const RED := Color(0.88, 0.34, 0.28, 1.0)

const PANEL_RECT := Rect2(36, 14, 568, 332)
const LIST_X := 48.0
const LIST_Y := 60.0
const LIST_W := 236.0
const ROW_H := 16.0
const DETAIL_X := 304.0

var world: CombatWorld
var session: GameSession
var is_open: bool = false

var _station: String = ""
var _recipes: Array = []
var _selected: int = 0
var _tier: int = 1
var _message: String = ""
var _message_color: Color = MUTED


func bind(p_world: CombatWorld, p_session: GameSession) -> void:
	world = p_world
	session = p_session
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_process(false)
	session.building_opened.connect(open)


func open(station: String) -> void:
	if is_open or TickManager.is_paused():
		return
	_station = station
	_recipes = RecipeCatalog.recipes_for(station)
	_selected = 0
	_tier = session.max_craft_tier()
	_say("Elige una receta. Mas tier = mejores stats y mas oro.", MUTED)
	is_open = true
	visible = true
	set_process(true)
	TickManager.set_paused(true)
	queue_redraw()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	set_process(false)
	TickManager.set_paused(false)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventKey) or not event.pressed:
		return
	match (event as InputEventKey).keycode:
		KEY_ESCAPE:
			close()
		KEY_UP, KEY_W:
			_selected = maxi(_selected - 1, 0)
		KEY_DOWN, KEY_S:
			_selected = mini(_selected + 1, _recipes.size() - 1)
		KEY_LEFT, KEY_A:
			_tier = maxi(_tier - 1, 1)
		KEY_RIGHT, KEY_D:
			_tier = mini(_tier + 1, session.max_craft_tier())
		KEY_ENTER, KEY_KP_ENTER:
			_craft()
		_:
			return
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventMouseButton) or not event.pressed or (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return
	var position := (event as InputEventMouseButton).position
	for i: int in range(_recipes.size()):
		if _row_rect(i).has_point(position):
			_selected = i
			accept_event()
			return
	if _tier_left_rect().has_point(position):
		_tier = maxi(_tier - 1, 1)
	elif _tier_right_rect().has_point(position):
		_tier = mini(_tier + 1, session.max_craft_tier())
	elif _craft_rect().has_point(position):
		_craft()
	elif not PANEL_RECT.has_point(position):
		close()
	accept_event()


func _craft() -> void:
	if _recipes.is_empty():
		return
	var result := session.craft(String(_recipes[_selected]["id"]), _tier)
	if bool(result["ok"]):
		var item: Dictionary = result["item"]
		_say("Fabricado: %s" % ItemCatalog.display_name(item), ItemCatalog.rarity_color(String(item["rarity"])))
		return
	match String(result["reason"]):
		"materials":
			_say("Te faltan materiales.", RED)
		"gold":
			_say("No tienes oro suficiente.", RED)
		"full":
			_say("La mochila esta llena.", RED)
		"tier":
			_say("Aun no has abierto ese tier en la torre.", RED)
		_:
			_say("No se puede fabricar ahora.", RED)


func _say(text: String, color: Color) -> void:
	_message = text
	_message_color = color


func _row_rect(i: int) -> Rect2:
	return Rect2(LIST_X, LIST_Y + float(i) * ROW_H, LIST_W, ROW_H - 2.0)


func _tier_left_rect() -> Rect2:
	return Rect2(DETAIL_X + 60.0, 52.0, 14.0, 12.0)


func _tier_right_rect() -> Rect2:
	return Rect2(DETAIL_X + 98.0, 52.0, 14.0, 12.0)


func _craft_rect() -> Rect2:
	return Rect2(DETAIL_X, 300.0, 120.0, 20.0)


func _draw() -> void:
	if not is_open or world == null:
		return
	draw_rect(Rect2(0, 0, 640, 360), Color(0.0, 0.0, 0.0, 0.5))
	UiStyle.draw_panel(self, PANEL_RECT)
	var player := world.player
	_text(RecipeCatalog.station_name(_station).to_upper(), Vector2(48, 36), 14, GOLD)
	_text("ESC  CERRAR", Vector2(0, 36), 7, MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 592)
	_text("ORO  %d" % player.gold, Vector2(0, 50), 7, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 592)
	_text("RECETAS", Vector2(LIST_X, 54), 7, MUTED)

	for i: int in range(_recipes.size()):
		var recipe: Dictionary = _recipes[i]
		var rect := _row_rect(i)
		var can := Crafting.reason(player, String(recipe["id"]), _tier, session.max_craft_tier()) == ""
		if i == _selected:
			draw_rect(rect, Color(0.16, 0.18, 0.25, 1.0))
			draw_rect(rect, EDGE, false, 1.0)
		var name := String(ItemCatalog.item(String(recipe["item"]))["name"])
		_text(name, rect.position + Vector2(4, 10), 7, TEXT if can else MUTED, HORIZONTAL_ALIGNMENT_LEFT, LIST_W - 8.0)
	if _recipes.is_empty():
		_text("Aqui aun no hay nada que fabricar.", Vector2(LIST_X, 74), 7, DIM)
		return

	var recipe: Dictionary = _recipes[_selected]
	var base := ItemCatalog.item(String(recipe["item"]))
	_text("TIER", Vector2(DETAIL_X, 62), 7, MUTED)
	_arrow(_tier_left_rect(), "<")
	_text("%d" % _tier, Vector2(DETAIL_X + 76, 62), 7, TEXT, HORIZONTAL_ALIGNMENT_CENTER, 22)
	_arrow(_tier_right_rect(), ">")
	_text("MAX %d" % session.max_craft_tier(), Vector2(DETAIL_X + 120, 62), 7, DIM)

	_text(String(base["name"]).to_upper(), Vector2(DETAIL_X, 90), 14, TEXT)
	_text(ItemCatalog.slot_name(String(base["slot"])).to_upper(), Vector2(DETAIL_X, 102), 7, MUTED)
	_text("STATS BASE (COMUN)  -  la rareza los mejora", Vector2(DETAIL_X, 118), 7, MUTED)
	var scale := ItemCatalog.tier_multiplier(_tier)
	var y := 128.0
	for stat: String in base["stats"]:
		var value := float(base["stats"][stat]) * scale
		_text("+%s %s" % [InventoryPanel._stat_value(stat, value), InventoryPanel._stat_label(stat)], Vector2(DETAIL_X, y), 7, TEXT)
		y += 9.0
	var classes: Variant = base.get("classes")
	if classes != null:
		_text("SOLO: %s" % ", ".join((classes as Array).map(func(c: Variant) -> String: return String(c).to_upper())), Vector2(DETAIL_X, y), 7, DIM)
		y += 9.0

	_text("MATERIALES", Vector2(DETAIL_X, 190), 7, MUTED)
	var cost := RecipeCatalog.cost_at(recipe, _tier)
	y = 200.0
	for id: String in cost:
		var have := player.material_count(id)
		var need := int(cost[id])
		_text("%s" % MaterialCatalog.display_name(id), Vector2(DETAIL_X, y), 7, TEXT)
		_text("%d / %d" % [have, need], Vector2(DETAIL_X, y), 7, GREEN if have >= need else RED, HORIZONTAL_ALIGNMENT_RIGHT, 240)
		y += 9.0
	var gold_cost := RecipeCatalog.gold_at(recipe, _tier)
	_text("Oro", Vector2(DETAIL_X, y), 7, TEXT)
	_text("%d / %d" % [player.gold, gold_cost], Vector2(DETAIL_X, y), 7, GREEN if player.gold >= gold_cost else RED, HORIZONTAL_ALIGNMENT_RIGHT, 240)

	var craft_rect := _craft_rect()
	var can_craft := Crafting.reason(player, String(recipe["id"]), _tier, session.max_craft_tier()) == ""
	draw_rect(craft_rect, Color(0.20, 0.32, 0.18, 1.0) if can_craft else Color(0.14, 0.15, 0.19, 1.0))
	draw_rect(craft_rect, GREEN if can_craft else DIM, false, 1.0)
	_text("FABRICAR  (INTRO)", craft_rect.position + Vector2(0, 13), 7, TEXT if can_craft else DIM, HORIZONTAL_ALIGNMENT_CENTER, craft_rect.size.x)
	_text(_message, Vector2(48, 330), 7, _message_color)


func _arrow(rect: Rect2, label: String) -> void:
	draw_rect(rect, Color(0.12, 0.14, 0.2, 1.0))
	draw_rect(rect, EDGE, false, 1.0)
	_text(label, rect.position + Vector2(0, 9), 7, TEXT, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


func _text(text: String, at: Vector2, font_size: int, color: Color, alignment: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(FONT, at, text, alignment, width, maxi(font_size, UiStyle.MIN_FONT), color)
