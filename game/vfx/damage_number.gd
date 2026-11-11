## DamageNumber — número de daño flotante (presentación pura).
class_name DamageNumber
extends Label

const FONT := preload("res://assets/fonts/m5x7.ttf")

var _elapsed: float = 0.0
var _duration: float = 0.72
var _rise: float = 34.0
var _start: Vector2 = Vector2.ZERO


func setup(amount: float, critical: bool) -> void:
	text = ("%d!" % roundi(amount)) if critical else str(roundi(amount))
	add_theme_font_override("font", FONT)
	add_theme_font_size_override("font_size", 16 if critical else 12)
	add_theme_color_override("font_color", Color(1.0, 0.85, 0.28, 1.0) if critical else Color(1.0, 0.98, 0.92, 0.95))
	add_theme_color_override("font_outline_color", Color(0.08, 0.03, 0.02, 1.0))
	add_theme_constant_override("outline_size", 4 if critical else 3)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	custom_minimum_size = Vector2(48, 18)
	size = Vector2(48, 18)
	pivot_offset = Vector2(24, 9)
	z_index = 60
	if critical:
		scale = Vector2(1.35, 1.35)
		_duration = 0.9
		_rise = 44.0
	set_process(true)


## Texto flotante sin cifra (p. ej. DODGE).
func setup_label(label: String, color: Color) -> void:
	text = label
	add_theme_font_override("font", FONT)
	add_theme_font_size_override("font_size", 12)
	add_theme_color_override("font_color", color)
	add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.1, 1.0))
	add_theme_constant_override("outline_size", 3)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	custom_minimum_size = Vector2(48, 18)
	size = Vector2(48, 18)
	pivot_offset = Vector2(24, 9)
	z_index = 60
	_duration = 0.6
	_rise = 26.0
	set_process(true)


func place(world_position: Vector2) -> void:
	_start = world_position + Vector2(-24, -56)
	position = _start


func _process(delta: float) -> void:
	_elapsed += delta
	var t := clampf(_elapsed / _duration, 0.0, 1.0)
	position = _start + Vector2(0, -_rise * ease(t, 0.4))
	modulate.a = 1.0 - ease(t, 2.0)
	if t >= 1.0:
		queue_free()
		return
	if _elapsed < 0.12:
		scale = Vector2.ONE * (1.0 + (1.0 - _elapsed / 0.12) * 0.25)
