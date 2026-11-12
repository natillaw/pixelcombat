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
var layout: FloorLayout
var biome: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _grass: PackedByteArray = PackedByteArray()
var _chunks: Array = []
var _chunk_cols: int = 0
var _chunk_rows: int = 0
var _prop_nodes: Array[Node] = []
var _season: String = "summer"
var _entities: Node2D


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
func build(p_layout: FloorLayout, entities: Node2D) -> void:
	clear()
	layout = p_layout
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
	_entities = entities
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
			elif kind == TileGrid.ROAD:
				pass
			elif kind == TileGrid.SOLID:
				pass
			elif kind != TileGrid.FLOOR:
				if String(biome["wall_style"]) == "cliffs" and wall_big[r * grid.cols + c]:
					_draw_cliff(c, r)
				else:
					_add_wall_prop(entities, c, r)
			else:
				_decorate(c, r)
	_spawn_decor()
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
	if float(biome["grass"]) <= 0.0:
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
	# Calles, cimientos de edificios y el sendero de entrada a salida son tierra.
	for r: int in range(grid.rows):
		for c: int in range(grid.cols):
			if grid.get_cell(c, r) == TileGrid.ROAD:
				_grass[r * grid.cols + c] = 0
	for cell: Vector2i in layout.footprints:
		_grass[cell.y * grid.cols + cell.x] = 0
	for cell: Vector2i in _trail_cells():
		_grass[cell.y * grid.cols + cell.x] = 0
	_despeckle()


## Sendero de tierra que va de la entrada a la salida del piso (3 casillas de ancho con
## algo de ondulacion): guia al jugador y rompe la monotonia de la hierba.
func _trail_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if layout.kind != FloorLayout.KIND_FLOOR:
		return cells
	var exit_position := Vector2.ZERO
	for portal: Dictionary in layout.portals:
		if String(portal["id"]) == "exit":
			exit_position = portal["position"]
	var target := grid.world_to_cell(exit_position)
	var field := grid.distance_field(target, 100000)
	var cell := grid.world_to_cell(layout.player_spawn)
	var guard := 0
	while field[cell.y * grid.cols + cell.x] > 0 and guard < 4000:
		guard += 1
		var best := cell
		var best_value: int = field[cell.y * grid.cols + cell.x]
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var n := Vector2i(cell.x + dx, cell.y + dy)
				if grid.in_bounds(n.x, n.y) and field[n.y * grid.cols + n.x] >= 0 and field[n.y * grid.cols + n.x] < best_value:
					best_value = field[n.y * grid.cols + n.x]
					best = n
		if best == cell:
			break
		cell = best
		var wobble := _rng.randi_range(-1, 1) if guard % 5 == 0 else 0
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var n := Vector2i(cell.x + dx + (wobble if dx == 0 else 0), cell.y + dy)
				if grid.in_bounds(n.x, n.y) and not grid.blocks_move(n.x, n.y):
					cells.append(n)
	return cells


## Quita motas: una casilla de hierba con menos de 3 vecinos de hierba pasa a tierra y una de
## tierra rodeada de hierba pasa a hierba (el autotile solo sabe dibujar formas limpias).
func _despeckle() -> void:
	for pass_index: int in range(3):
		# Primero se quitan las motas de hierba y despues se tapan los agujeros (sin mezclar
		# ambas cosas en la misma pasada, que oscilaba en un patron de ajedrez).
		var copy := _grass.duplicate()
		for r: int in range(grid.rows):
			for c: int in range(grid.cols):
				var count := 0
				for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n := Vector2i(c + offset.x, r + offset.y)
					if not grid.in_bounds(n.x, n.y) or copy[n.y * grid.cols + n.x] == 1:
						count += 1
				var here := copy[r * grid.cols + c] == 1
				if here and count < 3:
					_grass[r * grid.cols + c] = 0
				elif not here and count == 4 and grid.get_cell(c, r) != TileGrid.ROAD and not layout.footprints.has(Vector2i(c, r)):
					_grass[r * grid.cols + c] = 1


func _is_grass(c: int, r: int) -> bool:
	if not grid.in_bounds(c, r):
		return true
	return _grass[r * grid.cols + c] == 1


func _visible_cells() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(grid.cols * grid.rows)
	for r: int in range(grid.rows):
		for c: int in range(grid.cols):
			var source := grid.get_cell(c, r)
			if source == TileGrid.FLOOR or source == TileGrid.WATER or source == TileGrid.ROAD or source == TileGrid.SOLID:
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
	_stamp_rect(_img(file), region, chunk_pos)


