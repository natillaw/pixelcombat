class_name SandboxMapView
extends Node2D
## Draws the fixed test map. With the Pixel Crawler tileset installed (T-025) it draws the baked
## tile texture; otherwise it falls back to a rich, detailed procedural stone dungeon style.

var map: NavMap
var _baked: Texture2D = null
var _tried := false


func _init(m: NavMap = null) -> void:
	map = m


## Master prompt I: tower floors held by the bandits show their camps.
static func has_camps(m: NavMap) -> bool:
	if not (m is ProceduralMap) or (m as ProceduralMap).floor_number <= 0:
		return false
	var foes: Array = TowerExpedition.get_floor_config((m as ProceduralMap).floor_number).get("foes", [])
	return foes.any(func(id): return BanditArt.has(String(id)))


## The tall props (trees, rocks, logs, camp gear) as Y-sorted sprites: add it to the Y-sorted world so
## units walk behind them (owner 2026-11-02). Empty layer for maps without the forest art.
func prop_layer() -> Node2D:
	var layer: Node2D
	if map is ProceduralMap and BosqueArt.available():
		layer = BosqueArt.prop_sprites(ForestArt.tall_props(map, (map as ProceduralMap).seed_value, has_camps(map)))
	else:
		layer = Node2D.new()
		layer.y_sort_enabled = true
	var portal := exit_portal()
	if portal != null:
		portal.position = map.center_of(map.extract_cell) + Vector2(0, 8)
		layer.add_child(portal)
	return layer


## The exit portal (the tower portal of the kit, animated), feet on its position.
static func exit_portal() -> AnimatedSprite2D:
	var path := AssetCatalog.world("tower_portal")
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	var sf := SpriteFrames.new()
	for i in 6:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * 32, 0, 32, 48)
		sf.add_frame("default", at)
	sf.set_animation_speed("default", 8.0)
	var s := AnimatedSprite2D.new()
	s.sprite_frames = sf
	s.offset = Vector2(0, -24)
	s.play()
	return s


func _draw() -> void:
	if map == null:
		return
	if not _tried:
		_tried = true
		_baked = ForestArt.bake(map, (map as ProceduralMap).seed_value, has_camps(map)) if map is ProceduralMap else MapTiles.bake(map)
		if _baked != null and map is ProceduralMap:
			material = Ambience.wind_material(false)      # D-113: canopy sways in gusts (look only)
	if _baked != null:
		draw_texture(_baked, Vector2.ZERO)
	else:
		var cell: float = float(NavMap.CELL)
		for y in map.height:
			for x in map.width:
				var r := Rect2(float(x) * cell, float(y) * cell, cell, cell)
				var is_wall: bool = map.is_blocked_cell(Vector2i(x, y))
				if is_wall:
					# Rich layered stone wall with brick bevels and highlights
					draw_rect(r, Color(0.16, 0.13, 0.22))
					draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(cell - 4, cell - 4)), Color(0.20, 0.17, 0.28))
					draw_rect(Rect2(r.position, Vector2(cell, 7)), Color(0.32, 0.27, 0.46))
					draw_line(r.position + Vector2(0, 7), r.position + Vector2(cell, 7), Color(0.10, 0.08, 0.15), 1.5)
					draw_line(r.position + Vector2(cell * 0.5, 7), r.position + Vector2(cell * 0.5, cell), Color(0.10, 0.08, 0.15), 1.0)
					draw_line(r.position + Vector2(2, cell * 0.5), r.position + Vector2(cell - 2, cell * 0.5), Color(0.24, 0.20, 0.34), 1.0)
				else:
					# Detailed stone floor slab with bevel borders
					var shade: float = 0.155 if (x + y) % 2 == 0 else 0.175
					draw_rect(r, Color(shade, shade * 0.92, shade * 1.25))
					draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(cell - 2, cell - 2)), Color(shade * 1.2, shade * 1.1, shade * 1.4), false, 1.0)
					
					# Decorative stone tile cross lines for stone paver look
					draw_line(r.position + Vector2(0, cell * 0.5), r.position + Vector2(cell, cell * 0.5), Color(shade * 0.7, shade * 0.65, shade * 0.8), 0.7)
					draw_line(r.position + Vector2(cell * 0.5, 0), r.position + Vector2(cell * 0.5, cell), Color(shade * 0.7, shade * 0.65, shade * 0.8), 0.7)

					# Wall shadow casting to the south of walls
					if y > 0 and map.is_blocked_cell(Vector2i(x, y - 1)):
						draw_rect(Rect2(r.position, Vector2(cell, 10)), Color(0, 0, 0, 0.4))

	# Exit (owner 2026-11-02: "¿qué es extract?"): a portal stands on the exit cell (prop_layer); the
	# ground shows a soft glowing circle with runes and the word "Salida".
	var g: Vector2 = map.center_of(map.extract_cell)
	draw_set_transform(g + Vector2(0, 6), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 30.0, Color(0.55, 0.35, 0.95, 0.18))
	draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 40, Color(0.75, 0.6, 1.0, 0.55), 2.0)
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 32, Color(0.85, 0.75, 1.0, 0.35), 1.0)
	for k in 8:
		var a := TAU * float(k) / 8.0
		draw_rect(Rect2(Vector2(cos(a), sin(a)) * 26.0 - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.9, 0.8, 1.0, 0.7))
	draw_set_transform(Vector2.ZERO)
	var f := ThemeDB.fallback_font
	var txt := tr("EXIT")
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string_outline(f, g + Vector2(-tw / 2.0, 30), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color(0.1, 0.05, 0.2, 0.9))
	draw_string(f, g + Vector2(-tw / 2.0, 30), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.9, 0.82, 1.0))
