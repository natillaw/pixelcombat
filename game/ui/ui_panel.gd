## UiPanel — un Control que se dibuja como panel ornamentado (UiStyle.draw_panel), para las
## pantallas hechas con nodos (el creador de personaje).
class_name UiPanel
extends Control

var title: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	UiStyle.draw_panel(self, Rect2(Vector2.ZERO, size), title)