## Mezcla `region` de `source` en `at` (px del mapa) en TODOS los trozos que toque, asi un
## objeto que cruza el borde de un trozo no se corta a la mitad.
func _stamp_rect(source: Image, region: Rect2i, at: Vector2i) -> void:
	var span := CHUNK * TILE
	var first_x := maxi(0, int(floor(float(at.x) / float(span))))
	var first_y := maxi(0, int(floor(float(at.y) / float(span))))
	var last_x := mini(_chunk_cols - 1, int(floor(float(at.x + region.size.x - 1) / float(span))))
	var last_y := mini(_chunk_rows - 1, int(floor(float(at.y + region.size.y - 1) / float(span))))
	for cy: int in range(first_y, last_y + 1):
		for cx: int in range(first_x, last_x + 1):
			var chunk: Image = _chunks[cy * _chunk_cols + cx]
			chunk.blend_rect(source, region, Vector2i(at.x - cx * span, at.y - cy * span))


func _ground_sheet() -> String:
	return "grass_dirt_%s.png" % _season


func _dirt_sheet() -> String:
	return "dirt_nonwinter.png"


func _water_sheet() -> String:
	if String(biome["ground"]) == "grass":
		return "grass_shallows_%s.png" % _season
	return "dirt_shallows_%s.png" % ("autumn" if _season == "autumn" else ("winter" if _season == "winter" else "summer"))


func _draw_ground(c: int, r: int) -> void:
	if not _is_grass(c, r) or float(biome["grass"]) <= 0.0:
		_blit(_dirt_sheet(), Vector2i(_rng.randi_range(0, 2), _rng.randi_range(0, 1)), c, r)
		return
	var piece := _nine_piece(c, r, func(x: int, y: int) -> bool: return _is_grass(x, y), true)
	var enclosed := _is_grass(c, r - 1) and _is_grass(c + 1, r) and _is_grass(c, r + 1) and _is_grass(c - 1, r)
	if piece == Vector2i(1, 1) and not enclosed:
		_blit(_dirt_sheet(), Vector2i(_rng.randi_range(0, 2), _rng.randi_range(0, 1)), c, r)
		return
	_blit(_ground_sheet(), piece, c, r)


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


## Adoquin de la aldea (16 px ampliado x2 a la casilla de 32 px).
static func _cobble() -> Image:
	if _images.has("cobble32"):
		return _images["cobble32"]
	var texture: Texture2D = load("res://assets/pixel/village/cobblestone.png")
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(TILE, TILE, Image.INTERPOLATE_NEAREST)
	_images["cobble32"] = image
	return image


func _draw_road(c: int, r: int) -> void:
	var chunk: Image = _chunks[(r / CHUNK) * _chunk_cols + (c / CHUNK)]
	chunk.blend_rect(_cobble(), Rect2i(0, 0, TILE, TILE), Vector2i((c % CHUNK) * TILE, (r % CHUNK) * TILE))


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
		# La meseta se oscurece hacia dentro: solo el borde se ve claro; el interior es roca
		# en sombra, asi las masas gruesas no se ven como una mancha lisa y palida.
		var depth := 0
		for step: int in range(1, 4):
			if _is_wall(c - step, r) and _is_wall(c + step, r) and _is_wall(c, r - step):
				depth = step
		_stamp(_dark(0.55 + 0.14 * float(depth)), Vector2i(c * TILE, r * TILE))
	if below < 2:
		_stamp(_dark(0.18), Vector2i(c * TILE, r * TILE))


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
	sprite.scale = Vector2.ONE * float(prop.get("scale", 1.0))
	sprite.modulate = modulate
	_stamp(_shadow(int(texture.get_width() * 0.6), maxi(8, int(texture.get_width() * 0.16))), Vector2i(int(foot.x) - int(texture.get_width() * 0.3), int(foot.y) - maxi(8, int(texture.get_width() * 0.16)) / 2 - 3))
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
		var cell := Vector2i(_rng.randi_range(0, 5), _rng.randi_range(0, 4))
		if cell.y == 2 and cell.x >= 3:
			_stamp(_glow(26), Vector2i(c * TILE + 16 - 26, r * TILE + 22 - 26))
		_blit_region("mushrooms.png", Rect2i(cell.x * 32, cell.y * 32, 32, 32), Vector2i(c * TILE, r * TILE))
		return
	threshold += float(decor["rocks"])
	if roll < threshold:
		var smalls := [Rect2i(0, 97, 61, 31), Rect2i(64, 64, 58, 32), Rect2i(64, 96, 56, 32), Rect2i(128, 96, 32, 31)]
		var small: Rect2i = smalls[_rng.randi_range(0, smalls.size() - 1)]
		_blit_region("rocks_grasslands.png", small, Vector2i(c * TILE - 8, r * TILE))


