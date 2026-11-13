## CharacterCreator — pantalla de nuevo personaje: primero el lore (la Torre, Albor, los
## Despiertos) y despues el nombre, la clase y el aspecto (cuerpo, piel, pelo, ojos,
## barba). **La ropa no se elige**: todos empiezan con la mas sencilla de su clase; el resto
## de prendas hay que conseguirlas como equipo (items, crafting).
##
## Es presentacion pura: al confirmar emite \`created\` y es la sesion la que crea al
## personaje. Se dibuja con Controls sobre el lienzo de 640x360.
class_name CharacterCreator
extends Control

signal created(character_name: String, class_id: String, appearance: Dictionary)

const FONT := preload("res://assets/fonts/m6x11.ttf")
const GOLD := Color(0.94, 0.74, 0.36, 1.0)
const TEXT := Color(0.93, 0.90, 0.83, 1.0)
const MUTED := Color(0.86, 0.80, 0.62, 1.0)
const PANEL := Color(0.055, 0.065, 0.10, 0.97)
const EDGE := Color(0.62, 0.48, 0.24, 1.0)

const SKIN_NAMES := {"light": "Clara", "amber": "Ambar", "olive": "Oliva", "taupe": "Topo", "bronze": "Bronce", "brown": "Morena", "black": "Oscura"}
const HAIR_STYLES := [["", "Calvo"], ["hair_buzzcut", "Rapado"], ["hair_bob", "Bob"], ["hair_plain", "Suelto"], ["hair_balding", "Entradas"],
	["hair_flat_top_fade", "Cresta plana"], ["hair_parted3", "Raya al lado"], ["hair_curly_short", "Rizado corto"], ["hair_curly_long", "Rizado largo"],
	["hair_afro", "Afro"], ["hair_cornrows", "Trenzas pegadas"], ["hair_dreadlocks_short", "Rastas"], ["hair_bob_side_part", "Bob de lado"],
	["hair_lob", "Media melena"], ["hair_long_straight", "Largo liso"], ["hair_long_center_part", "Largo con raya"], ["hair_long_tied", "Largo atado"],
	["hair_xlong_wavy", "Larguisimo ondulado"], ["hair_high_ponytail", "Cola alta"], ["hair_half_up", "Medio recogido"]]
const BEARD_STYLES := [["", "Sin barba"], ["beard_trimmed", "Perilla"], ["beard_medium", "Barba media"], ["beard_winter", "Barba larga"], ["beard_handlebar", "Bigote de manillar"], ["beard_walrus", "Bigote de morsa"]]
const BROW_STYLES := [["", "Sin cejas"], ["brows_thin", "Cejas finas"], ["brows_thick", "Cejas gruesas"]]
const HAIR_COLOR_NAMES := {"black": "Negro", "dark_brown": "Castano oscuro", "chestnut": "Castano", "light_brown": "Castano claro", "blonde": "Rubio", "ginger": "Pelirrojo", "gray": "Gris", "white": "Blanco", "red": "Rojo"}
const EYE_NAMES := {"blue": "Azules", "green": "Verdes", "brown": "Marrones", "gray": "Grises"}
const NAMES := ["Kael", "Iria", "Dorian", "Selene", "Bram", "Nyra", "Torvin", "Lyra", "Aldric", "Vesna", "Rurik", "Maelis"]

var _stage: String = "lore"
var _page: int = 0
var _class_id: String = "warrior"
var _look: Dictionary = {"body": "male", "skin": "light", "eyes": "blue", "hair": "hair_buzzcut", "hair_color": "dark_brown", "beard": "", "brows": "brows_thin"}
var _was_paused: bool = false

var _root: Control
var _name_edit: LineEdit
var _preview: TextureRect
var _blurb: Label
var _value_labels: Dictionary = {}
var _class_buttons: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


## Abre el creador (pausa la simulacion mientras esta abierto).
func start() -> void:
	_stage = "lore"
	_page = 0
	visible = true
	_was_paused = TickManager.is_paused()
	TickManager.set_paused(true)
	_build()


func _finish() -> void:
	visible = false
	TickManager.set_paused(_was_paused)
	created.emit(_name_edit.text, _class_id, _appearance())


func _appearance() -> Dictionary:
	var out := _look.duplicate()
	out["head"] = "head_human_%s" % String(_look["body"])
	return out


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and _stage == "lore" and event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
		_next_page()
		get_viewport().set_input_as_handled()


# --- Construccion --------------------------------------------------------------------


func _build() -> void:
	if _root != null:
		_root.queue_free()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.015, 0.02, 0.035, 1.0)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)
	if _stage == "lore":
		_build_lore()
	else:
		_build_create()


func _panel(rect: Rect2, title: String = "") -> UiPanel:
	var panel := UiPanel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.title = title
	_root.add_child(panel)
	return panel


