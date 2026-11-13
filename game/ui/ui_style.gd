## UiStyle — el aspecto comun de todas las interfaces (inspirado en Drakantos): paneles
## azul noche con marco dorado y tachuelas en las esquinas, huecos biselados, barras en
## capsula con brillo y segmentos y botones a juego. Todo se dibuja por codigo (no hay
## texturas), asi que la misma funcion vale para el HUD, el inventario, el taller, el
## loadout y el creador de personaje.
class_name UiStyle
extends RefCounted

const FONT := preload("res://assets/fonts/m5x7.ttf")

const NAVY := Color(0.045, 0.058, 0.10, 0.98)
const NAVY_LIGHT := Color(0.085, 0.10, 0.16, 0.95)
const GOLD := Color(0.88, 0.68, 0.30, 1.0)
const GOLD_DIM := Color(0.50, 0.38, 0.20, 1.0)
const GOLD_LIGHT := Color(1.0, 0.88, 0.52, 1.0)
const TEXT := Color(0.94, 0.91, 0.84, 1.0)
const MUTED := Color(0.58, 0.62, 0.72, 1.0)


const PANEL_TEX := preload("res://assets/pixel/ui/craftpix/main_tiles.png")
const BUTTON_TEX := preload("res://assets/pixel/ui/craftpix/buttons.png")
## Panel verde con cabecera (titulado) y cuerpo marron liso (sin titulo), de Main_tiles.
## Marco dorado ornamental de Dragon Regalia (CC0); el centro azul se sustituye por azul noche.
const FRAME_TEX := preload("res://assets/pixel/ui/dragon_regalia/20240707dragon9SlicesB.png")
const SLOT_TEX := preload("res://assets/pixel/ui/dragon_regalia/20240713dragonFilledFrame-Sheet.png")
const RARITY_FRAMES := {
	"common": preload("res://assets/pixel/ui/ts_kit/ui/rarity_frame_common.png"),
	"uncommon": preload("res://assets/pixel/ui/ts_kit/ui/rarity_frame_uncommon.png"),
	"rare": preload("res://assets/pixel/ui/ts_kit/ui/rarity_frame_rare.png"),
	"epic": preload("res://assets/pixel/ui/ts_kit/ui/rarity_frame_epic.png"),
	"legendary": preload("res://assets/pixel/ui/ts_kit/ui/rarity_frame_legendary.png"),
	"mythic": preload("res://assets/pixel/ui/ts_kit/ui/rarity_frame_mythic.png"),
}
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


## Panel de la interfaz: sombra, centro azul noche y marco dorado ornamental (Dragon
## Regalia). Con `title` lleva una pestana dorada con el titulo.
static func draw_panel(canvas: CanvasItem, rect: Rect2, title: String = "") -> void:
	canvas.draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size), Color(0, 0, 0, 0.4))
	canvas.draw_rect(rect.grow(-6.0), NAVY)
	canvas.draw_rect(Rect2(rect.position + Vector2(5, 5), Vector2(rect.size.x - 10.0, 14.0)), Color(1, 1, 1, 0.04))
	nine_frame(canvas, FRAME_TEX, Rect2i(0, 0, 72, 72), 12, rect)
	if not title.is_empty():
		canvas.draw_string(FONT, Vector2(rect.position.x, rect.position.y + 17.0), title, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 14, GOLD_LIGHT)


