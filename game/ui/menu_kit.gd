## MenuKit — piezas comunes de los menus (titulo, boton, etiqueta) con el estilo del juego.
class_name MenuKit
extends RefCounted

const FONT := preload("res://assets/fonts/m6x11.ttf")
const GOLD := Color(0.94, 0.74, 0.36, 1.0)
const TEXT := Color(0.93, 0.90, 0.83, 1.0)
const MUTED := Color(0.78, 0.72, 0.56, 1.0)


static func label(parent: Control, text: String, rect: Rect2, size: int = 8, color: Color = TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var node := Label.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_override("font", FONT)
	node.add_theme_font_size_override("font_size", maxi(size, UiStyle.MIN_FONT))
	node.add_theme_color_override("font_color", color)
	node.horizontal_alignment = align
	node.clip_text = true
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


static func button(parent: Control, text: String, rect: Rect2, callback: Callable, size: int = 8) -> Button:
	var node := Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_override("font", FONT)
	node.add_theme_font_size_override("font_size", maxi(size, 14))
	node.add_theme_color_override("font_color", TEXT)
	node.add_theme_color_override("font_hover_color", GOLD)
	node.add_theme_color_override("font_disabled_color", Color(0.5, 0.48, 0.42, 1.0))
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		node.add_theme_stylebox_override(state, UiStyle.button_style(state))
	node.pressed.connect(callback)
	parent.add_child(node)
	return node


## Texto largo con ajuste de linea (para avisos y explicaciones).
static func note(parent: Control, text: String, width: float, size: int = 14, color: Color = MUTED) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_override("font", FONT)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.custom_minimum_size = Vector2(width, 0.0)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


static func panel(parent: Control, rect: Rect2, title: String = "") -> UiPanel:
	var node := UiPanel.new()
	node.position = rect.position
	node.size = rect.size
	node.title = title
	parent.add_child(node)
	return node


## Pinta lo que haya en `container` y lo vacia (los menus se reconstruyen al cambiar de pantalla).
static func clear(container: Node) -> void:
	for child: Node in container.get_children():
		child.queue_free()