# --- Sombras, brillos y decorado ------------------------------------------------------


## Mezcla una imagen pequena (sombra, brillo) en el trozo que contiene `at` (px del mapa).
func _stamp(image: Image, at: Vector2i) -> void:
	_stamp_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), at)


static func _shadow(width: int, height: int) -> Image:
	var key := "shadow:%d:%d" % [width, height]
	if _images.has(key):
		return _images[key]
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y: int in range(height):
		for x: int in range(width):
			var nx := (float(x) + 0.5) / float(width) * 2.0 - 1.0
			var ny := (float(y) + 0.5) / float(height) * 2.0 - 1.0
			var d := nx * nx + ny * ny
			if d <= 1.0:
				image.set_pixel(x, y, Color(0.0, 0.0, 0.03, 0.42 * (1.0 - d * 0.5)))
	_images[key] = image
	return image


static func _dark(alpha: float) -> Image:
	var key := "dark:%d" % int(alpha * 100.0)
	if _images.has(key):
		return _images[key]
	var image := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.02, 0.02, 0.06, minf(alpha, 0.92)))
	_images[key] = image
	return image


static func _glow(radius: int) -> Image:
	var key := "glow:%d" % radius
	if _images.has(key):
		return _images[key]
	var image := Image.create(radius * 2, radius * 2, false, Image.FORMAT_RGBA8)
	for y: int in range(radius * 2):
		for x: int in range(radius * 2):
			var d := Vector2(float(x) - float(radius) + 0.5, float(y) - float(radius) + 0.5).length() / float(radius)
			if d < 1.0:
				image.set_pixel(x, y, Color(0.45, 0.85, 1.0, 0.30 * (1.0 - d) * (1.0 - d)))
	_images[key] = image
	return image


## Imagen de la aldea ampliada x2 (los props de 16 px de la hoja de aldea).
static func _village_prop(name: String) -> Dictionary:
	var key := "village:" + name
	if _images.has(key):
		return _images[key]
	var texture: Texture2D = load("res://assets/pixel/village/%s.png" % name)
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
	var result := {"texture": ImageTexture.create_from_image(image)}
	_images[key] = result
	return result


## Decorado del layout (arboles, arbustos, barriles, cajas, rocas) como sprites ordenados
## por Y. Su colision ya esta reservada en el mapa (casillas SOLID).
func _spawn_decor() -> void:
	for spec: Dictionary in layout.decor:
		var foot: Vector2 = spec["position"]
		match String(spec["kind"]):
			"tree":
				_spawn_prop(_entities, _tree_sprite(String(biome["tree"]) if String(biome["tree"]) != "none" else "generic"), foot)
			"bush":
				_spawn_prop(_entities, _trim("bush_seasonal.png", Rect2i(0, 0, 32, 32 + 32 * (_rng.randi_range(0, 2) * 0))), foot)
			"barrel":
				_spawn_prop(_entities, _village_prop("barrel"), foot)
			"crate":
				_spawn_prop(_entities, _village_prop("crate"), foot)
			"rock":
				_spawn_prop(_entities, _rock_sprite(), foot)


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
		result = {"texture": ImageTexture.create_from_image(part.get_region(used)), "scale": 1.0}
	_images[key] = result
	return result


func _tree_sprite(kind: String) -> Dictionary:
	if kind == "pine":
		return _trim("trees_pine.png", Rect2i(0, 0, 96, 160))
	var tree_scale := 0.8
	var rows := {"spring": Rect2i(32, 0, 96, 160), "summer": Rect2i(32, 160, 96, 160), "autumn": Rect2i(288, 0, 100, 160), "winter": Rect2i(32, 320, 96, 160)}
	var tree: Dictionary = _trim("trees_generic.png", rows[_season]).duplicate()
	if not tree.is_empty():
		tree["scale"] = tree_scale
	return tree


func _rock_sprite() -> Dictionary:
	var regions := [Rect2i(0, 0, 64, 92), Rect2i(68, 0, 50, 64), Rect2i(130, 0, 60, 58)]
	return _trim("rocks_grasslands.png", regions[_rng.randi_range(0, regions.size() - 1)])
