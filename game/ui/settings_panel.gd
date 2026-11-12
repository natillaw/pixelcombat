## SettingsPanel — ajustes: volumen general y de efectos, pantalla completa y reasignacion de teclas.
## Lo usan el menu principal y el de pausa. Los cambios se aplican y se guardan al momento.
class_name SettingsPanel
extends Control

signal closed

var _listening: String = ""
var _buttons: Dictionary = {}
var _body: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func open() -> void:
	_listening = ""
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
	MenuKit.label(_body, "Volumen general", Rect2(60, 44, 120, 12), 8, MenuKit.MUTED)
	_slider(Rect2(180, 44, 140, 12), Settings.master, func(value: float) -> void: Settings.set_master(value); Settings.save())
	MenuKit.label(_body, "Efectos", Rect2(340, 44, 60, 12), 8, MenuKit.MUTED)
	_slider(Rect2(400, 44, 140, 12), Settings.sfx, func(value: float) -> void: Settings.set_sfx(value); Settings.save())
	var check := CheckBox.new()
	check.text = "Pantalla completa"
	check.position = Vector2(60, 62)
	check.button_pressed = Settings.fullscreen
	check.focus_mode = Control.FOCUS_NONE
	check.add_theme_font_override("font", MenuKit.FONT)
	check.add_theme_font_size_override("font_size", 8)
	check.toggled.connect(func(on: bool) -> void: Settings.set_fullscreen(on); Settings.save())
	_body.add_child(check)
	MenuKit.label(_body, "TECLAS (clic en una y pulsa la nueva; Esc cancela)", Rect2(60, 86, 480, 12), 8, MenuKit.GOLD)
	var half := int(ceil(float(Settings.REMAPPABLE.size()) / 2.0))
	for i: int in range(Settings.REMAPPABLE.size()):
		var pair: Array = Settings.REMAPPABLE[i]
		var column := i / half
		var row := i % half
		var x := 60.0 + float(column) * 270.0
		var y := 104.0 + float(row) * 22.0
		MenuKit.label(_body, String(pair[1]), Rect2(x, y + 3.0, 130, 12), 8, MenuKit.TEXT)
		var action := String(pair[0])
		_buttons[action] = MenuKit.button(_body, Settings.key_label(action), Rect2(x + 134.0, y, 110, 18), func() -> void: _listen(action))
	MenuKit.button(_body, "Restablecer teclas", Rect2(60, 306, 140, 20), func() -> void: Settings.reset_bindings(); _build())
	MenuKit.button(_body, "Volver", Rect2(460, 306, 100, 20), _close)


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
