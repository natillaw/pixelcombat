## Arena — escenario dibujado a partir de un [FloorLayout].
##
## Construye el suelo, los muros, los obstaculos con oclusion por y-sort, las
## antorchas, los edificios y portales de la ciudad, la camara, los actores y los
## helpers de VFX/SFX. Es presentacion pura: el escenario lo carga
## `CombatWorld.load_layout()` y la arena se reconstruye al recibir `layout_loaded`.
class_name Arena
extends Node2D

const TILE := 32.0
## Fuente pixel del juego (los carteles usaban la fuente por defecto de Godot, que desentonaba).
const PIXEL_FONT := preload("res://assets/fonts/m5x7.ttf")
const BRICK_H := 20.0
const BRICK_W := 44.0

var world: CombatWorld
## Opcional: la sesion decide si un portal esta activo (para colorear su marcador).
var session: GameSession
var camera: Camera2D
var entities: Node2D
var fx: Node2D
var player_actor: PlayerActor
var dummy_actors: Array[DummyActor] = []
var enemy_actors: Array[EnemyActor] = []
var portal_markers: Array[PortalMarker] = []
## Lo que hay bajo el cursor y se puede coger (lo pone main).
var hovered_pickable: Object = null

var layout: FloorLayout
var _theme: Dictionary = {}
var _size: Vector2 = Vector2(960.0, 640.0)
var _bounds: Rect2 = Rect2()
var terrain: TerrainRenderer = null
var _tiles: Array = []
var _grid_floor: Array = []
var _grid_walls: Array = []
var _grid_water: Array = []
var _wall_bricks: Array = []
var _cracks: Array = []
var _static_nodes: Array[Node] = []
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0

var _shake_time: float = 0.0
var _shake_duration: float = 0.0
var _shake_strength: float = 0.0
var _rng := RandomNumberGenerator.new()


## Monta la arena sobre el escenario que el mundo ya tiene cargado.
func build(p_world: CombatWorld) -> void:
	world = p_world
	assert(world.layout != null, "carga un FloorLayout en el mundo antes de construir la arena")

	_build_sfx_pool()

	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)

	fx = Node2D.new()
	fx.name = "Fx"
	fx.z_index = 20
	add_child(fx)

	_build_camera()

	player_actor = PlayerActor.new()
	player_actor.name = "Warrior"
	player_actor.position = world.player.position
	player_actor.setup(world.player, self)
	entities.add_child(player_actor)

	world.projectile_spawned.connect(_on_projectile_spawned)
	# Las crias que invoca un jefe aparecen despues y necesitan su actor.
	world.enemy_spawned.connect(_on_enemy_spawned)
	world.zone_spawned.connect(_on_zone_spawned)
	world.layout_loaded.connect(_rebuild)
	world.interacted.connect(_on_world_interacted)
	world.resource_gathered.connect(_on_resource_gathered)
	world.player.item_gained.connect(func(_item: Dictionary) -> void: play_event("pickup", world.player.position))
	world.loot_spawned.connect(_on_loot_spawned)
	_rebuild(world.layout)


## Redibuja todo el escenario: limpia lo del anterior y crea lo del nuevo.
func _rebuild(new_layout: FloorLayout) -> void:
	layout = new_layout
	_theme = new_layout.theme
	_size = new_layout.size
	_bounds = new_layout.bounds()
	_rng.seed = 90210 + int(new_layout.seed_value)

	for node: Node in _static_nodes:
		node.queue_free()
	_static_nodes.clear()
	for actor: Node in dummy_actors:
		actor.queue_free()
	dummy_actors.clear()
	for actor: Node in enemy_actors:
		actor.queue_free()
	enemy_actors.clear()
	portal_markers.clear()
	for child: Node in fx.get_children():
		child.queue_free()

	if terrain != null:
		terrain.clear()
		terrain.queue_free()
		terrain = null
	if layout.grid != null and TerrainRenderer.available():
		terrain = TerrainRenderer.new()
		terrain.name = "Terrain"
		add_child(terrain)
		move_child(terrain, 0)
		terrain.build(layout, entities)
		RenderingServer.set_default_clear_color(Color(0.03, 0.035, 0.05))
	elif layout.grid != null:
		_build_grid_data()
	else:
		_build_floor_data()
	_build_props()
	_build_torches()
	_build_portals()
	_build_dungeon_torches()
	_build_resources()
	_build_interactables()
	_build_npcs()
	_spawn_actors()

	camera.limit_right = int(_size.x)
	camera.limit_bottom = int(_size.y)
	camera.limit_top = -520 if layout.kind == FloorLayout.KIND_CITY else 0
	camera.position = world.player.position
	camera.reset_smoothing()
	player_actor.position = world.player.position
	queue_redraw()


func _color(key: String) -> Color:
	return _theme[key]


func _build_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position = world.player.position
	camera.limit_left = 0
	camera.limit_top = 0
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	add_child(camera)
	camera.make_current()


func _spawn_actors() -> void:
	for dummy_sim: DummySim in world.dummies:
		var dummy := DummyActor.new()
		dummy.name = "Dummy"
		dummy.position = dummy_sim.position
		dummy.setup(dummy_sim, self)
		entities.add_child(dummy)
		dummy_actors.append(dummy)

	for enemy_sim: EnemySim in world.enemies:
		_add_enemy_actor(enemy_sim)


func _add_enemy_actor(enemy_sim: EnemySim) -> void:
	var enemy := EnemyActor.new()
	enemy.name = String(enemy_sim.def_id).capitalize()
	enemy.position = enemy_sim.position
	enemy.setup(enemy_sim, self)
	entities.add_child(enemy)
	enemy_actors.append(enemy)


func _on_loot_spawned(drop: LootDrop) -> void:
	var actor := LootActor.new()
	actor.setup(drop, world, self)
	entities.add_child(actor)


func _on_zone_spawned(zone: GroundZone) -> void:
	var actor := ZoneActor.new()
	actor.setup(zone)
	fx.add_child(actor)


func _on_enemy_spawned(enemy_sim: EnemySim) -> void:
	if world.loading_layout:
		return
	_add_enemy_actor(enemy_sim)


## Cada proyectil de la simulacion tiene su actor, que se libera solo al morir.
func _on_projectile_spawned(projectile: ProjectileSim) -> void:
	var actor := ProjectileActor.new()
	actor.name = "Projectile"
	actor.setup(projectile)
	fx.add_child(actor)


