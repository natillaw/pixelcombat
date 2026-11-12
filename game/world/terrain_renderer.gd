## TerrainRenderer — dibuja un mapa de casillas (TileGrid) con el tileset LPC 4-season.
##
## Compone el suelo, el agua y los muros en texturas por trozos de 16x16 casillas (se
## construyen una vez al cargar el piso) y crea como Sprite2D, ordenados por Y con el
## resto de la escena, los arboles y rocas altos. El aspecto sale de `data/biomes.json`:
## estacion de las hojas, suelo (hierba o tierra), tinte de atmosfera, muros (cliffs o
## arboles) y densidad de decorado.
##
## Hojas usadas (assets/pixel/lpc_terrain, OGA-BY 3.0; ver CREDITS.txt): Grass-Dirt
## (hierba sobre tierra, 3x3 + esquinas interiores), Grass/Dirt-Shallows (agua), Mountain
## (cliffs: meseta + cara) y los objetos (arboles, rocas, flores, setas, hierba alta).
class_name TerrainRenderer
extends Node2D

const DIR := "res://assets/pixel/lpc_terrain/"
const BIOMES_PATH := "res://data/biomes.json"
const TILE := 32
const CHUNK := 16
## Un muro solo se dibuja a menos de esta distancia (casillas) de suelo o agua.
const VISIBLE_RANGE := 2

static var _images: Dictionary = {}
static var _biomes: Dictionary = {}

var grid: TileGrid
var biome: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _grass: PackedByteArray = PackedByteArray()
var _chunks: Array = []
var _chunk_cols: int = 0
var _chunk_rows: int = 0
var _prop_nodes: Array[Node] = []
var _season: String = "summer"


static func available() -> bool:
	return ResourceLoader.exists(DIR + "grass_dirt_summer.png") and FileAccess.file_exists(BIOMES_PATH)


static func biome_config(id: String) -> Dictionary:
	if _biomes.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BIOMES_PATH))
		if parsed is Dictionary:
			_biomes = parsed
	return (_biomes.get(id, _biomes.get("forest", {})) as Dictionary).duplicate(true)


static func _img(file: String) -> Image:
	if _images.has(file):
		return _images[file]
	var texture: Texture2D = load(DIR + file)
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	_images[file] = image
	return image


## Dibuja el mapa de `layout`. Los arboles y rocas altos se añaden a `entities`
## (ordenado por Y); todo lo demas queda en este nodo, debajo.
func build(layout: FloorLayout, entities: Node2D) -> void:
	clear()
	grid = layout.grid
	biome = biome_config(layout.biome)
	_season = String(biome["season"])
	_rng.seed = layout.seed_value + 17
	modulate = Color(float(biome["tint"][0]), float(biome["tint"][1]), float(biome["tint"][2]), 1.0)
	z_index = -50

	_chunk_cols = int(ceil(float(grid.cols) / float(CHUNK)))
	_chunk_rows = int(ceil(float(grid.rows) / float(CHUNK)))
	for i: int in range(_chunk_cols * _chunk_rows):
		_chunks.append(Image.create(CHUNK * TILE, CHUNK * TILE, false, Image.FORMAT_RGBA8))
	_build_grass_mask()

	var visible := _visible_cells()
	var wall_big := _large_wall_cells(visible)
	for r: int in range(grid.rows):
		for c: int in range(grid.cols):
			if not visible[r * grid.cols + c]:
				continue
			_draw_ground(c, r)
	for r: int in range(grid.rows):
		for c: int in range(grid.cols):
			if not visible[r * grid.cols + c]:
				continue
			var kind := grid.get_cell(c, r)
			if kind == TileGrid.WATER:
				_draw_water(c, r)
			elif kind != TileGrid.FLOOR:
				if String(biome["wall_style"]) == "cliffs" and wall_big[r * grid.cols + c]:
					_draw_cliff(c, r)
				else:
					_add_wall_prop(entities, c, r)
			else:
				_decorate(c, r)
	for index: int in range(_chunks.size()):
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture = ImageTexture.create_from_image(_chunks[index])
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(float(index % _chunk_cols), float(index / _chunk_cols)) * float(CHUNK * TILE)
		add_child(sprite)
	_chunks.clear()


