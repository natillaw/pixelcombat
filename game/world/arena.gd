## Arena — escenario procedural del primer corte (patio de entrenamiento).
##
## Construye el suelo de piedra, los muros, los pilares con oclusión por
## y-sort, las antorchas, la cámara, los actores y los helpers de VFX/SFX.
## Es presentación pura salvo por setup_arena(), que entrega los límites y los
## obstáculos a [CombatWorld] antes de empezar a simular.
class_name Arena
extends Node2D

const SIZE := Vector2(960.0, 640.0)
const WALL := 40.0
const BOUNDS := Rect2(WALL, WALL, SIZE.x - WALL * 2.0, SIZE.y - WALL * 2.0)
const TILE := 32.0
const FLOOR_COLOR := Color(0.13, 0.14, 0.18)
const FLOOR_DARK := Color(0.10, 0.11, 0.145)
const FLOOR_LIGHT := Color(0.165, 0.175, 0.215)
const WALL_COLOR := Color(0.17, 0.18, 0.23)
const WALL_DARK := Color(0.11, 0.12, 0.155)
const WALL_LIGHT := Color(0.24, 0.25, 0.31)
const GOLD := Color(0.78, 0.60, 0.28)

const PILLARS := [
	Vector2(145, 145), Vector2(815, 145),
	Vector2(145, 495), Vector2(815, 495),
	Vector2(185, 320), Vector2(775, 320),
]

const DUMMY_SPAWNS := [
	{"position": Vector2(480, 196), "auto_attack": true},
	{"position": Vector2(660, 390), "auto_attack": false},
	{"position": Vector2(300, 410), "auto_attack": false},
]

var world: CombatWorld
var camera: Camera2D
var entities: Node2D
var fx: Node2D
var warrior_actor: WarriorActor
var dummy_actors: Array[DummyActor] = []

var _tiles: Array = []
var _wall_bricks: Array = []
var _cracks: Array = []
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0

var _shake_time: float = 0.0
var _shake_duration: float = 0.0
var _shake_strength: float = 0.0
var _rng := RandomNumberGenerator.new()


func build(p_world: CombatWorld) -> void:
	world = p_world
	_rng.seed = 90210
	world.setup_arena(BOUNDS, _obstacles())

	_build_floor_data()
	_build_sfx_pool()

	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)

	fx = Node2D.new()
	fx.name = "Fx"
	fx.z_index = 20
	add_child(fx)

	_build_pillars()
	_build_torches()
	_build_camera()
	_spawn_actors()
	queue_redraw()


func _obstacles() -> Array:
	var out: Array = []
	for point: Vector2 in PILLARS:
		out.append({"position": point, "radius": 21.0})
	return out


