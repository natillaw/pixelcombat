## CityProp — decoracion de la ciudad dibujada en codigo con la misma paleta que el resto (estandartes,
## braseros, puestos de mercado, bancos, maceteros, estatuas, farolas y parterres). Presentacion pura:
## la colision de cada prop ya esta reservada en el mapa (casillas SOLID) por `Layouts`.
## El nodo esta en el pie del objeto; se dibuja hacia arriba (Y negativa).
class_name CityProp
extends Node2D

const STONE := Color(0.58, 0.59, 0.66)
const STONE_LIGHT := Color(0.74, 0.75, 0.82)
const STONE_DARK := Color(0.34, 0.35, 0.43)
const WOOD := Color(0.47, 0.31, 0.17)
const WOOD_DARK := Color(0.30, 0.19, 0.10)
const PURPLE := Color(0.40, 0.23, 0.66)
const PURPLE_DARK := Color(0.26, 0.14, 0.45)
const GOLD := Color(0.96, 0.79, 0.32)
const LEAF := Color(0.24, 0.52, 0.22)
const LEAF_LIGHT := Color(0.36, 0.68, 0.30)
const ANIMATED: Array[String] = ["banner", "brazier", "lamppost"]
const FLOWER_COLORS: Array[Color] = [Color(0.95, 0.35, 0.45), Color(0.98, 0.85, 0.35), Color(0.95, 0.95, 0.98), Color(0.7, 0.5, 0.95), Color(0.98, 0.6, 0.3)]

var kind: String = ""
var variant: int = 0
var _time: float = 0.0


func setup(p_kind: String, p_variant: int = 0) -> void:
	kind = p_kind
	variant = p_variant
	_time = float(abs(hash("%s%d%d" % [kind, variant, int(position.x * 7.0 + position.y)])) % 628) * 0.01
	set_process(ANIMATED.has(kind))
	if kind == "plaza_ring" or kind == "flowerbed":
		z_index = -30
		y_sort_enabled = false
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	match kind:
		"banner":
			_draw_banner()
		"brazier":
			_draw_brazier()
		"stall":
			_draw_stall()
		"bench":
			_draw_bench()
		"planter":
			_draw_planter()
		"statue":
			_draw_statue()
		"lamppost":
			_draw_lamppost()
		"flowerbed":
			_draw_flowerbed()
		"plaza_ring":
			_draw_plaza_ring()


func _shadow(width: float, height: float = 7.0) -> void:
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, height / width))
	draw_circle(Vector2.ZERO, width * 0.5, Color(0.0, 0.0, 0.0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_banner() -> void:
	_shadow(18.0)
	draw_rect(Rect2(-2, -78, 4, 78), WOOD_DARK)
	draw_rect(Rect2(-14, -78, 28, 3), WOOD)
	draw_circle(Vector2(0, -80), 3.0, GOLD)
	var sway := sin(_time * 1.6) * 2.0
	var cloth := PackedVector2Array([Vector2(-12, -75), Vector2(12, -75), Vector2(12 + sway * 0.5, -36), Vector2(sway, -28), Vector2(-12 + sway * 0.5, -36)])
	draw_colored_polygon(cloth, PURPLE)
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -75), Vector2(-4, -75), Vector2(-4 + sway * 0.4, -33), Vector2(-12 + sway * 0.5, -36)]), PURPLE_DARK)
	draw_arc(Vector2(sway * 0.3, -55), 7.0, 0.0, TAU, 14, GOLD, 2.0)
	draw_line(Vector2(sway * 0.3, -62), Vector2(sway * 0.3, -46), GOLD, 2.0)
	draw_line(Vector2(sway * 0.3 - 5, -50), Vector2(sway * 0.3 + 5, -50), GOLD, 2.0)


func _draw_brazier() -> void:
	_shadow(30.0)
	draw_rect(Rect2(-11, -14, 22, 14), STONE_DARK)
	draw_rect(Rect2(-9, -30, 18, 18), STONE)
	draw_rect(Rect2(-9, -30, 5, 18), STONE_LIGHT)
	draw_rect(Rect2(-14, -36, 28, 8), STONE_DARK)
	draw_rect(Rect2(-12, -38, 24, 4), Color(0.12, 0.1, 0.1))
	var flicker := sin(_time * 11.0) * 2.0 + sin(_time * 7.3) * 1.5
	draw_circle(Vector2(0, -44), 34.0 + flicker, Color(1.0, 0.6, 0.2, 0.10))
	draw_circle(Vector2(0, -44), 20.0 + flicker, Color(1.0, 0.65, 0.25, 0.14))
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -38), Vector2(-3, -50 - flicker), Vector2(0, -60 - flicker * 1.4), Vector2(4, -49 - flicker), Vector2(10, -38)]), Color(1.0, 0.42, 0.12))
	draw_colored_polygon(PackedVector2Array([Vector2(-5, -38), Vector2(0, -52 - flicker), Vector2(6, -38)]), Color(1.0, 0.82, 0.35))