func clear() -> void:
	for child: Node in get_children():
		child.queue_free()
	for node: Node in _prop_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_prop_nodes.clear()
	_chunks.clear()


# --- Mascaras ---------------------------------------------------------------------


## Parches de hierba con ruido de valor suavizado; `grass` del bioma es la fraccion.
func _build_grass_mask() -> void:
	_grass = PackedByteArray()
	_grass.resize(grid.cols * grid.rows)
	if String(biome["ground"]) != "grass":
		return
	var step := 7
	var lattice_cols := grid.cols / step + 3
	var lattice_rows := grid.rows / step + 3
	var lattice := PackedFloat32Array()
	lattice.resize(lattice_cols * lattice_rows)
	for i: int in range(lattice.size()):
		lattice[i] = _rng.randf()
	var fraction := float(biome["grass"])
	for r: int in range(grid.rows):
		for c: int in range(grid.cols):
			var fx := float(c) / float(step)
			var fy := float(r) / float(step)
			var ix := int(fx)
			var iy := int(fy)
			var tx := smoothstep(0.0, 1.0, fx - float(ix))
			var ty := smoothstep(0.0, 1.0, fy - float(iy))
			var a := lerpf(lattice[iy * lattice_cols + ix], lattice[iy * lattice_cols + ix + 1], tx)
			var b := lerpf(lattice[(iy + 1) * lattice_cols + ix], lattice[(iy + 1) * lattice_cols + ix + 1], tx)
			_grass[r * grid.cols + c] = 1 if lerpf(a, b, ty) < fraction else 0


func _is_grass(c: int, r: int) -> bool:
	if not grid.in_bounds(c, r):
		return true
	return _grass[r * grid.cols + c] == 1


func _visible_cells() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(grid.cols * grid.rows)
	for r: int in range(grid.rows):
		for c: int in range(grid.cols):
			if grid.get_cell(c, r) == TileGrid.FLOOR or grid.get_cell(c, r) == TileGrid.WATER:
				for dy: int in range(-VISIBLE_RANGE, VISIBLE_RANGE + 1):
					for dx: int in range(-VISIBLE_RANGE, VISIBLE_RANGE + 1):
						if grid.in_bounds(c + dx, r + dy):
							out[(r + dy) * grid.cols + c + dx] = 1
	return out


