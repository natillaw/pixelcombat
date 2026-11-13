## ResourceSprites — los sprites de los nodos de recoleccion, recortados de las mismas hojas LPC que usa el
## terreno (rocas, flores, hierba alta y arboles), para que mineral, hierbas y madera encajen con el mapa.
##   ore  = una roca de la hoja de rocas (con un destello del pack de efectos cuando esta lista)
##   herb = una mata de hierba alta con flores
##   wood = un arbol de la hoja generica (al agotarse queda el tocon: la base del tronco)
## Devuelve listas de {texture, offset, scale}: el pie del sprite queda en la posicion del nodo.
class_name ResourceSprites
extends RefCounted

const SMALL_ROCKS := [Rect2i(0, 97, 61, 31), Rect2i(64, 64, 58, 32), Rect2i(64, 96, 56, 32), Rect2i(128, 96, 32, 31)]
const BIG_ROCKS := [Rect2i(68, 0, 50, 64), Rect2i(130, 0, 60, 58)]
const TREE_SUMMER := Rect2i(32, 160, 96, 160)
const TREE_SCALE := 0.6


## Piezas para dibujar el nodo: [{texture, position (esquina sup. izq. respecto al pie), scale}].
static func parts(kind: String, seed_value: int, depleted: bool) -> Array:
	var out: Array = []
	match kind:
		"ore":
			var region: Rect2i = BIG_ROCKS[seed_value % BIG_ROCKS.size()] if seed_value % 3 == 0 else SMALL_ROCKS[seed_value % SMALL_ROCKS.size()]
			_add(out, "rocks_grasslands.png", region, 0.75, Vector2.ZERO)
		"herb":
			var tuft := Rect2i((seed_value % 6) * 32, 64, 32, 64)
			_add(out, "grasses_tall.png", tuft, 0.9, Vector2.ZERO)
			if not depleted:
				for i: int in range(3):
					var cell := Vector2i((seed_value + i * 3) % 9, (seed_value / 3 + i * 2) % 10)
					_add(out, "flowers.png", Rect2i(cell.x * 16, cell.y * 16, 16, 16), 1.0, Vector2(-14.0 + 14.0 * float(i), -10.0 - 6.0 * float(i % 2)))
		_:
			var tree := TerrainRenderer._trim("trees_generic.png", TREE_SUMMER)
			if not tree.is_empty():
				var texture: Texture2D = tree["texture"]
				if depleted:
					var stump := AtlasTexture.new()
					stump.atlas = texture
					stump.region = Rect2(0.0, float(texture.get_height()) - 34.0, float(texture.get_width()), 34.0)
					out.append({"texture": stump, "position": Vector2(-float(texture.get_width()) * 0.5, -34.0) * TREE_SCALE, "scale": TREE_SCALE})
				else:
					out.append({"texture": texture, "position": Vector2(-float(texture.get_width()) * 0.5, -float(texture.get_height())) * TREE_SCALE, "scale": TREE_SCALE})
	return out


static func _add(out: Array, file: String, region: Rect2i, scale: float, extra: Vector2) -> void:
	var trimmed := TerrainRenderer._trim(file, region)
	if trimmed.is_empty():
		return
	var texture: Texture2D = trimmed["texture"]
	out.append({"texture": texture, "position": Vector2(-float(texture.get_width()) * 0.5 * scale, -float(texture.get_height()) * scale) + extra, "scale": scale})
