@tool
extends EditorScript
## Genera res://art/tiles/bosque_tileset.tres desde bosque_tiles.png.
## Uso: abrir en el editor de scripts y File > Run (Ctrl+Shift+X).
## Terrenos (modo Match Corners): 0 = Pasto, 1 = Tierra, 2 = Agua.
## Evita que tierra y agua se toquen directo: no hay tiles de transición tierra/agua.

const TEX_PATH := "res://art/tiles/bosque_tiles.png"
const OUT_PATH := "res://art/tiles/bosque_tileset.tres"
const TILE := Vector2i(16, 16)

func _run() -> void:
	var ts := TileSet.new()
	ts.tile_size = TILE
	ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	var names := ["Pasto", "Tierra", "Agua"]
	var colors := [Color(0.42, 0.6, 0.28), Color(0.55, 0.38, 0.22), Color(0.2, 0.45, 0.5)]
	for i in names.size():
		ts.add_terrain(0)
		ts.set_terrain_name(0, i, names[i])
		ts.set_terrain_color(0, i, colors[i])

	var src := TileSetAtlasSource.new()
	src.texture = load(TEX_PATH)
	src.texture_region_size = TILE
	ts.add_source(src, 0)

	_add_block(src, Vector2i(0, 0), 1, 1.0)   # pasto / tierra
	_add_block(src, Vector2i(4, 0), 2, 0.0)   # pasto / agua (su tile 100% pasto no se usa)

	# variantes con probabilidad baja
	for x in range(8, 12):
		_add_full(src, Vector2i(x, 0), 0, 0.06)
	for x in range(8, 10):
		_add_full(src, Vector2i(x, 1), 1, 0.15)
		_add_full(src, Vector2i(x, 2), 2, 0.15)

	var err := ResourceSaver.save(ts, OUT_PATH)
	print("TileSet guardado: ", OUT_PATH, " (", error_string(err), ")")

## Bloque 4x4 de 16 tiles. Índice = TL*1 + TR*2 + BL*4 + BR*8 (1 = terreno secundario).
func _add_block(src: TileSetAtlasSource, origin: Vector2i, other: int, full_grass_prob: float) -> void:
	for i in 16:
		var c := origin + Vector2i(i % 4, int(i / 4))
		src.create_tile(c)
		var td := src.get_tile_data(c, 0)
		td.terrain_set = 0
		var tl := other if (i & 1) != 0 else 0
		var tr := other if (i & 2) != 0 else 0
		var bl := other if (i & 4) != 0 else 0
		var br := other if (i & 8) != 0 else 0
		var count := int(tl != 0) + int(tr != 0) + int(bl != 0) + int(br != 0)
		td.terrain = other if count >= 2 else 0
		td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, tl)
		td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER, tr)
		td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, bl)
		td.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER, br)
		if i == 0:
			td.probability = full_grass_prob

func _add_full(src: TileSetAtlasSource, c: Vector2i, terrain: int, prob: float) -> void:
	src.create_tile(c)
	var td := src.get_tile_data(c, 0)
	td.terrain_set = 0
	td.terrain = terrain
	for n in [TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
			TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER]:
		td.set_terrain_peering_bit(n, terrain)
	td.probability = prob