func _process(delta: float) -> void:
	if world == null or camera == null:
		return

	camera.position = world.player.position

	if _shake_time > 0.0:
		_shake_time = maxf(0.0, _shake_time - delta)
		var ratio := _shake_time / maxf(_shake_duration, 0.001)
		var amount := _shake_strength * ratio
		camera.offset = Vector2(_rng.randf_range(-amount, amount), _rng.randf_range(-amount, amount))
	else:
		camera.offset = Vector2.ZERO

	if session != null:
		for marker: PortalMarker in portal_markers:
			marker.active = session.portal_active(marker.portal)
			marker.near = session.nearest_portal() == marker.portal


# --- Helpers de presentación ------------------------------------------------


## Reproduce un efecto de la biblioteca (FxLibrary) en `at`.
func fx_at(id: String, at: Vector2, rotation: float = 0.0, fx_scale: float = 1.0, tint: Color = Color.WHITE, seconds: float = 0.0) -> FxSprite:
	if fx == null or not FxLibrary.has_effect(id):
		return null
	var sprite := FxSprite.new()
	sprite.position = at
	fx.add_child(sprite)
	sprite.setup(id, fx_scale, rotation, tint, seconds)
	return sprite


## Efectos de un suceso (data/fx.json "events"): subir de nivel, esquiva, estados...
func play_event(name: String, at: Vector2, extra_scale: float = 1.0) -> void:
	for entry: Dictionary in FxLibrary.event_fx(name):
		fx_at(String(entry["id"]), at + Vector2(0.0, -float(entry.get("up", 0.0))), 0.0, float(entry.get("scale", 1.0)) * extra_scale, Color.WHITE, float(entry.get("seconds", 0.0)))


## Efectos de lanzar una habilidad: delante del jugador (`ahead` x su alcance), sobre el
## mismo (`at: self`) o sobre el punto marcado (`at: aim`).
func play_cast_fx(skill: Dictionary, origin: Vector2, direction: Vector2, aim_point: Vector2, reach: float) -> void:
	for entry: Dictionary in FxLibrary.skill_fx(String(skill.get("id", ""))).get("cast", []):
		var at := origin + direction * reach * float(entry.get("ahead", 0.0))
		if String(entry.get("at", "")) == "aim":
			at = aim_point
		elif String(entry.get("at", "")) == "self":
			at = origin
		at += Vector2(0.0, -float(entry.get("up", 0.0)))
		fx_at(String(entry["id"]), at, direction.angle() if entry.has("ahead") else 0.0, float(entry.get("scale", 1.0)), Color.WHITE, float(entry.get("seconds", 0.0)))


## Efecto del golpe de una habilidad (o el generico de chispa/critico).
func play_hit_fx(skill: Dictionary, at: Vector2, critical: bool) -> void:
	var entry := FxLibrary.skill_fx(String(skill.get("id", "")))
	var id := String(entry.get("crit", "impacts/crit-hit")) if critical else String(entry.get("hit", "impacts/hit-spark"))
	fx_at(id, at + Vector2(0.0, -10.0), randf() * TAU if id.begins_with("explosions") else 0.0, 0.8 if not critical else 1.0)


func _on_world_interacted(object: Interactable) -> void:
	play_event("interact_" + object.kind, object.position)


func _on_resource_gathered(node: ResourceNode, _material_id: String, _amount: int) -> void:
	play_event("gather", node.position)


func spawn_slash(at: Vector2, direction: Vector2, radius: float, arc: float, heavy: bool) -> void:
	var slash := SlashArc.new()
	slash.setup(direction, radius, arc, 0.20 if not heavy else 0.30, heavy)
	slash.position = at
	fx.add_child(slash)


func spawn_impact(at: Vector2, color: Color, heavy: bool = false) -> void:
	var burst := ImpactBurst.new()
	burst.setup(color, heavy)
	burst.position = at
	fx.add_child(burst)


func spawn_damage_number(at: Vector2, amount: float, critical: bool = false) -> void:
	var number := DamageNumber.new()
	number.setup(amount, critical)
	number.place(at)
	fx.add_child(number)


func spawn_floating_text(at: Vector2, label: String, color: Color = Color.WHITE) -> void:
	var number := DamageNumber.new()
	number.setup_label(label, color)
	number.place(at)
	fx.add_child(number)


func play_sfx(stream: AudioStream, volume_db: float = -6.0, pitch: float = 1.0) -> void:
	if stream == null or _sfx_pool.is_empty():
		return
	var player := _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


