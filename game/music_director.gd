## MusicDirector — la musica segun donde estas y que pasa (presentacion pura: lee el estado, no escribe nada).
##
## Pistas (assets/audio/music/xdeviruchi, CC BY-SA 4.0): title (menu), town (ciudad), explore (pisos y patio),
## dungeon (pisos de tiers altos), battle (hay enemigos en guardia cerca), boss (barra de jefe), results
## (piso completado) y silencio al morir. Entre pistas hay un fundido. Prioridad: menu > muerte > victoria >
## jefe > combate > lugar.
class_name MusicDirector
extends Node

const DIR := "res://assets/audio/music/xdeviruchi/"
const TRACKS: Array[String] = ["title", "town", "explore", "dungeon", "battle", "boss", "results"]
const FADE_SECONDS := 1.2
## Segundos que sigue sonando el combate despues del ultimo enemigo en guardia.
const COMBAT_HOLD := 4.0
const VICTORY_SECONDS := 14.0
const COMBAT_RADIUS := 520.0
const CHECK_EVERY := 0.25

var world: CombatWorld
var session: GameSession
var menu: Control
## Pista que suena ahora ("" = silencio); la leen los tests.
var current_track: String = ""

var _combat_left: float = 0.0
var _victory_left: float = 0.0
var _check_in: float = 0.0
var _players: Array[AudioStreamPlayer] = []
var _active: int = 0


## Pista que toca para un contexto {menu, dead, victory, boss, combat, kind, tier}. Pura y probada.
static func choose(ctx: Dictionary) -> String:
	if bool(ctx.get("menu", false)):
		return "title"
	if bool(ctx.get("dead", false)):
		return ""
	if bool(ctx.get("victory", false)):
		return "results"
	if bool(ctx.get("boss", false)):
		return "boss"
	if bool(ctx.get("combat", false)):
		return "battle"
	match String(ctx.get("kind", "")):
		FloorLayout.KIND_CITY:
			return "town"
		FloorLayout.KIND_FLOOR:
			return "dungeon" if int(ctx.get("tier", 1)) >= 2 else "explore"
	return "explore"


func bind(p_world: CombatWorld, p_session: GameSession, p_menu: Control = null) -> void:
	world = p_world
	session = p_session
	menu = p_menu
	process_mode = Node.PROCESS_MODE_ALWAYS
	session.floor_completed.connect(func(_floor: int, _xp: int) -> void: _victory_left = VICTORY_SECONDS)
	session.location_changed.connect(func(_layout: FloorLayout) -> void: _victory_left = 0.0; _combat_left = 0.0)
	if DisplayServer.get_name() != "headless":
		for i: int in range(2):
			var player := AudioStreamPlayer.new()
			player.bus = Settings.MUSIC_BUS
			player.volume_db = -80.0
			add_child(player)
			_players.append(player)


func _process(delta: float) -> void:
	evaluate(delta)


## Revisa el contexto cada CHECK_EVERY s y cambia de pista si hace falta (publico para probarlo sin ventana).
func evaluate(delta: float) -> void:
	_victory_left = maxf(0.0, _victory_left - delta)
	_combat_left = maxf(0.0, _combat_left - delta)
	_check_in -= delta
	if _check_in > 0.0:
		return
	_check_in = CHECK_EVERY
	if _enemies_on_guard():
		_combat_left = COMBAT_HOLD
	var wanted := choose(context())
	if wanted != current_track:
		_switch_to(wanted)


func context() -> Dictionary:
	var layout: FloorLayout = session.layout if session != null else null
	return {
		"menu": menu != null and menu.visible,
		"dead": world != null and world.player != null and not world.player.alive,
		"victory": _victory_left > 0.0,
		"boss": _boss_fighting(),
		"combat": _combat_left > 0.0,
		"kind": layout.kind if layout != null else "",
		"tier": layout.tier if layout != null else 1,
	}


func _boss_fighting() -> bool:
	if world == null:
		return false
	for enemy: EnemySim in world.enemies:
		if enemy.alive and enemy.is_boss() and enemy.state != EnemySim.State.IDLE:
			return true
	return false


func _enemies_on_guard() -> bool:
	if world == null or world.player == null or not world.player.alive:
		return false
	for enemy: EnemySim in world.enemies:
		if enemy.alive and enemy.state != EnemySim.State.IDLE and enemy.position.distance_to(world.player.position) < COMBAT_RADIUS:
			return true
	return false


func _switch_to(track: String) -> void:
	current_track = track
	if _players.is_empty():
		return
	var old := _players[_active]
	_active = 1 - _active
	var next := _players[_active]
	var fade := create_tween().set_parallel(true)
	fade.tween_property(old, "volume_db", -80.0, FADE_SECONDS)
	fade.chain().tween_callback(old.stop)
	if track.is_empty():
		return
	var stream: AudioStream = load(DIR + track + ".ogg")
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = track != "results"
	next.stream = stream
	next.volume_db = -80.0
	next.play()
	create_tween().tween_property(next, "volume_db", 0.0, FADE_SECONDS)