func _build_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position = world.warrior.position
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(SIZE.x)
	camera.limit_bottom = int(SIZE.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	add_child(camera)
	camera.make_current()


func _spawn_actors() -> void:
	warrior_actor = WarriorActor.new()
	warrior_actor.name = "Warrior"
	warrior_actor.position = world.warrior.position
	warrior_actor.setup(world.warrior, self)
	entities.add_child(warrior_actor)

	for spawn: Dictionary in DUMMY_SPAWNS:
		var dummy_sim := world.add_dummy(spawn["position"], bool(spawn["auto_attack"]))
		var dummy := DummyActor.new()
		dummy.name = "Dummy"
		dummy.position = dummy_sim.position
		dummy.setup(dummy_sim, self)
		entities.add_child(dummy)
		dummy_actors.append(dummy)


func _process(delta: float) -> void:
	if world == null or camera == null:
		return

	camera.position = world.warrior.position

	if _shake_time > 0.0:
		_shake_time = maxf(0.0, _shake_time - delta)
		var ratio := _shake_time / maxf(_shake_duration, 0.001)
		var amount := _shake_strength * ratio
		camera.offset = Vector2(_rng.randf_range(-amount, amount), _rng.randf_range(-amount, amount))
	else:
		camera.offset = Vector2.ZERO


# --- Helpers de presentación ------------------------------------------------


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
		add_child(player)
		_sfx_pool.append(player)


# --- Geometría procedural ---------------------------------------------------


func _build_floor_data() -> void:
	_tiles.clear()
	_cracks.clear()

	var cols := int(BOUNDS.size.x / TILE)
	var rows := int(BOUNDS.size.y / TILE)
	for row: int in range(rows):
		for col: int in range(cols):
			var rect := Rect2(
				BOUNDS.position.x + col * TILE + 1.0,
				BOUNDS.position.y + row * TILE + 1.0,
				TILE - 2.0,
				TILE - 2.0
			)
			var roll := _rng.randf()
			var color := FLOOR_COLOR
			if roll < 0.22:
				color = FLOOR_DARK
			elif roll > 0.82:
				color = FLOOR_LIGHT
			color = color.darkened(_rng.randf_range(-0.02, 0.06))
			_tiles.append({"rect": rect, "color": color})

			if _rng.randf() < 0.06:
				var start := rect.position + Vector2(_rng.randf_range(4.0, 26.0), _rng.randf_range(4.0, 26.0))
				var end := start + Vector2(_rng.randf_range(-9.0, 9.0), _rng.randf_range(6.0, 16.0))
				_cracks.append({"a": start, "b": end})

	# Ladrillos de los muros: bandas de 20 px a lo largo de cada borde.
	var brick_h := 20.0
	var brick_w := 44.0
	for row: int in range(2):
		var y := row * brick_h
		var offset := 22.0 if row % 2 == 1 else 0.0
		var x := -offset
		while x < SIZE.x:
			_tiles_wall(Rect2(x + 2.0, y + 2.0, brick_w - 4.0, brick_h - 4.0))
			x += brick_w
	for row: int in range(2):
		var y := SIZE.y - (row + 1) * brick_h
		var offset := 22.0 if row % 2 == 0 else 0.0
		var x := -offset
		while x < SIZE.x:
			_tiles_wall(Rect2(x + 2.0, y + 2.0, brick_w - 4.0, brick_h - 4.0))
			x += brick_w
	for row: int in range(2):
		var x := row * brick_h
		var offset := 22.0 if row % 2 == 1 else 0.0
		var y := -offset
		while y < SIZE.y:
			_tiles_wall(Rect2(x + 2.0, y + 2.0, brick_h - 4.0, brick_w - 4.0))
			y += brick_w
	for row: int in range(2):
		var x := SIZE.x - (row + 1) * brick_h
		var offset := 22.0 if row % 2 == 0 else 0.0
		var y := -offset
		while y < SIZE.y:
			_tiles_wall(Rect2(x + 2.0, y + 2.0, brick_h - 4.0, brick_w - 4.0))
			y += brick_w


func _tiles_wall(rect: Rect2) -> void:
	var shade := _rng.randf_range(-0.015, 0.015)
	var color := WALL_COLOR.lightened(maxf(shade, 0.0)).darkened(maxf(-shade, 0.0))
	_wall_bricks.append({"rect": rect, "color": color})


func _build_pillars() -> void:
	for point: Vector2 in PILLARS:
		var pillar := Pillar.new()
		pillar.position = point
		entities.add_child(pillar)


func _build_torches() -> void:
	var spots := [
		Vector2(WALL + 8.0, 172.0),
		Vector2(WALL + 8.0, 468.0),
		Vector2(SIZE.x - WALL - 8.0, 172.0),
		Vector2(SIZE.x - WALL - 8.0, 468.0),
	]
	for i: int in range(spots.size()):
		var torch := Torch.new()
		torch.position = spots[i]
		torch.phase = float(i) * 1.7
		entities.add_child(torch)


func _draw() -> void:
	# Fondo exterior.
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.045, 0.05, 0.07))

	# Suelo de piedra.
	draw_rect(BOUNDS, FLOOR_DARK)
	for tile: Dictionary in _tiles:
		draw_rect(tile["rect"], tile["color"])
	for crack: Dictionary in _cracks:
		draw_line(crack["a"], crack["b"], Color(0.06, 0.07, 0.09, 0.85), 1.0)

	_draw_emblem()

	# Muros.
	for brick: Dictionary in _wall_bricks:
		draw_rect(brick["rect"], brick["color"])
	draw_rect(Rect2(0, 0, SIZE.x, SIZE.y), WALL_DARK, false, 4.0)
	draw_rect(BOUNDS, Color(0.0, 0.0, 0.0, 0.35), false, 3.0)
	draw_rect(BOUNDS.grow(3.0), Color(WALL_LIGHT.r, WALL_LIGHT.g, WALL_LIGHT.b, 0.35), false, 1.0)


func _draw_emblem() -> void:
	var center := BOUNDS.get_center()
	draw_arc(center, 168.0, 0.0, TAU, 72, Color(GOLD.r, GOLD.g, GOLD.b, 0.10), 2.0)
	draw_arc(center, 150.0, 0.0, TAU, 72, Color(GOLD.r, GOLD.g, GOLD.b, 0.07), 1.0)

	for i: int in range(8):
		var angle := TAU * float(i) / 8.0
		var a := center + Vector2(cos(angle), sin(angle)) * 150.0
		var b := center + Vector2(cos(angle), sin(angle)) * 168.0
		draw_line(a, b, Color(GOLD.r, GOLD.g, GOLD.b, 0.10), 1.0)

	# Emblema de espada, muy tenue, en el centro de la arena.
	var gold := Color(GOLD.r, GOLD.g, GOLD.b, 0.09)
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
	var phase: float = 0.0

	func _process(delta: float) -> void:
		phase += delta
		queue_redraw()

	func _draw() -> void:
		var flick := 0.8 + 0.2 * sin(phase * 11.0) + 0.06 * sin(phase * 23.0)
		var glow := 0.7 + 0.3 * sin(phase * 7.0)

		# Soporte metálico.
		draw_rect(Rect2(-2, -12, 4, 18), Color(0.12, 0.12, 0.15))
		draw_rect(Rect2(-8, -20, 16, 7), Color(0.23, 0.24, 0.29))
		draw_rect(Rect2(-8, -20, 16, 2), Color(0.39, 0.40, 0.47))

		# Resplandor cálido.
		draw_circle(Vector2(0, -30), 58.0 * glow, Color(1.0, 0.55, 0.18, 0.035))
		draw_circle(Vector2(0, -30), 36.0 * glow, Color(1.0, 0.62, 0.22, 0.05))
		draw_circle(Vector2(0, -30), 20.0 * glow, Color(1.0, 0.72, 0.30, 0.08))

		# Llama.
		draw_circle(Vector2(0, -27), 7.0 * flick, Color(1.0, 0.40, 0.10, 0.92))
		draw_circle(Vector2(1, -31), 4.8 * flick, Color(1.0, 0.70, 0.22, 0.95))
		draw_circle(Vector2(-1, -35), 2.4 * flick, Color(1.0, 0.95, 0.72, 0.95))