func shake(strength: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_duration = maxf(_shake_duration, duration)
	_shake_time = maxf(_shake_time, duration)


func _build_sfx_pool() -> void:
	for i: int in range(14):
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%02d" % i
		player.volume_db = -8.0
		player.bus = Settings.SFX_BUS
		add_child(player)
		_sfx_pool.append(player)


# --- Geometria procedural ---------------------------------------------------


func _floor_rect() -> Rect2:
	var wall := layout.wall
	return Rect2(wall, wall, _size.x - wall * 2.0, _size.y - wall * 2.0)


func _build_floor_data() -> void:
	_tiles.clear()
	_cracks.clear()
	_wall_bricks.clear()

	var area := _floor_rect()
	var cols := int(area.size.x / TILE)
	var rows := int(area.size.y / TILE)
	for row: int in range(rows):
		for col: int in range(cols):
			var rect := Rect2(
				area.position.x + col * TILE + 1.0,
				area.position.y + row * TILE + 1.0,
				TILE - 2.0,
				TILE - 2.0
			)
			var roll := _rng.randf()
			var color := _color("floor")
			if roll < 0.22:
				color = _color("floor_dark")
			elif roll > 0.82:
				color = _color("floor_light")
			color = color.darkened(_rng.randf_range(-0.02, 0.06))
			_tiles.append({"rect": rect, "color": color})

			if _rng.randf() < 0.06:
				var start := rect.position + Vector2(_rng.randf_range(4.0, 26.0), _rng.randf_range(4.0, 26.0))
				var end := start + Vector2(_rng.randf_range(-9.0, 9.0), _rng.randf_range(6.0, 16.0))
				_cracks.append({"a": start, "b": end})

	# Ladrillos de los muros: dos bandas de 20 px a lo largo de cada borde.
	for row: int in range(2):
		var y := row * BRICK_H
		var x := -(22.0 if row % 2 == 1 else 0.0)
		while x < _size.x:
			_add_brick(Rect2(x + 2.0, y + 2.0, BRICK_W - 4.0, BRICK_H - 4.0))
			x += BRICK_W
	for row: int in range(2):
		var y := _size.y - (row + 1) * BRICK_H
		var x := -(22.0 if row % 2 == 0 else 0.0)
		while x < _size.x:
			_add_brick(Rect2(x + 2.0, y + 2.0, BRICK_W - 4.0, BRICK_H - 4.0))
			x += BRICK_W
	for row: int in range(2):
		var x := row * BRICK_H
		var y := -(22.0 if row % 2 == 1 else 0.0)
		while y < _size.y:
			_add_brick(Rect2(x + 2.0, y + 2.0, BRICK_H - 4.0, BRICK_W - 4.0))
			y += BRICK_W
	for row: int in range(2):
		var x := _size.x - (row + 1) * BRICK_H
		var y := -(22.0 if row % 2 == 0 else 0.0)
		while y < _size.y:
			_add_brick(Rect2(x + 2.0, y + 2.0, BRICK_H - 4.0, BRICK_W - 4.0))
			y += BRICK_W


func _add_brick(rect: Rect2) -> void:
	var shade := _rng.randf_range(-0.015, 0.015)
	var color := _color("wall").lightened(maxf(shade, 0.0)).darkened(maxf(-shade, 0.0))
	_wall_bricks.append({"rect": rect, "color": color})


func _add_static(node: Node2D, at: Vector2) -> void:
	node.position = at
	entities.add_child(node)
	_static_nodes.append(node)


func _build_props() -> void:
	for obstacle: Dictionary in layout.obstacles:
		var radius: float = obstacle["radius"]
		if bool(obstacle.get("hidden", false)):
			continue
		if layout.kind == FloorLayout.KIND_CITY:
			_add_static(Fountain.new() if radius >= 30.0 else CityTree.new(), obstacle["position"])
		else:
			_add_static(Pillar.new(), obstacle["position"])
	for prop: Dictionary in layout.props:
		var city_prop := CityProp.new()
		city_prop.position = prop["position"]
		entities.add_child(city_prop)
		city_prop.setup(String(prop["kind"]), int(prop.get("variant", 0)))
		_static_nodes.append(city_prop)
	for landmark: Dictionary in layout.landmarks:
		if String(landmark["kind"]) == "giant_tower":
			var tower := GiantTower.new()
			tower.width = float(landmark["width"])
			tower.z_index = -40
			tower.position = landmark["position"]
			add_child(tower)
			_static_nodes.append(tower)
	for building: Dictionary in layout.buildings:
		if building.has("sprite") and ResourceLoader.exists(String(building["sprite"])):
			var sprite := Sprite2D.new()
			sprite.texture = load(String(building["sprite"]))
			sprite.centered = false
			sprite.offset = Vector2(-40.0, -73.0)
			sprite.scale = Vector2.ONE * float(building["scale"])
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_add_static(sprite, building["foot"])
			continue
		var facade := Building.new()
		facade.rect = building["rect"]
		facade.base_color = building["color"]
		facade.label = String(building["label"])
		# El y-sort usa la posicion: la base de la fachada.
		_add_static(facade, Vector2(0.0, (building["rect"] as Rect2).end.y))


func _build_torches() -> void:
	for i: int in range(layout.torches.size()):
		var torch := Torch.new()
		torch.phase = float(i) * 1.7
		_add_static(torch, layout.torches[i])


## Antorchas en las caras de los cliffs de los biomas de cueva y mazmorra: luz calida que
## rompe la oscuridad y marca el camino.
func _build_dungeon_torches() -> void:
	if layout.kind != FloorLayout.KIND_FLOOR or layout.grid == null or terrain == null or String(terrain.biome.get("wall_style", "")) != "cliffs":
		return
	var grid := layout.grid
	var placed: Array[Vector2i] = []
	for r: int in range(2, grid.rows - 2):
		for c: int in range(2, grid.cols - 2):
			if grid.get_cell(c, r) != TileGrid.WALL or grid.get_cell(c, r + 1) != TileGrid.FLOOR or _rng.randf() > 0.06:
				continue
			var spaced := true
			for other: Vector2i in placed:
				if absi(other.x - c) < 7 and absi(other.y - r) < 7:
					spaced = false
			if spaced:
				placed.append(Vector2i(c, r))
				var torch := Torch.new()
				torch.phase = float(placed.size()) * 1.3
				_add_static(torch, Vector2((float(c) + 0.5) * TileGrid.TILE, float(r + 1) * TileGrid.TILE - 4.0))


func _build_npcs() -> void:
	for spec: Dictionary in layout.npcs:
		var npc := NpcActor.new()
		npc.setup(spec)
		_add_static(npc, spec["position"])
		if spec.has("wander"):
			npc.blocker = {"position": npc.position, "radius": 12.0, "hidden": true}
			world.obstacles.append(npc.blocker)


func _build_interactables() -> void:
	for object: Interactable in world.interactables:
		var actor := InteractableActor.new()
		actor.object = object
		actor.world = world
		actor.arena = self
		_add_static(actor, object.position)


## Datos de dibujo de un mapa de casillas: suelo con variacion, muros con cara y agua.
func _build_grid_data() -> void:
	_grid_floor.clear()
	_grid_walls.clear()
	_grid_water.clear()
	var grid := layout.grid
	for r: int in range(grid.rows):
		for c: int in range(grid.cols):
			var kind := grid.get_cell(c, r)
			var rect := Rect2(float(c) * TileGrid.TILE, float(r) * TileGrid.TILE, TileGrid.TILE, TileGrid.TILE)
			if kind == TileGrid.FLOOR:
				var roll := _rng.randf()
				var color := _color("floor")
				if roll < 0.22:
					color = _color("floor_dark")
				elif roll > 0.8:
					color = _color("floor_light")
				_grid_floor.append({"rect": rect, "color": color.darkened(_rng.randf_range(-0.02, 0.05))})
			elif kind == TileGrid.WATER:
				_grid_water.append(rect)
			else:
				# Un muro solo se dibuja si toca suelo (el resto es oscuridad).
				var visible := false
				for dy: int in range(-2, 3):
					for dx: int in range(-2, 3):
						if grid.get_cell(c + dx, r + dy) == TileGrid.FLOOR:
							visible = true
				if visible:
					var face := grid.get_cell(c, r + 1) == TileGrid.FLOOR
					_grid_walls.append({"rect": rect, "face": face})


func _build_resources() -> void:
	for node: ResourceNode in world.resource_nodes:
		var actor := ResourceActor.new()
		actor.node = node
		actor.world = world
		actor.arena = self
		_add_static(actor, node.position)


func _build_portals() -> void:
	for portal: Dictionary in layout.portals:
		var marker := PortalMarker.new()
		marker.portal = portal
		marker.accent = _color("accent")
		marker.z_index = -1
		marker.position = portal["position"]
		entities.add_child(marker)
		_static_nodes.append(marker)
		portal_markers.append(marker)


func _draw_grid() -> void:
	draw_rect(Rect2(Vector2.ZERO, _size), _color("background"))
	for tile: Dictionary in _grid_floor:
		draw_rect(tile["rect"], tile["color"])
	for rect: Rect2 in _grid_water:
		draw_rect(rect, Color(0.12, 0.25, 0.38))
		draw_rect(Rect2(rect.position + Vector2(4, 8), Vector2(10, 2)), Color(0.35, 0.55, 0.7, 0.5))
	var wall: Color = _color("wall")
	for entry: Dictionary in _grid_walls:
		var rect: Rect2 = entry["rect"]
		draw_rect(rect, wall.darkened(0.25))
		if bool(entry["face"]):
			draw_rect(Rect2(rect.position, Vector2(TileGrid.TILE, TileGrid.TILE * 0.7)), wall.lightened(0.12))
			draw_rect(Rect2(rect.position + Vector2(0, TileGrid.TILE * 0.7), Vector2(TileGrid.TILE, TileGrid.TILE * 0.3)), wall.darkened(0.15))
		else:
			draw_rect(rect.grow(-1.0), wall)


func _draw() -> void:
	if layout == null:
		return
	if layout.grid != null:
		if terrain == null:
			_draw_grid()
		return
	var bounds := _bounds
	# Fondo exterior.
	draw_rect(Rect2(Vector2.ZERO, _size), _color("background"))

	# Suelo.
	draw_rect(_floor_rect(), _color("floor_dark"))
	for tile: Dictionary in _tiles:
		draw_rect(tile["rect"], tile["color"])
	for crack: Dictionary in _cracks:
		draw_line(crack["a"], crack["b"], Color(0.06, 0.07, 0.09, 0.85), 1.0)

	if bool(_theme.get("emblem", false)):
		_draw_emblem()

	# Muros.
	for brick: Dictionary in _wall_bricks:
		draw_rect(brick["rect"], brick["color"])
	var wall_light: Color = _color("wall_light")
	draw_rect(Rect2(Vector2.ZERO, _size), _color("wall_dark"), false, 4.0)
	draw_rect(bounds, Color(0.0, 0.0, 0.0, 0.35), false, 3.0)
	draw_rect(bounds.grow(3.0), Color(wall_light.r, wall_light.g, wall_light.b, 0.35), false, 1.0)


func _draw_emblem() -> void:
	var accent: Color = _color("accent")
	var center := _bounds.get_center()
	draw_arc(center, 168.0, 0.0, TAU, 72, Color(accent.r, accent.g, accent.b, 0.10), 2.0)
	draw_arc(center, 150.0, 0.0, TAU, 72, Color(accent.r, accent.g, accent.b, 0.07), 1.0)

	for i: int in range(8):
		var angle := TAU * float(i) / 8.0
		var a := center + Vector2(cos(angle), sin(angle)) * 150.0
		var b := center + Vector2(cos(angle), sin(angle)) * 168.0
		draw_line(a, b, Color(accent.r, accent.g, accent.b, 0.10), 1.0)

	# Emblema de espada, muy tenue, en el centro de la arena.
	var gold := Color(accent.r, accent.g, accent.b, 0.09)
	var c := center
	var blade := PackedVector2Array([
		c + Vector2(0, -78), c + Vector2(7, -52), c + Vector2(7, 38),
		c + Vector2(0, 56), c + Vector2(-7, 38), c + Vector2(-7, -52),
	])
	draw_colored_polygon(blade, gold)
	draw_rect(Rect2(c + Vector2(-36, 34), Vector2(72, 8)), gold)
	draw_rect(Rect2(c + Vector2(-5, 42), Vector2(10, 26)), gold)
	draw_circle(c + Vector2(0, 72), 7.0, gold)


class Pillar extends Node2D:
	var height: float = 76.0

	func _draw() -> void:
		var stone := Color(0.30, 0.31, 0.37)
		var stone_light := Color(0.39, 0.40, 0.47)
		var stone_dark := Color(0.19, 0.20, 0.25)

		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.42))
		draw_circle(Vector2.ZERO, 28.0, Color(0.0, 0.0, 0.0, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		draw_rect(Rect2(-23, -13, 46, 13), stone_dark)
		draw_rect(Rect2(-19, -19, 38, 7), stone)
		draw_rect(Rect2(-14, -height, 28, height - 12), stone)
		draw_rect(Rect2(-14, -height, 6, height - 18), stone_light)
		draw_rect(Rect2(-18, -height - 8, 36, 10), stone_light)
		draw_rect(Rect2(-23, -height - 15, 46, 8), stone_dark)
		draw_rect(Rect2(-19, -height - 18, 38, 4), stone)
		draw_line(Vector2(6, -height + 12), Vector2(9, -height + 34), stone_dark, 1.0)
		draw_line(Vector2(9, -height + 34), Vector2(5, -height + 52), stone_dark, 1.0)


class Torch extends Node2D:
	const SHEET := preload("res://assets/pixel/fx/torch_sheet.png")
	const FRAMES := 9
	const SIZE := 48

	var phase: float = 0.0
	var _sprite: AnimatedSprite2D

	func _ready() -> void:
		var frames := SpriteFrames.new()
		frames.add_animation(&"burn")
		frames.set_animation_speed(&"burn", 6.6)
		frames.set_animation_loop(&"burn", true)
		if frames.has_animation(&"default"):
			frames.remove_animation(&"default")
		for i: int in range(FRAMES):
			var atlas := AtlasTexture.new()
			atlas.atlas = SHEET
			atlas.region = Rect2(i * SIZE, 0, SIZE, SIZE)
			frames.add_frame(&"burn", atlas)
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = frames
		_sprite.centered = false
		_sprite.offset = Vector2(-SIZE * 0.5, -SIZE + 2.0)
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_sprite)
		_sprite.frame = int(abs(phase * 3.0)) % FRAMES
		_sprite.play(&"burn")

	func _process(delta: float) -> void:
		phase += delta
		queue_redraw()

	func _draw() -> void:
		# Resplandor calido que parpadea alrededor de la llama.
		var glow := 0.75 + 0.25 * sin(phase * 7.0) + 0.06 * sin(phase * 19.0)
		draw_circle(Vector2(0, -30), 64.0 * glow, Color(1.0, 0.55, 0.18, 0.035))
		draw_circle(Vector2(0, -30), 40.0 * glow, Color(1.0, 0.62, 0.22, 0.05))
		draw_circle(Vector2(0, -30), 22.0 * glow, Color(1.0, 0.72, 0.30, 0.08))


class CityTree extends Node2D:
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.42))
		draw_circle(Vector2.ZERO, 24.0, Color(0.0, 0.0, 0.0, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_rect(Rect2(-4, -34, 8, 34), Color(0.30, 0.20, 0.12))
		draw_circle(Vector2(0, -52), 24.0, Color(0.16, 0.34, 0.18))
		draw_circle(Vector2(-12, -44), 16.0, Color(0.20, 0.40, 0.21))
		draw_circle(Vector2(12, -46), 15.0, Color(0.13, 0.29, 0.16))
		draw_circle(Vector2(2, -62), 14.0, Color(0.23, 0.44, 0.24))


class Fountain extends Node2D:
	const RING := preload("res://assets/pixel/lpc_terrain/well_ring.png")
	var phase: float = 0.0

	func _process(delta: float) -> void:
		phase += delta
		queue_redraw()

	func _draw() -> void:
		# Brocal de piedra (pozo LPC de Xenodora) con agua viva dentro.
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.62))
		draw_circle(Vector2(0, 6), 40.0, Color(0.0, 0.0, 0.0, 0.25))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var scale := 1.35
		var size := Vector2(RING.get_size()) * scale
		var origin := Vector2(-size.x * 0.5, -size.y + 14.0)
		draw_texture_rect(RING, Rect2(origin, size), false)
		var center := Vector2(0, origin.y + size.y * 0.42)
		draw_set_transform(center, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 21.0, Color(0.16, 0.34, 0.5))
		draw_circle(Vector2.ZERO, 17.0 + sin(phase * 3.0) * 1.2, Color(0.27, 0.52, 0.68))
		draw_arc(Vector2.ZERO, 8.0 + fmod(phase * 6.0, 9.0), 0.0, TAU, 24, Color(0.75, 0.9, 1.0, 0.5), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Cristal flotante sobre la fuente: palpita y suelta destellos (como el de la plaza de referencia).
		var bob := sin(phase * 1.8) * 3.0
		var top := center + Vector2(0, -34.0 + bob)
		draw_circle(top, 30.0 + sin(phase * 2.6) * 3.0, Color(0.4, 0.65, 1.0, 0.10))
		draw_circle(top, 18.0, Color(0.55, 0.78, 1.0, 0.14))
		draw_colored_polygon(PackedVector2Array([top + Vector2(0, -20), top + Vector2(10, -4), top + Vector2(7, 16), top + Vector2(0, 22), top + Vector2(-7, 16), top + Vector2(-10, -4)]), Color(0.32, 0.55, 0.98))
		draw_colored_polygon(PackedVector2Array([top + Vector2(0, -20), top + Vector2(10, -4), top + Vector2(0, 2), top + Vector2(-10, -4)]), Color(0.62, 0.82, 1.0))
		draw_colored_polygon(PackedVector2Array([top + Vector2(0, 2), top + Vector2(10, -4), top + Vector2(7, 16), top + Vector2(0, 22)]), Color(0.2, 0.38, 0.8))
		for i: int in range(5):
			var t := fmod(phase * 0.6 + float(i) * 0.2, 1.0)
			var spark := top + Vector2(sin(float(i) * 2.4 + phase) * 16.0, 22.0 - t * 52.0)
			draw_circle(spark, 1.6, Color(0.8, 0.92, 1.0, 1.0 - t))


## Fachada de un edificio de oficio (decoracion; la puerta es un portal).
class Building extends Node2D:
	var rect: Rect2 = Rect2()
	var base_color: Color = Color(0.5, 0.35, 0.25)
	var label: String = ""

	func _draw() -> void:
		# Este nodo esta en (0, y_base); dibujamos con coordenadas de mundo.
		var wall := base_color
		var dark := base_color.darkened(0.35)
		var light := base_color.lightened(0.18)
		var origin := Vector2(0.0, -rect.end.y)
		var r := Rect2(rect.position + origin, rect.size)
		draw_rect(Rect2(r.position + Vector2(6, r.size.y - 6), Vector2(r.size.x, 10)), Color(0.0, 0.0, 0.0, 0.3))
		draw_rect(r, wall)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 8)), light)
		for i: int in range(1, 5):
			draw_line(r.position + Vector2(0, 28 * i), r.position + Vector2(r.size.x, 28 * i), dark, 1.0)
		# Tejado.
		var roof := PackedVector2Array([
			r.position + Vector2(-10, 4), r.position + Vector2(r.size.x * 0.5, -34), r.position + Vector2(r.size.x + 10, 4),
		])
		draw_colored_polygon(roof, dark.darkened(0.15))
		# Puerta y ventanas.
		var door := Rect2(r.position + Vector2(r.size.x * 0.5 - 16, r.size.y - 46), Vector2(32, 46))
		draw_rect(door, Color(0.16, 0.10, 0.07))
		draw_rect(Rect2(door.position + Vector2(2, 2), door.size - Vector2(4, 2)), Color(0.28, 0.18, 0.11))
		for x: float in [0.18, 0.74]:
			var win := Rect2(r.position + Vector2(r.size.x * x, 30), Vector2(22, 26))
			draw_rect(win, Color(0.09, 0.10, 0.14))
			draw_rect(Rect2(win.position + Vector2(2, 2), win.size - Vector2(4, 4)), Color(0.95, 0.72, 0.35, 0.85))
		# Cartel.
		var font: Font = PIXEL_FONT
		var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		var sign_rect := Rect2(r.position + Vector2(r.size.x * 0.5 - size.x * 0.5 - 6, 62), Vector2(size.x + 12, 20))
		draw_rect(sign_rect, Color(0.12, 0.08, 0.05))
		draw_string(font, sign_rect.position + Vector2(6, 15), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.85, 0.6))