## Muros que forman masas de >= 8 casillas (los demas se dibujan como arboles o rocas).
func _large_wall_cells(visible: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(grid.cols * grid.rows)
	var seen := PackedByteArray()
	seen.resize(grid.cols * grid.rows)
	for r: int in range(grid.rows):
		for c: int in range(grid.cols):
			if seen[r * grid.cols + c] == 1 or not _is_wall(c, r):
				continue
			var stack: Array[Vector2i] = [Vector2i(c, r)]
			var members: Array[Vector2i] = []
			seen[r * grid.cols + c] = 1
			while not stack.is_empty():
				var cell: Vector2i = stack.pop_back()
				members.append(cell)
				for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n := cell + offset
					if grid.in_bounds(n.x, n.y) and seen[n.y * grid.cols + n.x] == 0 and _is_wall(n.x, n.y):
						seen[n.y * grid.cols + n.x] = 1
						stack.append(n)
			if members.size() >= 8:
				for cell: Vector2i in members:
					out[cell.y * grid.cols + cell.x] = 1
	return out


func _is_wall(c: int, r: int) -> bool:
	var kind := grid.get_cell(c, r)
	return kind == TileGrid.WALL or kind == TileGrid.GATE


# --- Dibujo sobre los trozos --------------------------------------------------------


func _blit(file: String, tile: Vector2i, c: int, r: int) -> void:
	var chunk: Image = _chunks[(r / CHUNK) * _chunk_cols + (c / CHUNK)]
	var dest := Vector2i((c % CHUNK) * TILE, (r % CHUNK) * TILE)
	chunk.blend_rect(_img(file), Rect2i(tile.x * TILE, tile.y * TILE, TILE, TILE), dest)


func _blit_region(file: String, region: Rect2i, chunk_pos: Vector2i) -> void:
	var cell := Vector2i(chunk_pos.x / TILE, chunk_pos.y / TILE)
	if not grid.in_bounds(cell.x, cell.y):
		return
	var chunk: Image = _chunks[(cell.y / CHUNK) * _chunk_cols + (cell.x / CHUNK)]
	var local := Vector2i(chunk_pos.x % (CHUNK * TILE), chunk_pos.y % (CHUNK * TILE))
	chunk.blend_rect(_img(file), region, local)


func _ground_sheet() -> String:
	return "grass_dirt_%s.png" % _season


func _dirt_sheet() -> String:
	return "dirt_winter.png" if _season == "winter" else "dirt_nonwinter.png"


func _water_sheet() -> String:
	if String(biome["ground"]) == "grass":
		return "grass_shallows_%s.png" % _season
	return "dirt_shallows_%s.png" % ("autumn" if _season == "autumn" else ("winter" if _season == "winter" else "summer"))


func _draw_ground(c: int, r: int) -> void:
	if not _is_grass(c, r) or String(biome["ground"]) != "grass":
		_blit(_dirt_sheet(), Vector2i(_rng.randi_range(0, 2), _rng.randi_range(0, 1)), c, r)
		return
	_blit(_ground_sheet(), _nine_piece(c, r, func(x: int, y: int) -> bool: return _is_grass(x, y), true), c, r)


## Pieza del conjunto 3x3 (+ esquinas interiores en las filas 3-4) segun los vecinos.
func _nine_piece(c: int, r: int, same: Callable, with_inner: bool) -> Vector2i:
	var n: bool = same.call(c, r - 1)
	var e: bool = same.call(c + 1, r)
	var s: bool = same.call(c, r + 1)
	var w: bool = same.call(c - 1, r)
	if n and e and s and w:
		if with_inner:
			if not same.call(c + 1, r + 1):
				return Vector2i(0, 3)
			if not same.call(c - 1, r + 1):
				return Vector2i(1, 3)
			if not same.call(c + 1, r - 1):
				return Vector2i(0, 4)
			if not same.call(c - 1, r - 1):
				return Vector2i(1, 4)
			return Vector2i(0 + _rng.randi_range(0, 1), 5 + _rng.randi_range(0, 1))
		return Vector2i(1, 1)
	var col := 1
	var row := 1
	if not w:
		col = 0
	elif not e:
		col = 2
	if not n:
		row = 0
	elif not s:
		row = 2
	if (not w and not e) or (not n and not s):
		return Vector2i(1, 1)
	return Vector2i(col, row)


func _draw_water(c: int, r: int) -> void:
	var piece := _nine_piece(c, r, func(x: int, y: int) -> bool: return grid.get_cell(x, y) == TileGrid.WATER or not grid.in_bounds(x, y), false)
	_blit(_water_sheet(), piece, c, r)


## Muro como cliff: cara inferior contra el suelo, cara superior encima y meseta arriba.
func _draw_cliff(c: int, r: int) -> void:
	var sheet := "mountain_%s.png" % _season
	var below := 0
	while below < 2 and _is_wall(c, r + 1 + below):
		below += 1
	var west := _is_wall(c - 1, r)
	var east := _is_wall(c + 1, r)
	var col := 1
	if not west:
		col = 0
	elif not east:
		col = 2
	if below == 0:
		_blit(sheet, Vector2i(col, 4), c, r)
	elif below == 1:
		_blit(sheet, Vector2i(col, 3), c, r)
	else:
		var row := 0 if not _is_wall(c, r - 1) else 1
		_blit(sheet, Vector2i(col, row), c, r)


## Muros que no son cliffs: un arbol (o una roca en los biomas sin arboles) por casilla
## de dos en dos, y siempre en el borde junto al suelo.
func _add_wall_prop(entities: Node2D, c: int, r: int) -> void:
	var touches_floor := false
	for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if not _is_wall(c + offset.x, r + offset.y) and grid.get_cell(c + offset.x, r + offset.y) != TileGrid.WALL:
			touches_floor = true
	if not touches_floor and (c + r) % 2 != 0:
		return
	var tree := String(biome["tree"])
	var center := grid.cell_center(c, r) + Vector2(_rng.randf_range(-6.0, 6.0), 10.0 + _rng.randf_range(-4.0, 6.0))
	if tree == "none" or _rng.randf() < 0.18:
		_spawn_prop(entities, _rock_sprite(), center)
	else:
		_spawn_prop(entities, _tree_sprite(tree), center)


func _spawn_prop(entities: Node2D, prop: Dictionary, foot: Vector2) -> void:
	if prop.is_empty():
		return
	var texture: Texture2D = prop["texture"]
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.offset = Vector2(-texture.get_width() * 0.5, -float(texture.get_height()))
	sprite.position = foot
	sprite.modulate = modulate
	entities.add_child(sprite)
	_prop_nodes.append(sprite)


## Decorado del suelo (sin colision): flores, setas, hierba alta y rocas pequenas.
func _decorate(c: int, r: int) -> void:
	var decor: Dictionary = biome["decor"]
	var roll := _rng.randf()
	var at := Vector2i(c * TILE + _rng.randi_range(2, 14), r * TILE + _rng.randi_range(2, 14))
	var threshold := float(decor["flowers"])
	if roll < threshold and _is_grass(c, r):
		var cell := Vector2i(_rng.randi_range(0, 8), _rng.randi_range(0, 9))
		_blit_region("flowers.png", Rect2i(cell.x * 16, cell.y * 16, 16, 16), at)
		return
	threshold += float(decor["tufts"])
	if roll < threshold:
		var grass_rows := {"spring": 0, "summer": 64, "autumn": 128, "winter": 64}
		var tuft := Rect2i(_rng.randi_range(0, 5) * 32, int(grass_rows[_season]), 32, 64)
		_blit_region("grasses_tall.png", tuft, Vector2i(c * TILE, r * TILE - 32))
		return
	threshold += float(decor["mushrooms"])
	if roll < threshold:
		_blit_region("mushrooms.png", Rect2i(_rng.randi_range(0, 5) * 32, _rng.randi_range(0, 4) * 32, 32, 32), Vector2i(c * TILE, r * TILE))
		return
	threshold += float(decor["rocks"])
	if roll < threshold:
		var small := Rect2i(_rng.randi_range(0, 2) * 64, 128, 64, 64)
		_blit_region("rocks_grasslands.png", small, Vector2i(c * TILE - 16, r * TILE - 16))


# --- Sprites de objetos -------------------------------------------------------------


## Recorta una region de una hoja a su caja opaca; devuelve {texture} o {} si esta vacia.
static func _trim(file: String, region: Rect2i) -> Dictionary:
	var key := "%s:%s" % [file, str(region)]
	if _images.has(key):
		return _images[key]
	var source := _img(file)
	region = region.intersection(Rect2i(Vector2i.ZERO, source.get_size()))
	var part := source.get_region(region)
	var used := part.get_used_rect()
	var result: Dictionary = {}
	if used.size.x > 2 and used.size.y > 2:
		result = {"texture": ImageTexture.create_from_image(part.get_region(used))}
	_images[key] = result
	return result


func _tree_sprite(kind: String) -> Dictionary:
	if kind == "pine":
		return _trim("trees_pine.png", Rect2i(0, 0, 96, 160))
	var rows := {"spring": Rect2i(32, 0, 96, 160), "summer": Rect2i(32, 160, 96, 160), "autumn": Rect2i(288, 0, 100, 160), "winter": Rect2i(32, 320, 96, 160)}
	return _trim("trees_generic.png", rows[_season])


func _rock_sprite() -> Dictionary:
	var regions := [Rect2i(0, 0, 64, 128), Rect2i(64, 0, 64, 128), Rect2i(128, 0, 64, 128)]
	return _trim("rocks_grasslands.png", regions[_rng.randi_range(0, regions.size() - 1)])
