## Captura del entorno de los pisos: peligros del suelo, barriles, cofres, eventos y notas cerca del jugador.
## Necesita renderer real:  CAPTURE_DIR=$PWD/shots godot --path . res://tests/capture_environment.tscn
## FLOORS=3,5 elige los pisos (por defecto 3, 5, 7, 8).
extends Node

const MainScene := preload("res://game/main.tscn")

var _dir: String = ""
var _main: Node2D = null


func _ready() -> void:
	_dir = OS.get_environment("CAPTURE_DIR")
	if _dir.is_empty():
		_dir = ProjectSettings.globalize_path("user://captures")
	DirAccess.make_dir_recursive_absolute(_dir)
	OS.set_environment("PIXELCOMBAT_NO_SAVE", "1")
	OS.set_environment("PIXELCOMBAT_NO_CREATOR", "1")
	_main = MainScene.instantiate()
	add_child(_main)
	await _wait(0.5)
	var session: GameSession = _main.get("session")
	var world: CombatWorld = _main.get("world")
	var floors := [3, 5, 7, 8]
	var wanted := OS.get_environment("FLOORS")
	if not wanted.is_empty():
		floors = []
		for part: String in wanted.split(","):
			floors.append(int(part))
	for floor_number: int in floors:
		for n: int in range(1, floor_number):
			session.tower.complete(n)
		world.player.set_level(10)
		session.go_to_floor(floor_number)
		await _wait(0.6)
		var spots: Array = []
		if not session.layout.village.is_empty():
			spots.append(["village", (session.layout.village["position"] as Vector2) + Vector2(0, 30)])
		var camp_count := 0
		for camp: Dictionary in session.layout.camps:
			if String(camp["kind"]) == "camp" and camp_count < 2:
				camp_count += 1
				spots.append(["camp_%d" % camp_count, (camp["position"] as Vector2) + Vector2(0, 110)])
		for hazard: Dictionary in session.layout.hazards:
			spots.append(["hazard_%s" % hazard["kind"], hazard["position"] as Vector2 + Vector2(0, 50)])
		for enemy: EnemySim in world.enemies:
			if String(enemy.def_id).begins_with("barrel_"):
				spots.append(["barrel_near_%s" % enemy.def_id, enemy.position + Vector2(0, 80)])
				break
		for object: Interactable in world.interactables:
			if ["chest", "vault", "key", "note", "event_option"].has(object.kind):
				spots.append(["object_%s" % object.kind, object.position + Vector2(0, 70)])
		var seen := {}
		for entry: Array in spots:
			if seen.has(entry[0]):
				continue
			seen[entry[0]] = true
			world.player.position = entry[1]
			await _wait(1.6)
			await _shot("env_f%d_%s" % [floor_number, entry[0]])
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])