## Marcador de un punto de interaccion (puerta de la torre, salidas...).
class PortalMarker extends Node2D:
	var portal: Dictionary = {}
	var accent: Color = Color(0.9, 0.7, 0.3)
	var active: bool = true
	var near: bool = false
	var _time: float = 0.0

	var _sprite: AnimatedSprite2D = null

	func _ready() -> void:
		# Portales de piso (salida, entrenamiento): el portal arcano del pack de efectos, en bucle. La puerta de la torre y
		# las de los oficios no llevan nada en el suelo (el edificio ya es la puerta).
		var id := String(portal.get("id", ""))
		if id == "exit" or id == "entrance" or id == "to_city" or id == "to_training":
			var frames := FxLibrary.frames("arcane/portal-summon").duplicate() as SpriteFrames
			frames.set_animation_loop(&"play", true)
			_sprite = AnimatedSprite2D.new()
			_sprite.sprite_frames = frames
			_sprite.offset = Vector2(0, -44)
			_sprite.scale = Vector2.ONE * 0.9
			_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var material := CanvasItemMaterial.new()
			material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			_sprite.material = material
			add_child(_sprite)
			_sprite.play(&"play")

	func _process(delta: float) -> void:
		_time += delta
		if _sprite != null:
			_sprite.modulate = Color(1, 1, 1, 0.95 if active else 0.35)
		queue_redraw()

	func _draw() -> void:
		var radius: float = float(portal.get("radius", 34.0))
		var font: Font = PIXEL_FONT
		var label := String(portal.get("label", ""))
		# "Hablar con X" ya sale en la barra inferior y encima del PNJ; flotando tapaba su nombre.
		if label != "" and not label.begins_with("Hablar con") and (near or String(portal.get("action", "")) == "tower"):
			var size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
			draw_string(font, Vector2(-size.x * 0.5, -radius * 0.6 - 8.0 - (70.0 if _sprite != null else 0.0)), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.9) if active else Color(0.7, 0.7, 0.75, 0.9))


