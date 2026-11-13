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


const PANEL_TEX := preload("res://assets/pixel/ui/craftpix/main_tiles.png")
const BUTTON_TEX := preload("res://assets/pixel/ui/craftpix/buttons.png")
## Panel verde con cabecera (titulado) y cuerpo marron liso (sin titulo), de Main_tiles.
const PANEL_TITLED := Rect2i(299, 0, 26, 37)
const PANEL_PLAIN := Rect2i(299, 13, 26, 24)


## Dibuja `region` de `texture` estirada en `dest` por nueve parches (esquinas fijas).
static func nine(canvas: CanvasItem, texture: Texture2D, region: Rect2i, margin: Vector4i, dest: Rect2, tint: Color = Color.WHITE) -> void:
	var l := float(margin.x)
	var t := float(margin.y)
	var r := float(margin.z)
	var bottom := float(margin.w)
	if dest.size.x < l + r + 2.0 or dest.size.y < t + bottom + 2.0:
		canvas.draw_texture_rect_region(texture, dest, Rect2(region), tint)
		return
	var sx := [0.0, l, float(region.size.x) - r, float(region.size.x)]
	var sy := [0.0, t, float(region.size.y) - bottom, float(region.size.y)]
	var dx := [0.0, l, dest.size.x - r, dest.size.x]
	var dy := [0.0, t, dest.size.y - bottom, dest.size.y]
	for iy: int in range(3):
		for ix: int in range(3):
			var src := Rect2(float(region.position.x) + sx[ix], float(region.position.y) + sy[iy], sx[ix + 1] - sx[ix], sy[iy + 1] - sy[iy])
			var dst := Rect2(dest.position.x + dx[ix], dest.position.y + dy[iy], dx[ix + 1] - dx[ix], dy[iy + 1] - dy[iy])
			canvas.draw_texture_rect_region(texture, dst, src, tint)


## Panel de la interfaz (paquete CraftPix): sombra y cuerpo marron; con `title` lleva la
## cabecera verde con el titulo.
static func draw_panel(canvas: CanvasItem, rect: Rect2, title: String = "") -> void:
	canvas.draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size), Color(0, 0, 0, 0.35))
	if title.is_empty():
		nine(canvas, PANEL_TEX, PANEL_PLAIN, Vector4i(4, 4, 4, 4), rect)
	else:
		nine(canvas, PANEL_TEX, PANEL_TITLED, Vector4i(4, 14, 4, 4), rect)
		canvas.draw_string(FONT, Vector2(rect.position.x, rect.position.y + 12.0), title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 14, Color(0.93, 1.0, 0.9))


static func draw_diamond(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)]), color)


## Fondo de un hueco (habilidad, objeto): el cuerpo marron del paquete, oscurecido.
static func draw_slot_bg(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, Color(0.05, 0.035, 0.03, 1.0))
	nine(canvas, PANEL_TEX, PANEL_PLAIN, Vector4i(3, 3, 3, 3), rect, Color(0.62, 0.58, 0.62, 1.0))


static func draw_slot_edge(canvas: CanvasItem, rect: Rect2, edge: Color) -> void:
	# El marco ya lo da el panel; solo se resalta el estado (listo, sin recurso, potenciado).
	if edge.r > 0.6 or edge.g < 0.3:
		canvas.draw_rect(rect.grow(-1.0), Color(edge.r, edge.g, edge.b, 0.85), false, 1.0)


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


## Estilo de boton: los botones verdes del paquete CraftPix (normal, encima, pulsado).
static func button_style(state: String) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = BUTTON_TEX
	match state:
		"hover":
			style.region_rect = Rect2(100, 97, 40, 16)
		"pressed":
			style.region_rect = Rect2(4, 113, 40, 16)
		"disabled":
			style.region_rect = Rect2(54, 97, 40, 16)
		_:
			style.region_rect = Rect2(4, 97, 40, 16)
	style.texture_margin_left = 4.0
	style.texture_margin_right = 4.0
	style.texture_margin_top = 4.0
	style.texture_margin_bottom = 4.0
	style.content_margin_left = 3.0
	style.content_margin_right = 3.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 5.0
	return style
