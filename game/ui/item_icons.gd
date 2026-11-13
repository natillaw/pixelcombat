## ItemIcons — el icono de cada item es su propia pieza LPC: se compone la capa del item (la misma que se
## ve en el personaje), se recorta a su silueta y se amplia a escala entera con filtro de pixel. Asi todo
## item nuevo con `look` tiene icono sin dibujar nada; los anillos (sin capa) usan el icono del paquete
## CraftPix. Los iconos se cachean por pieza y tamano.
class_name ItemIcons
extends RefCounted

const SHEET := preload("res://assets/pixel/ui/craftpix/Equipment.png")
## Anillo del paquete CraftPix (px de la hoja Equipment.png).
const RING_REGION := Rect2(99, 354, 11, 12)

static var _cache: Dictionary = {}


## Textura del icono de `piece` ({id, rarity, tier, stats}) que cabe en `target` px; null si no tiene aspecto.
static func texture(piece: Dictionary, target: int = 28) -> Texture2D:
	var layer := ItemCatalog.look_layer(piece)
	if layer.is_empty():
		return _ring(target) if String(ItemCatalog.item(String(piece.get("id", ""))).get("slot", "")) == "ring" else null
	var pair: Array = layer[1]
	var key := "%s/%s/%d" % [str(pair[0]), str(pair[1]), target]
	if _cache.has(key):
		return _cache[key]
	var layers := LpcComposer.layers_from([pair], "male")
	var texture_out: Texture2D = null
	for anim: String in ["idle", "walk", "shoot", "spellcast", "slash", "thrust"]:
		var sheet := LpcComposer.compose_anim(layers, anim)
		if sheet == null:
			continue
		var row := 2 if sheet.get_height() >= 3 * LpcComposer.FRAME else 0
		var frame := sheet.get_region(Rect2i(0, row * LpcComposer.FRAME, LpcComposer.FRAME, LpcComposer.FRAME))
		var used := frame.get_used_rect()
		if used.size.x < 2 or used.size.y < 2:
			continue
		var crop := frame.get_region(used)
		var biggest := maxi(used.size.x, used.size.y)
		var factor := maxi(target / biggest, 1)
		if factor == 1 and biggest > target:
			var ratio := float(target) / float(biggest)
			crop.resize(maxi(int(round(used.size.x * ratio)), 1), maxi(int(round(used.size.y * ratio)), 1), Image.INTERPOLATE_NEAREST)
		elif factor > 1:
			crop.resize(used.size.x * factor, used.size.y * factor, Image.INTERPOLATE_NEAREST)
		texture_out = ImageTexture.create_from_image(crop)
		break
	_cache[key] = texture_out
	return texture_out


static func _ring(target: int) -> Texture2D:
	var key := "ring/%d" % target
	if _cache.has(key):
		return _cache[key]
	var image := SHEET.get_image().get_region(Rect2i(RING_REGION))
	var factor := maxi(target / int(maxf(RING_REGION.size.x, RING_REGION.size.y)), 1)
	image.resize(int(RING_REGION.size.x) * factor, int(RING_REGION.size.y) * factor, Image.INTERPOLATE_NEAREST)
	var out := ImageTexture.create_from_image(image)
	_cache[key] = out
	return out


## Dibuja el icono de `piece` centrado en `rect` (nada si no tiene).
static func draw(canvas: CanvasItem, piece: Dictionary, rect: Rect2, modulate: Color = Color.WHITE) -> void:
	var icon := texture(piece, int(minf(rect.size.x, rect.size.y)) - 2)
	if icon != null:
		canvas.draw_texture(icon, rect.position + ((rect.size - icon.get_size()) * 0.5).floor(), modulate)