## Item en el suelo: gema del color de su rareza que salta al caer, flota y, a partir
## de Raro, lanza un rayo de luz. Se libera cuando el mundo lo recoge o caduca.
class LootActor extends Node2D:
	var drop: LootDrop
	var _color: Color = Color.WHITE
	var _rank: int = 0
	var _time: float = 0.0

	var arena: Arena

	func setup(p_drop: LootDrop, world: CombatWorld, p_arena: Arena) -> void:
		drop = p_drop
		position = drop.position
		_color = ItemCatalog.rarity_color(String(drop.item["rarity"]))
		_rank = ItemCatalog.rarity_rank(String(drop.item["rarity"]))
		world.loot_removed.connect(_on_removed)
		arena = p_arena

	func _on_removed(removed: LootDrop) -> void:
		if removed == drop:
			queue_free()

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var fall := clampf(_time / LootDrop.PICKUP_DELAY, 0.0, 1.0)
		var hop := (1.0 - fall) * 22.0 * sin(fall * PI + 0.001) + (1.0 - fall) * 14.0
		var bob := sin(_time * 3.0) * 2.0 if fall >= 1.0 else 0.0
		var lift := Vector2(0.0, -10.0 - hop - bob)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 9.0, Color(0.0, 0.0, 0.0, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if _rank >= 2:
			var pulse := 0.5 + 0.5 * sin(_time * 4.0)
			draw_rect(Rect2(-3, -64, 6, 56), Color(_color.r, _color.g, _color.b, 0.10 + 0.08 * pulse))
			draw_rect(Rect2(-1, -64, 2, 56), Color(_color.r, _color.g, _color.b, 0.25 + 0.15 * pulse))
		if arena != null and arena.hovered_pickable == drop:
			draw_arc(lift, 13.0, 0.0, TAU, 24, Color(1, 1, 1, 0.9), 1.5)
		var gem := PackedVector2Array([lift + Vector2(0, -7), lift + Vector2(6, 0), lift + Vector2(0, 7), lift + Vector2(-6, 0)])
		draw_colored_polygon(gem, _color)
		draw_polyline(PackedVector2Array([gem[0], gem[1], gem[2], gem[3], gem[0]]), _color.lightened(0.5), 1.0)
		draw_rect(Rect2(lift + Vector2(-1, -4), Vector2(2, 3)), Color(1, 1, 1, 0.8))


## Nodo de recoleccion: veta de mineral, mata de hierba o arbol. Al agotarse queda
## apagado; mientras se recolecta muestra una barra de progreso.
class ResourceActor extends Node2D:
	var node: ResourceNode
	var world: CombatWorld
	var arena: Arena
	var _time: float = 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 17.0, Color(0.0, 0.0, 0.0, 0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if node.depleted != _shown_depleted:
			_rebuild()
		if arena != null and arena.hovered_pickable == node:
			draw_arc(Vector2(0, -12), 20.0, 0.0, TAU, 28, Color(1, 1, 1, 0.9), 1.5)
		if world != null and world.gather_node == node:
			var ratio := 1.0 - world.gather_left / maxf(node.gather_seconds(), 0.01)
			draw_rect(Rect2(-16, -42, 32, 5), Color(0.05, 0.05, 0.08, 0.9))
			draw_rect(Rect2(-15, -41, 30 * clampf(ratio, 0.0, 1.0), 3), Color(0.95, 0.78, 0.35))

	## Sprites del nodo (rocas, hierba y arboles de las hojas LPC del terreno); se rehacen al agotarse o reponerse.
	var _sprites: Array[Sprite2D] = []
	var _glint: FxSprite = null
	var _shown_depleted: bool = false

	func _ready() -> void:
		_rebuild()

	func _rebuild() -> void:
		for sprite: Sprite2D in _sprites:
			sprite.queue_free()
		_sprites = []
		if _glint != null:
			_glint.queue_free()
			_glint = null
		_shown_depleted = node.depleted
		var seed_value := absi(int(node.position.x * 7.0 + node.position.y * 13.0))
		for part: Dictionary in ResourceSprites.parts(node.kind, seed_value, node.depleted):
			var sprite := Sprite2D.new()
			sprite.texture = part["texture"]
			sprite.centered = false
			sprite.position = part["position"]
			sprite.scale = Vector2.ONE * float(part["scale"])
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var base := arena.terrain.modulate if arena != null and arena.terrain != null else Color.WHITE
			sprite.modulate = base * Color(0.55, 0.55, 0.6, 1.0) if node.depleted else base
			add_child(sprite)
			_sprites.append(sprite)
		# Las vetas y los nodos ricos brillan (efecto del pack) mientras se pueden recoger.
		if not node.depleted and (node.kind == "ore" or node.rich):
			_glint = FxSprite.new()
			add_child(_glint)
			_glint.setup("ui/treasure-glint", 0.6, 0.0, Color(1, 1, 1, 0.9), 0.0)
			_glint.position = Vector2(0.0, -14.0)
			_glint.z_index = 1

## Objeto de mision: altar, baliza, jaula, sello, reliquia, altar de entrega o waypoint.
class InteractableActor extends Node2D:
	var object: Interactable
	var world: CombatWorld
	var arena: Arena
	var _time: float = 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var done := object.done
		var pulse := 0.5 + 0.5 * sin(_time * 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 22.0, Color(0.0, 0.0, 0.0, 0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var base := Color(0.55, 0.62, 0.78)
		var glow := Color(0.45, 0.8, 1.0)
		match object.kind:
			"altar":
				glow = Color(0.95, 0.75, 0.3)
			"seal":
				glow = Color(0.7, 0.45, 1.0)
			"cage":
				glow = Color(0.6, 0.9, 0.5)
			"beacon":
				glow = Color(1.0, 0.55, 0.25)
			"relic":
				glow = Color(0.4, 1.0, 0.9)
			"relic_altar":
				glow = Color(1.0, 0.85, 0.35)
			"waypoint":
				glow = Color(0.5, 0.9, 1.0)
			"campfire":
				glow = Color(1.0, 0.62, 0.2)
		var tone := glow if not done else glow.darkened(0.55)
		match object.kind:
			"campfire":
				# Troncos cruzados y una llama que parpadea; apagada (gastada) queda la ceniza.
				draw_line(Vector2(-12, -3), Vector2(12, -9), Color(0.32, 0.2, 0.1), 4.0)
				draw_line(Vector2(-12, -9), Vector2(12, -3), Color(0.4, 0.26, 0.13), 4.0)
				if not done:
					var flame := 10.0 + 3.0 * pulse
					draw_circle(Vector2(0, -12), 26.0 + 6.0 * pulse, Color(tone.r, tone.g, tone.b, 0.1))
					draw_colored_polygon(PackedVector2Array([Vector2(-7, -8), Vector2(0, -8.0 - flame * 2.0), Vector2(7, -8)]), Color(1.0, 0.45, 0.12))
					draw_colored_polygon(PackedVector2Array([Vector2(-4, -8), Vector2(0, -8.0 - flame * 1.2), Vector2(4, -8)]), Color(1.0, 0.85, 0.35))
			"cage":
				draw_rect(Rect2(-12, -26, 24, 26), Color(0.25, 0.2, 0.15))
				for i: int in range(5):
					draw_line(Vector2(-10 + i * 5, -26), Vector2(-10 + i * 5, 0), tone.darkened(0.2) if not done else Color(0.3, 0.3, 0.3), 2.0)
				if not done:
					draw_circle(Vector2(0, -14), 5.0, Color(0.9, 0.8, 0.65))
			"waypoint":
				draw_arc(Vector2(0, -2), 16.0 + 3.0 * pulse, 0.0, TAU, 28, Color(tone.r, tone.g, tone.b, 0.8), 2.0)
				draw_rect(Rect2(-2, -34, 4, 34), tone.darkened(0.3))
				draw_colored_polygon(PackedVector2Array([Vector2(2, -34), Vector2(16, -29), Vector2(2, -24)]), tone)
			"relic":
				if not done:
					draw_colored_polygon(PackedVector2Array([Vector2(0, -34), Vector2(9, -22), Vector2(0, -10), Vector2(-9, -22)]), tone)
					draw_circle(Vector2(0, -22), 18.0 + 4.0 * pulse, Color(tone.r, tone.g, tone.b, 0.12))
			_:
				draw_rect(Rect2(-14, -12, 28, 12), base.darkened(0.3))
				draw_rect(Rect2(-10, -26, 20, 16), base)
				draw_circle(Vector2(0, -30), 6.0 + (2.0 * pulse if not done else 0.0), tone)
				if not done:
					draw_circle(Vector2(0, -30), 16.0 + 4.0 * pulse, Color(tone.r, tone.g, tone.b, 0.12))
		if arena != null and arena.hovered_pickable == object:
			draw_arc(Vector2(0, -14), 24.0, 0.0, TAU, 28, Color(1, 1, 1, 0.9), 1.5)
		if world != null and world.gather_node == object:
			var ratio := 1.0 - world.gather_left / maxf(object.channel_seconds, 0.01)
			draw_rect(Rect2(-16, -46, 32, 5), Color(0.05, 0.05, 0.08, 0.9))
			draw_rect(Rect2(-15, -45, 30 * clampf(ratio, 0.0, 1.0), 3), Color(0.95, 0.78, 0.35))


## La Torre de las Cien Puertas, vista de frente: un fuste de piedra oscura que sube mas alla del
## borde del mapa y se disuelve en la niebla (nunca se ve la cima). El nodo esta en el pie de la
## torre; el fuste crece hacia arriba (Y negativa). Se dibuja una vez: sillares, contrafuertes,
## ventanas con luz, bandas de runas, un arco de entrada y capas de niebla que lo oscurecen con
## la altura.
class GiantTower extends Node2D:
	const HEIGHT := 3400.0
	var width: float = 736.0

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 90210
		var half := width * 0.5
		var stone := Color(0.17, 0.18, 0.24)
		var stone_dark := Color(0.09, 0.10, 0.15)
		var stone_light := Color(0.27, 0.28, 0.36)
		# Fuste: se estrecha un poco con la altura.
		draw_colored_polygon(PackedVector2Array([Vector2(-half, 0), Vector2(half, 0), Vector2(half * 0.84, -HEIGHT), Vector2(-half * 0.84, -HEIGHT)]), stone)
		draw_colored_polygon(PackedVector2Array([Vector2(-half, 0), Vector2(-half * 0.55, 0), Vector2(-half * 0.5, -HEIGHT), Vector2(-half * 0.84, -HEIGHT)]), stone_dark)
		draw_colored_polygon(PackedVector2Array([Vector2(half * 0.55, 0), Vector2(half, 0), Vector2(half * 0.84, -HEIGHT), Vector2(half * 0.5, -HEIGHT)]), stone_dark)
		# Textura de piedra: la cara de los cliffs LPC (Mountain, invierno) en filas de 32 px.
		var face: Texture2D = load("res://assets/pixel/lpc_terrain/mountain_winter.png")
		var stone_y := 0.0
		var stone_row := 0
		while stone_y > -HEIGHT:
			var t_row := -stone_y / HEIGHT
			var shaft_w := lerpf(width, width * 0.84, t_row)
			var cols := int(ceil(shaft_w / 32.0))
			for ci: int in range(cols):
				var tile_x := -shaft_w * 0.5 + float(ci) * 32.0
				var src := Rect2(32.0 + float((ci + stone_row) % 2) * 0.0, 3.0 * 32.0 if stone_row % 2 == 0 else 4.0 * 32.0, 32.0, 32.0)
				draw_texture_rect_region(face, Rect2(tile_x, stone_y - 32.0, minf(32.0, -shaft_w * 0.5 + shaft_w - (tile_x + shaft_w * 0.5) + 32.0), 32.0), src, Color(0.55, 0.56, 0.7, 0.92))
			stone_y -= 32.0
			stone_row += 1
		# Hiladas de sillares.
		var y := 0.0
		var row := 0
		while y > -HEIGHT:
			var t := -y / HEIGHT
			var shaft_half := lerpf(half, half * 0.84, t)
			draw_line(Vector2(-shaft_half, y), Vector2(shaft_half, y), Color(0, 0, 0.02, 0.45), 1.0)
			var x := -shaft_half + float(row % 2) * 24.0
			while x < shaft_half:
				draw_line(Vector2(x, y), Vector2(x, y - 24.0), Color(0, 0, 0.02, 0.30), 1.0)
				x += 48.0
			y -= 24.0
			row += 1
		# Contrafuertes a los lados, con anillos de piedra clara.
		for side: float in [-1.0, 1.0]:
			var bx := side * (half - 34.0)
			draw_rect(Rect2(bx - 22.0, -HEIGHT, 44.0, HEIGHT), stone_light.darkened(0.25))
			draw_rect(Rect2(bx - 22.0, -HEIGHT, 6.0, HEIGHT), stone_light)
			draw_rect(Rect2(bx + 16.0, -HEIGHT, 6.0, HEIGHT), stone_dark)
			var ring := -140.0
			while ring > -HEIGHT:
				draw_rect(Rect2(bx - 28.0, ring, 56.0, 14.0), stone_light)
				draw_rect(Rect2(bx - 28.0, ring + 14.0, 56.0, 4.0), stone_dark)
				ring -= 220.0
		# Ventanas ojivales con luz y bandas de runas.
		var level := -170.0
		var index := 0
		while level > -HEIGHT:
			for i: int in range(5):
				var wx := lerpf(-half * 0.55, half * 0.55, float(i) / 4.0)
				var lit := rng.randf() < 0.55
				var glow := Color(1.0, 0.72, 0.30) if rng.randf() < 0.7 else Color(0.45, 0.80, 1.0)
				draw_rect(Rect2(wx - 9.0, level - 34.0, 18.0, 34.0), Color(0.02, 0.025, 0.05))
				draw_colored_polygon(PackedVector2Array([Vector2(wx - 9.0, level - 34.0), Vector2(wx, level - 46.0), Vector2(wx + 9.0, level - 34.0)]), Color(0.02, 0.025, 0.05))
				if lit:
					draw_rect(Rect2(wx - 6.0, level - 30.0, 12.0, 28.0), Color(glow.r, glow.g, glow.b, 0.85))
					draw_circle(Vector2(wx, level - 16.0), 26.0, Color(glow.r, glow.g, glow.b, 0.06))
				draw_rect(Rect2(wx - 11.0, level, 22.0, 4.0), stone_light)
			index += 1
			if index % 3 == 0:
				var band := level - 78.0
				draw_rect(Rect2(-half * 0.8, band, half * 1.6, 8.0), stone_dark)
				for k: int in range(14):
					var rx := lerpf(-half * 0.74, half * 0.74, float(k) / 13.0)
					draw_rect(Rect2(rx - 3.0, band + 2.0, 6.0, 4.0), Color(0.45, 0.85, 1.0, 0.75))
			level -= 150.0
		# Arco de entrada y escalinata.
		draw_rect(Rect2(-62.0, -150.0, 124.0, 150.0), stone_light.darkened(0.2))
		draw_rect(Rect2(-48.0, -134.0, 96.0, 134.0), Color(0.01, 0.012, 0.03))
		draw_colored_polygon(PackedVector2Array([Vector2(-48.0, -134.0), Vector2(0.0, -168.0), Vector2(48.0, -134.0)]), Color(0.01, 0.012, 0.03))
		draw_arc(Vector2(0.0, -134.0), 56.0, PI, TAU, 24, stone_light, 6.0)
		for i: int in range(5):
			draw_rect(Rect2(-76.0 + float(i) * 6.0, -float(i) * 5.0 - 4.0, 152.0 - float(i) * 12.0, 6.0), stone_light.darkened(0.1 * float(i % 2)))
		draw_circle(Vector2(0.0, -70.0), 70.0, Color(0.45, 0.8, 1.0, 0.07))
		draw_circle(Vector2(0.0, -70.0), 38.0, Color(0.45, 0.8, 1.0, 0.09))
		# Niebla: cada capa oscurece lo que tiene encima, hasta perder la cima.
		var layers := 48
		for i: int in range(layers):
			var top := -HEIGHT + HEIGHT * float(i) / float(layers)
			var alpha := pow(1.0 - float(i) / float(layers), 1.6) * 0.62
			draw_rect(Rect2(-half - 40.0, top, width + 80.0, HEIGHT / float(layers) + 2.0), Color(0.03, 0.04, 0.08, alpha))
		for i: int in range(26):
			var cy := -rng.randf_range(200.0, 1500.0)
			draw_circle(Vector2(rng.randf_range(-half, half), cy), rng.randf_range(60.0, 130.0), Color(0.55, 0.6, 0.72, 0.05))
		# Sombra proyectada al pie.
		draw_rect(Rect2(-half, 0.0, width, 14.0), Color(0, 0, 0, 0.35))
