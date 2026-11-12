## UiStyle — el aspecto comun de todas las interfaces (inspirado en Drakantos): paneles
## azul noche con marco dorado y tachuelas en las esquinas, huecos biselados, barras en
## capsula con brillo y segmentos y botones a juego. Todo se dibuja por codigo (no hay
## texturas), asi que la misma funcion vale para el HUD, el inventario, el taller, el
## loadout y el creador de personaje.
class_name UiStyle
extends RefCounted

const FONT := preload("res://assets/fonts/m5x7.ttf")

const NAVY := Color(0.045, 0.058, 0.10, 0.95)
const NAVY_LIGHT := Color(0.085, 0.10, 0.16, 0.95)
const GOLD := Color(0.88, 0.68, 0.30, 1.0)
const GOLD_DIM := Color(0.50, 0.38, 0.20, 1.0)
const GOLD_LIGHT := Color(1.0, 0.88, 0.52, 1.0)
const TEXT := Color(0.94, 0.91, 0.84, 1.0)
const MUTED := Color(0.58, 0.62, 0.72, 1.0)


## Panel con sombra, cuerpo degradado, doble marco dorado y tachuelas; con `title` lleva una
## placa centrada en el borde superior.
static func draw_panel(canvas: CanvasItem, rect: Rect2, title: String = "") -> void:
	canvas.draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size), Color(0, 0, 0, 0.38))
	canvas.draw_rect(rect, NAVY)
	canvas.draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(rect.size.x - 2, rect.size.y * 0.5)), Color(1, 1, 1, 0.025))
	canvas.draw_rect(Rect2(rect.position + Vector2(1, rect.size.y * 0.5), Vector2(rect.size.x - 2, rect.size.y * 0.5 - 1)), Color(0, 0, 0, 0.14))
	canvas.draw_rect(rect, GOLD_DIM, false, 1.0)
	canvas.draw_rect(rect.grow(-2.0), Color(GOLD.r, GOLD.g, GOLD.b, 0.20), false, 1.0)
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
		draw_diamond(canvas, corner, 3.0, GOLD)
		draw_diamond(canvas, corner, 1.5, GOLD_LIGHT)
	if not title.is_empty():
		var width := FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 18.0
		var plate := Rect2(rect.position.x + (rect.size.x - width) * 0.5, rect.position.y - 6.0, width, 12.0)
		canvas.draw_rect(plate, NAVY_LIGHT)
		canvas.draw_rect(plate, GOLD, false, 1.0)
		canvas.draw_string(FONT, Vector2(plate.position.x, plate.position.y + 9.0), title, HORIZONTAL_ALIGNMENT_CENTER, width, 8, GOLD_LIGHT)


static func draw_diamond(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)]), color)


## Fondo de un hueco (habilidad, objeto): degradado vertical con bisel.
static func draw_slot_bg(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, Color(0.035, 0.045, 0.08, 0.96))
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.5)), Color(1, 1, 1, 0.035))
	canvas.draw_line(rect.position + Vector2(1, 1), Vector2(rect.end.x - 1, rect.position.y + 1), Color(1, 1, 1, 0.13), 1.0)
	canvas.draw_line(Vector2(rect.position.x + 1, rect.end.y - 1), rect.end - Vector2(1, 1), Color(0, 0, 0, 0.5), 1.0)


static func draw_slot_edge(canvas: CanvasItem, rect: Rect2, edge: Color) -> void:
	canvas.draw_rect(rect, Color(edge.r * 0.85 + 0.12, edge.g * 0.8 + 0.08, edge.b * 0.6, 1.0), false, 1.0)
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
		canvas.draw_rect(Rect2(corner - Vector2(1, 1), Vector2(2, 2)), GOLD)


## Barra en capsula: fondo oscuro, relleno con brillo superior, sombra inferior y marcas
## cada 10 %.
static func draw_bar(canvas: CanvasItem, rect: Rect2, ratio: float, color: Color) -> void:
	canvas.draw_rect(rect.grow(1.0), Color(0.0, 0.0, 0.02, 0.95))
	canvas.draw_rect(rect, Color(0.07, 0.08, 0.12, 1.0))
	var clamped := clampf(ratio, 0.0, 1.0)
	if clamped > 0.0:
		var fill := Rect2(rect.position, Vector2(rect.size.x * clamped, rect.size.y))
		canvas.draw_rect(fill, color.darkened(0.12))
		canvas.draw_rect(Rect2(fill.position, Vector2(fill.size.x, maxf(1.0, fill.size.y * 0.45))), color.lightened(0.28))
		canvas.draw_rect(Rect2(Vector2(fill.position.x, fill.end.y - 1.0), Vector2(fill.size.x, 1.0)), color.darkened(0.45))
	for i: int in range(1, 10):
		var x := rect.position.x + rect.size.x * float(i) / 10.0
		canvas.draw_line(Vector2(x, rect.position.y + 1.0), Vector2(x, rect.end.y - 1.0), Color(0, 0, 0, 0.22), 1.0)
	canvas.draw_rect(rect.grow(1.0), GOLD_DIM, false, 1.0)


## Estilo de boton a juego para los Controls (creador de personaje).
static func button_style(state: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	match state:
		"hover":
			style.bg_color = Color(0.16, 0.18, 0.27, 1.0)
			style.border_color = GOLD_LIGHT
		"pressed":
			style.bg_color = Color(0.06, 0.07, 0.11, 1.0)
			style.border_color = GOLD
		"disabled":
			style.bg_color = Color(0.07, 0.08, 0.11, 1.0)
			style.border_color = Color(0.25, 0.25, 0.3, 1.0)
		_:
			style.bg_color = Color(0.10, 0.12, 0.19, 1.0)
			style.border_color = GOLD_DIM
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(2)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 1
	return style
