## SettingsPanel — ajustes: volumen general y de efectos, pantalla completa y reasignacion de teclas.
## Lo usan el menu principal y el de pausa. Los cambios se aplican y se guardan al momento.
class_name SettingsPanel
extends Control

signal closed

var _listening: String = ""
var _page: int = 0
var _buttons: Dictionary = {}
var _body: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func open() -> void:
	_listening = ""
	_page = 0
	visible = true
	_build()


func _build() -> void:
	if _body != null:
		_body.queue_free()
	_body = Control.new()
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_body)
	_buttons = {}
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.add_child(shade)
	MenuKit.panel(_body, Rect2(40, 20, 560, 320), "AJUSTES")
	if _page == 1:
		_build_access()
		return
	MenuKit.label(_body, "Volumen general", Rect2(60, 42, 150, 16), 14, MenuKit.MUTED)
	_slider(Rect2(212, 44, 110, 12), Settings.master, func(value: float) -> void: Settings.set_master(value); Settings.save())
	MenuKit.label(_body, "Efectos", Rect2(340, 42, 70, 16), 14, MenuKit.MUTED)
	_slider(Rect2(414, 44, 130, 12), Settings.sfx, func(value: float) -> void: Settings.set_sfx(value); Settings.save())
	var check := CheckBox.new()
	check.text = "Pantalla completa"
	check.position = Vector2(60, 60)
	check.button_pressed = Settings.fullscreen
	check.focus_mode = Control.FOCUS_NONE
	check.add_theme_font_override("font", MenuKit.FONT)
	check.add_theme_font_size_override("font_size", 14)
	check.toggled.connect(func(on: bool) -> void: Settings.set_fullscreen(on); Settings.save())
	_body.add_child(check)
	MenuKit.label(_body, "TECLAS: clic y pulsa la nueva (Esc cancela)", Rect2(60, 84, 480, 16), 14, MenuKit.GOLD)
	var half := int(ceil(float(Settings.REMAPPABLE.size()) / 2.0))
	for i: int in range(Settings.REMAPPABLE.size()):
		var pair: Array = Settings.REMAPPABLE[i]
		var column := i / half
		var row := i % half
		var x := 60.0 + float(column) * 270.0
		var y := 102.0 + float(row) * 22.0
		MenuKit.label(_body, String(pair[1]), Rect2(x, y + 3.0, 150, 16), 14, MenuKit.TEXT)
		var action := String(pair[0])
		_buttons[action] = MenuKit.button(_body, Settings.key_label(action), Rect2(x + 154.0, y, 100, 20), func() -> void: _listen(action))
	MenuKit.button(_body, "Accesibilidad y musica", Rect2(240, 312, 200, 22), func() -> void: _page = 1; _build())
	MenuKit.button(_body, "Restablecer teclas", Rect2(60, 312, 170, 22), func() -> void: Settings.reset_bindings(); _build())
	MenuKit.button(_body, "Volver", Rect2(450, 312, 110, 22), _close)


## Segunda pagina: musica y comodidad. Todo es solo visual/sonoro: la simulacion no cambia.
func _build_access() -> void:
	MenuKit.label(_body, "MUSICA Y COMODIDAD (no cambian el juego, solo como se ve y suena)", Rect2(60, 52, 500, 16), 14, MenuKit.GOLD)
	MenuKit.label(_body, "Musica", Rect2(60, 70, 190, 16), 14, MenuKit.MUTED)
	_slider(Rect2(260, 72, 200, 12), Settings.music, func(value: float) -> void: Settings.set_music(value); Settings.save())
	MenuKit.label(_body, "Sacudida de camara", Rect2(60, 96, 190, 16), 14, MenuKit.MUTED)
	_slider(Rect2(260, 98, 200, 12), Settings.shake, func(value: float) -> void: Settings.shake = value; Settings.save())
	_check_box("Golpe de zoom de la camara", Settings.zoom_punch, Vector2(60, 122), func(on: bool) -> void: Settings.zoom_punch = on; Settings.save())
	_check_box("Pausa de impacto (hit-stop)", Settings.hit_stop, Vector2(60, 148), func(on: bool) -> void: Settings.hit_stop = on; Settings.save())
	_check_box("Camara lenta al morir", Settings.slow_motion, Vector2(60, 174), func(on: bool) -> void: Settings.slow_motion = on; Settings.save())
	_check_box("Destellos rojos de dano", Settings.damage_flash, Vector2(60, 200), func(on: bool) -> void: Settings.damage_flash = on; Settings.save())
	MenuKit.label(_body, "Latencia simulada (pruebas): %d ms" % Settings.sim_latency_ms, Rect2(60, 232, 300, 16), 14, MenuKit.MUTED)
	var latency := HSlider.new()
	latency.position = Vector2(60, 252)
	latency.size = Vector2(300, 12)
	latency.min_value = 0
	latency.max_value = 300
	latency.step = 20
	latency.value = Settings.sim_latency_ms
	latency.focus_mode = Control.FOCUS_NONE
	latency.value_changed.connect(func(value: float) -> void: Settings.sim_latency_ms = int(value); Settings.save(); _build())
	_body.add_child(latency)
	MenuKit.button(_body, "Volver", Rect2(450, 312, 110, 22), func() -> void: _page = 0; _build())


func _check_box(text: String, value: bool, at: Vector2, on_toggle: Callable) -> void:
	var box := CheckBox.new()
	box.text = text
	box.position = at
	box.button_pressed = value
	box.focus_mode = Control.FOCUS_NONE
	box.add_theme_font_override("font", MenuKit.FONT)
	box.add_theme_font_size_override("font_size", 14)
	box.toggled.connect(on_toggle)
	_body.add_child(box)


func _slider(rect: Rect2, value: float, on_change: Callable) -> void:
	var slider := HSlider.new()
	slider.position = rect.position
	slider.size = rect.size
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(on_change)
	_body.add_child(slider)


func _listen(action: String) -> void:
	_listening = action
	(_buttons[action] as Button).text = "..."


func _close() -> void:
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _listening != "":
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode != KEY_ESCAPE:
				Settings.rebind(_listening, event)
			_listening = ""
			_build()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed:
			Settings.rebind(_listening, event)
			_listening = ""
			_build()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()