func _draw_stall() -> void:
	_shadow(100.0, 14.0)
	var a := Color(0.82, 0.2, 0.22) if variant % 2 == 0 else Color(0.25, 0.4, 0.78)
	# Mostrador y mercancia.
	draw_rect(Rect2(-40, -22, 80, 22), WOOD)
	draw_rect(Rect2(-40, -22, 80, 4), Color(0.6, 0.42, 0.24))
	draw_rect(Rect2(-40, -8, 80, 2), WOOD_DARK)
	for i: int in range(7):
		var x := -34.0 + float(i) * 11.0
		var tint: Color = FLOWER_COLORS[(i + variant) % FLOWER_COLORS.size()] if variant % 2 == 0 else [Color(0.7, 0.7, 0.78), Color(0.55, 0.38, 0.22), Color(0.82, 0.8, 0.7)][i % 3]
		draw_circle(Vector2(x, -27), 4.0, tint)
	# Postes y toldo a rayas.
	draw_rect(Rect2(-42, -64, 4, 44), WOOD_DARK)
	draw_rect(Rect2(38, -64, 4, 44), WOOD_DARK)
	for i: int in range(8):
		var x0 := -46.0 + float(i) * 11.5
		var color := a if i % 2 == 0 else Color(0.96, 0.94, 0.9)
		draw_colored_polygon(PackedVector2Array([Vector2(x0 + 2, -78), Vector2(x0 + 13.5, -78), Vector2(x0 + 15.5, -58), Vector2(x0, -58)]), color)
	draw_rect(Rect2(-46, -60, 92, 3), a.darkened(0.25))


func _draw_bench() -> void:
	_shadow(46.0)
	draw_rect(Rect2(-20, -14, 3, 14), WOOD_DARK)
	draw_rect(Rect2(17, -14, 3, 14), WOOD_DARK)
	draw_rect(Rect2(-22, -16, 44, 5), WOOD)
	draw_rect(Rect2(-22, -16, 44, 2), Color(0.62, 0.43, 0.25))
	draw_rect(Rect2(-22, -28, 44, 4), WOOD_DARK)
	draw_rect(Rect2(-22, -24, 3, 9), WOOD_DARK)
	draw_rect(Rect2(19, -24, 3, 9), WOOD_DARK)


func _draw_planter() -> void:
	_shadow(36.0)
	draw_rect(Rect2(-15, -16, 30, 16), STONE)
	draw_rect(Rect2(-15, -16, 30, 4), STONE_LIGHT)
	draw_rect(Rect2(-15, -3, 30, 3), STONE_DARK)
	for i: int in range(4):
		var p := Vector2(-9.0 + float(i) * 6.0, -22.0 - float(i % 2) * 4.0)
		draw_circle(p, 7.0, LEAF)
		draw_circle(p + Vector2(-2, -2), 4.0, LEAF_LIGHT)
	for i: int in range(5):
		draw_circle(Vector2(-11.0 + float(i) * 5.5, -24.0 - float((i * 3) % 4)), 1.8, FLOWER_COLORS[(i + variant) % FLOWER_COLORS.size()])


func _draw_statue() -> void:
	_shadow(34.0)
	draw_rect(Rect2(-14, -16, 28, 16), STONE_DARK)
	draw_rect(Rect2(-12, -22, 24, 7), STONE)
	# Guardian: cuerpo, escudo, casco y lanza.
	draw_rect(Rect2(-8, -54, 16, 32), STONE)
	draw_rect(Rect2(-8, -54, 5, 32), STONE_LIGHT)
	draw_circle(Vector2(0, -60), 7.0, STONE)
	draw_rect(Rect2(-7, -66, 14, 5), STONE_DARK)
	draw_rect(Rect2(-17, -50, 9, 18), STONE_DARK)
	draw_rect(Rect2(-16, -49, 7, 16), STONE_LIGHT)
	draw_rect(Rect2(12, -78, 3, 56), Color(0.45, 0.46, 0.54))
	draw_colored_polygon(PackedVector2Array([Vector2(10, -78), Vector2(13.5, -90), Vector2(17, -78)]), STONE_LIGHT)


func _draw_lamppost() -> void:
	_shadow(14.0)
	draw_rect(Rect2(-2, -62, 4, 62), Color(0.2, 0.2, 0.26))
	draw_rect(Rect2(-9, -72, 18, 12), Color(0.18, 0.18, 0.24))
	var glow := 0.8 + sin(_time * 5.0) * 0.1
	draw_rect(Rect2(-6, -70, 12, 8), Color(1.0, 0.82, 0.42, glow))
	draw_circle(Vector2(0, -66), 26.0, Color(1.0, 0.78, 0.35, 0.09))
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -72), Vector2(0, -80), Vector2(10, -72)]), Color(0.22, 0.22, 0.3))


func _draw_flowerbed() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant * 7919 + 13
	for i: int in range(22):
		var offset := Vector2(rng.randf_range(-34.0, 34.0), rng.randf_range(-10.0, 10.0))
		draw_line(offset + Vector2(0, 3), offset, LEAF, 1.5)
		draw_circle(offset + Vector2(0, -1), 2.2, FLOWER_COLORS[rng.randi() % FLOWER_COLORS.size()])


func _draw_plaza_ring() -> void:
	# Anillo de losas claras alrededor de la fuente (el suelo ya es adoquin; esto lo marca como plaza).
	var radius := 7.0 * 32.0
	for i: int in range(3):
		var r := radius - 4.0 - float(i) * 22.0
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(0.82, 0.8, 0.9, 0.34 - float(i) * 0.08), 8.0 if i == 0 else 3.0)
	for i: int in range(24):
		var angle := TAU * float(i) / 24.0
		draw_line(Vector2.from_angle(angle) * 70.0, Vector2.from_angle(angle) * (radius - 30.0), Color(0.82, 0.8, 0.9, 0.12), 2.0)
