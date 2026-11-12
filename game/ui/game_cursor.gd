## GameCursor — el raton del juego: puntero propio y espada cruzada (paquete PixelRPGCursors Lite)
## cuando esta sobre un enemigo. Solo cambia el cursor del sistema cuando cambia el estado.
class_name GameCursor
extends RefCounted

const DIR := "res://assets/pixel/cursors/"
const HOTSPOTS := {
	"default": {32: Vector2(3, 2), 64: Vector2(6, 4)},
	"attack": {32: Vector2(5, 3), 64: Vector2(10, 6)},
}

static var _current: String = ""
static var _size: int = 0
static var _textures: Dictionary = {}


## "default" o "attack". Con pantallas escaladas (>= 125 %) usa los de 64 px, como indica el pack.
static func set_mode(mode: String) -> void:
	var size := 64 if DisplayServer.screen_get_scale() >= 1.25 else 32
	if mode == _current and size == _size:
		return
	var key := "%s_%d" % [mode, size]
	if not _textures.has(key):
		var file := "UI_Cursor_%s_%d.png" % ["Attack" if mode == "attack" else "Default", size]
		_textures[key] = load(DIR + file)
	_current = mode
	_size = size
	Input.set_custom_mouse_cursor(_textures[key], Input.CURSOR_ARROW, HOTSPOTS[mode][size])


## Un enemigo vivo bajo el punto del mundo `point` (para cambiar a la espada).
static func enemy_under(world: CombatWorld, point: Vector2) -> bool:
	for enemy: EnemySim in world.enemies:
		if enemy.alive and enemy.position.distance_to(point) <= enemy.radius * 1.4 + 12.0:
			return true
	return false