func _label(text: String, rect: Rect2, size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", maxi(size, UiStyle.MIN_FONT))
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(rect.size.x, 0.0)
	label.clip_text = not wrap
	_root.add_child(label)
	label.size = rect.size
	return label


func _button(text: String, rect: Rect2, callback: Callable, size: int = 8) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.custom_minimum_size = Vector2.ZERO
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", maxi(size, UiStyle.MIN_FONT))
	button.add_theme_color_override("font_color", Color(0.93, 0.90, 0.83))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.52))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.88, 0.52))
	for state: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, UiStyle.button_style("normal" if state == "focus" else state))
	button.pressed.connect(callback)
	_root.add_child(button)
	button.size = rect.size
	return button


func _build_lore() -> void:
	var pages := Lore.intro_pages()
	var page: Dictionary = pages[_page]
	_panel(Rect2(30, 22, 580, 316), "LA TORRE DE LAS CIEN PUERTAS")
	var art := TowerArt.new()
	art.position = Vector2(46, 40)
	art.size = Vector2(150, 262)
	art.progress = float(_page) / float(maxi(pages.size() - 1, 1))
	_root.add_child(art)
	_label(String(page["title"]).to_upper(), Rect2(214, 46, 380, 22), 16, GOLD)
	_label(String(page["text"]), Rect2(214, 78, 380, 210), 16, TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	_label("%d / %d" % [_page + 1, pages.size()], Rect2(214, 292, 380, 12), 8, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_button("Saltar", Rect2(214, 308, 70, 22), _skip_lore)
	_button("Siguiente  >" if _page < pages.size() - 1 else "Crear personaje  >", Rect2(440, 308, 154, 22), _next_page)


func _next_page() -> void:
	if _stage != "lore":
		return
	if _page < Lore.intro_pages().size() - 1:
		_page += 1
	else:
		_stage = "create"
	_build()
	if _stage == "create":
		_refresh_preview()


func _skip_lore() -> void:
	_stage = "create"
	_build()
	_refresh_preview()


func _build_create() -> void:
	_panel(Rect2(10, 8, 620, 344), "TU PERSONAJE")
	# Vista previa.
	_panel(Rect2(22, 40, 196, 196), "VISTA PREVIA")
	_preview = TextureRect.new()
	_preview.position = Vector2(26, 56)
	_preview.size = Vector2(188, 176)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_root.add_child(_preview)
	_label("NOMBRE", Rect2(24, 242, 196, 12), 8, MUTED)
	_name_edit = LineEdit.new()
	_name_edit.position = Vector2(22, 256)
	_name_edit.size = Vector2(150, 22)
	_name_edit.max_length = 16
	_name_edit.text = NAMES[randi() % NAMES.size()]
	_name_edit.add_theme_font_override("font", FONT)
	_name_edit.add_theme_font_size_override("font_size", 14)
	_root.add_child(_name_edit)
	_button("?", Rect2(176, 256, 42, 22), _random_name)
	_label("Sin nombre te llamaran Despierto.", Rect2(22, 282, 196, 20), 8, MUTED, HORIZONTAL_ALIGNMENT_LEFT, true)
	# Opciones de aspecto.
	_panel(Rect2(226, 40, 202, 256), "ASPECTO")
	_value_labels.clear()
	_option_row(0, "Cuerpo", "body")
	_option_row(1, "Piel", "skin")
	_option_row(2, "Pelo", "hair")
	_option_row(3, "Color de pelo", "hair_color")
	_option_row(4, "Ojos", "eyes")
	_option_row(5, "Barba", "beard")
	_option_row(6, "Cejas", "brows")
	_label("La ropa se consigue como equipo.", Rect2(243, 268, 176, 14), 8, MUTED, HORIZONTAL_ALIGNMENT_LEFT, true)
	# Clases.
	_panel(Rect2(430, 40, 192, 270), "CLASE")
	_class_buttons.clear()
	var y := 66.0
	for class_id: String in ["warrior", "rogue", "mage", "archer"]:
		var blurb := Lore.class_blurb(class_id)
		var button := _button(String(ClassCatalog.class_def(class_id)["name"]).to_upper(), Rect2(440, y, 172, 24), _select_class.bind(class_id))
		_class_buttons[class_id] = button
		y += 28.0
	_blurb = _label("", Rect2(443, 182, 166, 118), 8, TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	_button("Despertar  >", Rect2(436, 318, 184, 26), _finish, 16)
	_button("<  Historia", Rect2(22, 318, 100, 26), _back_to_lore)
	_refresh_class_buttons()


func _back_to_lore() -> void:
	_stage = "lore"
	_page = 0
	_build()


func _random_name() -> void:
	_name_edit.text = NAMES[randi() % NAMES.size()]


func _option_row(index: int, title: String, key: String) -> void:
	var y := 66.0 + float(index) * 28.0
	_label(title.to_upper(), Rect2(243, y, 176, 12), 8, MUTED)
	_button("<", Rect2(243, y + 12.0, 24, 14), _cycle.bind(key, -1))
	_button(">", Rect2(385, y + 12.0, 24, 14), _cycle.bind(key, 1))
	_value_labels[key] = _label("", Rect2(269, y + 12.0, 112, 14), 8, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_update_value(key)


func _values(key: String) -> Array:
	match key:
		"body":
			return [["male", "Masculino"], ["female", "Femenino"]]
		"skin":
			return (LpcWardrobe.SKINS as Array).map(func(id: String) -> Array: return [id, SKIN_NAMES.get(id, id)])
		"hair":
			return HAIR_STYLES
		"hair_color":
			return (LpcWardrobe.HAIR_COLORS as Array).map(func(id: String) -> Array: return [id, HAIR_COLOR_NAMES.get(id, id)])
		"eyes":
			return (LpcWardrobe.EYES as Array).map(func(id: String) -> Array: return [id, EYE_NAMES.get(id, id)])
		"beard":
			return BEARD_STYLES
		"brows":
			return BROW_STYLES
	return []


func _cycle(key: String, direction: int) -> void:
	var values := _values(key)
	if key == "beard" and String(_look["body"]) == "female":
		return
	var index := 0
	for i: int in range(values.size()):
		if String((values[i] as Array)[0]) == String(_look[key]):
			index = i
	index = (index + direction + values.size()) % values.size()
	_look[key] = String((values[index] as Array)[0])
	if key == "body" and String(_look["body"]) == "female":
		_look["beard"] = ""
	_update_value("beard")
	_update_value(key)
	_refresh_preview()


func _update_value(key: String) -> void:
	var label: Label = _value_labels.get(key)
	if label == null:
		return
	for entry: Variant in _values(key):
		if String((entry as Array)[0]) == String(_look[key]):
			label.text = String((entry as Array)[1])
	if key == "beard" and String(_look["body"]) == "female":
		label.text = "-"


func _select_class(class_id: String) -> void:
	_class_id = class_id
	_refresh_class_buttons()
	_refresh_preview()


func _refresh_class_buttons() -> void:
	for class_id: String in _class_buttons:
		var button: Button = _class_buttons[class_id]
		button.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4) if class_id == _class_id else Color(0.93, 0.90, 0.83))
	if _blurb != null:
		_blurb.text = "%s\n%s" % [String(Lore.class_blurb(_class_id)["tagline"]), String(Lore.class_blurb(_class_id)["text"])]


func _refresh_preview() -> void:
	if _preview == null:
		return
	_preview.texture = ClassLook.portrait(_class_id, _appearance())


## Ilustracion de la Torre para las paginas de historia: cielo estrellado, la aguja negra que se
## pierde en la niebla y ventanas encendidas que aumentan con cada pagina.
class TowerArt extends Control:
	var progress: float = 0.0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.04, 0.09))
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for i: int in range(40):
			draw_rect(Rect2(rng.randf_range(2, size.x - 2), rng.randf_range(2, size.y * 0.6), 1, 1), Color(0.8, 0.85, 1.0, rng.randf_range(0.3, 0.9)))
		draw_circle(Vector2(size.x * 0.78, size.y * 0.16), 11.0, Color(0.9, 0.92, 1.0, 0.9))
		draw_circle(Vector2(size.x * 0.78 + 4.0, size.y * 0.16 - 2.0), 10.0, Color(0.03, 0.04, 0.09))
		var cx := size.x * 0.5
		var base := size.y - 10.0
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 34.0, base), Vector2(cx + 34.0, base), Vector2(cx + 20.0, 0.0), Vector2(cx - 20.0, 0.0)]), Color(0.08, 0.09, 0.14))
		draw_polyline(PackedVector2Array([Vector2(cx - 34.0, base), Vector2(cx - 20.0, 0.0)]), Color(0.3, 0.32, 0.42), 1.0)
		draw_polyline(PackedVector2Array([Vector2(cx + 34.0, base), Vector2(cx + 20.0, 0.0)]), Color(0.3, 0.32, 0.42), 1.0)
		var windows := 6 + int(progress * 14.0)
		for i: int in range(windows):
			var t := float(i) / 20.0
			var y := base - 14.0 - t * (base - 8.0) * 0.95
			var x := cx + (-1.0 if i % 2 == 0 else 1.0) * lerpf(14.0, 6.0, t)
			draw_rect(Rect2(x - 2.0, y, 4.0, 6.0), Color(1.0, 0.75, 0.35, 0.9))
		for i: int in range(5):
			draw_rect(Rect2(0, size.y * 0.55 + float(i) * size.y * 0.09, size.x, size.y * 0.09), Color(0.05, 0.06, 0.1, 0.12 + 0.1 * float(i)))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.62, 0.48, 0.24), false, 1.0)