## Marco sin el parche central: esquinas fijas y bordes repetidos en mosaico (una franja
## del centro de cada lado), para que el ornamento no se estire. El centro lo pinta quien llama.
static func nine_frame(canvas: CanvasItem, texture: Texture2D, region: Rect2i, margin: int, dest: Rect2, tint: Color = Color.WHITE) -> void:
	var m := float(margin)
	var rw := float(region.size.x)
	var rh := float(region.size.y)
	var ox := float(region.position.x)
	var oy := float(region.position.y)
	if dest.size.x < 2.0 * m or dest.size.y < 2.0 * m:
		return
	var strip := 4.0
	var mid_x := ox + rw * 0.5 - strip * 0.5
	var mid_y := oy + rh * 0.5 - strip * 0.5
	# Bordes en mosaico.
	var x := m
	while x < dest.size.x - m:
		var w := minf(strip, dest.size.x - m - x)
		canvas.draw_texture_rect_region(texture, Rect2(dest.position.x + x, dest.position.y, w, m), Rect2(mid_x, oy, w, m), tint)
		canvas.draw_texture_rect_region(texture, Rect2(dest.position.x + x, dest.position.y + dest.size.y - m, w, m), Rect2(mid_x, oy + rh - m, w, m), tint)
		x += strip
	var y := m
	while y < dest.size.y - m:
		var h := minf(strip, dest.size.y - m - y)
		canvas.draw_texture_rect_region(texture, Rect2(dest.position.x, dest.position.y + y, m, h), Rect2(ox, mid_y, m, h), tint)
		canvas.draw_texture_rect_region(texture, Rect2(dest.position.x + dest.size.x - m, dest.position.y + y, m, h), Rect2(ox + rw - m, mid_y, m, h), tint)
		y += strip
	# Esquinas.
	canvas.draw_texture_rect_region(texture, Rect2(dest.position, Vector2(m, m)), Rect2(ox, oy, m, m), tint)
	canvas.draw_texture_rect_region(texture, Rect2(dest.position + Vector2(dest.size.x - m, 0), Vector2(m, m)), Rect2(ox + rw - m, oy, m, m), tint)
	canvas.draw_texture_rect_region(texture, Rect2(dest.position + Vector2(0, dest.size.y - m), Vector2(m, m)), Rect2(ox, oy + rh - m, m, m), tint)
	canvas.draw_texture_rect_region(texture, Rect2(dest.position + dest.size - Vector2(m, m), Vector2(m, m)), Rect2(ox + rw - m, oy + rh - m, m, m), tint)


## Marco de rareza (ts_kit) sobre un hueco; `rarity` = common..mythic.
static func draw_rarity_frame(canvas: CanvasItem, rect: Rect2, rarity: String) -> void:
	if not RARITY_FRAMES.has(rarity):
		return
	nine_frame(canvas, RARITY_FRAMES[rarity] as Texture2D, Rect2i(0, 0, 24, 24), 4, rect, Color(0.5, 0.52, 0.6, 1.0) if rarity == "common" else Color.WHITE)


static func draw_diamond(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)]), color)


## Fondo de un hueco (habilidad, objeto): el cuerpo marron del paquete, oscurecido.
static func draw_slot_bg(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, Color(0.03, 0.035, 0.07, 1.0))
	nine(canvas, SLOT_TEX, Rect2i(0, 0, 32, 32), Vector4i(7, 7, 7, 7), rect, Color(0.34, 0.34, 0.5, 1.0))


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


## Estilo de boton: la placa ornamental de Dragon Regalia (4 estados de 100 x 35 en una hoja),
## teñida para que case con el azul noche y el dorado de los paneles.
const DRAGON_BUTTON := preload("res://assets/pixel/ui/dragon_regalia/20240709dragonButtonA-Sheet.png")


static func button_style(state: String) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = DRAGON_BUTTON
	match state:
		"hover":
			style.region_rect = Rect2(0, 0, 100, 35)
			style.modulate_color = Color(1.25, 1.1, 0.85, 1.0)
		"pressed":
			style.region_rect = Rect2(200, 0, 100, 35)
			style.modulate_color = Color(0.9, 0.85, 1.0, 1.0)
		"disabled":
			style.region_rect = Rect2(300, 0, 100, 35)
			style.modulate_color = Color(0.55, 0.55, 0.65, 1.0)
		_:
			style.region_rect = Rect2(0, 0, 100, 35)
			style.modulate_color = Color(0.5, 0.65, 1.45, 1.0)
	style.texture_margin_left = 13.0
	style.texture_margin_right = 13.0
	style.texture_margin_top = 8.0
	style.texture_margin_bottom = 8.0
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	return style
